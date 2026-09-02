# CPU Throttling High

**Alert:** FarajaCPUThrottlingHigh
**Meaning:** A container is being CPU-throttled more than 25% of the time — it's hitting its CPU limit repeatedly.

## Steps
1. Check current CPU usage vs limit in Grafana's CPU per pod panel
2. If consistently throttled under normal load, raise the CPU limit in `backend-deployment.yaml`
3. If it's a traffic spike, consider adding an HPA to scale horizontally instead