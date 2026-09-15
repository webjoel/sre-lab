#!/usr/bin/env bash
# Verifica pré-requisitos do sre-lab. Falha se algo obrigatório estiver faltando.
set -euo pipefail

FAILED=0
ok()   { printf '  \033[32m✔\033[0m %s\n' "$1"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$1"; }
fail() { printf '  \033[31m✘\033[0m %s\n' "$1"; FAILED=1; }

echo "Ferramentas obrigatórias:"
for bin in docker kind kubectl terraform tflint pre-commit jq curl make; do
  if command -v "$bin" >/dev/null 2>&1; then ok "$bin"; else fail "$bin não encontrado"; fi
done

echo "Ferramentas das próximas fases:"
for bin in gh go helm k9s kubectx aws act trivy cosign; do
  if command -v "$bin" >/dev/null 2>&1; then ok "$bin"; else warn "$bin ainda não instalado (opcional agora)"; fi
done

echo "Docker:"
if docker info >/dev/null 2>&1; then ok "daemon acessível sem sudo"; else fail "Docker parado ou usuário fora do grupo docker"; fi

echo "Memória:"
avail_gb=$(awk '/MemAvailable/ {printf "%.1f", $2/1024/1024}' /proc/meminfo)
if awk -v a="$avail_gb" 'BEGIN {exit !(a >= 6)}'; then
  ok "${avail_gb} GiB disponíveis"
else
  warn "${avail_gb} GiB disponíveis; feche navegador/IDE pesados antes de subir perfis maiores"
fi

echo "Limites do inotify (kind):"
watches=$(sysctl -n fs.inotify.max_user_watches)
instances=$(sysctl -n fs.inotify.max_user_instances)
if (( watches >= 524288 && instances >= 512 )); then
  ok "watches=${watches} instances=${instances}"
else
  fail "watches=${watches} instances=${instances}; rode 'make host-setup'"
fi

exit "$FAILED"
