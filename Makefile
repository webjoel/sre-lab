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

PINNED_FILES := Makefile docker-compose.yml docker-compose.localstack.yml \
                apps/*/Dockerfile deploy/charts/*/values.yaml

.PHONY: pin-images
pin-images: ## Compara cada imagem fixada por digest com o digest atual da tag no registry
	@grep -ohE '[a-z0-9./_-]+:[A-Za-z0-9._-]+@sha256:[0-9a-f]{64}' $(PINNED_FILES) | sort -u | \
	while read -r ref; do \
		tag=$${ref%@*}; pinado=$${ref#*@}; \
		atual=$$(docker buildx imagetools inspect "$$tag" --format '{{.Manifest.Digest}}' 2>/dev/null); \
		if [ -z "$$atual" ]; then echo "??  $$tag (registry inacessível)"; \
		elif [ "$$atual" = "$$pinado" ]; then echo "ok  $$tag"; \
		else echo "NOVA $$tag -> $$tag@$$atual"; fi; \
	done
	@echo
	@echo 'NOVA = a tag aponta para outro digest. Para atualizar, troque o digest em:'
	@echo '  $(PINNED_FILES)'
	@echo 'Digest é mais forte que tag: tag pode ser reescrita, digest não.'

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
up: prereqs cluster-up status ## Sobe o cluster kind (LocalStack só a partir da Fase 3)

.PHONY: down
down: localstack-down cluster-down ## Destrói o cluster (e o LocalStack, se estiver rodando)

.PHONY: cluster-up
cluster-up: ## Cria o cluster kind via Terraform
	terraform -chdir=$(TF_DIR) init -upgrade
	terraform -chdir=$(TF_DIR) apply -auto-approve -var="cluster_name=$(CLUSTER_NAME)"

.PHONY: cluster-down
cluster-down: ## Remove o cluster kind via Terraform
	terraform -chdir=$(TF_DIR) destroy -auto-approve -var="cluster_name=$(CLUSTER_NAME)"

.PHONY: localstack-up
localstack-up: ## Sobe o LocalStack — só necessário a partir da Fase 3 (requer .env)
	@test -f .env || { echo "Crie o .env a partir do .env.example"; exit 1; }
	docker compose -f docker-compose.localstack.yml --env-file .env up -d --wait

.PHONY: localstack-down
localstack-down: ## Para o LocalStack
	-LOCALSTACK_AUTH_TOKEN=x docker compose -f docker-compose.localstack.yml down

.PHONY: status
status: ## Visão da MÁQUINA: nós, todos os pods, consumo de memória dos containers
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

GO_IMAGE ?= golang:1.27@sha256:3680233e3204827fbdc66088528ae6d4b3d034f51d03a99d454f6de034888244

# BASE_URL é o alvo dos testes (smoke, k6). No compose a API responde direto em localhost:8080;
# no cluster é preciso um port-forward ativo (make k8s-fwd) apontando para a mesma porta.
BASE_URL ?= http://localhost:8080

# k6 em container: nada para instalar. --network host permite alcançar a API em localhost.
# Imagens fixadas por digest (tag mantida só para leitura; o digest é o que vale).
# 'make pin-images' mostra os digests atuais. Atualização vira PR do Dependabot na Fase 6.
K6_IMAGE         ?= grafana/k6:latest@sha256:5221b620a4f874faff6e32ba597aa667c058391fe4898b1c6f6377f062c6cdec
LOCALSTACK_IMAGE ?= localstack/localstack:latest@sha256:4abc29e923e5ed8a63d6c705a9dfa74b15d560e7055845299d87b22dabf9f6e2
VUS      ?= 10
DURATION ?= 1m
K6 = docker run --rm -i --network host -v "$(CURDIR)":/work -w /work -e BASE_URL=$(BASE_URL) $(K6_IMAGE)

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
smoke: ## Teste ponta a ponta (BASE_URL): cria pedido e espera virar PAID
	@./scripts/smoke.sh

.PHONY: k6-smoke
k6-smoke: ## Fumaça com k6 (BASE_URL): 5 requisições, valida que a API responde
	@$(K6) run /work/load/smoke.js

.PHONY: k6
k6: ## Carga com k6 (BASE_URL); ex.: make k6 VUS=30 DURATION=3m
	@$(K6) run -e VUS=$(VUS) -e DURATION=$(DURATION) /work/load/baseline.js

.PHONY: images
images: ## Compara o tamanho das imagens das aplicações
	@docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" | grep -E "REPOSITORY|sre-lab-apps"

# ---------- Fase 2: Kubernetes ----------

NAMESPACE ?= pedidos
K8S_VERSION ?= 1.35.0
KUBECONFORM_IMAGE ?= ghcr.io/yannh/kubeconform:v0.7.0@sha256:85dbef6b4b312b99133decc9c6fc9495e9fc5f92293d4ff3b7e1b30f5611823c
RELEASE   ?= pedidos
CHART     := deploy/charts/pedidos
IMAGE_TAG ?= dev

.PHONY: k8s-build
k8s-build: ## Builda as imagens e carrega no cluster kind (sem registry)
	docker build -t sre-lab/order-api:$(IMAGE_TAG) apps/order-api
	docker build -t sre-lab/payment-worker:$(IMAGE_TAG) apps/payment-worker
	kind load docker-image sre-lab/order-api:$(IMAGE_TAG) sre-lab/payment-worker:$(IMAGE_TAG) --name $(CLUSTER_NAME)

.PHONY: k8s-lint
k8s-lint: ## Valida o chart: lint, render e schema do Kubernetes (mesmas checagens do CI)
	helm lint $(CHART)
	@helm template $(RELEASE) $(CHART) --namespace $(NAMESPACE) > /tmp/sre-lab-render.yaml && echo "template OK"
	@if command -v kubeconform >/dev/null 2>&1; then \
		kubeconform -strict -summary -kubernetes-version $(K8S_VERSION) /tmp/sre-lab-render.yaml; \
	else \
		echo "kubeconform não instalado; usando container (make tools ALVOS=\"fase6\" instala local)"; \
		docker run --rm -i $(KUBECONFORM_IMAGE) -strict -summary -kubernetes-version $(K8S_VERSION) < /tmp/sre-lab-render.yaml; \
	fi

.PHONY: k8s-up
k8s-up: k8s-build ## Instala/atualiza a release no cluster
	helm upgrade --install $(RELEASE) $(CHART) \
		--namespace $(NAMESPACE) --create-namespace \
		--set image.tag=$(IMAGE_TAG) \
		--wait --timeout 5m

.PHONY: k8s-down
k8s-down: ## Remove a release (PVCs sobrevivem; use k8s-purge para apagar tudo)
	helm uninstall $(RELEASE) --namespace $(NAMESPACE) || true

.PHONY: k8s-purge
k8s-purge: k8s-down ## Remove a release, os PVCs e o namespace
	kubectl delete pvc --all -n $(NAMESPACE) --ignore-not-found
	kubectl delete namespace $(NAMESPACE) --ignore-not-found

.PHONY: k8s-fwd
k8s-fwd: ## Expõe a API do cluster em localhost:8080 — deixe rodando e use outro terminal
	kubectl -n $(NAMESPACE) port-forward svc/$(RELEASE)-order-api 8080:80

.PHONY: k8s-fwd-rabbit
k8s-fwd-rabbit: ## Expõe o painel do RabbitMQ em localhost:15672
	kubectl -n $(NAMESPACE) port-forward svc/$(RELEASE)-rabbitmq 15672:15672

.PHONY: k8s-status
k8s-status: ## Visão da RELEASE: pods, services, PVCs e eventos do namespace
	@echo "== Pods =="; kubectl -n $(NAMESPACE) get pods -o wide
	@echo; echo "== Services =="; kubectl -n $(NAMESPACE) get svc
	@echo; echo "== PVCs =="; kubectl -n $(NAMESPACE) get pvc
	@echo; echo "== Eventos (10 mais recentes) =="
	@kubectl -n $(NAMESPACE) get events --sort-by=.lastTimestamp | tail -10

.PHONY: k8s-logs
k8s-logs: ## Logs das aplicações (todas as réplicas)
	kubectl -n $(NAMESPACE) logs -l app.kubernetes.io/part-of=pedidos --all-containers --prefix -f --tail=50

.PHONY: k8s-metrics
k8s-metrics: ## Instala o metrics-server (necessário para kubectl top e HPA)
	helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/ 2>/dev/null || true
	helm repo update metrics-server
	helm upgrade --install metrics-server metrics-server/metrics-server \
		--namespace kube-system \
		--set 'args={--kubelet-insecure-tls}' \
		--wait
	@echo "Aguardando primeira coleta..."; sleep 20; kubectl top nodes

.PHONY: k8s-psql
k8s-psql: ## psql interativo no Postgres do cluster
	kubectl -n $(NAMESPACE) exec -it sts/$(RELEASE)-postgres -- psql -U pedidos -d pedidos

.PHONY: k8s-queues
k8s-queues: ## Profundidade das filas no RabbitMQ do cluster
	kubectl -n $(NAMESPACE) exec sts/$(RELEASE)-rabbitmq -- rabbitmqctl list_queues name messages

.PHONY: k8s-debug
k8s-debug: ## Container efêmero com ferramentas de rede (POD=<nome do pod>)
	@test -n "$(POD)" || { echo "uso: make k8s-debug POD=<nome do pod>"; exit 1; }
	kubectl -n $(NAMESPACE) debug -it $(POD) --image=nicolaka/netshoot --target=order-api
