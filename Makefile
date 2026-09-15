SHELL := /bin/bash
.DEFAULT_GOAL := help

CLUSTER_NAME ?= sre-lab
TF_DIR       := infra/terraform/envs/local
export KUBECONFIG := $(HOME)/.kube/$(CLUSTER_NAME)

.PHONY: help
help: ## Lista os comandos disponíveis
	@grep -hE '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'

.PHONY: tools
tools: ## Instala ferramentas (ex.: make tools ALVOS="go fase2"; padrão: núcleo)
	@./scripts/install-tools.sh $(ALVOS)

.PHONY: clean-tools
clean-tools: ## Diagnostica cópias duplicadas/antigas de ferramentas (use ARGS=--apply para remover)
	@./scripts/clean-old-tools.sh $(ARGS)

.PHONY: versions
versions: ## Mostra as versões instaladas em tabela Markdown
	@./scripts/tool-versions.sh

.PHONY: prereqs
prereqs: ## Verifica ferramentas, Docker, RAM e limites do inotify
	@./scripts/check-prereqs.sh

.PHONY: host-setup
host-setup: ## Ajusta o Ubuntu para o kind (inotify persistente; pede sudo)
	@./scripts/host-setup.sh

.PHONY: up
up: prereqs cluster-up localstack-up status ## Sobe o ambiente completo da fase atual

.PHONY: down
down: localstack-down cluster-down ## Destroi todo o ambiente

.PHONY: cluster-up
cluster-up: ## Cria o cluster kind via Terraform
	terraform -chdir=$(TF_DIR) init -upgrade
	terraform -chdir=$(TF_DIR) apply -auto-approve -var="cluster_name=$(CLUSTER_NAME)"

.PHONY: cluster-down
cluster-down: ## Remove o cluster kind via Terraform
	terraform -chdir=$(TF_DIR) destroy -auto-approve -var="cluster_name=$(CLUSTER_NAME)"

.PHONY: localstack-up
localstack-up: ## Sobe o LocalStack (requer LOCALSTACK_AUTH_TOKEN no .env)
	@test -f .env || { echo "Crie o .env a partir do .env.example"; exit 1; }
	docker compose -f docker-compose.localstack.yml --env-file .env up -d --wait

.PHONY: localstack-down
localstack-down: ## Para o LocalStack
	-LOCALSTACK_AUTH_TOKEN=x docker compose -f docker-compose.localstack.yml down

.PHONY: status
status: ## Mostra nós, pods e consumo de memória
	@echo "== Nós =="; kubectl get nodes -o wide
	@echo; echo "== Pods =="; kubectl get pods -A
	@echo; echo "== Consumo dos containers (host) =="
	@docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"
	@echo; free -h

.PHONY: lint
lint: ## Roda todos os hooks do pre-commit em todos os arquivos
	pre-commit run --all-files

.PHONY: hooks
hooks: ## Instala os hooks do pre-commit e atualiza as versões
	pre-commit install
	pre-commit autoupdate

# ---------- Fase 1: aplicações em docker compose ----------

GO_IMAGE ?= golang:1.27

# k6 em container: nada para instalar. --network host permite alcançar a API em localhost.
K6_IMAGE ?= grafana/k6:latest
VUS      ?= 10
DURATION ?= 1m
K6 = docker run --rm -i --network host -v "$(CURDIR)":/work -w /work -e BASE_URL=$${BASE_URL:-http://localhost:8080} $(K6_IMAGE)

.PHONY: go-tidy
go-tidy: ## Gera o go.sum da order-api (usa Go em container; não precisa de Go instalado)
	docker run --rm -u $$(id -u):$$(id -g) -e GOCACHE=/tmp/gocache -e GOMODCACHE=/tmp/gomod \
		-v "$(CURDIR)/apps/order-api":/src -w /src $(GO_IMAGE) go mod tidy

.PHONY: app-up
app-up: ## Builda e sobe API, worker, Postgres e RabbitMQ
	@test -f apps/order-api/go.sum || { echo "Rode 'make go-tidy' primeiro"; exit 1; }
	docker compose up -d --build --wait

.PHONY: app-down
app-down: ## Derruba as aplicações e apaga os volumes
	docker compose down -v

.PHONY: app-logs
app-logs: ## Acompanha os logs das aplicações
	docker compose logs -f order-api payment-worker

.PHONY: smoke
smoke: ## Teste ponta a ponta: cria pedido e espera virar PAID
	@./scripts/smoke.sh

.PHONY: k6-smoke
k6-smoke: ## Teste de fumaça com k6 (rápido, valida o fluxo)
	@$(K6) run /work/load/smoke.js

.PHONY: k6
k6: ## Carga com k6 (ex.: make k6 VUS=30 DURATION=3m)
	@$(K6) run -e VUS=$(VUS) -e DURATION=$(DURATION) /work/load/baseline.js

.PHONY: images
images: ## Compara o tamanho das imagens das aplicações
	@docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" | grep -E "REPOSITORY|sre-lab-apps"
