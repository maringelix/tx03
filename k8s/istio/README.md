# Istio Service Mesh - DX03

> Advanced traffic management, security, and observability for microservices

**Version:** Istio 1.20.1  
**Profile:** default  
**Status:** Ready to deploy

---

## 📋 Overview

Istio provides:

### 🔐 Security
- **mTLS (Mutual TLS):** Automatic encryption between services
- **Authorization Policies:** Fine-grained access control
- **Certificate Management:** Automatic certificate rotation
- **JWT Authentication:** Token validation for APIs

### 🚦 Traffic Management
- **Load Balancing:** Intelligent request distribution
- **Circuit Breaking:** Automatic failure handling
- **Retries & Timeouts:** Resilient communication
- **Canary Deployments:** Gradual rollouts
- **A/B Testing:** Traffic splitting

### 📊 Observability
- **Distributed Tracing:** Request flow visualization (Jaeger)
- **Metrics Collection:** Prometheus integration
- **Service Graph:** Kiali visualization
- **Access Logs:** Detailed request logging

---

## 🚀 Deployment

### Quick Start

```bash
# Via GitHub Actions (recommended)
gh workflow run deploy-istio.yml

# Or manually trigger via UI
# https://github.com/maringelix/tx03/actions/workflows/deploy-istio.yml
```

### Manual Installation

```bash
# 1. Download Istio
export ISTIO_VERSION=1.20.1
curl -L https://istio.io/downloadIstio | sh -
cd istio-${ISTIO_VERSION}
export PATH=$PWD/bin:$PATH

# 2. Pre-check
istioctl x precheck

# 3. Install Istio
istioctl install --set profile=default --skip-confirmation

# 4. Label namespace for sidecar injection
kubectl label namespace dx03-dev istio-injection=enabled

# 5. Apply Istio configurations
kubectl apply -f k8s/istio/

# 6. Restart pods to inject sidecars
kubectl rollout restart deployment -n dx03-dev

# 7. Install addons (optional)
kubectl apply -f samples/addons/
```

---

## 📦 Components Installed

### Core Components
- **istiod:** Control plane (Pilot, Citadel, Galley)
- **istio-ingressgateway:** External traffic entry point
- **istio-egressgateway:** External traffic exit point (optional)

### Addons (Optional)
- **Kiali:** Service mesh visualization (`port 20001`)
- **Jaeger:** Distributed tracing (`port 16686`)
- **Prometheus:** Metrics collection (`port 9090`)
- **Grafana:** Metrics dashboards (`port 3000`)

---

## 🌐 Istio Resources

### Gateway Configuration

**File:** `k8s/istio/gateway.yaml`

```yaml
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: dx03-gateway
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 443
      name: https
      protocol: HTTPS
    hosts:
    - "dx03.ddns.net"
    tls:
      mode: SIMPLE
      credentialName: dx03-tls-cert
```

**Features:**
- HTTP to HTTPS redirect
- TLS termination
- Multi-domain support

### VirtualService Routing

**Traffic Rules:**
- `/api/*` → Backend service
- `/health/*` → Backend health checks
- `/*` → Frontend service

**Advanced Features:**
- Timeout: 30s (backend), 15s (frontend)
- Retries: 3 attempts on 5xx errors
- Traffic splitting for canary deployments

### DestinationRule Policies

**Backend:**
- Load balancing: LEAST_REQUEST
- Max connections: 100
- Circuit breaker: 5 consecutive errors
- Outlier detection: Automatic pod ejection

**Frontend:**
- Load balancing: ROUND_ROBIN
- Max connections: 50
- HTTP/2 support

---

## 🔐 Security Configuration

### mTLS (Mutual TLS)

**Status:** STRICT mode enforced

```yaml
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: dx03-dev
spec:
  mtls:
    mode: STRICT
```

**Benefits:**
- Automatic encryption between all services
- No code changes required
- Certificate rotation handled by Istio

### Authorization Policies

**Default Deny:**
```yaml
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: deny-all
spec: {} # Denies all traffic by default
```

**Allowed Traffic:**
1. ✅ Ingress Gateway → Frontend/Backend
2. ✅ Frontend → Backend
3. ✅ Prometheus scraping
4. ❌ Everything else (default deny)

---

## 📊 Observability

### Kiali Dashboard

**Access:**
```bash
kubectl port-forward -n istio-system svc/kiali 20001:20001
# Open: http://localhost:20001
```

**Features:**
- Service topology graph
- Traffic flow visualization
- Configuration validation
- Health status
- Metrics and traces

### Jaeger Tracing

**Access:**
```bash
kubectl port-forward -n istio-system svc/jaeger 16686:16686
# Open: http://localhost:16686
```

**Capabilities:**
- Request trace visualization
- Latency analysis
- Service dependency mapping
- Error tracking

### Prometheus Metrics

**Istio Metrics Available:**
```promql
# Request rate
rate(istio_requests_total[5m])

# Request duration (P95)
histogram_quantile(0.95, rate(istio_request_duration_milliseconds_bucket[5m]))

# Error rate
rate(istio_requests_total{response_code=~"5.."}[5m])

# mTLS status
istio_tcp_connections_opened_total{connection_security_policy="mutual_tls"}
```

---

## 🧪 Verification

### Check Installation

