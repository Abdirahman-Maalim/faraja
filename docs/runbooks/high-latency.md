# High Latency

**Alert:** FarajaHighLatency
**Meaning:** P95 request latency has exceeded 500ms for 10+ minutes.

## Steps
1. Check CPU/memory usage on backend pods in Grafana — resource starvation is the most common cause
2. Check database query performance: `kubectl exec -it postgres-0 -n faraja-ns -- psql -U postgres -c "SELECT * FROM pg_stat_activity;"`
3. Check pod restart count — a recently restarted pod may still be warming up
4. If replicas are under load, consider scaling: `kubectl scale deployment/faraja-backend-deployment -n faraja-ns --replicas=5`