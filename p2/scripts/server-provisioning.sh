#!/usr/bin/env bash
set -euo pipefail

curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server" sh -s - \
    --write-kubeconfig-mode 644 \
    --node-ip 192.168.56.110 \
    --advertise-address 192.168.56.110 \
    --tls-san 192.168.56.110 \
    --flannel-iface eth1

echo "Waiting for K3s server to become ready..."

# Wait until K3s is actually running
until systemctl is-active --quiet k3s; do
    sleep 2
done

echo "K3s server is running"

# Copy the node token to the Vagrant shared folder
cp /var/lib/rancher/k3s/server/node-token /vagrant/k3s-node-token

chmod 600 /vagrant/k3s-node-token

echo "K3s node token has been made available to the worker."
echo "K3s server installation complete"

# Show cluster status
k3s kubectl get nodes
