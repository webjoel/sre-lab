// order-api: API REST de pedidos do sre-lab.
package main

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	amqp "github.com/rabbitmq/amqp091-go"
)

type Config struct {
	Port         string
	DatabaseURL  string
	AMQPURL      string
	ChaosEnabled bool
}

func loadConfig() Config {
	return Config{
		Port:         getenv("PORT", "8080"),
		DatabaseURL:  getenv("DATABASE_URL", "postgres://pedidos:pedidos@localhost:5432/pedidos?sslmode=disable"),
		AMQPURL:      getenv("AMQP_URL", "amqp://pedidos:pedidos@localhost:5672/"),
		ChaosEnabled: os.Getenv("CHAOS_ENABLED") == "true",
	}
}

func getenv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func main() {
	os.Exit(run())
}

func run() int {
	slog.SetDefault(slog.New(slog.NewJSONHandler(os.Stdout, nil)))
	cfg := loadConfig()

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	chaos := &Chaos{}
	app := &App{}

	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", app.healthz)
	mux.HandleFunc("GET /readyz", app.readyz)
	mux.Handle("POST /orders", chaos.Middleware(http.HandlerFunc(app.createOrder)))
	mux.Handle("GET /orders/{id}", chaos.Middleware(http.HandlerFunc(app.getOrder)))
	if cfg.ChaosEnabled {
		mux.HandleFunc("GET /chaos", chaos.get)
		mux.HandleFunc("PUT /chaos", chaos.put)
	}

	srv := &http.Server{
		Addr:              ":" + cfg.Port,
		Handler:           accessLog(mux),
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       10 * time.Second,
		WriteTimeout:      30 * time.Second,
		IdleTimeout:       60 * time.Second,
	}

	// O servidor HTTP sobe ANTES de conectar em Postgres e RabbitMQ. Assim /healthz
	// responde 200 desde o primeiro instante (o processo está vivo) e /readyz responde 503
	// enquanto as dependências não estão prontas. Sem isso, a startup probe recebe
	// "connection refused" e o Kubernetes não distingue "inicializando" de "morto".
	serverErr := make(chan error, 1)
	go func() {
		slog.Info("servidor HTTP iniciado", "port", cfg.Port, "chaos_enabled", cfg.ChaosEnabled)
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			serverErr <- err
		}
	}()

	// Conecta nas dependências em background, com retry. Enquanto não terminar,
	// a aplicação está viva mas não pronta.
	depsReady := make(chan struct{})
	depsFailed := make(chan error, 1)
	go func() {
		pool, err := connectDB(ctx, cfg.DatabaseURL)
		if err != nil {
			depsFailed <- err
			return
		}
		broker, err := connectBroker(ctx, cfg.AMQPURL)
		if err != nil {
			pool.Close()
			depsFailed <- err
			return
		}
		app.setDeps(pool, broker)
		slog.Info("dependências conectadas; aplicação pronta")
		close(depsReady)
	}()

	exitCode := 0
	var brokerClosed <-chan *amqp.Error

	for {
		select {
		case <-ctx.Done():
			slog.Info("sinal de encerramento recebido")
		case err := <-serverErr:
			slog.Error("servidor HTTP falhou", "err", err)
			exitCode = 1
		case err := <-depsFailed:
			slog.Error("não foi possível conectar nas dependências", "err", err)
			exitCode = 1
		case <-depsReady:
			// Passa a vigiar a conexão com o broker só depois que ela existe.
			// Design crash-only: se cair, o processo encerra e o orquestrador reinicia.
			brokerClosed = app.brokerClosed()
			depsReady = nil // evita reentrar neste caso
			continue
		case amqpErr := <-brokerClosed:
			slog.Error("conexão com RabbitMQ perdida", "err", amqpErr)
			exitCode = 1
		}
		break
	}

	shutdownCtx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	if err := srv.Shutdown(shutdownCtx); err != nil {
		slog.Error("shutdown do servidor HTTP com erro", "err", err)
		exitCode = 1
	}
	app.closeDeps()
	slog.Info("order-api encerrada", "exit_code", exitCode)
	return exitCode
}

// retry executa fn até dar certo, com espera fixa entre tentativas.
func retry(ctx context.Context, attempts int, wait time.Duration, what string, fn func() error) error {
	var err error
	for i := 1; i <= attempts; i++ {
		if err = fn(); err == nil {
			return nil
		}
		slog.Warn("tentativa de conexão falhou", "dependencia", what, "tentativa", i, "err", err)
		select {
		case <-ctx.Done():
			return ctx.Err()
		case <-time.After(wait):
		}
	}
	return err
}
