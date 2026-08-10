#!/usr/bin/env bash

set -euo pipefail
SERVER_IP="192.168.56.110"
TOKEN_FILE="/vagrant/k3s-node-token"


echo "Waiting for K3s server token..."

# Wait for the server to generate the token
until [ -f "$TOKEN_FILE" ]; do
    echo "Token not available yet. Waiting..."
    sleep 2
done

echo "K3s server token found."

K3S_TOKEN=$(cat "$TOKEN_FILE")

echo "Testing connection to K3s server..."

# Wait for the K3s API server to become reachable
until curl -k -s "https://${SERVER_IP}:6443" > /dev/null; do
    echo "K3s server is not reachable yet. Waiting..."
    sleep 2
done

echo "K3s server is reachable."

# Install K3s agent
curl -sfL https://get.k3s.io | K3S_URL="https://${SERVER_IP}:6443" K3S_TOKEN="$K3S_TOKEN" sh -s - agent \
    --node-ip 192.168.56.111 \
    --flannel-iface eth1

echo "Waiting for K3s agent..."

# Give it more time - agent can take a while on first join
for i in $(seq 1 60); do
    if systemctl is-active --quiet k3s-agent; then
        echo "K3s agent is running"
        exit 0
    fi
    sleep 5
done

echo "K3s agent failed to start"
systemctl status k3s-agent --no-pager
journalctl -u k3s-agent -n 50 --no-pager
exit 1
