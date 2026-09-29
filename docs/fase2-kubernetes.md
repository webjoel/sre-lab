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

Nos primeiros segundos após a instalação, `make k8s-status` mostra eventos `Warning` como
`Readiness probe failed: ... statuscode: 503`. É esperado: a API sobe o HTTP antes de conectar nas
dependências (ADR 0002) e responde 503 no `/readyz` até terminar. Warning que persiste é que merece atenção.

Para remover: `make k8s-down` (mantém os PVCs) ou `make k8s-purge` (apaga tudo).

**Sempre suba pelo `make k8s-up`** depois de mexer no código ou de um exercício com `--set`. Ele
rebuilda as imagens e passa `--set image.tag` — um `helm upgrade --set <outra coisa>` sem a tag
volta para a tag padrão do chart (`dev`), com a imagem que estiver no nó.

## Por que sem registry

`make k8s-build` builda as imagens e usa `kind load docker-image` para injetá-las direto nos nós.
Por isso `imagePullPolicy: IfNotPresent` — com `Always`, o kubelet tentaria buscar num registry
e falharia com `ErrImagePull`. A partir da Fase 5 as imagens passam a vir do GHCR, versionadas.

**Pegadinha:** `kind load` com a mesma tag não reinicia os pods — `make k8s-up` com o código novo
mas a mesma tag `dev` deixa os pods rodando a imagem antiga, porque o spec do Deployment não mudou.
Depois de rebuildar, force o rollout das duas aplicações:

```bash
kubectl -n pedidos rollout restart deploy/pedidos-order-api deploy/pedidos-payment-worker
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
| **Sem `replicas` no Deployment quando o HPA está ligado** | O HPA passa a ser o dono do campo. Se o chart também declarasse, todo `helm upgrade` brigaria com ele pelo `.spec.replicas` e falharia com conflito de server-side apply |

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

Antes de começar, garanta que o cluster roda o código atual: `make k8s-up`.

**Pegadinha do Helm que atravessa todos os exercícios:** `helm upgrade` **sem nenhum** `--set` ou
`-f` reaproveita os values da revisão anterior. Por isso "voltar ao normal" é com `--reset-values` —
sem ele, o upgrade repete o valor quebrado e o Helm ainda responde `STATUS: deployed`.

**1. Quebrar e diagnosticar.** Provoque cada falha e diagnostique **antes** de olhar a causa:

```bash
# CrashLoopBackOff: senha errada
helm upgrade pedidos deploy/charts/pedidos -n pedidos --set postgres.password=errada
kubectl -n pedidos get pods
kubectl -n pedidos describe pod <pod>
kubectl -n pedidos logs <pod> --previous     # --previous mostra o log do container que morreu
```

Repare que os pods **antigos continuam atendendo**: com `maxUnavailable: 0` o rollout só derruba um
pod velho depois que o novo fica pronto — e o novo nunca fica. O deploy trava, o serviço não cai.
(O Postgres não muda de senha: ela só é definida no primeiro boot, quando o volume está vazio.)

```bash
# OOMKilled: limite de memória abaixo do consumo
# O request também precisa baixar: a API recusa request maior que o limit.
helm upgrade pedidos deploy/charts/pedidos -n pedidos \
  --set orderApi.resources.limits.memory=8Mi --set orderApi.resources.requests.memory=8Mi
```

Parada, a API em Go usa ~3 MiB e **não estoura** 8 MiB. O OOM só aparece sob carga — em outro
terminal, `make k8s-fwd`, e depois:

```bash
make k6 VUS=50 DURATION=30s
kubectl -n pedidos get pod <pod> -o jsonpath='{.status.containerStatuses[0].lastState}' | jq
```

O k6 vai mostrar quase 100% de erro: quando o pod morre, o port-forward cai junto (ele é preso a um
pod só). Outra lição: um limite de memória que "funciona" em repouso diz pouco.

```bash
# Pending: mais CPU do que o nó tem
helm upgrade pedidos deploy/charts/pedidos -n pedidos --set orderApi.resources.requests.cpu=8
kubectl -n pedidos describe pod <pod>        # olhe a seção Events: Insufficient cpu

