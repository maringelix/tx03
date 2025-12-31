# 📊 Observability Stack - DX03

Stack completa de observabilidade para aplicação DX03 rodando no GKE Autopilot.

## 🎯 Overview

A stack de observabilidade do DX03 combina Prometheus, Grafana e Google Cloud Monitoring para fornecer visibilidade completa da aplicação e infraestrutura.

### Componentes Implementados

- **Prometheus** - Coleta e armazenamento de métricas
- **Grafana** - Visualização e dashboards
- **Alertmanager** - Gerenciamento e notificações de alertas
- **Kube State Metrics** - Métricas de recursos do Kubernetes
- **Google Cloud Monitoring** - Métricas de nodes e infraestrutura GKE
- **prom-client** - Instrumentação do backend Node.js

## 🚀 Deploy

### Via GitHub Actions Workflow

```bash
# Install (primeira vez)
gh workflow run deploy-observability.yml --field action=install

# Upgrade (atualizar)
gh workflow run deploy-observability.yml --field action=upgrade

# Uninstall (remover)
gh workflow run deploy-observability.yml --field action=uninstall
```

### Secrets Necessários

Configure no GitHub Actions:

```bash
GRAFANA_PASSWORD=<senha-forte>
SLACK_WEBHOOK_URL=<webhook-slack> # Opcional
WIF_PROVIDER=<workload-identity-provider>
WIF_SERVICE_ACCOUNT=<service-account-email>
GCP_PROJECT_ID=<project-id>
```

## 📈 Métricas Coletadas

### Backend (Node.js + prom-client)

**Métricas HTTP:**
- `dx03_backend_http_request_duration_seconds` - Latência das requisições
- `dx03_backend_http_requests_total` - Total de requisições por rota/método/status
- `dx03_backend_http_requests_in_progress` - Requisições simultâneas

**Métricas de Banco de Dados:**
- `dx03_backend_db_pool_connections` - Conexões do pool PostgreSQL
- `dx03_backend_db_query_duration_seconds` - Latência das queries
- `dx03_backend_db_queries_total` - Total de queries por tipo/status

**Métricas do Node.js:**
- `dx03_backend_process_cpu_*` - Uso de CPU
- `dx03_backend_process_resident_memory_bytes` - Memória utilizada
- `dx03_backend_nodejs_eventloop_lag_*` - Event loop lag
- `dx03_backend_nodejs_heap_*` - Heap do V8

### Kubernetes (Kube State Metrics)

- Pods: status, restarts, CPU, memória
- Deployments: replicas desejadas vs disponíveis
- Services: endpoints ativos
- PersistentVolumes: capacidade e uso

### Infraestrutura (Google Cloud Monitoring)

- CPU e memória dos nodes
- Network I/O dos nodes
- Disk I/O e utilização
- Métricas do Load Balancer

## 🖥️ Acesso aos Componentes

### Grafana

**Via Port-Forward (Recomendado):**
```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3001:80
```

Acesse: http://localhost:3001

**Credenciais padrão:**
- Username: `admin`
- Password: Definida no secret `GRAFANA_PASSWORD`

**Reset de senha se necessário:**
```bash
kubectl exec -n monitoring deployment/kube-prometheus-stack-grafana -- \
  grafana-cli admin reset-admin-password NovaSenha123
```

### Prometheus

**Via Port-Forward:**
```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
```

Acesse: http://localhost:9090

**Endpoints úteis:**
- `/targets` - Status dos targets sendo monitorados
- `/graph` - Query interface
- `/alerts` - Alertas ativos

### Alertmanager

**Via Port-Forward:**
```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-alertmanager 9093:9093
```

Acesse: http://localhost:9093

## 📊 Dashboards Disponíveis

### 1. DX03 Application Dashboard

Métricas específicas da aplicação DX03:
- **Running Pods** - Total de pods em execução
- **CPU Usage by Pod** - Uso de CPU por pod
- **Memory Usage by Pod** - Uso de memória por pod
- **Network Traffic** - Tráfego de rede (incoming/outgoing)
- **Pod Information** - Tabela com detalhes dos pods

### 2. GKE Nodes Dashboard (Cloud Monitoring)

Métricas dos nodes do GKE Autopilot:
- **Node CPU Utilization** - Utilização de CPU dos nodes
- **Node Memory Utilization** - Utilização de memória dos nodes
- **CPU Usage by Node** - Série temporal de CPU por node
- **Memory Allocatable** - Memória disponível por node
- **Network Traffic** - Tráfego enviado/recebido pelos nodes

### 3. Dashboards Built-in

