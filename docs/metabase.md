# Metabase — análise sobre os dados do lab

O Metabase entra como camada de análise sobre o Postgres do domínio de pedidos. Não é observabilidade
de infraestrutura (isso é Grafana): é a visão de **negócio** sobre os mesmos dados.

Entra na **Fase 8**, junto com os exercícios de banco, e o perfil `dados`.

## Por que vale a pena, apesar de não aparecer nas vagas

Nenhuma das 38 vagas cita Metabase. O que várias citam é "painéis executivos", "KPIs" e "indicadores
para acompanhamento dos serviços" — e é exatamente isso que ele entrega, com um esforço pequeno.

O ponto que ele ensina, e que Grafana não ensina bem: a diferença entre **SLI técnico** e
**métrica de negócio**. O Grafana responde "a API está respondendo em 15 ms". O Metabase responde
"3,4% dos pedidos de hoje não foram pagos". Quando você mostra os dois lado a lado num incidente,
a conversa com o time de produto muda de tom. Saber traduzir confiabilidade em impacto de negócio é
uma das competências que separam SRE sênior de pleno.

## Instalação

Nada é instalado no host: o Metabase roda no cluster, como os demais serviços. Entra como uma
Application do ArgoCD apontando para `platform/metabase/` (manifests próprios, não há chart oficial
mantido pela Metabase), dentro do perfil `dados`. **Esses manifests são escritos na Fase 8; hoje o
diretório ainda não existe.**

### Desenho

| Item | Decisão |
|---|---|
| Imagem | `metabase/metabase` (oficial), Deployment com 1 réplica |
| Recursos | requests 512Mi, limits 1Gi |
| Banco de metadados | Postgres dedicado (`MB_DB_TYPE=postgres`), no mesmo cluster CloudNativePG |
| Acesso aos dados | usuário `metabase_ro`, somente SELECT |
| Segredos | senhas via Vault + External Secrets, nunca no manifesto |
| Probes | `startupProbe` generosa em `/api/health` |
| Exposição | port-forward no início; HTTPRoute + Keycloak (OIDC) depois |

### JVM em container: a armadilha do limite de memória

O Metabase é uma aplicação Java, e **JVM com `limits.memory` é uma armadilha clássica**: se nada for
dito, a JVM pode dimensionar o heap pela memória visível do nó, ignorar o cgroup e levar OOMKill —
o pod morre sem log de erro da aplicação, só `Reason: OOMKilled` no estado do container.

A correção é fazer a JVM respeitar o cgroup:

```yaml
env:
  - name: JAVA_OPTS
    value: "-XX:MaxRAMPercentage=70 -XX:+ExitOnOutOfMemoryError"
```

`MaxRAMPercentage` calcula o heap como fração do limite do container. `ExitOnOutOfMemoryError` faz o
processo encerrar em vez de ficar vivo e inútil, para o Kubernetes reiniciá-lo (crash-only, como as
aplicações do lab). Esse é um dos temas mais cobrados em entrevista quando há Java em Kubernetes.

### Boot lento exige startupProbe

Ele leva de 60 a 90 segundos para subir, porque é JVM e roda migrations no primeiro boot. Sem
`startupProbe`, a liveness mata o pod antes de terminar, gerando um `CrashLoopBackOff` que parece
erro de aplicação e não é. É o mesmo raciocínio do ADR 0002, agora aplicado a software de terceiros
— com a diferença de que aqui não dá para corrigir o código: só resta ajustar a probe.

```yaml
startupProbe:
  httpGet: { path: /api/health, port: http }
  periodSeconds: 5
  failureThreshold: 30     # até 150s para subir
```

### Banco de metadados próprio

Por padrão o Metabase usa H2 em arquivo, que corrompe com facilidade e não sobrevive a restart de
pod. No lab ele aponta para um banco `metabase` separado, no mesmo cluster CloudNativePG.

Isso cria uma **dependência circular** que vale registrar como ADR: se o Postgres cair, você perde o
serviço **e** o painel que mostraria o tamanho do estrago. Em produção, a análise costuma ficar em
outra instância justamente por isso.

Consequência prática, e ligação direta com o `disaster-recovery.md`: na edição open source, os
dashboards e perguntas vivem nesse banco, não em arquivos versionados. **Seu trabalho no Metabase só
está protegido se o backup desse banco estiver funcionando.**

### Usuário somente leitura

```sql
CREATE USER metabase_ro WITH PASSWORD '...';
GRANT CONNECT ON DATABASE pedidos TO metabase_ro;
GRANT USAGE ON SCHEMA public TO metabase_ro;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO metabase_ro;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO metabase_ro;
```

Consulta analítica mal escrita em tabela de produção derruba serviço — daí o exercício 2, e a
correção do exercício 3 (apontar para a réplica de leitura).

Consumo total aproximado: 512 MB a 1 GB. Por isso fica no perfil `dados`, e não sobe junto com a
observabilidade completa.

## Painel sugerido: "Saúde do negócio"

| Pergunta | Consulta |
|---|---|
| Pedidos por status hoje | `GROUP BY status` com filtro do dia |
| Taxa de conversão (PAID / total) | o SLI de negócio do serviço |
| Pedidos presos em PENDING há mais de 10 min | a mesma consulta que vira alerta na Fase 7 |
| Tempo médio entre criação e pagamento | latência ponta a ponta do ponto de vista do cliente |
| Valor total travado em PENDING | traduz confiabilidade em dinheiro |
| Pedidos por hora (últimas 24h) | padrão de tráfego, base para capacity planning |

A quarta e a sexta linhas são as mais interessantes. O tempo entre criação e pagamento é o consumer
lag visto pelo cliente, e não pela fila. E o valor travado em PENDING transforma "63 pedidos com
falha" em "R$ 4.812 parados", que é a frase que faz a diretoria priorizar a correção.

## Exercícios

1. **Mesmo incidente, duas telas.** Ligue o chaos, gere carga e compare o Grafana (latência, erro,
   error budget) com o Metabase (conversão, valor travado). Escreva um parágrafo do que cada público
   entende de cada tela.
2. **Consulta que derruba.** Rode uma consulta pesada e sem índice no Metabase enquanto o k6 gera
   carga, e observe o efeito no p95 da API. Depois investigue com `pg_stat_activity` e `EXPLAIN`.
   É o argumento concreto para separar réplica de leitura de instância primária.
3. **Réplica de leitura.** Aponte o Metabase para a réplica do CloudNativePG em vez do primário e
   repita o exercício 2. Compare o impacto.
4. **JVM e cgroup.** Suba o Metabase **sem** `JAVA_OPTS`, com `limits.memory: 1Gi`, e observe o
   comportamento sob uso. Depois adicione `MaxRAMPercentage` e compare. Confirme o heap real:
   ```bash
   kubectl -n pedidos exec deploy/metabase -- java -XX:+PrintFlagsFinal -version | grep -i maxheap
   ```
5. **SLI de negócio.** Defina o SLO de conversão de pedidos (por exemplo, 99% pagos em até 5 min) e
   construa o mesmo indicador nas duas ferramentas: alerta de burn rate no Prometheus e painel no
   Metabase.
