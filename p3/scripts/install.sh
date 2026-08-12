#!/usr/bin/env bash
# Ставит всё, что нужно для K3d + Argo CD: Docker, kubectl, k3d.
set -euo pipefail

log() { printf '\033[1;34m[install]\033[0m %s\n' "$*"; }

# ---------- Docker ----------
if command -v docker >/dev/null 2>&1; then
    log "Docker уже установлен: $(docker --version)"
else
    log "Ставлю Docker..."
    curl -fsSL https://get.docker.com | sudo sh
    sudo usermod -aG docker "$USER"
    log "Пользователь $USER добавлен в группу docker (нужен релогин)"
fi

# ---------- kubectl ----------
if command -v kubectl >/dev/null 2>&1; then
    log "kubectl уже установлен: $(kubectl version --client -o yaml | grep gitVersion | head -1)"
else
    log "Ставлю kubectl..."
    ver=$(curl -fsSL https://dl.k8s.io/release/stable.txt)
    curl -fsSLo /tmp/kubectl "https://dl.k8s.io/release/${ver}/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 /tmp/kubectl /usr/local/bin/kubectl
    rm -f /tmp/kubectl
fi

# ---------- k3d ----------
if command -v k3d >/dev/null 2>&1; then
    log "k3d уже установлен: $(k3d version | head -1)"
else
    log "Ставлю k3d..."
    curl -fsSL https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | sudo bash
fi

log "Готово. Версии:"
docker --version
kubectl version --client 2>/dev/null | head -1
k3d version | head -1

if ! groups | grep -qw docker; then
    log "ВНИМАНИЕ: перелогинься или выполни 'newgrp docker', иначе k3d не увидит Docker"
fi
