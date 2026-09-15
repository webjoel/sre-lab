#!/usr/bin/env bash
# Encontra cópias duplicadas/antigas das ferramentas do lab e ajuda a remover as que sobram.
#
# Por padrão NÃO remove nada: só mostra o diagnóstico e o que seria feito.
#   ./scripts/clean-old-tools.sh            # diagnóstico (dry-run)
#   ./scripts/clean-old-tools.sh --apply    # remove de fato, pedindo confirmação por item
#   ./scripts/clean-old-tools.sh --apply --yes   # sem perguntar (use com atenção)
#
# Regra: mantém a cópia de MAIOR versão e remove as demais. Nunca remove a única cópia existente.
set -uo pipefail

APPLY=0
ASSUME_YES=0
for arg in "$@"; do
  case "$arg" in
    --apply) APPLY=1 ;;
    --yes|-y) ASSUME_YES=1 ;;
    -h|--help) sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "argumento desconhecido: $arg" >&2; exit 1 ;;
  esac
done

log()  { printf '\n\033[36m==> %s\033[0m\n' "$*"; }
ok()   { printf '  \033[32m✔\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*"; }
info() { printf '    %s\n' "$*"; }

# Diretórios varridos além do PATH (pegam cópias que o PATH atual esconde).
EXTRA_DIRS=(/usr/local/bin /usr/bin /bin /snap/bin /opt/bin "$HOME/bin" "$HOME/.local/bin")

version_of() {
  local path=$1 bin out
  bin=$(basename "$path")
  case "$bin" in
    kubectl)   out=$("$path" version --client 2>/dev/null) ;;
    terraform) out=$("$path" version 2>/dev/null | head -1) ;;
    go)        out=$("$path" version 2>/dev/null) ;;
    helm)      out=$("$path" version --template '{{.Version}}' 2>/dev/null) ;;
    *)         out=$("$path" --version 2>/dev/null | head -1) ;;
  esac
  grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' <<< "$out" | head -1
}

# Lista caminhos reais e únicos de um binário (PATH + diretórios extras), resolvendo symlinks.
copies_of() {
  local bin=$1 p
  {
    type -a -P "$bin" 2>/dev/null
    for d in "${EXTRA_DIRS[@]}"; do [[ -x "$d/$bin" ]] && echo "$d/$bin"; done
  } | while read -r p; do readlink -f "$p" 2>/dev/null || echo "$p"; done | sort -u
}

origin_of() {
  local path=$1 pkg
  if [[ "$path" == /snap/* ]]; then
    echo "snap"
  elif pkg=$(dpkg -S "$path" 2>/dev/null | cut -d: -f1); then
    echo "apt:$pkg"
  else
    echo "solto"
  fi
}

remove_path() {
  local path=$1 origin=$2 bin=$3
  local cmd
  case "$origin" in
    apt:*) cmd="sudo apt-get remove -y ${origin#apt:}" ;;
    snap)  cmd="sudo snap remove $(snap list 2>/dev/null | awk -v b="$bin" '$1 ~ b {print $1; exit}')" ;;
    solto) cmd="sudo rm -i $path" ;;
  esac

  if [[ "$APPLY" != "1" ]]; then
    info "seria removido com: $cmd"
    return
  fi

  if [[ "$ASSUME_YES" != "1" ]]; then
    read -rp "    remover? [$cmd] (s/N) " resp
    [[ "${resp,,}" == "s" ]] || { info "mantido"; return; }
  fi
  if eval "$cmd"; then
    ok "removido: $path"
  else
    warn "falha ao remover $path"
  fi
}

check_tool() {
  local bin=$1 min=$2
  log "$bin (mínimo exigido: $min)"

  mapfile -t paths < <(copies_of "$bin")
  if ((${#paths[@]} == 0)); then
    warn "não instalado"
    return
  fi
  if ((${#paths[@]} == 1)); then
    local v; v=$(version_of "${paths[0]}")
    ok "uma cópia só: ${paths[0]} (versão ${v:-?})"
    [[ -n "$v" ]] && ! printf '%s\n%s\n' "$min" "$v" | sort -VC && warn "abaixo do mínimo; rode: FORCE=1 ./scripts/install-tools.sh"
    return
  fi

  # Escolhe a de maior versão para manter.
  local keep="" keep_v=""
  for p in "${paths[@]}"; do
    local v; v=$(version_of "$p")
    [[ -z "$v" ]] && continue
    if [[ -z "$keep_v" ]] || ! printf '%s\n%s\n' "$v" "$keep_v" | sort -VC; then
      keep="$p"; keep_v="$v"
    fi
  done

  warn "${#paths[@]} cópias encontradas"
  for p in "${paths[@]}"; do
    local v o; v=$(version_of "$p"); o=$(origin_of "$p")
    if [[ "$p" == "$keep" ]]; then
      ok "MANTER  $p (versão ${v:-?}, origem $o)"
    else
      printf '  \033[31m✘\033[0m REMOVER %s (versão %s, origem %s)\n' "$p" "${v:-?}" "$o"
      remove_path "$p" "$o" "$bin"
    fi
  done
}

check_tool kubectl   1.31.0
check_tool terraform 1.6.0
check_tool go        1.25.0
check_tool helm      3.14.0
check_tool kind      0.24.0
check_tool gh        2.50.0

log "Pacotes do apt relacionados (podem reinstalar versões antigas em atualizações)"
dpkg -l 2>/dev/null | awk '/^ii/ {print $2}' \
  | grep -E '^(golang(-[0-9.]+)?(-go)?|kubectl|terraform|helm|gh)$' \
  | sed 's/^/    /' || true
[[ -d /usr/local/go ]] && info "/usr/local/go existe (instalação oficial do Go — mantenha)"

if [[ "$APPLY" != "1" ]]; then
  log "Nada foi removido. Para aplicar: ./scripts/clean-old-tools.sh --apply"
else
  log "Abra um novo terminal (ou rode 'hash -r') e confira com 'make versions'"
fi
