# Istio Ambient Mesh - GKE Autopilot Compatible

> **Sidecar-free service mesh using eBPF technology**

## Overview

**Istio Ambient Mesh** é uma arquitetura alternativa do Istio que **não usa sidecars**. Em vez de injetar containers `istio-proxy` em cada pod, ele usa:
- **ztunnel** (zero-trust tunnel): Componente L4 que roda como DaemonSet
- **waypoint proxies**: Componentes L7 opcionais para features avançadas
- **eBPF**: Tecnologia de kernel para captura de tráfego transparente

## Why Ambient Mesh?

### Problem with Sidecar Injection
GKE Autopilot Warden bloqueia Istio sidecar injection devido a:
- Configurações de segurança do `istio-proxy` violam políticas Autopilot
- Security contexts incompatíveis com restrições do GKE
- Mutating webhooks muito permissivos

### Ambient Mesh Solution
✅ **No sidecars** - Não injeta containers nos pods da aplicação  
✅ **GKE Autopilot compatible** - ztunnel como DaemonSet é permitido  
✅ **Transparent** - Aplicação não precisa ser modificada  
✅ **Lower overhead** - Menos recursos consumidos (sem proxy por pod)  
✅ **mTLS automático** - L4 encryption via ztunnel  
✅ **Features opcionais** - L7 features via waypoint proxies quando necessário  

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Istio Control Plane                      │
│                    (istiod - já instalado)                   │
└─────────────────────────────────────────────────────────────┘
                              │
                    ┌─────────┴─────────┐
                    │                   │
         ┌──────────▼──────────┐   ┌───▼────────────────┐
         │   ztunnel (L4)      │   │  Waypoint Proxy    │
         │   DaemonSet         │   │  (L7 - Optional)   │
         │   - mTLS            │   │  - Routing         │
         │   - AuthN/AuthZ     │   │  - Retries         │
         │   - Telemetry       │   │  - Circuit Break   │
         └──────────┬──────────┘   └───┬────────────────┘
                    │                   │
         ┌──────────▼───────────────────▼──────────┐
         │     Application Pods (1/1 containers)    │
         │     No istio-proxy sidecar injected      │
         └──────────────────────────────────────────┘
```

## Installation Steps

### 1. Install Istio with Ambient Profile

```bash
# Download istioctl if not already installed
curl -L https://istio.io/downloadIstio | sh -
cd istio-*
export PATH=$PWD/bin:$PATH

# Install Istio with ambient profile
istioctl install --set profile=ambient --skip-confirmation

# Verify installation
kubectl get pods -n istio-system
# Expected: istiod + ztunnel DaemonSet running
```

### 2. Enable Ambient Mesh for Namespace

```bash
# Label namespace for ambient mesh
kubectl label namespace dx03-dev istio.io/dataplane-mode=ambient

# Verify label
kubectl get namespace dx03-dev --show-labels
```

### 3. Verify Traffic Encryption

```bash
# Check ztunnel logs
kubectl logs -n istio-system -l app=ztunnel --tail=50

# Verify mTLS is active
istioctl proxy-status

# Check workload status
kubectl get workloadentry -A
```

### 4. Optional: Deploy Waypoint Proxy for L7 Features

```bash
# Deploy waypoint proxy for namespace
istioctl waypoint apply -n dx03-dev

# Or for specific service
istioctl waypoint apply -n dx03-dev --for service/dx03-backend

# Verify waypoint proxy
kubectl get pods -n dx03-dev -l istio.io/gateway-name
```

## Migration from Sidecar to Ambient

### Current State (Sidecar - Não Funciona)
- ❌ Label: `istio-injection=enabled`
- ❌ Pods: Bloqueados pelo GKE Warden
- ❌ Status: 0/2 pods criados

### Target State (Ambient - Funciona)
- ✅ Label: `istio.io/dataplane-mode=ambient`
- ✅ Pods: 1/1 containers (sem sidecar)
- ✅ ztunnel: L4 features ativas
- ✅ Status: 2/2 pods running

### Migration Steps

```bash
# 1. Remove sidecar injection label (já feito)
kubectl label namespace dx03-dev istio-injection-

# 2. Enable ambient mesh
kubectl label namespace dx03-dev istio.io/dataplane-mode=ambient

# 3. Restart pods (if needed)
kubectl rollout restart deployment/dx03-backend -n dx03-dev
kubectl rollout restart deployment/dx03-frontend -n dx03-dev

# 4. Verify traffic is encrypted
istioctl proxy-status
```

## Features Available

### ✅ L4 Features (via ztunnel - sempre ativo)
- **mTLS encryption** - Automatic encryption between services
- **Zero-trust security** - Identity-based authentication
- **Basic telemetry** - Connection metrics
- **Authorization policies** - L4 AuthZ rules
- **Traffic capture** - Transparent traffic interception

### 🔄 L7 Features (via waypoint proxy - opcional)
- **Advanced routing** - Header-based, path-based routing
- **Traffic shifting** - Canary, A/B testing
- **Retries & timeouts** - Resilience features
- **Circuit breaking** - Fault tolerance
- **Rate limiting** - Traffic control
- **Rich telemetry** - HTTP metrics, tracing

## Configuration Files

### Namespace Label
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: dx03-dev
  labels:
    istio.io/dataplane-mode: ambient
```

