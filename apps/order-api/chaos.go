package main

import (
	"encoding/json"
	"log/slog"
	"math"
	"math/rand/v2"
	"net/http"
	"sync/atomic"
	"time"
)

// Chaos injeta latência e erros nas rotas de pedidos para queimar error budget,
// disparar alertas e treinar troubleshooting. Só é exposto com CHAOS_ENABLED=true.
type Chaos struct {
	latencyMs atomic.Int64
	errorRate atomic.Uint64 // float64 armazenado como bits
}

type chaosConfig struct {
	LatencyMs int64   `json:"latency_ms"`
	ErrorRate float64 `json:"error_rate"`
}

func (c *Chaos) snapshot() chaosConfig {
	return chaosConfig{
		LatencyMs: c.latencyMs.Load(),
		ErrorRate: math.Float64frombits(c.errorRate.Load()),
	}
}

func (c *Chaos) Middleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		cfg := c.snapshot()
		if cfg.LatencyMs > 0 {
			select {
			case <-time.After(time.Duration(cfg.LatencyMs) * time.Millisecond):
			case <-r.Context().Done():
				return
			}
		}
		if cfg.ErrorRate > 0 && rand.Float64() < cfg.ErrorRate {
			writeError(w, http.StatusInternalServerError, "erro injetado (chaos)")
			return
		}
		next.ServeHTTP(w, r)
	})
}

func (c *Chaos) get(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, c.snapshot())
}

func (c *Chaos) put(w http.ResponseWriter, r *http.Request) {
	var cfg chaosConfig
	if err := json.NewDecoder(http.MaxBytesReader(w, r.Body, 1<<10)).Decode(&cfg); err != nil {
		writeError(w, http.StatusBadRequest, "JSON inválido")
		return
	}
	if cfg.LatencyMs < 0 || cfg.LatencyMs > 10000 || cfg.ErrorRate < 0 || cfg.ErrorRate > 1 {
		writeError(w, http.StatusUnprocessableEntity, "latency_ms entre 0 e 10000; error_rate entre 0 e 1")
		return
	}
	c.latencyMs.Store(cfg.LatencyMs)
	c.errorRate.Store(math.Float64bits(cfg.ErrorRate))
	slog.Warn("configuração de chaos alterada", "latency_ms", cfg.LatencyMs, "error_rate", cfg.ErrorRate)
	writeJSON(w, http.StatusOK, cfg)
}
