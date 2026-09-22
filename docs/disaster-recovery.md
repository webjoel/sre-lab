# Disaster Recovery — do backup ao restore medido

Backup sem teste de restauração não é DR: é esperança. Este documento define os alvos, descreve os
cenários e exige um número medido ao final de cada um.

Entra na **Fase 4** (quando o Postgres passa a ser operado pelo CloudNativePG, com backup para o S3
do LocalStack) e é reexercitado na **Fase 10**, junto com os game days.

## 1. Vocabulário que cai em entrevista

| Termo | O que é | No lab |
|---|---|---|
| **RPO** (Recovery Point Objective) | Quanto dado você aceita perder, medido em tempo | Alvo: 5 min |
| **RTO** (Recovery Time Objective) | Quanto tempo o serviço pode ficar indisponível | Alvo: 30 min |
| **RPO/RTO real** | O que você de fato consegue, medido em teste | É isso que o exercício descobre |
| **Backup full** | Cópia completa em um instante | Base backup do CloudNativePG |
| **WAL archiving** | Registro contínuo das transações | É o que permite RPO baixo |
| **PITR** (Point-In-Time Recovery) | Restaurar para um instante exato | Full + WAL até o timestamp |
| **Retenção** | Por quanto tempo os backups existem | 7 dias no lab |

A distinção mais cobrada: **backup full define o pior RPO; o WAL é o que reduz o RPO para minutos.**
Sem archiving contínuo, perder tudo desde o último full é o cenário normal, não o excepcional.

## 2. Alvos declarados do serviço de pedidos

| Alvo | Valor | Justificativa |
|---|---|---|
| RPO | 5 minutos | Pedido perdido é dinheiro perdido; WAL a cada 5 min limita a perda |
| RTO | 30 minutos | Acima disso o incidente vira caso de imprensa |
| Retenção | 7 dias | Suficiente para detectar corrupção lógica |
| Teste de restore | Mensal | Backup não testado não conta como backup |

Estes números são uma decisão de negócio, não técnica. Em entrevista, dizer "o RPO era 5 minutos
porque o time de produto aceitou perder até 5 minutos de pedidos" vale mais que qualquer configuração.

## 3. Configuração (Fase 4)

O CloudNativePG faz backup contínuo para um bucket S3 do LocalStack:

- Base backup diário, WAL archiving contínuo, retenção de 7 dias.
- As credenciais do bucket vêm do Vault via External Secrets, não do `values.yaml`.
- Um `ScheduledBackup` cuida do full; o WAL é contínuo por configuração do cluster.

Verificação antes de qualquer cenário — se um destes falhar, não existe DR:

```bash
kubectl -n pedidos get cluster pedidos-pg -o jsonpath='{.status.conditions}' | jq
kubectl -n pedidos get backup                      # último backup completou?
kubectl -n pedidos exec -it pedidos-pg-1 -- \
  psql -c "SELECT last_archived_wal, last_archived_time, last_failed_wal FROM pg_stat_archiver;"
```

`last_failed_wal` preenchido significa archiving quebrado: o RPO real é o do último full, não 5 minutos.

## 4. Cenários

Em todos, **anote o horário de início e de fim**. O número medido é o objetivo do exercício.

### Cenário A — Perda total da instância

Simula falha de nó ou exclusão acidental do banco.

```bash
# 1. Estado antes: guarde a contagem e o último id
kubectl -n pedidos exec -it pedidos-pg-1 -- psql -U pedidos -d pedidos \
  -c "SELECT count(*), max(created_at) FROM orders;"

# 2. Gere carga por 2 minutos (make k6) para haver transações recentes

# 3. Destrua (marque o horário)
kubectl -n pedidos delete cluster pedidos-pg

# 4. Restaure a partir do backup (bootstrap: recovery)
kubectl apply -f deploy/dr/cluster-restore.yaml

# 5. Ao voltar, compare
kubectl -n pedidos exec -it pedidos-pg-1 -- psql -U pedidos -d pedidos \
  -c "SELECT count(*), max(created_at) FROM orders;"
```

**Registre:** RTO real (passo 3 até a aplicação voltar a responder), RPO real (diferença entre o
`max(created_at)` de antes e o de depois) e quantos pedidos se perderam.

### Cenário B — Corrupção lógica (PITR)

O caso mais comum na vida real: alguém roda um `UPDATE` ou `DELETE` sem `WHERE`. O backup mais
recente já contém o estrago, então restaurar o último backup não resolve.

```bash
# 1. Anote o timestamp ANTES do erro
date -u +"%Y-%m-%dT%H:%M:%SZ"

# 2. Provoque o dano
kubectl -n pedidos exec -it pedidos-pg-1 -- psql -U pedidos -d pedidos \
  -c "UPDATE orders SET status = 'PAID';"   # sem WHERE, de propósito

# 3. Restaure para o instante anterior (targetTime no cluster de recovery)
# 4. Compare a distribuição de status com a de antes
```

**Registre:** quanto tempo levou para identificar o instante correto. Na prática, essa é a parte
lenta — não a restauração em si, e sim descobrir *quando* o erro aconteceu.

### Cenário C — Perda da fila

A DLQ e as mensagens não confirmadas também são dados. Derrube o RabbitMQ e descubra o que sobrevive.

```bash
kubectl -n pedidos delete pod pedidos-rabbitmq-0
make k8s-queues     # a DLQ sobreviveu? e as mensagens em trânsito?
```

**Registre:** quantos pedidos ficaram órfãos (`PENDING` sem mensagem na fila). Esse é o cenário em
que o padrão Outbox (Fase 8) mostra seu valor.

### Cenário D — Restore em ambiente limpo

O teste mais severo: restaurar sem o cluster original, como aconteceria numa perda de região.

```bash
make k8s-purge                 # apaga release, PVCs e namespace
kubectl apply -f deploy/dr/cluster-restore.yaml
```

**Registre:** o que faltava para o restore funcionar sozinho. Quase sempre aparece alguma dependência
implícita — o Secret do bucket, o namespace, a credencial. É esse achado que faz o runbook prestar.

## 5. Runbook e postmortem

Cada cenário gera dois artefatos, que valem mais que o exercício em si:

- `docs/runbooks/restore-postgres.md` — passo a passo executável sob pressão, com os comandos exatos.
- `docs/postmortems/` — o que foi medido, o que não funcionou de primeira, o que mudou depois.

Tabela para manter viva no README, atualizada a cada teste:

| Cenário | RTO alvo | RTO medido | RPO alvo | RPO medido | Data | Observações |
|---|---|---|---|---|---|---|
| A — perda da instância | 30 min | | 5 min | | | |
| B — PITR | 30 min | | 5 min | | | |
| C — perda da fila | — | | — | | | |
| D — ambiente limpo | 60 min | | 5 min | | | |

## 6. O que isso responde em entrevista

- "Como vocês garantiam a recuperação?" — com números medidos, não com "tínhamos backup".
- "Já testaram o restore?" — a pergunta que desmonta a maioria das respostas.
- "Qual a diferença entre RPO e RTO?" — respondida com um caso concreto seu.
- "O que deu errado no teste?" — a resposta mais valiosa, porque sempre dá algo errado.
