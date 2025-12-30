# 📊 Observability Stack para DX03 (GKE)

Stack completa de observabilidade com **Prometheus**, **Grafana** e **Alertmanager** para monitorar a aplicação DX03 rodando no Google Kubernetes Engine (GKE).

## 📦 Componentes

- **Prometheus**: Coleta e armazena métricas de time-series
- **Grafana**: Visualização e dashboards interativos
- **Alertmanager**: Gerenciamento e roteamento de alertas
- **Node Exporter**: Métricas de hardware e OS dos nodes
- **Kube State Metrics**: Métricas dos recursos do Kubernetes

## 🚀 Deploy via GitHub Actions

### 1. Configurar Secret do Grafana

Antes de executar o workflow, configure o secret `GRAFANA_PASSWORD`:

```bash
# No GitHub: Settings → Secrets and variables → Actions → New repository secret
Nome: GRAFANA_PASSWORD
Valor: <sua-senha-forte>
```

### 2. Executar Workflow

1. Acesse: [Actions → Deploy Observability Stack](../../actions/workflows/deploy-observability.yml)
2. Clique em **Run workflow**
3. Selecione a action: **install**
4. (Opcional) Adicione Slack Webhook URL para notificações
5. Clique em **Run workflow**

### 3. Aguardar Deploy

O workflow irá:
- ✅ Criar namespace `monitoring`
- ✅ Instalar kube-prometheus-stack via Helm
- ✅ Configurar Alertmanager com Slack (se fornecido)
- ✅ Criar ServiceMonitors para DX03
- ✅ Instalar dashboard customizado do DX03
- ✅ Aguardar todos os pods ficarem prontos

**Tempo estimado**: 5-8 minutos

## 🔐 Acessar Grafana

### Opção 1: Port-forward (Recomendado)

```bash
# Port-forward para Grafana
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 8080:80

# Acesse no navegador
http://localhost:8080

# Credenciais
Username: admin
Password: <GRAFANA_PASSWORD secret>
```

### Opção 2: Expor via Load Balancer (Custo adicional)

```bash
# Criar LoadBalancer service
kubectl expose service kube-prometheus-stack-grafana \
  --type=LoadBalancer \
  --name=grafana-external \
  -n monitoring

# Aguardar IP externo
kubectl get svc grafana-external -n monitoring -w

# Acesse pelo IP
http://<EXTERNAL-IP>
```

⚠️ **Atenção**: LoadBalancer no GCP tem custo adicional (~$20/mês).

## 📈 Acessar Prometheus

```bash
# Port-forward para Prometheus
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090

# Acesse no navegador
http://localhost:9090

# Explorar targets
http://localhost:9090/targets

# Explorar métricas
http://localhost:9090/graph
```

## 🔔 Acessar Alertmanager

```bash
# Port-forward para Alertmanager
kubectl port-forward -n monitoring svc/kube-prometheus-stack-alertmanager 9093:9093

# Acesse no navegador
http://localhost:9093

# Ver alertas ativos
http://localhost:9093/#/alerts
```

## 📊 Dashboards Disponíveis

### DX03 Application Dashboard

Dashboard customizado com:
- **Running Pods**: Número de pods rodando
- **CPU Usage**: Uso de CPU por pod
- **Memory Usage**: Uso de memória por pod
- **Network Traffic**: Tráfego de rede por pod
- **Pod Information**: Tabela com informações dos pods

