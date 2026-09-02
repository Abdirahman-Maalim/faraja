# CoreDNS Down

**Alert:** CoreDNSDown
**Meaning:** CoreDNS has zero available replicas — cluster-wide DNS resolution is broken.

## Steps
1. Check CoreDNS pods: `kubectl get pods -n kube-system -l k8s-app=kube-dns`
2. Check recent events: `kubectl describe deployment coredns -n kube-system`
3. Check logs: `kubectl logs -n kube-system -l k8s-app=kube-dns`
4. If crash-looping, check for a resource limit issue or bad ConfigMap change
5. Restart if needed: `kubectl rollout restart deployment/coredns -n kube-system`
 