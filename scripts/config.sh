#!/usr/bin/env bash
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Kubernetes / ArgoCD
NAMESPACE="${NAMESPACE:-faraja-ns}"
ARGOCD_NS="${ARGOCD_NS:-argocd}"
ARGOCD_APP="${ARGOCD_APP:-faraja}"
GIT_BRANCH="${GIT_BRANCH:-Developer}"

# Docker Hub
DOCKERHUB_USER="${DOCKERHUB_USER:-teqiee}"
BACKEND_IMAGE="${BACKEND_IMAGE:-$DOCKERHUB_USER/faraja-backend}"
FRONTEND_IMAGE="${FRONTEND_IMAGE:-$DOCKERHUB_USER/faraja-frontend}"
BACKEND_MANIFEST="${BACKEND_MANIFEST:-k8s/backend-deployment.yaml}"
FRONTEND_MANIFEST="${FRONTEND_MANIFEST:-k8s/frontend-deployment.yaml}"
BACKEND_DEPLOY="${BACKEND_DEPLOY:-faraja-backend-deployment}"
FRONTEND_DEPLOY="${FRONTEND_DEPLOY:-faraja-frontend-deployment}"
BACKEND_URL="${BACKEND_URL:-http://localhost:8001}"

# Database
DB_STATEFULSET="${DB_STATEFULSET:-faraja-db-sts}"
DB_POD="${DB_POD:-${DB_STATEFULSET}-0}"
DB_NAME="${DB_NAME:-faraja}"
DB_USER="${DB_USER:-postgres}"

# Monitoring namespace (where kube-prometheus-stack lives)
MONITORING_NS="${MONITORING_NS:-monitoring}"

# say "text"  - start of a step.        say "Pulling image"
say()  { echo "==> $*"; }

# ok "text"   - something worked.       ok "backend is up"
ok()   { echo "[ok]    $*"; }

# warn "text" - odd but keep going.     warn "grafana not found"
warn() { echo "[warn]  $*"; }

# bad "text"  - a check failed.         bad "pods not running"
bad()  { echo "[FAIL]  $*"; }

# die "text"  - stop the script.        die "backend down"
die()  { echo "[error] $*" >&2; exit 1; }

# stop if a tool is missing.   need kubectl curl python3
need() { for p in "$@"; do command -v "$p" >/dev/null || die "missing: $p"; done; }

# ask "text"  - y/n prompt. Set ASSUME_YES=1 to skip.
ask() {
  [ "${ASSUME_YES:-}" = 1 ] && return 0
  read -r -p "$1 [y/N] " a
  [ "$a" = y ]
}
}