# High Memory Usage

**Alert:** FarajaHighMemoryUsage
**Meaning:** A pod is using over 90% of its memory limit for 10+ minutes — at risk of OOMKill.

## Steps
1. Check Grafana's Memory per pod panel to see which pod and the trend
2. Check for a memory leak: is usage climbing steadily, or is it a flat plateau?
3. If it's a leak, plan a rolling restart while investigating: `kubectl rollout restart deployment/faraja-backend-deployment -n faraja-ns`
4. If legitimate load, raise the memory limit