**Como acessar**:
1. Acesse Grafana (http://localhost:8080)
2. Menu lateral → Dashboards → Browse
3. Procure por "DX03 Application Dashboard"

### Dashboards Pré-instalados

- **Kubernetes / Compute Resources / Cluster**: Visão geral do cluster
- **Kubernetes / Compute Resources / Namespace (Pods)**: Métricas por namespace
- **Kubernetes / Networking / Cluster**: Networking do cluster
- **Node Exporter / Nodes**: Métricas detalhadas dos nodes
- **Prometheus / Overview**: Estatísticas do Prometheus

## 🎯 Métricas Coletadas

### Métricas de Container

```promql
# CPU usage
container_cpu_usage_seconds_total{namespace="dx03-dev"}

# Memory usage
container_memory_working_set_bytes{namespace="dx03-dev"}

# Network traffic
container_network_receive_bytes_total{namespace="dx03-dev"}
container_network_transmit_bytes_total{namespace="dx03-dev"}
```

### Métricas de Kubernetes

```promql
# Pod status
kube_pod_status_phase{namespace="dx03-dev"}

# Pod restarts
kube_pod_container_status_restarts_total{namespace="dx03-dev"}

# Resource requests/limits
kube_pod_container_resource_requests{namespace="dx03-dev"}
kube_pod_container_resource_limits{namespace="dx03-dev"}
```

### Métricas de Node

```promql
# Node CPU
node_cpu_seconds_total

# Node memory
node_memory_MemAvailable_bytes
node_memory_MemTotal_bytes

# Disk usage
node_filesystem_avail_bytes
node_filesystem_size_bytes
```

## 🔔 Configurar Alertas via Slack

### 1. Criar Slack App

1. Acesse https://api.slack.com/apps
2. Clique em **Create New App** → **From scratch**
3. Nome: "DX03 Alerts"
4. Workspace: Seu workspace
5. Clique em **Create App**

### 2. Ativar Incoming Webhooks

1. No menu lateral → **Incoming Webhooks**
2. Ative **Activate Incoming Webhooks**
3. Clique em **Add New Webhook to Workspace**
4. Selecione o canal: `#dx03-alerts`
5. Copie a **Webhook URL**

### 3. Configurar no GitHub

```bash
# Adicione como secret
Settings → Secrets and variables → Actions → New repository secret
Nome: SLACK_WEBHOOK_URL
Valor: https://hooks.slack.com/services/XXXXX/YYYYY/ZZZZZ
```

### 4. Re-executar Workflow

Execute o workflow novamente com action: **upgrade**. O Alertmanager será reconfigurado com o webhook do Slack.

## 📦 Armazenamento

### Persistent Volumes

A stack cria os seguintes PVCs:

```bash
# Listar PVCs
kubectl get pvc -n monitoring

# Volumes criados:
# - prometheus-kube-prometheus-stack-prometheus-db-0 (10Gi)
# - kube-prometheus-stack-grafana (5Gi)
# - alertmanager-kube-prometheus-stack-alertmanager-db-0 (2Gi)
```

### Retenção de Dados

- **Prometheus**: 7 dias (configurável em `prometheus-values.yaml`)
- **Grafana**: Persistente enquanto o PVC existir
- **Alertmanager**: Persistente enquanto o PVC existir

## 🔄 Upgrade da Stack

```bash
# Via workflow: Run workflow → Action: upgrade
```

Ou manualmente:

```bash
# Update Helm repo
helm repo update

# Upgrade
helm upgrade kube-prometheus-stack \
  prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --values k8s/observability/prometheus-values.yaml \
  --set grafana.adminPassword="<YOUR_PASSWORD>"
```

## 🗑️ Desinstalar Stack

```bash
# Via workflow: Run workflow → Action: uninstall
```

Ou manualmente:

```bash
# Uninstall Helm chart
helm uninstall kube-prometheus-stack -n monitoring

# Delete namespace
kubectl delete namespace monitoring

# (Opcional) Delete PVCs para remover dados
kubectl delete pvc --all -n monitoring
```

## 💰 Custos Estimados

### Recursos da Stack

| Componente | CPU | Memória | Storage |
|------------|-----|---------|---------|
| Prometheus | 200m-1000m | 512Mi-2Gi | 10Gi |
| Grafana | 100m-300m | 256Mi-512Mi | 5Gi |
| Alertmanager | 50m-200m | 128Mi-256Mi | 2Gi |
| Prometheus Operator | 50m-200m | 128Mi-256Mi | - |
| Node Exporter | 50m-100m | 64Mi-128Mi | - |
| Kube State Metrics | 50m-100m | 128Mi-256Mi | - |
| **Total** | **~500m-2000m** | **~1.2Gi-3.5Gi** | **17Gi** |

### Custo Mensal Estimado (GKE Autopilot)

- **Compute (pods)**: ~$15-25/mês
- **Storage (PD)**: ~$2-3/mês (17Gi × $0.10/Gi)
- **Total**: **~$17-28/mês**

⚠️ **Nota**: GKE Autopilot cobra apenas pelos recursos efetivamente usados.

## 📚 Recursos Adicionais

- [Prometheus Documentation](https://prometheus.io/docs/introduction/overview/)
- [Grafana Documentation](https://grafana.com/docs/)
- [kube-prometheus-stack Chart](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
- [PromQL Basics](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [Grafana Dashboards](https://grafana.com/grafana/dashboards/)

## 🐛 Troubleshooting

### Pods não iniciam

```bash
# Ver status
kubectl get pods -n monitoring

# Ver logs
kubectl logs -n monitoring <pod-name>

# Descrever pod
kubectl describe pod -n monitoring <pod-name>
```

### Prometheus não coleta métricas

```bash
# Ver targets no Prometheus
http://localhost:9090/targets

# Ver ServiceMonitors
kubectl get servicemonitor -n monitoring

# Ver logs do Prometheus
kubectl logs -n monitoring prometheus-kube-prometheus-stack-prometheus-0
```

### Grafana não conecta ao Prometheus

```bash
# Testar conexão
kubectl exec -it -n monitoring <grafana-pod> -- wget -O- http://kube-prometheus-stack-prometheus:9090/api/v1/status/config

# Ver logs do Grafana
kubectl logs -n monitoring <grafana-pod>
```

### Alertmanager não envia notificações

```bash
# Ver configuração
kubectl get secret alertmanager-config -n monitoring -o yaml

# Ver logs
kubectl logs -n monitoring alertmanager-kube-prometheus-stack-alertmanager-0

# Testar webhook
curl -X POST https://hooks.slack.com/services/YOUR/WEBHOOK/URL \
  -H 'Content-Type: application/json' \
  -d '{"text": "Test message"}'
```

## 📝 Logs Úteis

```bash
# Logs de todos os pods
kubectl logs -n monitoring --all-containers=true -l release=kube-prometheus-stack

# Seguir logs do Prometheus
kubectl logs -n monitoring -f prometheus-kube-prometheus-stack-prometheus-0

# Seguir logs do Grafana
kubectl logs -n monitoring -f <grafana-pod> -c grafana

# Seguir logs do Alertmanager
kubectl logs -n monitoring -f alertmanager-kube-prometheus-stack-alertmanager-0
```

## ✅ Checklist de Deploy

- [ ] Secret `GRAFANA_PASSWORD` configurado
- [ ] (Opcional) Secret `SLACK_WEBHOOK_URL` configurado
- [ ] Workflow executado com sucesso
- [ ] Todos os pods em estado `Running`
- [ ] Grafana acessível via port-forward
- [ ] Dashboard "DX03 Application Dashboard" visível
- [ ] Prometheus coletando métricas de `dx03-dev`
- [ ] Alertmanager configurado (se Slack configurado)

---

**Status**: ✅ Pronto para deploy  
**Última atualização**: 2025-12-30
