# Anthos Service Mesh (ASM) - Google-Managed Istio

> **Fully managed service mesh optimized for GKE**

## Overview

**Anthos Service Mesh (ASM)** é a versão **gerenciada pelo Google** do Istio, otimizada para GKE e compatível com **GKE Autopilot**.

## Key Differences: ASM vs Open Source Istio

| Feature | Open Source Istio | ASM (Anthos Service Mesh) |
|---------|-------------------|---------------------------|
| **Management** | Self-managed | Fully managed by Google |
| **Autopilot Compatibility** | ❌ Sidecar blocked | ✅ Fully compatible |
| **Control Plane** | You manage istiod | Google manages control plane |
| **Updates** | Manual upgrades | Automatic updates |
| **Support** | Community | Google Cloud Support (SLA) |
| **Cost** | Free (compute only) | **$0.50 per vCPU/month** + compute |
| **Observability** | Self-configured | Integrated with Cloud Operations |
| **Security** | Self-configured | Integrated with Cloud Security |

## Pricing

### ASM Cost Breakdown

**Base Cost**: $0.50 per vCPU per month (for workloads with sidecars)

**Example for dx03** (4 pods, 2 vCPU each):
```
4 pods × 2 vCPU × $0.50 = $4.00/month for ASM
+ GKE Autopilot compute costs
+ Ingress traffic costs
```

**Free Tier**: None (charges apply immediately)

**Note**: You still pay for underlying compute (Autopilot pods) on top of ASM fees.

### Cost Comparison

| Solution | Monthly Cost (dx03 workload) |
|----------|------------------------------|
| **No Service Mesh** | $0 (GKE Autopilot only) |
| **Istio Open Source** | ❌ Blocked by GKE Warden |
| **Istio Ambient Mesh** | $0 (GKE Autopilot only) |
| **ASM (Anthos)** | ~$4-8/month + GKE compute |

## Installation Options

### Option 1: In-Cluster Control Plane (Recommended)

ASM control plane runs inside your GKE cluster.

```bash
# Install ASM using asmcli
curl https://storage.googleapis.com/csm-artifacts/asm/asmcli > asmcli
chmod +x asmcli

# Install ASM
./asmcli install \
  --project_id tx03-444615 \
  --cluster_name tx03-gke-cluster \
  --cluster_location us-central1 \
  --fleet_id tx03-444615 \
  --output_dir ./asm-output \
  --enable_all \
  --ca mesh_ca

# Enable sidecar injection
kubectl label namespace dx03-dev istio-injection=enabled istio.io/rev=asm-managed --overwrite
```

### Option 2: Managed Control Plane (Google-hosted)

Google fully manages the control plane outside your cluster.

```bash
# Enable managed ASM
gcloud container fleet mesh enable \
  --project=tx03-444615

# Update cluster to use managed control plane
gcloud container fleet mesh update \
  --management automatic \
  --memberships tx03-gke-cluster \
  --project=tx03-444615 \
  --location=us-central1

# Enable automatic sidecar injection
kubectl label namespace dx03-dev istio-injection- istio.io/rev=asm-managed --overwrite
```

## Features

### ✅ What You Get with ASM

1. **Fully Managed Control Plane**
   - Google manages istiod upgrades
   - Automatic security patches
   - High availability built-in

2. **GKE Autopilot Compatibility**
   - Sidecars work with Autopilot (no GKE Warden issues)
   - Optimized resource requests
   - Automatic scaling

3. **Cloud Operations Integration**
   - Metrics → Cloud Monitoring (no Prometheus needed)
   - Logs → Cloud Logging
   - Traces → Cloud Trace
   - Dashboards in Google Cloud Console

4. **Enterprise Features**
   - Google Cloud Support with SLA
   - Certificate Authority Service integration
   - Config validation and rollback
   - Multi-cluster mesh

5. **Security**
   - Workload Identity integration
   - Certificate management
   - Binary Authorization integration
   - Security posture dashboard

### ⚠️ Limitations

1. **Cost**: $0.50 per vCPU/month (not free)
2. **Vendor Lock-in**: Tightly coupled with GCP
3. **Less Control**: Can't customize everything
4. **Migration**: Requires migration from OSS Istio

## Migration from Open Source Istio to ASM

### Prerequisites

```bash
# Enable required APIs
gcloud services enable mesh.googleapis.com
gcloud services enable anthos.googleapis.com
gcloud services enable gkehub.googleapis.com

# Register cluster to fleet
gcloud container fleet memberships register tx03-gke-cluster \
  --gke-cluster=us-central1/tx03-gke-cluster \
  --enable-workload-identity \
  --project=tx03-444615
```

### Migration Steps

```bash
# 1. Download ASM installation tool
curl https://storage.googleapis.com/csm-artifacts/asm/asmcli_1.20 > asmcli
chmod +x asmcli

# 2. Validate prerequisites
./asmcli validate \
  --project_id tx03-444615 \
  --cluster_name tx03-gke-cluster \
  --cluster_location us-central1 \
  --fleet_id tx03-444615 \
  --output_dir ./asm-validation

# 3. Install ASM (migrate mode)
./asmcli install \
  --project_id tx03-444615 \
  --cluster_name tx03-gke-cluster \
  --cluster_location us-central1 \
  --fleet_id tx03-444615 \
  --output_dir ./asm-output \
  --enable_all \
  --ca mesh_ca \
  --option legacy-default-ingressgateway

# 4. Update namespace label (switch to ASM revision)
kubectl label namespace dx03-dev \
  istio-injection- \
  istio.io/rev=asm-managed \
  --overwrite

# 5. Restart pods to get ASM sidecars
kubectl rollout restart deployment -n dx03-dev
```

