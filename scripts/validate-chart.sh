#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
CHART=helm/faraja
OUT=$(mktemp -d)

echo "== helm lint (both environments)"
helm lint $CHART -f $CHART/values-minikube.yaml
helm lint $CHART -f $CHART/values-eks.yaml

echo "== render"
helm template faraja $CHART -f $CHART/values-eks.yaml     > "$OUT/eks.yaml"
helm template faraja $CHART -f $CHART/values-minikube.yaml > "$OUT/minikube.yaml"

if command -v kubeconform >/dev/null; then
  echo "== kubeconform (Gateway API CRDs skipped unless schemas are available)"
  kubeconform -strict -summary -ignore-missing-schemas "$OUT/eks.yaml" "$OUT/minikube.yaml"
else
  echo "(kubeconform not installed, skipping schema check)"
fi

echo "== sanity: Minikube render must not contain Gateway/StorageClass/ECR"
! grep -E "kind: (Gateway|HTTPRoute|StorageClass)|amazonaws.com" "$OUT/minikube.yaml"

echo "== diff: chart (EKS values) vs current k8s/ manifests (kind/name pairs)"
pairs() { grep -E '^(kind|  name):' "$1" | paste -sd' ' | sed 's/kind:/\nkind:/g' | sed 's/  name:/name:/' | sort -u; }
cat k8s/*.yaml | grep -v '^#' > "$OUT/k8s-all.yaml"
diff <(pairs "$OUT/k8s-all.yaml") <(pairs "$OUT/eks.yaml") && echo "kind/name sets match" || \
  echo "differences above: expected only Secret example (not rendered) and Namespace (created by ArgoCD)"

echo "== full diff of rendered EKS values vs k8s/ (review manually)"
diff <(kubectl kustomize k8s 2>/dev/null || cat "$OUT/k8s-all.yaml") "$OUT/eks.yaml" | head -80 || true

echo "Rendered files kept in $OUT"
