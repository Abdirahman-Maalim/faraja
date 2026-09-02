# PVC Pending

**Alert:** FarajaPVCPending
**Meaning:** A PersistentVolumeClaim has been stuck in Pending state for 5+ minutes.

## Steps
1. Check the PVC status: `kubectl describe pvc <name> -n faraja-ns`
2. Look at the Events section — usually shows why binding failed (no matching PV, storage class issue)
3. Check available PVs: `kubectl get pv`
4. If using a StorageClass with dynamic provisioning, check the provisioner is running