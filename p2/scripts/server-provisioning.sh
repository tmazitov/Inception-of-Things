#!/usr/bin/env bash
set -euo pipefail

MANIFEST_DIR="/tmp/confs"

echo "========================================"
echo " Installing dependencies"
echo "========================================"

apt-get update
apt-get install -y curl

echo "========================================"
echo " Checking manifest directory"
echo "========================================"

if [ ! -d "$MANIFEST_DIR" ]; then
    echo "ERROR: $MANIFEST_DIR does not exist"
    exit 1
fi

echo "Manifests found:"
ls -la "$MANIFEST_DIR"

echo "========================================"
echo " Installing K3s"
echo "========================================"

if ! command -v k3s >/dev/null 2>&1; then

    curl -sfL https://get.k3s.io | \
        INSTALL_K3S_EXEC="server" sh -s - \
        --write-kubeconfig-mode 644

else
    echo "K3s is already installed"
fi

echo "========================================"
echo " Waiting for K3s"
echo "========================================"

until systemctl is-active --quiet k3s; do
    sleep 2
done

echo "K3s service is running"

echo "========================================"
echo " Waiting for Kubernetes node"
echo "========================================"

until k3s kubectl get nodes >/dev/null 2>&1; do
    sleep 2
done

until k3s kubectl get nodes \
    -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' \
    2>/dev/null | grep -q True; do
    sleep 2
done

echo "Kubernetes node is Ready"

echo "========================================"
echo " Checking Traefik"
echo "========================================"

until k3s kubectl get deployment traefik \
    -n kube-system >/dev/null 2>&1; do
    sleep 2
done

echo "Traefik deployment exists"

echo "========================================"
echo " Deploying applications"
echo "========================================"

k3s kubectl apply -f "$MANIFEST_DIR/applications.yaml"

echo "========================================"
echo " Deploying services"
echo "========================================"

k3s kubectl apply -f "$MANIFEST_DIR/services.yaml"

echo "========================================"
echo " Deploying ingress"
echo "========================================"

k3s kubectl apply -f "$MANIFEST_DIR/ingress.yaml"

echo "========================================"
echo " Waiting for applications"
echo "========================================"

k3s kubectl rollout status deployment/app1 --timeout=120s
k3s kubectl rollout status deployment/app2 --timeout=120s
k3s kubectl rollout status deployment/app3 --timeout=120s

echo "========================================"
echo " K3s cluster status"
echo "========================================"

k3s kubectl get nodes -o wide

echo
echo "========================================"
echo " Deployments"
echo "========================================"

k3s kubectl get deployments

echo
echo "========================================"
echo " Pods"
echo "========================================"

k3s kubectl get pods -o wide

echo
echo "========================================"
echo " Services"
echo "========================================"

k3s kubectl get services

echo
echo "========================================"
echo " Ingress"
echo "========================================"

k3s kubectl get ingress

echo
echo "========================================"
echo " Testing applications"
echo "========================================"

echo "--- app1.com ---"
curl -s -H "Host: app1.com" "http://127.0.0.1"
echo

echo "--- app2.com ---"
curl -s -H "Host: app2.com" "http://127.0.0.1"
echo

echo "--- app3.com ---"
curl -s -H "Host: app3.com" "http://127.0.0.1"
echo

echo "--- default ---"
curl -s -H "Host: anything.com" "http://127.0.0.1"
echo

echo
echo "========================================"
echo " K3s provisioning complete!"
echo "========================================"