O Grafana vem com vários dashboards pré-configurados:
- Kubernetes Cluster Overview
- Prometheus Stats
- Node Exporter (desabilitado no Autopilot)

## 🔔 Alertas

### Configuração do Slack

✅ **Status:** CONFIGURADO E ATIVO

1. Crie um Incoming Webhook no Slack:
   - https://api.slack.com/messaging/webhooks
   - Escolha o canal (#alerts recomendado)
   - Copie a URL do webhook

2. Configure o secret no GitHub:
   ```bash
   gh secret set SLACK_WEBHOOK_URL --body "https://hooks.slack.com/services/..."
   ```

3. Execute o workflow de upgrade:
   ```bash
   gh workflow run deploy-observability.yml --field action=upgrade
   ```

**Configuração Atual:**
- ✅ Secret `SLACK_WEBHOOK_URL` configurado no GitHub
- ✅ Alertmanager reconfigurado com webhook válido
- ✅ Canal: `#dx03-alerts`
- ✅ Notificações ativas para alertas critical, warning e info

### Alertas Configurados

**Alertas Críticos (repeat: 4h):**
- Pod crashlooping
- Deployment com replicas insuficientes
- Node com recursos críticos
- Database connection failures

**Alertas Warning (repeat: 12h):**
- Alto uso de CPU/memória (>80%)
- Latência elevada (P95 > 500ms)
- Error rate acima do threshold (>5%)
- Pool de conexões DB próximo do limite (>80%)

**Alertas Info (repeat: 24h):**
- Eventos de scaling
- Deployment updates
- Certificate renewal notices

## 🔍 Queries Úteis (PromQL)

### Métricas da Aplicação

```promql
# Request rate (req/s)
rate(dx03_backend_http_requests_total[5m])

# Latência P95
histogram_quantile(0.95, 
  rate(dx03_backend_http_request_duration_seconds_bucket[5m])
)

# Error rate (%)
sum(rate(dx03_backend_http_requests_total{status_code=~"5.."}[5m])) / 
sum(rate(dx03_backend_http_requests_total[5m])) * 100

# Conexões ativas do pool DB
dx03_backend_db_pool_connections{state="total"}
```

### Métricas do Kubernetes

```promql
# CPU usage por pod
rate(container_cpu_usage_seconds_total{namespace="dx03-dev"}[5m])

# Memória usage por pod
container_memory_usage_bytes{namespace="dx03-dev"}

# Pods rodando
kube_pod_status_phase{namespace="dx03-dev", phase="Running"}

# Pod restarts
rate(kube_pod_container_status_restarts_total{namespace="dx03-dev"}[1h])
```

## 📦 Armazenamento e Retenção

### Prometheus
- **Retenção:** 7 dias
- **Storage:** 10Gi PVC (standard-rwo)
- **Intervalo de scrape:** 30s

### Grafana
- **Persistence:** 5Gi PVC (standard-rwo)
- **Dashboards:** Persistidos no PVC
- **Datasources:** Definidos no values.yaml

### Alertmanager
- **Storage:** 2Gi PVC (standard-rwo)
- **Retenção:** Baseada na resolução dos alertas

## 🛠️ Troubleshooting

### Grafana não carrega dados

1. Verifique se o Prometheus está coletando:
   ```bash
   kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
   ```
   Acesse http://localhost:9090/targets

2. Teste query no Prometheus:
   ```
   up{job="dx03-backend"}
   ```

3. Verifique datasource no Grafana:
   - Configuration → Data Sources → Prometheus
   - Clique em "Test" para validar conexão

### Métricas do backend não aparecem

1. Verifique se o pod está expondo `/metrics`:
   ```bash
   kubectl exec -n dx03-dev deployment/dx03-backend -- \
     wget -q -O- http://localhost:3000/metrics
   ```

2. Verifique o ServiceMonitor:
   ```bash
   kubectl get servicemonitor -n monitoring
   kubectl describe servicemonitor dx03-backend -n monitoring
   ```

3. Verifique se o label `release=kube-prometheus-stack` está presente:
   ```bash
   kubectl get servicemonitor dx03-backend -n monitoring -o yaml
   ```

### Alertas não chegam no Slack

1. Verifique se o Alertmanager está rodando:
   ```bash
   kubectl get pods -n monitoring | grep alertmanager
   ```

2. Verifique a configuração:
   ```bash
   kubectl get secret alertmanager-config -n monitoring -o yaml
   ```

3. Teste o webhook manualmente:
   ```bash
   curl -X POST <SLACK_WEBHOOK_URL> \
     -H 'Content-Type: application/json' \
     -d '{"text":"Test from Alertmanager"}'
   ```

### Pods em CrashLoopBackOff

**Grafana crashando:**
- Problema comum: Plugins incompatíveis
- Solução: Remover plugins Angular deprecados do values.yaml

**Prometheus OOMKilled:**
- Aumentar recursos no values.yaml
- Reduzir retenção de dados
- Diminuir frequência de scrape

### GKE Autopilot: Recursos Negados

Componentes desabilitados por serem incompatíveis com Autopilot:
- ❌ Node Exporter (usa hostPath)
- ❌ Monitoring de kube-system
- ✅ Alternativa: Google Cloud Monitoring

## 💰 Custos Estimados

**GKE Autopilot (us-central1):**
- Prometheus pod: ~$15-20/mês
- Grafana pod: ~$5-10/mês
- Alertmanager pod: ~$3-5/mês
- **Total estimado:** $23-35/mês

**Persistent Storage:**
- 17Gi total (10Gi + 5Gi + 2Gi): ~$3-5/mês

**Total geral:** ~$26-40/mês

## 📚 Referências

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
- [GKE Autopilot Documentation](https://cloud.google.com/kubernetes-engine/docs/concepts/autopilot-overview)
- [prom-client (Node.js)](https://github.com/siimon/prom-client)

## 🔄 Upgrade e Manutenção

### Upgrade do Helm Chart

```bash
# Verificar versão atual
helm list -n monitoring

# Atualizar repo
helm repo update

# Upgrade via workflow
gh workflow run deploy-observability.yml --field action=upgrade
```

### Backup de Dashboards

Os dashboards são persistidos no PVC do Grafana. Para backup adicional:

```bash
# Export via API
curl -H "Authorization: Bearer <api-key>" \
  http://localhost:3001/api/dashboards/db/<dashboard-slug> > backup.json
```

### Limpeza

Para remover completamente:

```bash
# Via workflow (mantém PVCs por padrão)
gh workflow run deploy-observability.yml --field action=uninstall

# Manual (incluindo PVCs)
helm uninstall kube-prometheus-stack -n monitoring
kubectl delete pvc -n monitoring --all
kubectl delete namespace monitoring
```

---

## 🔐 Segurança e HTTPS

### HTTPS Redirect

✅ **Status:** ATIVO (implementado em 31/12/2025)

**Configuração:**
- Recurso: `FrontendConfig` (GKE-specific)
- Comportamento: Redireciona todo tráfego HTTP → HTTPS (301 Moved Permanently)
- Certificado: Google-managed SSL certificate (válido até 29/03/2026)
- Aplicado em: Load Balancer Ingress

**Arquivos:**
- [k8s/frontend-config.yaml](https://github.com/maringelix/dx03/blob/master/k8s/frontend-config.yaml) - FrontendConfig resource
- [k8s/ingress.yaml](https://github.com/maringelix/dx03/blob/master/k8s/ingress.yaml) - Ingress com annotation

**Teste:**
```bash
# HTTP deve retornar 301 redirect
curl -I http://dx03.ddns.net

# Deve retornar:
# HTTP/1.1 301 Moved Permanently
# Location: https://dx03.ddns.net/
```

**Implementação:**
```yaml
# FrontendConfig
apiVersion: networking.gke.io/v1beta1
kind: FrontendConfig
metadata:
  name: dx03-frontend-config
spec:
  redirectToHttps:
    enabled: true
    responseCodeName: "MOVED_PERMANENTLY_DEFAULT"

# Ingress annotation
metadata:
  annotations:
    networking.gke.io/v1beta1.FrontendConfig: "dx03-frontend-config"
```

---

## 📊 Histórico de Implementação

### Session 31/12/2025 - HTTPS Redirect + Slack Alerts

**Implementações:**
1. ✅ **HTTPS Redirect** via FrontendConfig
   - Criado recurso FrontendConfig
   - Atualizado Ingress com annotation
   - Workflow deploy atualizado
   - Commits: `f44fccc`, `2e43c1f`

2. ✅ **Slack Alertmanager**
   - Diagnosticado: Secret `SLACK_WEBHOOK_URL` não configurado
   - Configurado secret no GitHub
   - Re-deploy observability executado
   - Alertmanager com webhook ativo
   - Run ID: `20612370155` (success)

**Resultados:**
- Todo tráfego HTTP → HTTPS (301)
- Alertas Prometheus → Slack `#dx03-alerts`
- Zero downtime nas mudanças

---

**Última atualização:** 31 de Dezembro de 2025
