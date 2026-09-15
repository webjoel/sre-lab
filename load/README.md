# Testes de carga (k6)

| Arquivo | Para quê |
|---|---|
| `smoke.js` | Teste de fumaça: 5 requisições, 1 usuário. Valida o fluxo antes de gastar tempo com carga |
| `baseline.js` | Carga sustentada com rampa. Mede a latência de referência da aplicação |
| `lib/orders.js` | Funções e métricas compartilhadas |

## Rodando

```bash
make k6-smoke                          # fumaça
make k6                                # baseline com 10 VUs por 1 minuto
make k6 VUS=30 DURATION=3m             # carga maior
BASE_URL=http://outro:8080 make k6     # contra outro alvo
```

O k6 roda em container, então não é preciso instalar nada (`--network host` para alcançar a API em `localhost`).

## Lendo a saída

- `http_req_duration` — latência total. Olhe **p(95)** e **p(99)**, não a média: a média esconde a cauda, e é a cauda que o usuário sente.
- `http_req_failed` — taxa de erro. É o SLI de disponibilidade.
- `order_create_duration` / `order_get_duration` — métricas por endpoint, porque o p95 agregado esconde qual rota está lenta.
- `checks` — validações de conteúdo (status, corpo da resposta).
- ✓ ou ✗ ao lado de cada **threshold**: se algum falhar, o k6 sai com código diferente de zero. É isso que permite usá-lo como gate no pipeline (Fase 5).

## Thresholds e SLOs

Os thresholds do `baseline.js` são um ponto de partida. Na Fase 7, quando os SLOs forem definidos,
o mesmo alvo de latência passa a valer em dois lugares: aqui (antes do deploy) e no alerta de
burn rate (depois do deploy). Essa conexão é o que transforma um teste de carga em ferramenta de confiabilidade.

## Exercício: queimando error budget

Com o baseline rodando em um terminal, injete falhas em outro:

```bash
curl -X PUT localhost:8080/chaos -d '{"latency_ms":800,"error_rate":0.2}'
curl -X PUT localhost:8080/chaos -d '{"latency_ms":0,"error_rate":0}'    # normaliza
```

Observe os thresholds falhando e a distribuição de latência mudando. Na Fase 7 isso vira gráfico no Grafana.

## Cuidado com a máquina

O k6 e o cluster dividem a mesma CPU. Com VUs demais você mede a saturação do seu notebook,
não a da aplicação. Se a latência subir mas a CPU da aplicação estiver baixa, o gargalo é o gerador de carga.