```bash
# Istio version
istioctl version

# Control plane status
kubectl get pods -n istio-system

# Proxy status
istioctl proxy-status

# Configuration validation
istioctl analyze -n dx03-dev

# Check sidecar injection
kubectl get pods -n dx03-dev -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].name}{"\n"}{end}'
```

### Verify mTLS

```bash
# Check mTLS status
istioctl authn tls-check $(kubectl get pod -n dx03-dev -l app=dx03-backend -o jsonpath='{.items[0].metadata.name}') -n dx03-dev

# Should show:
# HOST:PORT                                  STATUS     SERVER     CLIENT     AUTHN POLICY
# dx03-backend.dx03-dev.svc.cluster.local   OK         STRICT     ISTIO      default/dx03-dev
```

### Test Traffic

```bash
# Generate traffic
for i in {1..100}; do
  curl -s https://dx03.ddns.net/api/status > /dev/null
  echo "Request $i sent"
  sleep 0.1
done

# View in Kiali dashboard
```

---

## 🔧 Troubleshooting

### Sidecar Not Injected

```bash
# Check namespace label
kubectl get namespace dx03-dev -L istio-injection

# Label namespace if needed
kubectl label namespace dx03-dev istio-injection=enabled

# Restart pods
kubectl rollout restart deployment -n dx03-dev
```

### Configuration Issues

```bash
# Analyze configuration
istioctl analyze -n dx03-dev

# Check pilot logs
kubectl logs -n istio-system -l app=istiod -f

# Describe problematic resource
kubectl describe virtualservice dx03-routes -n dx03-dev
```

### mTLS Issues

```bash
# Check mTLS configuration
istioctl authn tls-check -n dx03-dev

# View certificates
istioctl proxy-config secret -n dx03-dev <pod-name>

# Check PeerAuthentication
kubectl get peerauthentication -n dx03-dev
```

### Performance Issues

```bash
# Check resource usage
kubectl top pods -n istio-system
kubectl top pods -n dx03-dev

# View proxy statistics
istioctl proxy-config clusters <pod-name> -n dx03-dev

# Check circuit breaker status
istioctl proxy-config endpoints <pod-name> -n dx03-dev
```

---

## 📈 Advanced Features

### Canary Deployment

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: backend-canary
spec:
  http:
  - match:
    - headers:
        canary:
          exact: "true"
    route:
    - destination:
        host: dx03-backend
        subset: v2
      weight: 100
  - route:
    - destination:
        host: dx03-backend
        subset: v1
      weight: 90
    - destination:
        host: dx03-backend
        subset: v2
      weight: 10
```

### Fault Injection (Testing)

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: backend-fault-injection
spec:
  http:
  - fault:
      delay:
        percentage:
          value: 10.0
        fixedDelay: 5s
      abort:
        percentage:
          value: 5.0
        httpStatus: 500
```

### Request Timeout & Retries

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: backend-resilience
spec:
  http:
  - timeout: 10s
    retries:
      attempts: 3
      perTryTimeout: 3s
      retryOn: 5xx,reset,connect-failure
```

---

## 🎯 Best Practices

### Security
1. ✅ Always use STRICT mTLS mode in production
2. ✅ Implement default-deny authorization policies
3. ✅ Use least privilege for service-to-service communication
4. ✅ Enable JWT authentication for external APIs
5. ✅ Regularly rotate certificates (automatic with Istio)

### Performance
1. ✅ Set appropriate connection pool sizes
2. ✅ Configure circuit breakers to prevent cascading failures
3. ✅ Use outlier detection for automatic pod ejection
4. ✅ Optimize sidecar resource limits
5. ✅ Monitor proxy CPU/memory usage

### Observability
1. ✅ Keep tracing sample rate reasonable (10-20% in prod)
2. ✅ Use consistent tagging across services
3. ✅ Enable access logging selectively
4. ✅ Set up alerts for service mesh health
5. ✅ Regular review of Kiali dashboards

---

## 📚 Resources

### Documentation
- **Istio Docs:** https://istio.io/latest/docs/
- **Kiali Docs:** https://kiali.io/docs/
- **Jaeger Docs:** https://www.jaegertracing.io/docs/

### Istio Configurations
- [k8s/istio/gateway.yaml](k8s/istio/gateway.yaml) - Gateway and routing
- [k8s/istio/security.yaml](k8s/istio/security.yaml) - mTLS and authorization
- [k8s/istio/telemetry.yaml](k8s/istio/telemetry.yaml) - Metrics and tracing

### Workflows
- [.github/workflows/deploy-istio.yml](.github/workflows/deploy-istio.yml) - CI/CD automation

---

## 🔄 Maintenance

### Upgrade Istio

```bash
# Via workflow
gh workflow run deploy-istio.yml -f action=upgrade

# Or manually
istioctl upgrade --skip-confirmation
```

### Uninstall

```bash
# Via workflow
gh workflow run deploy-istio.yml -f action=uninstall

# Or manually
istioctl uninstall --purge --skip-confirmation
kubectl delete namespace istio-system
```

### Monitor Health

```bash
# Control plane status
kubectl get pods -n istio-system

# Proxy sync status
istioctl proxy-status

# Configuration issues
istioctl analyze -A
```

---

**Last Updated:** December 31, 2025  
**Maintained by:** DevOps Team @ TX03
