# sre-lab

Laboratório de SRE rodando localmente no Ubuntu: Kubernetes (kind), Terraform, GitOps, DevSecOps,
observabilidade com SLOs e IA aplicada a operações.

> Status: **Fases 0 e 1 concluídas** — próxima: Fase 2 (Kubernetes)

## Pré-requisitos

Ubuntu (x86_64) com Docker Engine e o plugin Docker Compose (v2 ou v5 — o que importa é ser o
plugin `docker compose`, não o antigo `docker-compose`).

Opcional, recomendado em máquinas com 16 GiB: **zram**, que cria swap comprimida na própria RAM.
Quando a memória enche, páginas menos usadas são comprimidas em vez de ir para o disco (lento) ou
de o kernel matar processos.

```bash
sudo apt install -y zram-tools
sudo sed -i 's/^#\?PERCENT=.*/PERCENT=50/' /etc/default/zramswap
sudo systemctl restart zramswap
swapon --show
```

As demais ferramentas são instaladas pelos métodos oficiais de cada projeto, com checksum conferido:

```bash
make tools                    # base + núcleo: make, git, jq, gh, pre-commit, kind, kubectl, terraform, tflint
make tools ALVOS="troubleshoot"  # diagnóstico do host: tmux, htop, sysstat, lsof, strace, tcpdump, dig...
make tools ALVOS="podman"     # Podman, skopeo, buildah e dive (exercícios de container)
make tools ALVOS="go"         # Go (opcional; o build da API roda em container)
make tools ALVOS="fase2"      # Helm, k9s, kubectx e kubens, quando chegar na Fase 2
make versions                 # tabela de versões para registrar abaixo
make clean-tools              # diagnostica versões antigas duplicadas (não remove nada)
make clean-tools ARGS=--apply # remove as antigas, pedindo confirmação
```

### Versões testadas

| Ferramenta | Versão |
|---|---|
| Docker | Docker version 29.8.1, build 4a63305 |
| Docker Compose | 5.5.1 |
| Podman | podman version 4.9.3 |
| skopeo | não instalado |
| dive | não instalado |
| kind | kind v0.33.0 go1.26.7 linux/amd64 |
| kubectl | Client Version: v1.37.0 |
| Terraform | Terraform v1.16.3 |
| tflint | TFLint version 0.64.0 |
| pre-commit | pre-commit 4.6.2 |
| Python | Python 3.12.3 |
| jq | jq-1.7 |
| GitHub CLI | gh version 2.101.0 (2026-09-15) |
| Go | go version go1.27.1 linux/amd64 |
| Helm | v4.3.0 |
| k9s | Version              v0.51.0 |
| kubectx | v0.0.0+unknown |
| AWS CLI | não instalado |

## Primeiros passos

```bash
make host-setup          # ajusta inotify do Ubuntu para o kind (uma vez, pede sudo)
cp .env.example .env     # coloque seu LOCALSTACK_AUTH_TOKEN
make hooks               # instala e atualiza os hooks do pre-commit
make up                  # cria o cluster kind + LocalStack
export KUBECONFIG=~/.kube/sre-lab
kubectl get nodes
make down                # destrói tudo
```

`make help` lista todos os comandos.

## Fase 1: rodando as aplicações

```bash
make go-tidy     # uma vez: gera o go.sum da order-api (ou 'go mod tidy' se tiver Go local)
make app-up      # builda e sobe tudo em docker compose
make smoke       # cria um pedido e espera virar PAID
make k6-smoke    # teste de fumaça com k6
make k6          # carga com k6: latência p95/p99 e taxa de erro
make images      # compara tamanho das imagens Go vs Python
make app-down
```

Depois de um reboot, os containers ficam parados mas não somem: `docker compose start` religa sem
rebuild. `make app-down` remove os volumes e zera o banco.

Detalhes da API, do chaos e dos problemas intencionais em `apps/README.md`; testes de carga em `load/README.md`.

### Injetando falhas (chaos)

A API expõe um endpoint de injeção de falhas quando sobe com `CHAOS_ENABLED=true` (o padrão no compose).
São dois comandos separados — um liga, outro normaliza:

```bash
curl localhost:8080/chaos                                                 # estado atual
curl -X PUT localhost:8080/chaos -d '{"latency_ms":800,"error_rate":0.2}' # +800 ms e 20% de erro
curl -X PUT localhost:8080/chaos -d '{"latency_ms":0,"error_rate":0}'     # volta ao normal
```

