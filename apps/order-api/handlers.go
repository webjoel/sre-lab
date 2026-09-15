package main

import (
	"context"
	"encoding/json"
	"errors"
	"log/slog"
	"net/http"
	"regexp"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type App struct {
	db     *pgxpool.Pool
	broker *Broker
}

type Order struct {
	ID          string    `json:"id"`
	CustomerID  string    `json:"customer_id"`
	AmountCents int64     `json:"amount_cents"`
	Currency    string    `json:"currency"`
	Status      string    `json:"status"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
}

type createOrderRequest struct {
	CustomerID  string `json:"customer_id"`
	AmountCents int64  `json:"amount_cents"`
	Currency    string `json:"currency"`
}

func (r createOrderRequest) validate() error {
	switch {
	case strings.TrimSpace(r.CustomerID) == "":
		return errors.New("customer_id é obrigatório")
	case r.AmountCents <= 0:
		return errors.New("amount_cents deve ser maior que zero")
	case len(r.Currency) != 3:
		return errors.New("currency deve ter 3 letras (ex.: BRL)")
	}
	return nil
}

var uuidPattern = regexp.MustCompile(`^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$`)

const orderColumns = `id::text, customer_id, amount_cents, currency, status, created_at, updated_at`

func scanOrder(row pgx.Row, o *Order) error {
	return row.Scan(&o.ID, &o.CustomerID, &o.AmountCents, &o.Currency, &o.Status, &o.CreatedAt, &o.UpdatedAt)
}

func (a *App) createOrder(w http.ResponseWriter, r *http.Request) {
	r.Body = http.MaxBytesReader(w, r.Body, 1<<20)
	dec := json.NewDecoder(r.Body)
	dec.DisallowUnknownFields()

	var req createOrderRequest
	if err := dec.Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "JSON inválido")
		return
	}
	if err := req.validate(); err != nil {
		writeError(w, http.StatusUnprocessableEntity, err.Error())
		return
	}

	var o Order
	row := a.db.QueryRow(r.Context(),
		`INSERT INTO orders (customer_id, amount_cents, currency) VALUES ($1, $2, $3) RETURNING `+orderColumns,
		req.CustomerID, req.AmountCents, strings.ToUpper(req.Currency))
	if err := scanOrder(row, &o); err != nil {
		slog.Error("erro ao gravar pedido", "err", err)
		writeError(w, http.StatusInternalServerError, "erro ao gravar pedido")
		return
	}

	// PROBLEMA INTENCIONAL (exercício da Fase 8): gravar no banco e publicar na fila não é atômico.
	// Se o publish falhar, o pedido fica PENDING para sempre. A correção clássica é o padrão Outbox.
	evt := OrderCreated{OrderID: o.ID, AmountCents: o.AmountCents, Currency: o.Currency}
	if err := a.broker.PublishOrderCreated(r.Context(), evt); err != nil {
		slog.Error("pedido gravado mas evento não publicado", "order_id", o.ID, "err", err)
		writeError(w, http.StatusServiceUnavailable, "pedido gravado, mas não enviado para processamento")
		return
	}

	slog.Info("pedido criado", "order_id", o.ID, "amount_cents", o.AmountCents, "currency", o.Currency)
	w.Header().Set("Location", "/orders/"+o.ID)
	writeJSON(w, http.StatusCreated, o)
}

func (a *App) getOrder(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	if !uuidPattern.MatchString(id) {
		writeError(w, http.StatusNotFound, "pedido não encontrado")
		return
	}

	var o Order
	row := a.db.QueryRow(r.Context(), `SELECT `+orderColumns+` FROM orders WHERE id = $1`, id)
	if err := scanOrder(row, &o); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			writeError(w, http.StatusNotFound, "pedido não encontrado")
			return
		}
		slog.Error("erro ao consultar pedido", "order_id", id, "err", err)
		writeError(w, http.StatusInternalServerError, "erro ao consultar pedido")
		return
	}
	writeJSON(w, http.StatusOK, o)
}

// healthz (liveness): o processo está vivo. Não consulta dependências de propósito,
// para uma queda do banco não fazer o Kubernetes reiniciar todos os pods em cascata.
func (a *App) healthz(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

// readyz (readiness): consegue atender tráfego agora? Aqui sim, checa as dependências.
func (a *App) readyz(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithTimeout(r.Context(), 2*time.Second)
	defer cancel()

	checks := map[string]string{"postgres": "ok", "rabbitmq": "ok"}
	ready := true
	if err := a.db.Ping(ctx); err != nil {
		checks["postgres"] = err.Error()
		ready = false
	}
	if !a.broker.IsOpen() {
		checks["rabbitmq"] = "conexão fechada"
		ready = false
	}

	status := http.StatusOK
	if !ready {
		status = http.StatusServiceUnavailable
	}
	writeJSON(w, status, checks)
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}

func writeError(w http.ResponseWriter, status int, msg string) {
	writeJSON(w, status, map[string]string{"error": msg})
}

type statusRecorder struct {
	http.ResponseWriter
	status int
}

func (s *statusRecorder) WriteHeader(code int) {
	s.status = code
	s.ResponseWriter.WriteHeader(code)
}

func accessLog(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/healthz" || r.URL.Path == "/readyz" {
			next.ServeHTTP(w, r)
			return
		}
		start := time.Now()
		rec := &statusRecorder{ResponseWriter: w, status: http.StatusOK}
		next.ServeHTTP(rec, r)
		slog.Info("http_request",
			"method", r.Method,
			"path", r.URL.Path,
			"status", rec.status,
			"duration_ms", time.Since(start).Milliseconds())
	})
}
