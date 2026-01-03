### Cost Analysis Results

**Period:** 2025-12-04 to 2026-01-03


## Top Cost Drivers

1. **GKE Autopilot**: $10-15/month
2. **Cloud SQL**: $10-15/month
3. **Load Balancer**: $20-25/month
4. **Cloud Armor**: $7-10/month
5. **Monitoring/Logging**: $5-10/month

## Active Resources

### GKE Clusters
NAME              LOCATION     CURRENT_NODE_COUNT  STATUS
tx03-gke-cluster  us-central1  4                   RUNNING

### Cloud SQL Instances
NAME                    REGION       TIER  STATUS
tx03-postgres-2f0f334b  us-central1        RUNNABLE

### Load Balancers
NAME                                             REGION       IP_ADDRESS      TARGET
k8s2-fr-wusz7858-dx03-dev-dx03-ingress-o3rycb61               34.36.62.164    https://www.googleapis.com/compute/v1/projects/project-28e61e96-b6ac-4249-a21/global/targetHttpProxies/k8s2-tp-wusz7858-dx03-dev-dx03-ingress-o3rycb61
k8s2-fs-wusz7858-dx03-dev-dx03-ingress-o3rycb61               34.36.62.164    https://www.googleapis.com/compute/v1/projects/project-28e61e96-b6ac-4249-a21/global/targetHttpsProxies/k8s2-ts-wusz7858-dx03-dev-dx03-ingress-o3rycb61
acdcb8524c69547ac85ea66846053bd6                 us-central1  136.119.67.159  https://www.googleapis.com/compute/v1/projects/project-28e61e96-b6ac-4249-a21/regions/us-central1/targetPools/acdcb8524c69547ac85ea66846053bd6

### Persistent Disks
NAME                                       ZONE                                                                                               SIZE_GB  TYPE         STATUS
gk3-tx03-gke-cluster-pool-2-ea05e37d-9n4f  https://www.googleapis.com/compute/v1/projects/project-28e61e96-b6ac-4249-a21/zones/us-central1-a  100      pd-balanced  READY
gk3-tx03-gke-cluster-pool-2-4356841d-dbzg  https://www.googleapis.com/compute/v1/projects/project-28e61e96-b6ac-4249-a21/zones/us-central1-b  100      pd-balanced  READY
gk3-tx03-gke-cluster-pool-2-a337c303-rbdc  https://www.googleapis.com/compute/v1/projects/project-28e61e96-b6ac-4249-a21/zones/us-central1-c  100      pd-balanced  READY
pvc-2b2311e7-0b27-442b-8fe8-2d2590562bd2   https://www.googleapis.com/compute/v1/projects/project-28e61e96-b6ac-4249-a21/zones/us-central1-c  5        pd-balanced  READY
pvc-f7403a7a-b346-4b43-b821-cd5fec15b6c7   https://www.googleapis.com/compute/v1/projects/project-28e61e96-b6ac-4249-a21/zones/us-central1-c  10       pd-balanced  READY
gk3-tx03-gke-cluster-pool-2-4b35f29b-5x4l  https://www.googleapis.com/compute/v1/projects/project-28e61e96-b6ac-4249-a21/zones/us-central1-f  100      pd-balanced  READY

## Budget Status

**Monthly Budget:** $100
**Estimated Monthly Cost:** $60-70
**Budget Utilization:** ~65%

✅ Within budget limits

## 3-Month Forecast

Based on current usage patterns:

| Month | Estimated Cost | Status |
|-------|----------------|--------|
| Current | $65 | ✅ On track |
| Next month | $70 | ✅ Within budget |
| 3 months | $75 | ⚠️ Monitor closely |

