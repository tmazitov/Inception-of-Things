#!/usr/bin/env bash
set -euo pipefail

K3S_IP="192.168.56.110"
MANIFEST_DIR="/vagrant/confs"

echo "========================================"
echo " Installing dependencies"
echo "========================================"

apt-get update
apt-get install -y curl

echo "========================================"
echo " Installing K3s"
echo "========================================"

if ! command -v k3s >/dev/null 2>&1; then

    curl -sfL https://get.k3s.io | \
        INSTALL_K3S_EXEC="server" sh -s - \
        --write-kubeconfig-mode 644 \
        --node-ip "$K3S_IP" \
        --advertise-address "$K3S_IP" \
        --tls-san "$K3S_IP" \
        --flannel-iface eth1

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

k3s kubectl get nodes

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
curl -s -H "Host: app1.com" "http://$K3S_IP"
echo

echo "--- app2.com ---"
curl -s -H "Host: app2.com" "http://$K3S_IP"
echo

echo "--- default ---"
curl -s -H "Host: anything.com" "http://$K3S_IP"
echo

echo
echo "========================================"
echo " K3s provisioning complete!"
echo "========================================"

# #!/usr/bin/env bash
# set -euo pipefail

# curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server" sh -s - \
#     --write-kubeconfig-mode 644 \
#     --node-ip 192.168.56.110 \
#     --advertise-address 192.168.56.110 \
#     --tls-san 192.168.56.110 \
#     --flannel-iface eth1

# echo "Waiting for K3s server to become ready..."

# # Wait until K3s is actually running
# until systemctl is-active --quiet k3s; do
#     sleep 2
# done

# echo "K3s server is running"

# # Copy the node token to the Vagrant shared folder
# cp /var/lib/rancher/k3s/server/node-token /vagrant/k3s-node-token

# chmod 600 /vagrant/k3s-node-token

# echo "K3s node token has been made available to the worker."
# echo "K3s server installation complete"

# # Show cluster status
# k3s kubectl get nodes
