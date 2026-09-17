# Aplicações do domínio "pedidos"

```
cliente → order-api (Go) → Postgres (INSERT, status PENDING)
                         → RabbitMQ  exchange "orders" → fila "orders.created"
                                                          ↓
                                   payment-worker (Python) → Postgres (UPDATE → PAID)
                                                          ↓ falha
                                        exchange "orders.dlx" → fila "orders.dead" (DLQ)
```

## order-api (porta 8080)

| Rota | Descrição |
|---|---|
| `POST /orders` | Cria pedido: `{"customer_id":"c1","amount_cents":1000,"currency":"BRL"}` |
| `GET /orders/{id}` | Consulta pedido |
| `GET /healthz` | Liveness: responde 200 desde o primeiro instante (o processo está vivo) |
| `GET /readyz` | Readiness: checa Postgres e RabbitMQ; 503 enquanto conectando |
| `GET/PUT /chaos` | Injeção de falhas (só com `CHAOS_ENABLED=true`) |

### Injetando falhas (chaos)

São comandos separados — um consulta, um liga, outro normaliza:

```bash
curl localhost:8080/chaos                                                 # estado atual
curl -X PUT localhost:8080/chaos -d '{"latency_ms":800,"error_rate":0.2}' # +800 ms e 20% de erro
curl -X PUT localhost:8080/chaos -d '{"latency_ms":0,"error_rate":0}'     # volta ao normal
```

Exercício: rode `make k6` em um terminal e ligue o chaos em outro. Os thresholds passam a falhar (✗)
e a distribuição de latência muda. Na Fase 7 isso vira gráfico e alerta de burn rate no Grafana.

## payment-worker (health na porta 8081)

Consome `orders.created`, simula processamento (50–300 ms) e marca o pedido como `PAID`.
Com probabilidade `FAIL_RATE` (padrão 5%), simula falha e manda a mensagem para a DLQ; o pedido fica `PENDING`.

## Decisões de design

- **Logs JSON estruturados** nas duas aplicações, prontos para o Loki (Fase 7).
- **Liveness ≠ readiness**: `/healthz` não consulta dependências, para uma queda do banco não reiniciar todos os pods em cascata.
- **HTTP antes das dependências**: o servidor sobe primeiro e conecta em banco e fila em background, então a startup probe recebe resposta HTTP em vez de "connection refused" (ver ADR 0002).
- **Crash-only**: se perder a conexão com o banco ou a fila, o processo encerra e o orquestrador reinicia. Mensagens sem ack voltam para a fila.
- **Publisher confirms** na API e **consumo idempotente** no worker (`WHERE status = 'PENDING'`).
- **Imagens mínimas e não-root**: Go em distroless static; Python em slim com venv copiado. Containers com filesystem read-only e sem capabilities.

## Problemas intencionais (viram exercícios)

| Problema | Onde aparece | Fase |
|---|---|---|
| INSERT no banco e publish na fila não são atômicos: pedido pode ficar PENDING para sempre | `handlers.go` | 8 (padrão Outbox) |
| Sem retry com backoff: falha transitória vai direto para a DLQ | worker | 8 (retry queue com TTL) |
| Sem métricas nem traces | ambos | 7 (OpenTelemetry) |
| Nenhum alerta para pedidos presos em PENDING ou DLQ crescendo | — | 7 (SLOs e alertas) |
| Sem testes automatizados | ambos | 5 (pipeline) |
| Thresholds do k6 são chutados, não derivados de SLO | `load/baseline.js` | 7 (SLOs) |
