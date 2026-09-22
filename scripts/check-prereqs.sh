#!/usr/bin/env bash
# Verifica pré-requisitos do sre-lab. Falha se algo obrigatório estiver faltando.
set -euo pipefail

FAILED=0
ok()   { printf '  \033[32m✔\033[0m %s\n' "$1"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$1"; }
fail() { printf '  \033[31m✘\033[0m %s\n' "$1"; FAILED=1; }

echo "Obrigatórias (Fases 0 e 1):"
for bin in docker kind kubectl terraform tflint pre-commit git jq yq curl make; do
  if command -v "$bin" >/dev/null 2>&1; then ok "$bin"; else fail "$bin não encontrado"; fi
done

# Próximas fases: ausência aqui é normal — cada uma se instala quando a fase chega.
echo "Próximas fases (instale com: make tools ALVOS=\"<alvo>\"):"
fase() {
  local alvo=$1; shift
  local faltando=()
  for bin in "$@"; do
    command -v "$bin" >/dev/null 2>&1 || faltando+=("$bin")
  done
  if ((${#faltando[@]} == 0)); then
    ok "$alvo: completo"
  else
    warn "$alvo: falta ${faltando[*]}"
  fi
}

fase "go (opcional)"            go
fase "podman (opcional)"        podman skopeo dive
fase "troubleshoot"             tmux htop lsof strace tcpdump dig openssl
fase "fase2 (Kubernetes)"       helm k9s kubectx kubens
fase "fase3 (Terraform/AWS)"    aws awslocal terraform-docs
fase "fase4 (plataforma)"       vault
fase "fase5 (CI/CD e GitOps)"   act argocd
fase "fase6 (DevSecOps)"        trivy cosign syft kubeconform checkov semgrep
fase "fase7 (observabilidade)"  promtool
fase "fase8 (dados)"            psql redis-cli kcat
fase "fase9 (IA)"               ollama
fase "legado (opcional)"        ansible multipass

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
