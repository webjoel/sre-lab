# sre-lab

Laboratório de SRE rodando localmente no Ubuntu: Kubernetes (kind), Terraform, GitOps, DevSecOps,
observabilidade com SLOs e IA aplicada a operações.

> Status: **Fase 2 — Kubernetes**

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

Uma vez por máquina:

```bash
make host-setup          # ajusta o inotify do Ubuntu para o kind (pede sudo)
make hooks               # instala e atualiza os hooks do pre-commit
make prereqs             # confere ferramentas, Docker, RAM e inotify
```

`make help` lista todos os comandos.

## Fase 1 — Aplicações em containers

O caminho mais curto para ver o lab funcionando. Não precisa de cluster.

```bash
make go-tidy     # uma vez: gera o go.sum da order-api (ou 'go mod tidy' se tiver Go local)
make app-up      # builda e sobe API, worker, Postgres e RabbitMQ em docker compose
make smoke       # cria um pedido e espera virar PAID
make k6-smoke    # teste de fumaça com k6
make k6          # carga com k6: latência p95/p99 e taxa de erro
make images      # compara o tamanho das imagens Go vs Python
make app-down    # derruba e apaga os volumes
```

Depois de um reboot, os containers ficam parados mas não somem: `docker compose start` religa sem
rebuild. `make app-down` remove os volumes e zera o banco.

**Onde está o quê:**

| Assunto | Arquivo |
|---|---|
| Rotas da API, injeção de falhas (chaos), decisões de design, problemas intencionais | `apps/README.md` |
| Cenários de carga, thresholds, como ler a saída do k6 | `load/README.md` |
| Diagnóstico: host, dentro de containers, banco e filas | `docs/troubleshooting.md` |

## Fase 2 — Kubernetes

Subir o cluster:

```bash
make up                  # cria o cluster kind via Terraform
export KUBECONFIG=~/.kube/sre-lab
kubectl get nodes
make status              # nós, pods e consumo de memória
make down                # destrói o cluster
```

Levar as aplicações para o cluster (chart Helm em `deploy/charts/pedidos`):

```bash
make k8s-lint            # valida o chart sem aplicar
make k8s-up              # builda, carrega no kind e instala a release
make k8s-status          # pods, services, PVCs e eventos
make k8s-fwd             # expõe a API em localhost:8080 (bloqueia o terminal)
make k8s-logs            # logs das aplicações
make k8s-psql            # psql no Postgres do cluster
make k8s-queues          # profundidade das filas
make k8s-down            # remove a release (PVCs sobrevivem)
```

Decisões do chart, problemas intencionais e sete exercícios de troubleshooting em
`docs/fase2-kubernetes.md`.

O LocalStack só é necessário a partir da Fase 3 (Terraform criando recursos "AWS"). Quando chegar lá:
`cp .env.example .env`, coloque o `LOCALSTACK_AUTH_TOKEN` (conta gratuita) e rode `make localstack-up`.

### Medições

Mesmo teste (`make k6`: 10 VUs, rampa + 1 min de patamar) nos dois ambientes:

| Métrica | Fase 1 (docker compose) | Fase 2 (cluster, via port-forward) | Diferença |
|---|---|---|---|
| `POST /orders` p95 | 8,64 ms | 15,11 ms | +75% |
| `POST /orders` p99 | 10,68 ms | 19,44 ms | +82% |
| `GET /orders/{id}` p95 | 2,38 ms | 4,97 ms | +109% |
| `http_req_failed` | 0,00% | 0,00% | — |
| Vazão | 29,81 req/s | 29,83 req/s | — |
| Pedidos criados em 90 s | 1.345 | 1.344 | — |

**A vazão idêntica é o dado mais informativo da tabela.** Os dois ambientes pararam em ~29,8 req/s,
o que significa que o teto veio do gerador de carga (10 VUs com think time), não da aplicação.
Ou seja: mediu-se latência sob carga leve, e nenhum dos dois ambientes chegou perto de saturar.

**Por que a latência dobrou no cluster.** Resistir à conclusão fácil de "Kubernetes é mais lento" —
há quatro causas candidatas, e separá-las é o exercício:

1. **port-forward**: túnel de processo único; o tráfego passa por kubectl → apiserver → kubelet → pod.
   Principal suspeito. Testar sem o túnel, gerando carga de dentro do cluster:
   ```bash
   kubectl -n pedidos run k6-teste --rm -it --restart=Never \
     --image=grafana/k6:latest --env BASE_URL=http://pedidos-order-api \
     -- run - < load/baseline.js
   ```
2. **Rede do cluster**: CNI e kube-proxy adicionam saltos que não existem no compose.
3. **`requests` de CPU baixos** (25m): podem limitar sob concorrência.
4. **Tudo no mesmo nó**: os cinco pods competem pelos mesmos recursos (o control-plane tem taint
   `NoSchedule`, então nada é agendado nele).

### Achados que viram exercício nas próximas fases

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
4. **Medir com port-forward mede o port-forward também.** O método de medição faz parte do resultado;
   comparar ambientes exige igualar o caminho até a aplicação.

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
| 0 | Fundação: ferramentas, pre-commit, CI | concluída |
| 1 | Aplicação e containers | concluída |
| 2 | Kubernetes | em andamento |
| 3 | Terraform (state remoto, LocalStack, bootstrap ArgoCD) | — |
| 4 | Plataforma (Keycloak, Vault, Kyverno, Gateway API, CloudNativePG, KEDA) | — |
| 5 | CI/CD e GitOps | — |
| 6 | DevSecOps | — |
| 7 | Observabilidade e SLOs | — |
| 8 | Automação e dados | — |
| 9 | IA e LLMOps | — |
| 10 | Game days | — |