### Verify Migration

```bash
# Check ASM control plane
kubectl get pods -n istio-system

# Check sidecar version
kubectl get pods -n dx03-dev -o jsonpath='{.items[*].spec.containers[*].image}' | grep istio-proxy

# Check workload in ASM dashboard
gcloud alpha anthos service-mesh services list \
  --project=tx03-444615 \
  --location=us-central1
```

## Configuration

### Namespace with ASM

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: dx03-dev
  labels:
    # ASM-managed sidecar injection
    istio.io/rev: asm-managed
    
    # Google Cloud labels
    cloud.google.com/service-mesh: enabled
```

### ASM ConfigMap

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: asm-options
  namespace: istio-system
data:
  # Cloud Trace integration
  TRACER_ZIPKIN_ADDRESS: "cloudtrace:9411"
  
  # Cloud Monitoring integration
  MONITORING: "CLOUD_MONITORING"
  
  # Cloud Logging
  ACCESS_LOG_ENCODING: "JSON"
```

## Monitoring & Observability

### Cloud Console Dashboards

Access ASM dashboards in Google Cloud Console:

1. **Service Mesh Overview**
   ```
   https://console.cloud.google.com/anthos/services
   ```

2. **Service Dashboard** (per service metrics)
   ```
   https://console.cloud.google.com/anthos/services/dx03-backend
   ```

3. **SLOs and SLIs**
   ```
   https://console.cloud.google.com/anthos/slo
   ```

### Cloud Monitoring Queries

```sql
-- Request rate
fetch k8s_container
| metric 'istio.io/service/server/request_count'
| filter resource.namespace_name == 'dx03-dev'

-- Error rate
fetch k8s_container
| metric 'istio.io/service/server/request_count'
| filter resource.namespace_name == 'dx03-dev'
| filter metric.response_code >= 400

-- Latency P95
fetch k8s_container
| metric 'istio.io/service/server/response_latencies'
| filter resource.namespace_name == 'dx03-dev'
| group_by [resource.namespace_name]
| percentile 95
```

## Support & SLA

### Support Levels

| Plan | Response Time | Cost |
|------|---------------|------|
| **Basic** | Best effort | Included |
| **Standard** | 4 hours (P2) | $150/month |
| **Enhanced** | 1 hour (P1) | $500/month |
| **Premium** | 15 min (P1) | Custom |

### SLA Coverage

✅ Control plane availability: 99.9%  
✅ Data plane (sidecars): Covered  
✅ Certificate management: Covered  
❌ Application bugs: Not covered  

## Cost Optimization Tips

### Reduce ASM Costs

1. **Selective Sidecar Injection**
   ```yaml
   # Only inject sidecars where needed
   apiVersion: v1
   kind: Pod
   metadata:
     annotations:
       sidecar.istio.io/inject: "false"
   ```

2. **Resource Limits**
   ```yaml
   # Optimize sidecar resources
   apiVersion: install.istio.io/v1alpha1
   kind: IstioOperator
   spec:
     values:
       global:
         proxy:
           resources:
             requests:
               cpu: 50m
               memory: 128Mi
   ```

3. **Use Ambient Mesh Alternative**
   - If L7 features not critical, use Istio Ambient (free)
   - ASM doesn't support Ambient yet (as of Jan 2026)

## Decision Matrix

### When to Use ASM

✅ **Use ASM if:**
- Need enterprise support with SLA
- Want fully managed control plane
- Deep integration with Google Cloud Operations
- Multi-cluster service mesh
- Budget allows $4-8/month for small workloads

❌ **Don't use ASM if:**
- Budget is tight (Free Tier project)
- Istio Ambient Mesh meets requirements
- Want to avoid vendor lock-in
- Small development workload

## Alternative: Istio Ambient Mesh

For **dx03** project with budget constraints, **Istio Ambient Mesh** is recommended:

| Criteria | ASM | Ambient Mesh | Winner |
|----------|-----|--------------|---------|
| **Cost** | ~$4-8/month | $0 | 🏆 Ambient |
| **GKE Autopilot** | ✅ Compatible | ✅ Compatible | Tie |
| **Support** | Enterprise SLA | Community | ASM |
| **Management** | Fully managed | Self-managed | ASM |
| **Features** | Full L7 | L4 + optional L7 | ASM |
| **Maturity** | GA | Beta | ASM |

**Recommendation**: Start with **Istio Ambient Mesh** (free), evaluate ASM later if enterprise features needed.

## References

- **ASM Docs**: https://cloud.google.com/service-mesh/docs
- **ASM Pricing**: https://cloud.google.com/service-mesh/pricing
- **ASM vs OSS Istio**: https://cloud.google.com/service-mesh/docs/managed/service-mesh-compare
- **GKE Autopilot ASM**: https://cloud.google.com/service-mesh/docs/unified-install/gke-install-autopilot

---

**Status**: Alternative option (paid)  
**Cost**: ~$4-8/month for dx03  
**Recommendation**: Use Ambient Mesh first (free), consider ASM for production with SLA requirements
