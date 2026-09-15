package main

import (
	"context"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

func connectDB(ctx context.Context, url string) (*pgxpool.Pool, error) {
	cfg, err := pgxpool.ParseConfig(url)
	if err != nil {
		return nil, err
	}
	cfg.MaxConns = 10

	var pool *pgxpool.Pool
	err = retry(ctx, 15, 2*time.Second, "postgres", func() error {
		p, err := pgxpool.NewWithConfig(ctx, cfg)
		if err != nil {
			return err
		}
		if err := p.Ping(ctx); err != nil {
			p.Close()
			return err
		}
		pool = p
		return nil
	})
	return pool, err
}
