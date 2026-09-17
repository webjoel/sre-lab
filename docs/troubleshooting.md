# Troubleshooting: ferramentas do host e dentro do container

Instale as ferramentas do host com `make tools ALVOS="troubleshoot"`.

## No host

| Pergunta | Ferramenta |
|---|---|
| O que está consumindo CPU e memória? | `htop`, `pidstat 1` |
| O disco é o gargalo? | `iostat -xz 1`, `iotop -o` |
| O que aconteceu às 3h da manhã? | `sar -u -f /var/log/sysstat/saXX` (histórico, não só o agora) |
| Qual processo está usando esta porta? | `ss -tulpn`, `lsof -i :8080` |
| Vazamento de file descriptor? | `lsof -p <pid> \| wc -l` comparado com `cat /proc/<pid>/limits` |
| O processo travou, em que chamada? | `strace -p <pid> -f -T` |
| O pacote está chegando? | `tcpdump -i any -nn port 5432` |
| O DNS resolve? | `dig +short api.exemplo.com`, `dig @10.96.0.10 -p 53 servico.default.svc.cluster.local` |
| O certificado está válido? | `openssl s_client -connect host:443 \| openssl x509 -noout -dates` |
| A porta está aberta? | `nc -zv host 5432` |
| Não perder a sessão no meio do incidente | `tmux new -s incidente` |

`net-tools` (`netstat`, `ifconfig`) está na lista porque você vai encontrar em servidores antigos,
mas prefira os equivalentes do `iproute2`: `ss` e `ip`.

## Dentro do container: nenhuma dessas existe

As imagens do lab são mínimas de propósito. A `order-api` usa distroless: **não tem shell, nem
curl, nem ps**. Isso é bom para segurança e ruim para depuração, e é exatamente o cenário real.

Um `kubectl exec` numa imagem distroless falha. A resposta certa, e pergunta frequente em
entrevista, são os **containers efêmeros**:

```bash
# Anexa um container com ferramentas ao pod, sem reiniciá-lo e sem alterar a imagem
kubectl debug -it <pod> --image=nicolaka/netshoot --target=order-api

# Depois de anexado, o processo alvo é visível porque os namespaces são compartilhados:
ss -tulpn ; dig kubernetes.default ; curl -s localhost:8080/readyz
```

A imagem `nicolaka/netshoot` reúne quase tudo da tabela acima e é o padrão de mercado para isso.

Para investigar um nó do kind, onde os containers rodam em containerd e não em Docker:

```bash
docker exec -it sre-lab-control-plane crictl ps
docker exec -it sre-lab-control-plane journalctl -u kubelet -n 100
```

## Inspecionando banco e filas (Fase 1, docker compose)

```bash
# Quantos pedidos em cada estado, e a janela de tempo de cada grupo
docker exec sre-lab-apps-postgres-1 psql -U pedidos -d pedidos -c "
SELECT status, count(*),
       min(created_at)::time AS mais_antigo,
       max(created_at)::time AS mais_recente
FROM orders GROUP BY status;"

# Psql interativo
docker exec -it sre-lab-apps-postgres-1 psql -U pedidos -d pedidos

# Profundidade das filas (orders.created = pendente de processar; orders.dead = DLQ)
docker exec sre-lab-apps-rabbitmq-1 rabbitmqctl list_queues name messages

# Acompanhar a fila crescer durante a carga (consumer lag em tempo real)
watch -n2 'docker exec sre-lab-apps-rabbitmq-1 rabbitmqctl list_queues name messages'

# Logs das aplicações (JSON estruturado)
make app-logs
```

Painel do RabbitMQ: <http://localhost:15672> (usuário e senha `pedidos`). Nas mensagens da DLQ,
o cabeçalho `x-death` mostra quantas vezes a mensagem falhou e por quê.

## No cluster (Fase 2)

Os mesmos diagnósticos, via Makefile: `make k8s-psql`, `make k8s-queues`, `make k8s-logs`,
`make k8s-status`. Detalhes e exercícios de troubleshooting no Kubernetes em `fase2-kubernetes.md`.

## Exercícios (Fase 1)

1. Suba as aplicações e descubra, pelo host, qual processo escuta a porta 8080 e quantos file descriptors ele tem abertos.
2. Injete 800 ms de latência pelo endpoint de chaos e capture com `tcpdump` o tráfego para o Postgres. Compare com o estado normal.
3. Com o k6 rodando, use `pidstat 1` e `iostat -xz 1` para identificar se o gargalo é CPU, I/O ou a própria aplicação.
4. Descubra o PID do container da API no host (`docker inspect`) e acompanhe as chamadas de sistema com `strace` durante uma requisição.
