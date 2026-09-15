// Teste de fumaça: 1 usuário virtual, poucas requisições. Valida que o fluxo funciona
// antes de gastar tempo com carga. É o que roda no PR, rápido e barato.
import { check } from 'k6';
import http from 'k6/http';
import { BASE_URL, createOrder, getOrder } from './lib/orders.js';

export const options = {
  vus: 1,
  iterations: 5,
  thresholds: {
    // Em teste de fumaça, qualquer erro é falha: não há tolerância a "ruído de carga".
    checks: ['rate==1.00'],
    http_req_failed: ['rate==0.00'],
  },
};

export function setup() {
  const res = http.get(`${BASE_URL}/readyz`);
  check(res, { 'aplicação pronta (readyz 200)': (r) => r.status === 200 });
  if (res.status !== 200) {
    throw new Error(`aplicação não está pronta: ${res.status} ${res.body}`);
  }
}

export default function () {
  const order = createOrder();
  if (order) {
    getOrder(order.id);
  }
}
