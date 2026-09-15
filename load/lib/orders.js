// Funções compartilhadas entre os cenários de carga.
import { check } from 'k6';
import http from 'k6/http';
import { Trend } from 'k6/metrics';

export const BASE_URL = __ENV.BASE_URL || 'http://localhost:8080';

// Métricas customizadas por endpoint: o p95 agregado esconde qual rota está lenta.
export const createDuration = new Trend('order_create_duration', true);
export const getDuration = new Trend('order_get_duration', true);

const JSON_HEADERS = { headers: { 'Content-Type': 'application/json' } };

export function createOrder() {
  const payload = JSON.stringify({
    customer_id: `k6-${__VU}-${__ITER}`,
    amount_cents: Math.floor(Math.random() * 50000) + 100,
    currency: 'BRL',
  });

  // tags.name agrupa as métricas por rota lógica (evita cardinalidade alta com o id na URL).
  const res = http.post(`${BASE_URL}/orders`, payload, {
    ...JSON_HEADERS,
    tags: { name: 'POST /orders' },
  });

  createDuration.add(res.timings.duration);
  const ok = check(res, {
    'POST /orders devolve 201': (r) => r.status === 201,
    'resposta traz o id do pedido': (r) => !!r.json('id'),
  });

  return ok ? res.json() : null;
}

export function getOrder(id) {
  const res = http.get(`${BASE_URL}/orders/${id}`, { tags: { name: 'GET /orders/{id}' } });
  getDuration.add(res.timings.duration);
  check(res, { 'GET /orders/{id} devolve 200': (r) => r.status === 200 });
  return res.status === 200 ? res.json() : null;
}
