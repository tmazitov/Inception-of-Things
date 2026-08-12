#!/usr/bin/env bash
# Creates the K3d cluster, installs Argo CD and applies the Application.
set -euo pipefail

CLUSTER="${CLUSTER:-iot}"
CONFS="$(cd "$(dirname "${BASH_SOURCE[0]}")/../confs" && pwd)"

log() { printf '\033[1;32m[setup]\033[0m %s\n' "$*"; }

# ---------- cluster ----------
if k3d cluster list | grep -qw "$CLUSTER"; then
    log "Cluster '$CLUSTER' already exists"
else
    log "Creating cluster '$CLUSTER'..."
    k3d cluster create "$CLUSTER"
fi

kubectl config use-context "k3d-${CLUSTER}"
kubectl wait --for=condition=Ready node --all --timeout=120s

# ---------- namespaces ----------
for ns in argocd dev; do
    kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f -
done

# ---------- Argo CD ----------
log "Installing Argo CD (this takes a couple of minutes)..."
# --server-side is required: the applicationsets.argoproj.io CRD exceeds 256 KB,
# and a plain apply fails on the last-applied-configuration annotation
kubectl apply -n argocd --server-side --force-conflicts \
    -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

log "Waiting for Argo CD pods to become ready..."
kubectl wait --for=condition=available --timeout=600s \
    deployment --all -n argocd

# ---------- Application ----------
log "Applying the Application..."
kubectl apply -f "${CONFS}/application.yaml"

# ---------- summary ----------
log "Argo CD admin password:"
kubectl -n argocd get secret argocd-initial-admin-secret \
    -o jsonpath='{.data.password}' | base64 -d; echo

cat <<'EOF'

Next steps:
  Argo CD UI    kubectl port-forward -n argocd svc/argocd-server 8080:443
                open https://localhost:8080  (login: admin)

  Application   kubectl port-forward -n dev svc/iot-app 8888:8888
                curl http://localhost:8888

  Status        kubectl get applications -n argocd
EOF
