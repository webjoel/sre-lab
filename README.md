# sre-lab

Laboratório de SRE rodando localmente no Ubuntu: Kubernetes (kind), Terraform, GitOps, DevSecOps,
observabilidade com SLOs e IA aplicada a operações.

> Status: **Fase 1 — Aplicação e containers**

## Pré-requisitos

Ubuntu (x86_64) com Docker Engine e o plugin Docker Compose.
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
| Docker | Docker version 29.8.0, build 88096ef |
| Docker Compose | 5.5.1 |
| Podman | podman version 4.9.3 |
| skopeo | não instalado |
| dive | não instalado |
| kind | kind v0.33.0 go1.26.7 linux/amd64 |
| kubectl | Client Version: v1.37.0 |
| Terraform | Terraform v1.16.2 |
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
make go-tidy     # uma vez: gera o go.sum da order-api
make app-up      # builda e sobe tudo em docker compose
make smoke       # cria um pedido e espera virar PAID
make k6-smoke    # teste de fumaça com k6
make k6          # carga com k6: latência p95/p99 e taxa de erro
make images      # compara tamanho das imagens Go vs Python
make app-down
```

Detalhes da API, do chaos e dos problemas intencionais em `apps/README.md`; testes de carga em `load/README.md`.

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
| 0 | Fundação: kind, LocalStack, pre-commit, CI básico | concluída |
| 1 | Aplicação e containers | em andamento |
| 2 | Kubernetes | — |
| 3 | Terraform (state remoto, LocalStack, bootstrap ArgoCD) | — |
| 4 | Plataforma (Keycloak, Vault, Kyverno, Gateway API, CloudNativePG, KEDA) | — |
| 5 | CI/CD e GitOps | — |
| 6 | DevSecOps | — |
| 7 | Observabilidade e SLOs | — |
| 8 | Automação e dados | — |
| 9 | IA e LLMOps | — |
| 10 | Game days | — |
