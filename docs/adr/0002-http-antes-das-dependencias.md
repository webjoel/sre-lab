# ADR 0002 — O servidor HTTP sobe antes de conectar nas dependências

- Status: aceita
- Data: 2026-09-17

## Contexto
Na primeira instalação no Kubernetes, os três pods de aplicação reiniciaram uma vez, cerca de
30 segundos após subirem, e os eventos mostraram:

```
Startup probe failed: Get "http://10.244.1.2:8080/healthz": dial tcp: connect: connection refused
```

A causa: a aplicação conectava em Postgres e RabbitMQ (retry de 15 × 2 s = 30 s) **antes** de
chamar `ListenAndServe`. No primeiro boot do cluster, o banco e a fila demoram mais que isso para
ficar prontos, então a aplicação esgotava o retry e encerrava. O Kubernetes reiniciava, e na
segunda tentativa as dependências já estavam de pé.

Funcionava, mas com dois problemas:
- A startup probe recebia "connection refused", não uma resposta HTTP. O Kubernetes não conseguia
  distinguir "ainda inicializando" de "processo morto ou travado".
- Um `RESTARTS: 1` aparecia em toda instalação nova, virando ruído que mascara reinícios reais.

## Decisão
O servidor HTTP sobe primeiro; a conexão com as dependências acontece em background:

- `/healthz` (liveness) responde 200 desde o primeiro instante — o processo está vivo.
- `/readyz` (readiness) responde 503 com `{"postgres":"conectando"}` até as dependências ficarem prontas.
- As rotas de negócio respondem 503 enquanto as dependências forem nulas.
- As dependências são guardadas atrás de `sync.RWMutex`, porque passam a ser preenchidas de forma
  assíncrona enquanto requisições já podem chegar.
- Se a conexão falhar mesmo após o retry, o processo encerra (crash-only preservado).

## Alternativas consideradas
- **Aumentar o `failureThreshold` da startup probe**: esconderia o sintoma sem corrigir a causa; a
  probe continuaria sem conseguir distinguir inicialização de processo morto.
- **initContainer esperando banco e fila**: funciona, mas transfere para o Kubernetes uma
  responsabilidade da aplicação e não ajuda quando a dependência cai depois do boot.

## Consequências
- Instalação nova não gera mais `RESTARTS: 1`, então esse contador volta a ser sinal, não ruído.
- A aplicação passa a ter um estado intermediário ("viva, não pronta"), que é o comportamento
  correto para um serviço com dependências externas.
- O código ficou um pouco mais complexo (mutex e goroutine de inicialização). É o custo de tratar
  inicialização como estado em vez de pré-condição.
