#!/usr/bin/env bash

set -e

K3S_IP="192.168.56.110"

echo "Updating /etc/hosts..."

sudo sed -i '/# K3S-APPS-BEGIN/,/# K3S-APPS-END/d' /etc/hosts

sudo tee -a /etc/hosts > /dev/null <<EOF
# K3S-APPS-BEGIN
${K3S_IP} app1.com
${K3S_IP} app2.com
${K3S_IP} app3.com
# K3S-APPS-END
EOF

echo
echo "K3s host entries:"
grep -A3 'K3S-APPS-BEGIN' /etc/hosts