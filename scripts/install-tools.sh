#!/usr/bin/env bash
# Instala as ferramentas do sre-lab no Ubuntu, usando o método oficial de cada projeto
# e conferindo o checksum SHA-256 de todo binário baixado.
#
# Uso:
#   ./scripts/install-tools.sh              # base + núcleo (Fases 0 e 1)
#   ./scripts/install-tools.sh troubleshoot # ferramentas de diagnóstico do host (Semana 1 do plano)
#   ./scripts/install-tools.sh podman       # Podman, skopeo e dive (build rootless e inspeção de imagem)
#   ./scripts/install-tools.sh go           # Go (opcional; o build da API já roda em container)
#   ./scripts/install-tools.sh fase2        # Helm, k9s, kubectx e kubens
#   ./scripts/install-tools.sh fase3        # AWS CLI
#   ./scripts/install-tools.sh tudo         # todos os alvos acima
#
# Versões: por padrão instala a última estável. Para fixar, exporte a variável antes:
#   KIND_VERSION=v0.30.0 KUBECTL_VERSION=v1.34.1 ./scripts/install-tools.sh
#   (também aceita TFLINT_VERSION, HELM_VERSION, K9S_VERSION, GO_VERSION=go1.27.1, TERRAFORM_VERSION=1.13.0)
# Para reinstalar ou atualizar o que já existe: FORCE=1 ./scripts/install-tools.sh
set -euo pipefail

BIN_DIR=/usr/local/bin
FORCE="${FORCE:-0}"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

log() { printf '\n\033[36m==> %s\033[0m\n' "$*"; }
ok()   { printf '  \033[32m✔\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*"; }
die() { printf '  \033[31m✘\033[0m %s\n' "$*" >&2; exit 1; }

os_field() { awk -F= -v k="$1" '$1==k {gsub(/"/, "", $2); print $2}' /etc/os-release; }

[[ "$(uname -m)" == "x86_64" ]] || die "Script preparado para x86_64 (amd64)."
[[ "$(os_field ID)" == "ubuntu" ]] || die "Script preparado para Ubuntu."

# Versões mínimas exigidas pelo lab (o Terraform do lab pede >= 1.6; o kubectl precisa
# ficar no máximo uma minor atrás do cluster que o kind cria).
MIN_KUBECTL=1.31.0
MIN_TERRAFORM=1.6.0
MIN_KIND=0.24.0
MIN_HELM=3.14.0
MIN_GO=1.25.0
MIN_GH=2.50.0

# Extrai só o número de versão (primeiro x.y.z encontrado na saída).
current_version() {
  local bin=$1 out
  case "$bin" in
    kubectl)   out=$(kubectl version --client 2>/dev/null) ;;
    terraform) out=$(terraform version 2>/dev/null | head -1) ;;
    kind)      out=$(kind version 2>/dev/null) ;;
    helm)      out=$(helm version --template '{{.Version}}' 2>/dev/null) ;;
    go)        out=$(go version 2>/dev/null) ;;
    gh)        out=$(gh --version 2>/dev/null | head -1) ;;
    *)         out=$("$bin" --version 2>/dev/null | head -1) ;;
  esac
  grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' <<< "$out" | head -1
}

