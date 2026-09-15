#!/usr/bin/env bash
# Teste de ponta a ponta: cria um pedido e espera o worker marcar como PAID.
set -euo pipefail
API="${API:-http://localhost:8080}"

resp=$(curl -fsS -X POST "$API/orders" -H 'Content-Type: application/json' \
  -d '{"customer_id":"cliente-42","amount_cents":15990,"currency":"BRL"}')
id=$(jq -r .id <<< "$resp")
echo "Pedido $id criado"

for i in $(seq 1 20); do
  status=$(curl -fsS "$API/orders/$id" | jq -r .status)
  echo "  tentativa $i: $status"
  if [[ "$status" == "PAID" ]]; then
    echo "OK: pedido pago"
    exit 0
  fi
  sleep 1
done

echo "Pedido não foi pago em 20s. Pode ter caído na DLQ (FAIL_RATE): veja http://localhost:15672"
exit 1
