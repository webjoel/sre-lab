#!/usr/bin/env bash
# Ajustes de host para rodar kind com vários nós no Ubuntu.
set -euo pipefail

CONF=/etc/sysctl.d/99-sre-lab.conf
echo "Gravando $CONF (requer sudo)..."
printf 'fs.inotify.max_user_watches = 524288\nfs.inotify.max_user_instances = 512\n' | sudo tee "$CONF" >/dev/null
sudo sysctl --system >/dev/null
echo "inotify: watches=$(sysctl -n fs.inotify.max_user_watches) instances=$(sysctl -n fs.inotify.max_user_instances)"

if ! swapon --show | grep -q zram; then
  echo
  echo "Dica para 16 GiB de RAM: zram comprime memória e reduz travamentos."
  echo "  sudo apt install zram-tools   # depois ajuste PERCENT=50 em /etc/default/zramswap"
fi