# version_ge <atual> <mínimo>
version_ge() { [[ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -1)" == "$2" ]]; }

# Confere se a versão ATIVA no PATH é a esperada. Instalação via apt vai para /usr/bin,
# e um binário antigo em /usr/local/bin (que vem antes no PATH) continuaria vencendo.
declare -a SHADOWED=()
verify_active() {
  local bin=$1 min=$2 cur path
  hash -r # esquece o caminho em cache do shell
  path=$(command -v "$bin" 2>/dev/null) || { warn "$bin não encontrado no PATH após a instalação"; return; }
  cur=$(current_version "$bin")
  if [[ -n "$cur" ]] && version_ge "$cur" "$min"; then
    ok "$bin $cur ativo em $path"
  else
    warn "$bin ativo ainda é $cur em $path (esperado >= $min)"
    SHADOWED+=("$path (versão $cur)")
  fi
}

# already <bin> [versão_mínima]
# Pula a instalação só se a ferramenta existe E atende ao mínimo. Instalação antiga
# (apt, snap) que não atende é substituída, e o caminho dela é reportado no fim.
declare -a OUTDATED=()
already() {
  local bin=$1 min=${2:-} cur path
  [[ "$FORCE" == "1" ]] && return 1
  command -v "$bin" >/dev/null 2>&1 || return 1
  path=$(command -v "$bin")
  if [[ -n "$min" ]]; then
    cur=$(current_version "$bin")
    if [[ -z "$cur" ]] || ! version_ge "$cur" "$min"; then
      warn "$bin ${cur:-?} em $path está abaixo do mínimo $min; instalando versão atual"
      OUTDATED+=("$bin ${cur:-?} em $path")
      return 1
    fi
  fi
  ok "$bin ${cur:-} já instalado em $path (FORCE=1 para reinstalar)"
  return 0
}

need() {
  for bin in "$@"; do
    command -v "$bin" >/dev/null 2>&1 || die "$bin não encontrado; rode primeiro: ./scripts/install-tools.sh nucleo"
  done
}

latest_github_tag() {
  local tag
  tag=$(curl -fsSL "https://api.github.com/repos/$1/releases/latest" 2>/dev/null | jq -r '.tag_name // empty')
  [[ -n "$tag" ]] || die "não consegui descobrir a última versão de $1 (limite da API do GitHub?). Fixe a versão pela variável de ambiente."
  echo "$tag"
}

verify_sha256() {
  local file=$1 expected=$2
  [[ -n "$expected" ]] || die "checksum não encontrado para $(basename "$file"); confira a página de releases do projeto."
  echo "$expected  $file" | sha256sum --check --status || die "checksum INVÁLIDO para $(basename "$file"); download abortado."
  ok "checksum SHA-256 conferido: $(basename "$file")"
}

install_base() {
  log "Pacotes base (apt)"
  sudo apt-get update -qq
  sudo apt-get install -y -qq make git curl jq unzip ca-certificates gnupg pipx python3-venv
  ok "make, git, curl, jq, unzip, gnupg, pipx, python3-venv"

  log "pre-commit (pipx)"
  if [[ "$FORCE" != "1" ]] && pipx list --short 2>/dev/null | grep -q '^pre-commit '; then
    ok "pre-commit já instalado via pipx"
  else
    pipx install --force pre-commit
    pipx ensurepath >/dev/null
    ok "pre-commit instalado em ~/.local/bin"
  fi
}

install_troubleshoot() {
  log "Ferramentas de diagnóstico do host (apt)"
  # Agrupadas pelo que cada uma responde durante um incidente.
  local pkgs=(
    tmux          # sessões que sobrevivem à queda do SSH; indispensável em plantão
    htop          # CPU, memória e processos, interativo
    iotop         # qual processo está fazendo I/O (precisa de sudo)
    sysstat       # iostat, mpstat, pidstat e o histórico do sar
    lsof          # arquivos e sockets abertos; caça file descriptor vazando
    strace        # chamadas de sistema de um processo travado
    tcpdump       # captura de pacotes
    iproute2      # ip, ss (substituem ifconfig e netstat)
    net-tools     # netstat, ifconfig, route: obsoletos, mas ainda presentes em servidor antigo
    dnsutils      # dig, nslookup
    openssl       # inspeção de TLS e certificados
    ncat          # teste de conectividade TCP/UDP (pacote ncat, binário nc)
    unzip
  )
  sudo apt-get update -qq
  sudo apt-get install -y -qq "${pkgs[@]}"
  ok "${pkgs[*]}"

  # O sar só guarda histórico se a coleta periódica estiver ligada.
  if [[ -f /etc/default/sysstat ]] && ! grep -q '^ENABLED="true"' /etc/default/sysstat; then
    sudo sed -i 's/^ENABLED=.*/ENABLED="true"/' /etc/default/sysstat
    sudo systemctl enable --now sysstat >/dev/null 2>&1 || true
    ok "coleta histórica do sysstat ativada (sar)"
  fi
}

install_kubectl() {
  log "kubectl (binário oficial em dl.k8s.io)"
  already kubectl "$MIN_KUBECTL" && return
  local v="${KUBECTL_VERSION:-$(curl -fsSL https://dl.k8s.io/release/stable.txt)}"
  local base="https://dl.k8s.io/release/$v/bin/linux/amd64"
  curl -fsSLo "$TMP/kubectl" "$base/kubectl"
  verify_sha256 "$TMP/kubectl" "$(curl -fsSL "$base/kubectl.sha256" 2>/dev/null || true)"
  sudo install -m 0755 "$TMP/kubectl" "$BIN_DIR/kubectl"
  ok "kubectl $v"
}

install_kind() {
  log "kind (release oficial no GitHub)"
  already kind "$MIN_KIND" && return
  local v="${KIND_VERSION:-$(latest_github_tag kubernetes-sigs/kind)}"
  local base="https://github.com/kubernetes-sigs/kind/releases/download/$v"
  curl -fsSLo "$TMP/kind" "$base/kind-linux-amd64"
  verify_sha256 "$TMP/kind" "$(curl -fsSL "$base/kind-linux-amd64.sha256sum" 2>/dev/null | awk '{print $1}' || true)"
  sudo install -m 0755 "$TMP/kind" "$BIN_DIR/kind"
  ok "kind $v"
}

install_terraform() {
  log "Terraform (repositório apt oficial da HashiCorp, assinado com GPG)"
  already terraform "$MIN_TERRAFORM" && return
  local keyring=/usr/share/keyrings/hashicorp-archive-keyring.gpg
  curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor --yes -o "$keyring"
  echo "deb [arch=amd64 signed-by=$keyring] https://apt.releases.hashicorp.com $(os_field VERSION_CODENAME) main" \
    | sudo tee /etc/apt/sources.list.d/hashicorp.list >/dev/null
  sudo apt-get update -qq
  if [[ -n "${TERRAFORM_VERSION:-}" ]]; then
    sudo apt-get install -y -qq "terraform=${TERRAFORM_VERSION}*"
  else
    sudo apt-get install -y -qq terraform
  fi
  verify_active terraform "$MIN_TERRAFORM"
}

install_tflint() {
  log "tflint (release oficial no GitHub)"
  already tflint && return
  local v="${TFLINT_VERSION:-$(latest_github_tag terraform-linters/tflint)}"
  local base="https://github.com/terraform-linters/tflint/releases/download/$v"
  curl -fsSLo "$TMP/tflint_linux_amd64.zip" "$base/tflint_linux_amd64.zip"
  verify_sha256 "$TMP/tflint_linux_amd64.zip" \
    "$(curl -fsSL "$base/checksums.txt" 2>/dev/null | awk '$2=="tflint_linux_amd64.zip" {print $1}' || true)"
  unzip -oq "$TMP/tflint_linux_amd64.zip" -d "$TMP"
  sudo install -m 0755 "$TMP/tflint" "$BIN_DIR/tflint"
  ok "tflint $v"
}

install_podman() {
  log "Podman, skopeo e buildah (apt do Ubuntu)"
  # O lab roda em Docker; o Podman entra como exercício: build rootless, comparação de
  # modelo (daemon vs fork/exec) e inspeção de imagens em registries.
  if [[ "$FORCE" != "1" ]] && command -v podman >/dev/null 2>&1 && command -v skopeo >/dev/null 2>&1; then
    ok "podman e skopeo já instalados"
  else
    sudo apt-get update -qq
    sudo apt-get install -y -qq podman skopeo buildah
    ok "podman, skopeo, buildah"
  fi

  # dive: inspeciona camadas da imagem e mostra espaço desperdiçado. Útil na Fase 1.
  if ! already dive; then
    local v file
    v=$(latest_github_tag wagoodman/dive)
    file="dive_${v#v}_linux_amd64.deb"
    curl -fsSLo "$TMP/$file" "https://github.com/wagoodman/dive/releases/download/$v/$file"
    verify_sha256 "$TMP/$file" \
      "$(curl -fsSL "https://github.com/wagoodman/dive/releases/download/$v/dive_${v#v}_checksums.txt" 2>/dev/null | awk -v f="$file" '$2==f {print $1}' || true)"
    sudo apt-get install -y -qq "$TMP/$file"
    ok "dive $v"
  fi
}

install_gh() {
  log "GitHub CLI (repositório apt oficial do GitHub, assinado com GPG)"
  already gh "$MIN_GH" && return
  local keyring=/usr/share/keyrings/githubcli-archive-keyring.gpg
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | sudo gpg --dearmor --yes -o "$keyring"
  sudo chmod a+r "$keyring"
  echo "deb [arch=amd64 signed-by=$keyring] https://cli.github.com/packages stable main" \
    | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null

  # O Ubuntu Pro (ESM) publica o gh com prioridade 510, acima dos 500 padrão de um
  # repositório de terceiro — então o apt manteria a versão antiga do Ubuntu.
  # Este pin dá prioridade ao repositório oficial do GitHub apenas para o pacote gh.
  sudo tee /etc/apt/preferences.d/github-cli >/dev/null <<'PIN'
Package: gh
Pin: origin cli.github.com
Pin-Priority: 600
PIN

  sudo apt-get update -qq
  sudo apt-get install -y -qq --allow-downgrades gh
  verify_active gh "$MIN_GH"
  ok "autentique com: gh auth login"
}

install_kubectx() {
  log "kubectx e kubens (apt do Ubuntu)"
  if [[ "$FORCE" != "1" ]] && command -v kubectx >/dev/null 2>&1 && command -v kubens >/dev/null 2>&1; then
    ok "kubectx e kubens já instalados"
    return
  fi
  sudo apt-get install -y -qq kubectx
  ok "kubectx e kubens"
}

install_go() {
  log "Go (tarball oficial em go.dev)"
  need curl jq
  already go "$MIN_GO" && return
  local url='https://go.dev/dl/?mode=json'
  [[ -n "${GO_VERSION:-}" ]] && url='https://go.dev/dl/?mode=json&include=all'
  local json v file sha
  json=$(curl -fsSL "$url")
  v="${GO_VERSION:-$(jq -r '.[0].version' <<< "$json")}"
  file="$v.linux-amd64.tar.gz"
  sha=$(jq -r --arg f "$file" '[.[].files[] | select(.filename == $f) | .sha256][0] // empty' <<< "$json")
  curl -fsSLo "$TMP/$file" "https://go.dev/dl/$file"
  verify_sha256 "$TMP/$file" "$sha"
  sudo rm -rf /usr/local/go
  sudo tar -C /usr/local -xzf "$TMP/$file"

  # PATH com /usr/local/go PRIMEIRO: se houver um Go antigo do apt em /usr/bin, ele perderia.
  # shellcheck disable=SC2016 # $PATH e $HOME devem ser expandidos pelo shell, não agora
  local line='export PATH="/usr/local/go/bin:$HOME/go/bin:$PATH"'
  grep -qxF "$line" "$HOME/.bashrc" 2>/dev/null || echo "$line" >> "$HOME/.bashrc"
  ok "$v instalado em /usr/local/go (PATH no ~/.bashrc; abra um novo terminal)"
}

install_helm() {
  log "Helm (release oficial em get.helm.sh)"
  need curl jq
  already helm "$MIN_HELM" && return
  local v="${HELM_VERSION:-$(latest_github_tag helm/helm)}"
  local file="helm-$v-linux-amd64.tar.gz"
  curl -fsSLo "$TMP/$file" "https://get.helm.sh/$file"
  verify_sha256 "$TMP/$file" "$(curl -fsSL "https://get.helm.sh/$file.sha256sum" 2>/dev/null | awk '{print $1}' || true)"
  tar -xzf "$TMP/$file" -C "$TMP"
  sudo install -m 0755 "$TMP/linux-amd64/helm" "$BIN_DIR/helm"
  ok "helm $v"
}

install_k9s() {
  log "k9s (release oficial no GitHub)"
  need curl jq
  already k9s && return
  local v="${K9S_VERSION:-$(latest_github_tag derailed/k9s)}"
  local base="https://github.com/derailed/k9s/releases/download/$v"
  local file="k9s_Linux_amd64.tar.gz"
  curl -fsSLo "$TMP/$file" "$base/$file"
  verify_sha256 "$TMP/$file" \
    "$(curl -fsSL "$base/checksums.sha256" 2>/dev/null | awk -v f="$file" '$2==f {print $1}' || true)"
  tar -xzf "$TMP/$file" -C "$TMP" k9s
  sudo install -m 0755 "$TMP/k9s" "$BIN_DIR/k9s"
  ok "k9s $v"
}

install_awscli() {
  log "AWS CLI v2 (instalador oficial da AWS)"
  need curl unzip
  already aws && return
  curl -fsSLo "$TMP/awscliv2.zip" "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip"
  unzip -oq "$TMP/awscliv2.zip" -d "$TMP"
  sudo "$TMP/aws/install" --update
  ok "$(aws --version)"
}

usage() { sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'; }

nucleo() { install_base; install_gh; install_kind; install_kubectl; install_terraform; install_tflint; }

for alvo in "${@:-nucleo}"; do
  case "$alvo" in
    nucleo) nucleo ;;
    troubleshoot) install_troubleshoot ;;
    podman) install_podman ;;
    go)     install_go ;;
    fase2)  install_helm; install_k9s; install_kubectx ;;
    fase3)  install_awscli ;;
    tudo)   nucleo; install_troubleshoot; install_podman; install_go; install_helm; install_k9s; install_kubectx; install_awscli ;;
    -h|--help) usage; exit 0 ;;
    *) usage; die "alvo desconhecido: $alvo" ;;
  esac
