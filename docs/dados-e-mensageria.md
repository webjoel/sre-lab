# Bancos e mensageria no lab

O domínio "pedidos" cresce em duas etapas para cobrir os quatro sistemas, sem ligar tudo ao mesmo tempo
(a máquina tem 16 GiB).

## Arquitetura alvo

```
POST /orders → order-api (Go) ──→ PostgreSQL        (escrita: fonte da verdade)
                    │                  ↑
                    │                  └── Redis     (cache de leitura do GET /orders/{id})
                    │
                    ├──→ RabbitMQ  "orders.created"  → payment-worker → UPDATE status = PAID
                    │    (fila de trabalho: uma mensagem, um consumidor, DLQ)
                    │
                    └──→ Kafka     "order.events"    → projection-worker → MongoDB
                         (log de eventos: vários consumidores independentes, replay)
```

A mesma informação passa por dois caminhos de propósito, porque eles ensinam coisas diferentes:

| | RabbitMQ (fila) | Kafka (log de eventos) |
|---|---|---|
| Modelo | Mensagem consumida e removida | Log persistido; cada consumidor tem seu offset |
| Ordem | Por fila | Por partição |
| Reprocessar | Só com DLQ ou requeue | Voltar o offset e reler o histórico |
| O que dá errado | Fila crescendo, DLQ enchendo | Consumer lag, rebalanceamento, partição desbalanceada |
| Métrica que você vai alertar | Profundidade da fila | Lag do consumer group |

## Papel de cada sistema

**PostgreSQL** — fonte da verdade transacional. Operado pelo operator CloudNativePG (Fase 4):
réplica, failover, PgBouncer, backup para o S3 do LocalStack. Exercícios: `EXPLAIN ANALYZE`, índices,
locks em `pg_stat_activity`, esgotamento do pool de conexões.

**Redis** — cache do `GET /orders/{id}`. Ensina invalidação, TTL, e o cenário clássico de
cache stampede (muitas requisições ao banco quando a chave expira). Exercício: derrubar o Redis e
verificar se a aplicação degrada com elegância em vez de cair.

**Kafka** — stream de eventos de pedido, em modo KRaft (sem ZooKeeper, que foi removido no Kafka 4).
Exercícios: partições e chave de particionamento, consumer lag como SLI, reprocessar histórico
movendo o offset, e o que acontece quando o consumidor fica mais lento que o produtor.

**MongoDB** — modelo de leitura construído a partir dos eventos do Kafka (uma visão desnormalizada
de pedidos por cliente). Ensina consistência eventual: o Mongo pode estar atrasado em relação ao Postgres,
e o lag do consumer é justamente a medida desse atraso. Exercícios: índices, `explain`, replica set e eleição.

## Custo de memória e perfis

| Perfil | Componentes | RAM |
|---|---|---|
| `base` | Postgres + RabbitMQ + apps | ~1,2 GiB |
| `seguranca` | base + Keycloak, Vault, Kyverno, cert-manager, Envoy Gateway | ~2,5 GiB |
| `dados` | base + Redis + Kafka (1 broker) + MongoDB | ~2,5 GiB |

O perfil `dados` não roda junto com o de observabilidade completa. Para as fases de SLO,
use `base` mais observabilidade; para as fases de dados, use `dados` com Prometheus e Grafana apenas.

## Onde entra em cada fase

| Fase | O que acontece |
|---|---|
| 1 | Postgres e RabbitMQ em docker compose (pronto) |
| 4 | CloudNativePG, Redis e cluster do RabbitMQ no Kubernetes, via operators |
| 7 | Métricas dos quatro sistemas no Grafana; consumer lag e profundidade de fila viram SLIs |
| 8 | Kafka, `projection-worker` e MongoDB entram; exercícios de banco e de reprocessamento |
| 10 | Game days: derrubar a réplica do Postgres, encher a DLQ, saturar o consumer do Kafka |
