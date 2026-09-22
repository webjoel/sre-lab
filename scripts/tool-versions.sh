#!/usr/bin/env bash
# Imprime as versões das ferramentas em formato de tabela Markdown (para colar no README).
set -uo pipefail

row() {
  local name=$1; shift
  if command -v "$1" >/dev/null 2>&1; then
    local out
    # Descarta avisos em stderr (ex.: helm reclamando de kubeconfig inexistente).
    out=$("$@" 2>/dev/null | grep -v -E '^(W[0-9]|WARNING|warning)' | head -1)
    printf '| %s | %s |\n' "$name" "${out:-erro ao consultar}"
  else
    printf '| %s | não instalado |\n' "$name"
  fi
}

echo "| Ferramenta | Versão |"
echo "|---|---|"
row "Docker"          docker --version
row "Docker Compose"  docker compose version --short
row "Podman"          podman --version
row "skopeo"          skopeo --version
row "dive"            dive --version
row "kind"            kind version
row "kubectl"         kubectl version --client
row "Terraform"       terraform version
row "tflint"          tflint --version
row "pre-commit"      pre-commit --version
row "Python"          python3 --version
row "jq"              jq --version
row "GitHub CLI"      gh --version
row "Go"              go version
row "Helm"            helm version --template '{{.Version}}'
row "k9s"             k9s version --short
row "kubectx"         kubectx --version
row "AWS CLI"         aws --version
row "act"             act --version
row "Trivy"           trivy --version
row "Cosign"          cosign version
row "Syft"            syft version
row "kubeconform"     kubeconform -v
row "Checkov"         checkov --version
row "Ollama"          ollama --version
row "Ansible"         ansible --version
row "yq"              yq --version
row "awslocal"        awslocal --version
row "terraform-docs"  terraform-docs --version
row "Vault CLI"       vault version
row "Argo CD CLI"     argocd version --client
row "Semgrep"         semgrep --version
row "promtool"        promtool --version
row "psql"            psql --version
row "redis-cli"       redis-cli --version
row "kcat"            kcat -V