# Volte ao normal
helm upgrade pedidos deploy/charts/pedidos -n pedidos --reset-values
```

**2. Readiness na prática.** Derrube o Postgres e observe a API sair do Service sem reiniciar:

```bash
kubectl -n pedidos scale sts/pedidos-postgres --replicas=0
kubectl -n pedidos get pods          # order-api fica 0/1 READY, mas sem RESTARTS
kubectl -n pedidos get endpointslices -l kubernetes.io/service-name=pedidos-order-api -o wide
kubectl -n pedidos scale sts/pedidos-postgres --replicas=1
```

(`kubectl get endpoints` ainda funciona, mas a API `Endpoints` está depreciada desde o Kubernetes 1.33;
o Service usa EndpointSlice.)

Observe também o **worker**: ele continua `1/1` com o banco fora, porque só descobre a falha quando
precisa do banco. Com o Postgres de volta, rode `make smoke`: o primeiro pedido derruba o worker uma
vez (a conexão antiga morreu: `terminating connection due to administrator command`), ele reinicia,
a mensagem volta da fila e o pedido é pago. É o design crash-only funcionando — veja com
`kubectl -n pedidos logs deploy/pedidos-payment-worker --previous`.

**3. Debug em imagem distroless.** `kubectl exec` na `order-api` falha (não há shell).
Use container efêmero:

```bash
make k8s-debug POD=<nome do pod da order-api>
# dentro:
curl -s localhost:8080/readyz       # mesma rede do pod
ss -tln                             # a porta 8080 da API aparece aqui
ps                                  # o processo /order-api é visível (--target compartilha os PIDs)
dig +search pedidos-postgres        # sem +search o dig ignora o resolv.conf e não resolve nada
```

Para o worker: `make k8s-debug POD=<pod do worker> ALVO=payment-worker`. O container efêmero fica
registrado no pod até ele ser recriado.

**4. DNS interno.** Ainda dentro do `make k8s-debug`, entenda a resolução por Service:

```bash
cat /etc/resolv.conf                              # search pedidos.svc.cluster.local svc.cluster.local ...
dig +short pedidos-postgres.pedidos.svc.cluster.local   # nome completo: resolve sem +search
dig +short +search pedidos-postgres               # nome curto: completado pelo search
dig +short +search pedidos-postgres.pedidos       # serviço de outro namespace: <svc>.<namespace>
```

O IP devolvido é o ClusterIP do Service, não o do pod: `kubectl -n pedidos get svc pedidos-postgres`.

**5. RBAC.** O chart cria a Role `pedidos-leitura` (ler pods, logs, services, eventos, configmaps e
deployments), mas **não a atribui a ninguém** — Role sem RoleBinding não dá acesso. Crie uma
identidade, ligue a Role a ela e comprove o que ela pode e não pode:

```bash
# 1. Identidade e vínculo com a Role
kubectl -n pedidos create serviceaccount leitor
kubectl -n pedidos create rolebinding leitor-leitura --role=pedidos-leitura --serviceaccount=pedidos:leitor

# 2. Pergunte à API (--as simula a identidade)
QUEM=system:serviceaccount:pedidos:leitor
kubectl -n pedidos auth can-i list pods --as=$QUEM                        # yes
kubectl -n pedidos auth can-i get pods --subresource=log --as=$QUEM       # yes
kubectl -n pedidos auth can-i delete pods --as=$QUEM                      # no
kubectl -n pedidos auth can-i get secrets --as=$QUEM                      # no: a senha fica fora
kubectl -n pedidos auth can-i create pods --subresource=exec --as=$QUEM   # no: nada de exec

# 3. Um kubeconfig de verdade para essa identidade, com token de 1 hora
cp ~/.kube/sre-lab ~/.kube/sre-lab-leitor
export KUBECONFIG=~/.kube/sre-lab-leitor
kubectl config set-credentials leitor --token="$(KUBECONFIG=~/.kube/sre-lab kubectl -n pedidos create token leitor --duration=1h)"
kubectl config set-context --current --user=leitor --namespace=pedidos
kubectl get pods                       # funciona
kubectl delete pod pedidos-postgres-0 --dry-run=server  # Forbidden (dry-run: a permissão é
                                                         # checada, mas nada é apagado se errar o kubeconfig)
kubectl get pods -n kube-system        # Forbidden: a Role vale só no namespace pedidos

# 4. Limpeza
export KUBECONFIG=~/.kube/sre-lab
rm ~/.kube/sre-lab-leitor
kubectl -n pedidos delete rolebinding leitor-leitura
kubectl -n pedidos delete serviceaccount leitor
```

Compare com a ServiceAccount da própria aplicação: `kubectl -n pedidos auth can-i list pods
--as=system:serviceaccount:pedidos:pedidos-order-api` responde `no` — ela não tem permissão nenhuma,
de propósito (a aplicação não fala com a API do Kubernetes).

**6. HPA.** Instale o metrics-server, ligue o autoscaling e gere carga **de dentro do cluster**:

```bash
make k8s-metrics
helm upgrade pedidos deploy/charts/pedidos -n pedidos --set orderApi.autoscaling.enabled=true
kubectl -n pedidos get hpa -w                          # em um terminal
kubectl -n pedidos top pods                            # em outro, de tempos em tempos
make k6-cluster VUS=50 DURATION=3m
```

Por que `k6-cluster` e não `make k6`: o `port-forward` conecta em **um pod só**. Com ele, o HPA
escala para 5 réplicas, mas toda a carga continua em um pod (medido no lab: 244m de CPU em um,
1m nos outros quatro). O `k6-cluster` roda o k6 num pod e bate no Service, que distribui (medido:
64–70m em cada um dos cinco). O `--no-vu-connection-reuse` que ele usa importa: com conexões
persistentes, os pods criados durante o teste não receberiam nada.

Observe: a API escala por CPU, mas o gargalo real (consumer lag do worker, `make k8s-queues`) não
melhora. Escalar pelo sinal errado é um erro comum — o KEDA, na Fase 4, escala pela fila.

Para desligar:

```bash
helm upgrade pedidos deploy/charts/pedidos -n pedidos --reset-values --force-conflicts
```

O `--force-conflicts` é necessário **só nessa transição**: enquanto o HPA existia, o campo
`.spec.replicas` pertencia ao controlador dele, e o Helm (que usa server-side apply) precisa de
autorização explícita para retomá-lo. É o mesmo mecanismo de posse de campos que o ArgoCD trata
na Fase 5.

**7. Compare com a Fase 1.** Rode `make k6` contra o cluster (com `make k8s-fwd`) e compare com a
linha de base do compose. A latência tende a ser maior: há uma camada de rede a mais e o
port-forward é um gargalo. Rode também `make k6-cluster` e compare as três medições: mesma
aplicação, números diferentes conforme **de onde** se mede. Isso é uma lição sobre método de
medição, não sobre o Kubernetes.