done

if ((${#SHADOWED[@]})); then
  log "Atenção: versão antiga continua vencendo no PATH"
  printf '  %s\n' "${SHADOWED[@]}"
  cat <<'MSG'

  A versão nova foi instalada, mas um binário antigo aparece primeiro no PATH
  (normalmente em /usr/local/bin, que vem antes de /usr/bin). Remova o antigo:

    ls -l $(command -v <ferramenta>)     # onde está o que está sendo usado
    dpkg -S $(command -v <ferramenta>)   # veio do apt?
    snap list                            # veio do snap?

  Binário solto: sudo rm <caminho>. Pacote apt: sudo apt remove <pacote>.
  Snap: sudo snap remove <pacote>. Depois abra um novo terminal e rode 'make versions'.
MSG
fi

if ((${#OUTDATED[@]})); then
  log "Instalações antigas encontradas e substituídas"
  printf '  %s\n' "${OUTDATED[@]}"
  cat <<'MSG'

  As versões novas ficaram em /usr/local/bin (ou /usr/local/go), que costuma vir antes no PATH.
  Para não ficar com duas versões na máquina, remova a antiga na origem. Descubra qual é:

    dpkg -S $(command -v <ferramenta>)   # instalada pelo apt
    snap list                            # instalada pelo snap

  E remova com 'sudo apt remove <pacote>' ou 'sudo snap remove <pacote>'.
  Depois abra um novo terminal e rode 'make versions' de novo.
MSG
fi

log "Pronto. Abra um novo terminal (PATH) e rode 'make versions' para registrar as versões no README."