### Waypoint Proxy (Optional)
```yaml
apiVersion: gateway.networking.k8s.io/v1beta1
kind: Gateway
metadata:
  name: dx03-waypoint
  namespace: dx03-dev
spec:
  gatewayClassName: istio-waypoint
  listeners:
  - name: mesh
    port: 15008
    protocol: HBONE
```

## Verification Commands

```bash
# Check ztunnel status
kubectl get daemonset -n istio-system ztunnel

# Check ambient-enabled namespaces
kubectl get namespaces -l istio.io/dataplane-mode=ambient

# Check workload enrollment
kubectl get workloadentry -A

# Verify mTLS
istioctl experimental authz check <pod-name> -n dx03-dev

# Check ztunnel logs for traffic
kubectl logs -n istio-system -l app=ztunnel -f
```

## Monitoring & Observability

### Kiali Dashboard
```bash
# Port-forward Kiali
kubectl port-forward -n istio-system svc/kiali 20001:20001

# Access: http://localhost:20001
# View: Ambient mesh topology, mTLS status
```

### Prometheus Metrics
```bash
# Ambient-specific metrics
kubectl port-forward -n istio-system svc/prometheus 9090:9090

# Metrics to check:
# - istio_tcp_connections_opened_total
# - istio_tcp_connections_closed_total
# - ztunnel_*
```

### Grafana Dashboards
```bash
# Port-forward Grafana
kubectl port-forward -n istio-system svc/grafana 3000:3000

# Dashboards:
# - Istio Ambient Mesh Dashboard
# - ztunnel Performance
```

## Troubleshooting

### Pods not enrolled in ambient mesh
```bash
# Check namespace label
kubectl get namespace dx03-dev -o yaml | grep dataplane-mode

# Check ztunnel logs
kubectl logs -n istio-system -l app=ztunnel | grep dx03-dev
```

### mTLS not working
```bash
# Verify certificates
istioctl proxy-config secret -n istio-system <ztunnel-pod>

# Check SPIFFE identities
kubectl exec -n istio-system <ztunnel-pod> -- pilot-agent request GET /certs
```

### Performance issues
```bash
# Check ztunnel resource usage
kubectl top pods -n istio-system -l app=ztunnel

# Increase ztunnel resources if needed
kubectl patch daemonset -n istio-system ztunnel --type='json' \
  -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/resources/requests/memory", "value":"512Mi"}]'
```

## GKE Autopilot Compatibility

### ✅ What Works
- ztunnel DaemonSet (GKE allows it)
- Namespace-level ambient enrollment
- mTLS L4 encryption
- Basic telemetry
- Authorization policies

### ⚠️ Limitations
- ztunnel resources auto-adjusted by Autopilot
- Some eBPF features may be limited
- Waypoint proxy resources also managed by Autopilot

### ⚙️ Autopilot Optimizations
```yaml
# ztunnel will be auto-adjusted by Autopilot
# Example mutation:
# CPU: 100m → 250m (Autopilot default)
# Memory: 256Mi → 512Mi (Autopilot default)
```

## Cost Comparison

| Mode | Pods | Sidecars | ztunnel | Waypoint | Overhead |
|------|------|----------|---------|----------|----------|
| **No Mesh** | 4 pods (2 backend + 2 frontend) | 0 | 0 | 0 | 0% |
| **Sidecar** ❌ | 4 pods | 4 sidecars | 0 | 0 | ~100% (blocked) |
| **Ambient L4** ✅ | 4 pods | 0 | 3 DaemonSet | 0 | ~15-20% |
| **Ambient L7** ✅ | 4 pods | 0 | 3 DaemonSet | 1-2 | ~25-30% |

## Next Steps

1. ✅ **Migrate to Ambient** - Remove sidecar injection, enable ambient
2. ✅ **Test L4 Features** - Verify mTLS, basic telemetry
3. 🔄 **Evaluate L7 Needs** - Decide if waypoint proxy is needed
4. 🔄 **Apply Policies** - Configure AuthZ, traffic rules
5. 🔄 **Monitor Performance** - Check ztunnel resource usage

## References

- **Istio Ambient Mesh Docs**: https://istio.io/latest/docs/ambient/
- **Ambient Architecture**: https://istio.io/latest/blog/2022/introducing-ambient-mesh/
- **GKE Autopilot Compatibility**: https://cloud.google.com/service-mesh/docs/unified-install/gke-install-multi-cluster
- **ztunnel GitHub**: https://github.com/istio/ztunnel

---

**Status**: Ready to implement  
**Compatibility**: GKE Autopilot ✅  
**Overhead**: Low (~15-20% with ztunnel only)  
**Maturity**: Beta (Istio 1.20+)
