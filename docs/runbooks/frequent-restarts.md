# Pod Restarting Frequently

**Alert:** FarajaPodRestartingFrequently
**Meaning:** A pod has restarted more than 3 times in the last 30 minutes.

## Steps
1. Check the reason: `kubectl describe pod <pod-name> -n faraja-ns` — look at `Last State`
2. Check logs from the previous crash: `kubectl logs <pod-name> -n faraja-ns --previous`
3. Common causes: unhandled exception on startup, failed DB connection, OOMKill
4. If it's crash-looping on a bad deploy, roll back: `kubectl rollout undo deployment/faraja-backend-deployment -n faraja-ns`