Exercício: rode `make k6` em um terminal e ligue o chaos em outro. Os thresholds passam a falhar (✗)
e a distribuição de latência muda. Na Fase 7 isso vira gráfico e alerta de burn rate no Grafana.

### Inspecionando banco e filas

```bash
# Quantos pedidos em cada estado, e a janela de tempo de cada grupo
docker exec sre-lab-apps-postgres-1 psql -U pedidos -d pedidos -c "
SELECT status, count(*),
       min(created_at)::time AS mais_antigo,
       max(created_at)::time AS mais_recente
FROM orders GROUP BY status;"

# Psql interativo
docker exec -it sre-lab-apps-postgres-1 psql -U pedidos -d pedidos

# Profundidade das filas (orders.created = pendente de processar; orders.dead = DLQ)
docker exec sre-lab-apps-rabbitmq-1 rabbitmqctl list_queues name messages

# Acompanhar a fila crescer durante a carga (consumer lag em tempo real)
watch -n2 'docker exec sre-lab-apps-rabbitmq-1 rabbitmqctl list_queues name messages'

# Logs das aplicações (JSON estruturado)
make app-logs
```

Painel do RabbitMQ: <http://localhost:15672> (usuário e senha `pedidos`). Nas mensagens da DLQ,
o cabeçalho `x-death` mostra quantas vezes a mensagem falhou e por quê.

### Medições da linha de base (Fase 1)

Primeira execução de `make k6` (10 VUs, 1 min), para servir de referência:

| Métrica | Valor |
|---|---|
| `POST /orders` p95 | ~8,6 ms |
| `POST /orders` p99 | ~10,7 ms |
| `GET /orders/{id}` p95 | ~2,4 ms |
| `http_req_failed` | 0,00% |
| Pedidos criados em 90 s | ~1.345 (≈15/s) |

**Três achados que viram exercício nas próximas fases:**

1. **Os thresholds atuais são frouxos.** O limite era p95 < 500 ms e a realidade foi 8,6 ms — a
   aplicação poderia ficar 50× mais lenta sem o teste reclamar. Na Fase 7 o número passa a vir do SLO.
2. **A taxa de erro de 0% engana.** O worker falha de propósito em ~5% e manda para a DLQ, deixando o
   pedido em `PENDING` — e o k6 não vê nada, porque a API respondeu 201. "A API respondeu" não é
   "o pedido foi processado": é a diferença entre SLI técnico e SLI de negócio.
3. **O worker não acompanha a vazão da API.** A API cria ~15 pedidos/s; o worker processa ~5,7/s
   (50–300 ms por mensagem, um de cada vez). A fila acumula durante o teste e leva minutos para
   drenar. Isso é **consumer lag**, sem nenhum erro aparecer. Cuidado com a armadilha: `PREFETCH=10`
   não resolve — prefetch controla a entrega antecipada, não o paralelismo do consumidor.
   Na Fase 4 o KEDA passa a escalar o worker pelo tamanho da fila.

## Plataforma (Fase 4)

`docs/fase4-plataforma.md` detalha Keycloak (SSO e OIDC), Vault, Kyverno, CloudNativePG e a
migração de Ingress para Gateway API.

## Dados e mensageria

`docs/dados-e-mensageria.md` explica o papel de PostgreSQL, Redis, RabbitMQ, Kafka e MongoDB
no lab, o custo de memória de cada um e em que fase entram.

## Troubleshooting

`docs/troubleshooting.md` reúne as ferramentas de diagnóstico do host, como investigar dentro de
containers mínimos (que não têm shell) e exercícios práticos.

## Decisões

Veja `docs/adr/`. A primeira decisão (ADR 0001) explica o dimensionamento para uma máquina com 16 GiB de RAM.

## Roadmap

| Fase | Tema | Status |
|---|---|---|
| 0 | Fundação: ferramentas, pre-commit, CI | concluída (cluster kind a validar com `make up`) |
| 1 | Aplicação e containers | concluída |
| 2 | Kubernetes | — |
| 3 | Terraform (state remoto, LocalStack, bootstrap ArgoCD) | — |
| 4 | Plataforma (Keycloak, Vault, Kyverno, Gateway API, CloudNativePG, KEDA) | — |
| 5 | CI/CD e GitOps | — |
| 6 | DevSecOps | — |
| 7 | Observabilidade e SLOs | — |
| 8 | Automação e dados | — |
| 9 | IA e LLMOps | — |
| 10 | Game days | — |
