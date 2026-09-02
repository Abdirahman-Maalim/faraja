# HPA At Max Replicas

**Alert:** FarajaHPAMaxReplicas
**Meaning:** The Horizontal Pod Autoscaler has been at its maximum replica count for 15+ minutes — it can't scale further.

## Steps
1. Check current load: `kubectl get hpa -n faraja-ns`
2. If sustained high load is expected to continue, raise `maxReplicas` in the HPA spec
3. Check if the cluster/node has enough capacity to run more replicas
4. Consider vertical scaling (bigger pods) as an alternative if horizontal scaling is maxed out 