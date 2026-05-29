#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLUSTER_NAME="${CLUSTER_NAME:-devsecops}"
KUBE_CONTEXT="${KUBE_CONTEXT:-kind-devsecops}"
IMAGE_NAME="${IMAGE_NAME:-shared-app:latest}"
ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"
APPS=(
  "shared-app-dev"
  "shared-app-stage"
  "shared-app-prod"
)

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

for cmd in docker kind kubectl; do
  require_cmd "$cmd"
done

echo "Building image: $IMAGE_NAME"
docker build -t "$IMAGE_NAME" "$ROOT_DIR/shared-app"

echo "Loading image into kind cluster: $CLUSTER_NAME"
kind load docker-image --name "$CLUSTER_NAME" "$IMAGE_NAME"

echo "Refreshing Argo CD applications"
kubectl annotate application \
  -n "$ARGOCD_NAMESPACE" \
  --context "$KUBE_CONTEXT" \
  "${APPS[@]}" \
  argocd.argoproj.io/refresh=hard \
  --overwrite >/dev/null

echo "Waiting for deployments"
kubectl rollout status deployment/shared-app -n dev --context "$KUBE_CONTEXT" --timeout=180s
kubectl rollout status deployment/shared-app -n stage --context "$KUBE_CONTEXT" --timeout=180s
kubectl rollout status deployment/shared-app -n prod --context "$KUBE_CONTEXT" --timeout=180s

echo
echo "Argo CD status"
kubectl get application -n "$ARGOCD_NAMESPACE" --context "$KUBE_CONTEXT" -o wide

echo
echo "Shared-app workloads"
kubectl get deploy,svc,pods -A --context "$KUBE_CONTEXT" | grep shared-app || true
