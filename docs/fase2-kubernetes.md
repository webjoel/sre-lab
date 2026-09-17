# Fase 2 — Kubernetes

As mesmas aplicações da Fase 1, agora no cluster kind, empacotadas em um chart Helm.

## Rodando

```bash
make k8s-lint      # valida o chart sem aplicar nada
make k8s-up        # builda, carrega no kind e instala a release
make k8s-status    # pods, services, PVCs e eventos recentes
make k8s-fwd       # expõe a API em localhost:8080 (bloqueia o terminal)
```

Com o port-forward ativo, em outro terminal: `make smoke`, `make k6`, `make k8s-queues`, `make k8s-psql`.

Para remover: `make k8s-down` (mantém os PVCs) ou `make k8s-purge` (apaga tudo).

## Por que sem registry

`make k8s-build` builda as imagens e usa `kind load docker-image` para injetá-las direto nos nós.
Por isso `imagePullPolicy: IfNotPresent` — com `Always`, o kubelet tentaria buscar num registry
e falharia com `ErrImagePull`. A partir da Fase 5 as imagens passam a vir do GHCR, versionadas.

**Pegadinha:** `kind load` com a mesma tag não reinicia os pods. Depois de rebuildar, force o rollout:

```bash
kubectl -n pedidos rollout restart deploy/pedidos-order-api
```

Em produção isso não acontece porque cada build gera uma tag nova — usar `latest` é justamente
o que impede rollback e torna o deploy não reprodutível.

## Decisões do chart (e o porquê)

| Decisão | Motivo |
|---|---|
| **Sem limite de CPU** | Limite de CPU causa throttling do cgroup e latência de cauda. Memória tem limite porque não é compressível: estourar significa OOMKill |
| **`startupProbe` separada** | Dá até 60 s para o boot (retry de conexão) sem afrouxar a liveness. Sem ela, você precisaria de uma liveness lenta, que demora a detectar travamento real |
| **liveness não checa dependências** | Se o Postgres cair, reiniciar a API não ajuda e piora: todos os pods reiniciam em cascata. Só a readiness checa |
| **readiness checa dependências** | Sem banco ou fila, o pod sai do Service e para de receber tráfego, mas continua vivo para voltar quando normalizar |
| **`maxUnavailable: 0`** | O rollout sobe o pod novo antes de derrubar o antigo; a capacidade nunca cai durante o deploy |
| **`checksum/secret` nas annotations** | Muda a annotation quando o Secret muda, disparando rollout. Sem isso, o pod fica com a variável antiga até alguém reiniciar na mão |
| **`automountServiceAccountToken: false`** | As aplicações não falam com a API do Kubernetes. Token montado sem uso é material para escalada de privilégio |
| **`readOnlyRootFilesystem: true`** | Contêiner não escreve no próprio filesystem. O worker precisa de `/tmp`, que vem de um `emptyDir` |
| **`whenUnsatisfiable: ScheduleAnyway`** | O lab tem um worker só. Com `DoNotSchedule`, a segunda réplica ficaria `Pending` para sempre |
| **StatefulSet para banco e fila** | Identidade estável e PVC por réplica. Deployment não serve para carga com estado |
| **PDB com `minAvailable: 1`** | Protege de disrupção **voluntária** (drain, upgrade), não de crash |

## Problemas intencionais desta fase

| Problema | Consequência | Corrigido na |
|---|---|---|
| Senha em texto claro no `values.yaml`, versionado no Git | Qualquer um que clone o repositório lê a senha | Fase 4 (Vault + ESO) |
| Secret do Kubernetes é só base64, não criptografia | Leitura no namespace = senha exposta | Fase 4 |
| Postgres e RabbitMQ com uma instância, sem backup | Perda do nó = perda dos dados | Fase 4 (CloudNativePG, RabbitMQ Operator) |
| Migration via `initdb` só roda no primeiro boot | Mudança de schema exige apagar o volume | Fase 5 (Job de migration) |
| Tag `dev` fixa | Sem rollback, deploy não reprodutível | Fase 5 (GHCR + tag por commit) |
| Sem NetworkPolicy | Qualquer pod do cluster alcança o banco | Fase 10 |

## Exercícios

**1. Quebrar e diagnosticar.** Provoque cada falha e diagnostique **antes** de olhar a causa:

```bash
# CrashLoopBackOff: senha errada
helm upgrade pedidos deploy/charts/pedidos -n pedidos --set postgres.password=errada
kubectl -n pedidos get pods
kubectl -n pedidos describe pod <pod>
kubectl -n pedidos logs <pod> --previous     # --previous mostra o log do container que morreu

# OOMKilled: limite de memória absurdo
helm upgrade pedidos deploy/charts/pedidos -n pedidos --set orderApi.resources.limits.memory=8Mi
kubectl -n pedidos get pod <pod> -o jsonpath='{.status.containerStatuses[0].lastState}' | jq

# Pending: mais CPU do que o nó tem
helm upgrade pedidos deploy/charts/pedidos -n pedidos --set orderApi.resources.requests.cpu=8
kubectl -n pedidos describe pod <pod>        # olhe a seção Events

# Volte ao normal
helm upgrade pedidos deploy/charts/pedidos -n pedidos
```

**2. Readiness na prática.** Derrube o Postgres e observe a API sair do Service sem reiniciar:

```bash
kubectl -n pedidos scale sts/pedidos-postgres --replicas=0
kubectl -n pedidos get pods          # order-api fica 0/1 READY, mas sem RESTARTS
kubectl -n pedidos get endpoints pedidos-order-api    # lista vazia
kubectl -n pedidos scale sts/pedidos-postgres --replicas=1
```

**3. Debug em imagem distroless.** `kubectl exec` na `order-api` falha (não há shell).
Use container efêmero:

```bash
make k8s-debug POD=<nome do pod da order-api>
# dentro: dig pedidos-postgres, curl -s localhost:8080/readyz, ss -tulpn
```

**4. DNS interno.** Entenda a resolução por Service:
`pedidos-postgres` → `pedidos-postgres.pedidos.svc.cluster.local`.

**5. RBAC.** Crie um kubeconfig usando a Role `pedidos-leitura` e comprove que ele lê pods
mas não consegue deletar:

```bash
kubectl -n pedidos auth can-i delete pods --as=system:serviceaccount:pedidos:pedidos-order-api
```

**6. HPA.** Instale o metrics-server, ligue o autoscaling e gere carga:

```bash
make k8s-metrics
helm upgrade pedidos deploy/charts/pedidos -n pedidos --set orderApi.autoscaling.enabled=true
kubectl -n pedidos get hpa -w
make k6 VUS=50 DURATION=3m
```

Observe: a API escala por CPU, mas o gargalo real (consumer lag do worker) não melhora.
Escalar pelo sinal errado é um erro comum — o KEDA, na Fase 4, escala pela fila.

**7. Compare com a Fase 1.** Rode `make k6` contra o cluster (com port-forward) e compare com a
linha de base do compose. A latência tende a ser maior: há uma camada de rede a mais e o
port-forward é um gargalo. Isso é uma lição sobre método de medição, não sobre o Kubernetes.
