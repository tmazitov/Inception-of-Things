#!/usr/bin/env bash
# Installs everything needed for K3d + Argo CD: Docker, kubectl, k3d.
set -euo pipefail

log() { printf '\033[1;34m[install]\033[0m %s\n' "$*"; }

# ---------- Docker ----------
if command -v docker >/dev/null 2>&1; then
    log "Docker is already installed: $(docker --version)"
else
    log "Installing Docker..."
    curl -fsSL https://get.docker.com | sudo sh
    sudo usermod -aG docker "$USER"
    log "User $USER added to the docker group (re-login required)"
fi

# ---------- kubectl ----------
if command -v kubectl >/dev/null 2>&1; then
    log "kubectl is already installed: $(kubectl version --client -o yaml | grep gitVersion | head -1)"
else
    log "Installing kubectl..."
    ver=$(curl -fsSL https://dl.k8s.io/release/stable.txt)
    curl -fsSLo /tmp/kubectl "https://dl.k8s.io/release/${ver}/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 /tmp/kubectl /usr/local/bin/kubectl
    rm -f /tmp/kubectl
fi

# ---------- k3d ----------
if command -v k3d >/dev/null 2>&1; then
    log "k3d is already installed: $(k3d version | head -1)"
else
    log "Installing k3d..."
    curl -fsSL https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | sudo bash
fi

log "Done. Versions:"
docker --version
kubectl version --client 2>/dev/null | head -1
k3d version | head -1

if ! groups | grep -qw docker; then
    log "WARNING: re-login or run 'newgrp docker', otherwise k3d will not see Docker"
fi
