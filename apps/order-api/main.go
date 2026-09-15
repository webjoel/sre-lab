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

	pool, err := connectDB(ctx, cfg.DatabaseURL)
	if err != nil {
		slog.Error("falha ao conectar no Postgres", "err", err)
		return 1
	}
	defer pool.Close()

	broker, err := connectBroker(ctx, cfg.AMQPURL)
	if err != nil {
		slog.Error("falha ao conectar no RabbitMQ", "err", err)
		return 1
	}
	defer broker.Close()

	chaos := &Chaos{}
	app := &App{db: pool, broker: broker}

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

	serverErr := make(chan error, 1)
	go func() {
		slog.Info("order-api iniciada", "port", cfg.Port, "chaos_enabled", cfg.ChaosEnabled)
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			serverErr <- err
		}
	}()

	exitCode := 0
	select {
	case <-ctx.Done():
		slog.Info("sinal de encerramento recebido")
	case err := <-serverErr:
		slog.Error("servidor HTTP falhou", "err", err)
		exitCode = 1
	case amqpErr := <-broker.Closed():
		// Design crash-only: sem reconexão elaborada; o orquestrador (Docker/Kubernetes) reinicia o processo.
		slog.Error("conexão com RabbitMQ perdida", "err", amqpErr)
		exitCode = 1
	}

	shutdownCtx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	if err := srv.Shutdown(shutdownCtx); err != nil {
		slog.Error("shutdown do servidor HTTP com erro", "err", err)
		exitCode = 1
	}
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
