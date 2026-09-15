-- Schema do domínio de pedidos. Na Fase 4 isso passa a ser aplicado no bootstrap do CloudNativePG.
CREATE TABLE IF NOT EXISTS orders (
    id            uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id   text        NOT NULL,
    amount_cents  bigint      NOT NULL CHECK (amount_cents > 0),
    currency      char(3)     NOT NULL,
    status        text        NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'PAID')),
    created_at    timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz NOT NULL DEFAULT now()
);

-- Suporta a consulta "pedidos presos em PENDING há mais de N minutos" (alerta da Fase 7).
CREATE INDEX IF NOT EXISTS orders_status_created_at_idx ON orders (status, created_at);
