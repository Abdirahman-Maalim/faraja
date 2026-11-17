# Helm chart

`helm/faraja/` replaces the raw manifests in `k8s/` (kept until the first successful EKS sync, then removable).

| File | Purpose |
|---|---|
| `values.yaml` | Shared defaults (replicas, resources, probes, ports) |
| `values-minikube.yaml` | Local: no ECR, no Gateway, `standard` storage |
| `values-eks.yaml` | EKS: ECR registry, image tags (bumped by Jenkins), Gateway + EBS StorageClass |

```bash
# Validate (helm lint + render + schema check + diff vs k8s/)
scripts/validate-chart.sh

# Minikube
kubectl create secret generic faraja-db-secret -n faraja-ns --from-literal=POSTGRES_PASSWORD=... --from-literal=DATABASE_URL=...   # after creating the namespace
helm upgrade --install faraja helm/faraja -f helm/faraja/values-minikube.yaml -n faraja-ns --create-namespace
helm test faraja -n faraja-ns
kubectl -n faraja-ns port-forward svc/frontend 3001:3001

# Upgrade / rollback
helm upgrade faraja helm/faraja -f helm/faraja/values-minikube.yaml -n faraja-ns
helm rollback faraja 1 -n faraja-ns
```

On EKS ArgoCD renders the chart with `values-eks.yaml`; Jenkins builds images, lints the chart, and commits the new
`tag:` values. The database Secret is never in Git: create it by hand once.

Switching account: change `imageRegistry` in `values-eks.yaml` and `REGISTRY` in the `Jenkinsfile`.

## Database secret
```bash
kubectl -n faraja-ns create secret generic faraja-db-secret --from-literal=POSTGRES_PASSWORD=... --from-literal=DATABASE_URL=...
```
