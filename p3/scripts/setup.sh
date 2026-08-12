#!/usr/bin/env bash
# Поднимает кластер K3d, ставит Argo CD и создаёт Application.
set -euo pipefail

CLUSTER="${CLUSTER:-iot}"
CONFS="$(cd "$(dirname "${BASH_SOURCE[0]}")/../confs" && pwd)"

log() { printf '\033[1;32m[setup]\033[0m %s\n' "$*"; }

# ---------- кластер ----------
if k3d cluster list | grep -qw "$CLUSTER"; then
    log "Кластер '$CLUSTER' уже существует"
else
    log "Создаю кластер '$CLUSTER'..."
    k3d cluster create "$CLUSTER"
fi

kubectl config use-context "k3d-${CLUSTER}"
kubectl wait --for=condition=Ready node --all --timeout=120s

# ---------- namespaces ----------
for ns in argocd dev; do
    kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f -
done

# ---------- Argo CD ----------
log "Ставлю Argo CD (это займёт пару минут)..."
kubectl apply -n argocd \
    -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

log "Жду, пока поднимутся поды Argo CD..."
kubectl wait --for=condition=available --timeout=600s \
    deployment --all -n argocd

# ---------- Application ----------
log "Применяю Application..."
kubectl apply -f "${CONFS}/application.yaml"

# ---------- итог ----------
log "Пароль admin для Argo CD:"
kubectl -n argocd get secret argocd-initial-admin-secret \
    -o jsonpath='{.data.password}' | base64 -d; echo

cat <<'EOF'

Дальше:
  UI Argo CD    kubectl port-forward -n argocd svc/argocd-server 8080:443
                открыть https://localhost:8080  (login: admin)

  Приложение    kubectl port-forward -n dev svc/iot-app 8888:8888
                curl http://localhost:8888

  Статус        kubectl get applications -n argocd
EOF
