# High Error Rate

**Alert:** FarajaHighErrorRate
**Meaning:** More than 1% of requests are returning 5xx errors for 5+ minutes.

## Steps
1. Check pod logs: `kubectl logs -n faraja-ns -l app=faraja --tail=100`
2. Check if the database is reachable: `kubectl exec -it <backend-pod> -n faraja-ns -- python -c "from app.db.session import engine; engine.connect()"`
3. Check recent deployments — was there a code change just before errors started?
4. If a bad deploy caused it, roll back: `kubectl rollout undo deployment/faraja-backend-deployment -n faraja-ns`