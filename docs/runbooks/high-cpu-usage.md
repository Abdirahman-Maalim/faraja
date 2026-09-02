# High CPU Usage

**Alert:** FarajaHighCPUUsage
**Meaning:** A pod has used over 90% of its CPU limit for 15+ minutes.

## Steps
1. Check Grafana's CPU per pod panel for the trend
2. Identify if it's one pod (imbalanced load) or all pods (genuine high traffic)
3. Scale out if genuine load: `kubectl scale deployment/faraja-backend-deployment -n faraja-ns --replicas=5`
4. If one pod is disproportionately loaded, check for a stuck request or inefficient query