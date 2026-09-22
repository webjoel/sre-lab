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

Imagem oficial `metabase/metabase`, via chart ou manifesto simples no perfil `dados`.

Dois cuidados:

- **Banco de metadados próprio.** Por padrão o Metabase usa H2 em arquivo, que corrompe fácil e não
  sobrevive a restart de pod. No lab, aponte para um banco `metabase` separado no mesmo Postgres —
  e note que isso cria uma dependência circular interessante: se o Postgres cair, você perde o
  serviço **e** o painel que mostraria o estrago. Vale registrar como ADR.
- **Usuário somente leitura.** O Metabase conecta no banco de pedidos com um usuário dedicado, sem
  permissão de escrita. Consulta analítica mal escrita em tabela de produção derruba serviço.

```sql
CREATE USER metabase_ro WITH PASSWORD '...';
GRANT CONNECT ON DATABASE pedidos TO metabase_ro;
GRANT USAGE ON SCHEMA public TO metabase_ro;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO metabase_ro;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO metabase_ro;
```

Consumo aproximado: 512 MB a 1 GB de RAM (é uma aplicação JVM). Por isso fica no perfil `dados`, e
não sobe junto com a observabilidade completa.

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
4. **SLI de negócio.** Defina o SLO de conversão de pedidos (por exemplo, 99% pagos em até 5 min) e
   construa o mesmo indicador nas duas ferramentas: alerta de burn rate no Prometheus e painel no
   Metabase.
