# Traffic Drop

**Alert:** FarajaTrafficDrop
**Meaning:** Request rate is less than 50% of what it was at this time last week.

## Steps
1. Check if this is expected (holiday, off-hours, planned maintenance)
2. Check pod health: `kubectl get pods -n faraja-ns`
3. Check frontend connectivity to backend — is the frontend actually reaching the API?
4. Check for a DNS/networking issue: `kubectl exec -it <frontend-pod> -n faraja-ns -- nslookup faraja-backend-svc`