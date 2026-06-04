#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLUSTER_NAME="akuity-argocd-lab"
ARGO_CHART_VERSION="9.5.17"

require_command() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "ERROR: required command not found: $cmd"
    exit 1
  fi
}

for cmd in docker kind kubectl helm git; do
  require_command "$cmd"
done

if grep -R "REPLACE_WITH_YOUR_GIT_REPO_URL" \
  "$ROOT_DIR/apps" \
  "$ROOT_DIR/bootstrap/root-app.yaml" \
  --include='*.yaml' --include='*.yml' >/dev/null 2>&1; then
  echo "ERROR: the repository URL placeholder still exists in deployable manifests."
  echo "Run: ./scripts/set-repo-url.sh https://github.com/<user>/<repo>.git"
  echo "Then commit and push your repo before bootstrapping."
  exit 1
fi

if ! docker info >/dev/null 2>&1; then
  echo "ERROR: Docker is not reachable. Start Docker Desktop and ensure WSL integration is enabled."
  exit 1
fi

if ! kind get clusters | grep -qx "$CLUSTER_NAME"; then
  echo "Creating kind cluster: $CLUSTER_NAME"
  kind create cluster --config "$ROOT_DIR/kind/cluster.yaml"
else
  echo "Using existing kind cluster: $CLUSTER_NAME"
fi

kubectl cluster-info >/dev/null

echo "Adding/updating Helm repositories"
helm repo add argo https://argoproj.github.io/argo-helm >/dev/null 2>&1 || true
helm repo update argo >/dev/null

echo "Installing minimal bootstrap Argo CD"
helm upgrade --install argocd argo/argo-cd \
  --namespace argocd \
  --create-namespace \
  --version "$ARGO_CHART_VERSION" \
  --values "$ROOT_DIR/bootstrap/argocd-bootstrap-values.yaml" \
  --wait \
  --timeout 12m

echo "Waiting for Argo CD API resources"
kubectl -n argocd rollout status deployment/argocd-server --timeout=5m
kubectl -n argocd rollout status deployment/argocd-repo-server --timeout=5m
kubectl wait --for=condition=Established crd/applications.argoproj.io --timeout=2m

echo "Applying root parent app"
kubectl apply -f "$ROOT_DIR/bootstrap/root-app.yaml"

echo "Waiting for child Applications to be created"
for i in {1..60}; do
  count="$(kubectl -n argocd get applications.argoproj.io --no-headers 2>/dev/null | wc -l | tr -d ' ')"
  if [[ "$count" -ge 4 ]]; then
    break
  fi
  sleep 5
done

kubectl -n argocd get applications.argoproj.io

cat <<'MSG'

Bootstrap complete.

Next commands:
  ./scripts/verify.sh
  kubectl -n argocd port-forward svc/argocd-server 8080:443
  kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80

Argo CD initial admin password:
  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo

MSG
