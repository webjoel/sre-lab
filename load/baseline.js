// Carga sustentada com rampa. Serve para medir a latência normal da aplicação
// e para alimentar dashboards, SLOs e a análise de canary nas próximas fases.
//
//   k6 run load/baseline.js                        # padrão: 10 VUs por 1 minuto
//   k6 run -e VUS=30 -e DURATION=3m load/baseline.js
import { sleep } from 'k6';
import { createOrder, getOrder } from './lib/orders.js';

const VUS = Number(__ENV.VUS || 10);
const DURATION = __ENV.DURATION || '1m';

export const options = {
  stages: [
    { duration: '20s', target: VUS }, // rampa de subida: evita medir só o "susto" inicial
    { duration: DURATION, target: VUS }, // patamar: é daqui que sai a latência de referência
    { duration: '10s', target: 0 }, // descida suave
  ],
  thresholds: {
    // Estes números são um ponto de partida. Na Fase 7 eles passam a vir dos SLOs definidos
    // para a aplicação, e o mesmo alvo passa a valer aqui e no alerta de burn rate.
    'http_req_duration{name:POST /orders}': ['p(95)<500', 'p(99)<1000'],
    'http_req_duration{name:GET /orders/{id}}': ['p(95)<200'],
    http_req_failed: ['rate<0.01'], // menos de 1% de erro
  },
};

export default function () {
  const order = createOrder();
  if (order) {
    sleep(0.3); // dá tempo do worker processar antes da consulta
    getOrder(order.id);
  }
  sleep(Math.random() * 0.5); // think time: usuários reais não disparam em loop fechado
}
