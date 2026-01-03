# Guia de Referência Rápida - TX03

> Quick reference para comandos e recursos do projeto TX03/DX03

**Última atualização:** 31 de Dezembro de 2025

---

## 📋 Índice

- [Informações do Projeto](#informações-do-projeto)
- [Acesso Rápido](#acesso-rápido)
- [Comandos Terraform](#comandos-terraform)
- [Comandos Kubernetes](#comandos-kubernetes)
- [Observabilidade](#observabilidade)
- [Segurança](#segurança)
- [Service Mesh (Istio)](#service-mesh-istio)
- [Cost Management](#cost-management)
- [CI/CD](#cicd)
- [Troubleshooting](#troubleshooting)
- [Links Úteis](#links-úteis)

---

## 🎯 Informações do Projeto

### Recursos GCP

```bash
PROJECT_ID="project-28e61e96-b6ac-4249-a21"
PROJECT_NUMBER="<number>"
REGION="us-central1"
CLUSTER_NAME="tx03-gke-cluster"
```

### Aplicação

```bash
# URLs
HTTP:  http://dx03.ddns.net
HTTPS: https://dx03.ddns.net

# IP Estático
EXTERNAL_IP="34.36.62.164"

# Namespaces
APP_NAMESPACE="dx03-dev"
MONITORING_NAMESPACE="monitoring"
GATEKEEPER_NAMESPACE="gatekeeper-system"
TRIVY_NAMESPACE="trivy-system"
ISTIO_SYSTEM_NAMESPACE="istio-system"
ARGOCD_NAMESPACE="argocd"
```

### Repositórios

```bash
# GitHub
INFRA_REPO="https://github.com/maringelix/tx03"
APP_REPO="https://github.com/maringelix/dx03"

# Artifact Registry
REGISTRY="us-central1-docker.pkg.dev/${PROJECT_ID}/dx03"
```

---

## 🚀 Acesso Rápido

### Conectar ao Cluster

```bash
# 1. Autenticar
gcloud auth login

# 2. Configurar projeto
gcloud config set project project-28e61e96-b6ac-4249-a21

# 3. Conectar ao GKE
gcloud container clusters get-credentials tx03-gke-cluster \
  --region us-central1 \
  --project project-28e61e96-b6ac-4249-a21

# 4. Verificar
kubectl config current-context
kubectl get nodes
```

### Port-Forward para Serviços

```bash
# Grafana (http://localhost:3001)
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3001:80

# Prometheus (http://localhost:9091)
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9091:9090

# Alertmanager (http://localhost:9093)
kubectl port-forward -n monitoring svc/kube-prometheus-stack-alertmanager 9093:9093

# Backend direto (http://localhost:3000)
kubectl port-forward -n dx03-dev svc/dx03-backend 3000:3000

# Kiali - Service Mesh Dashboard (http://localhost:20001)
kubectl port-forward -n istio-system svc/kiali 20001:20001

# Jaeger - Distributed Tracing (http://localhost:16686)
kubectl port-forward -n istio-system svc/tracing 16686:80

# Istio Grafana (http://localhost:3002)
kubectl port-forward -n istio-system svc/grafana 3002:3000

# ArgoCD UI (https://localhost:8080)
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

### Credenciais

```bash
# Grafana
Username: admin
Password: Admin123456

# Cloud SQL
Username: dx03user
Password: (Secret no GitHub)
Database: dx03db
```

---

## 🏗️ Comandos Terraform

### Workflow Básico

```bash
cd terraform/

# Inicializar
terraform init

# Planejar mudanças
terraform plan

# Aplicar
terraform apply

# Destruir (CUIDADO!)
terraform destroy
```

### Comandos Úteis

```bash
# Ver estado atual
terraform show

# Listar recursos
terraform state list

# Ver recurso específico
terraform state show google_container_cluster.gke_cluster

# Importar recurso existente
terraform import google_container_cluster.gke_cluster projects/${PROJECT_ID}/locations/${REGION}/clusters/${CLUSTER_NAME}

# Refresh state
terraform refresh

# Validar configuração
terraform validate

# Formatar código
terraform fmt -recursive
```

### Módulos

```bash
# Aplicar apenas um módulo
terraform apply -target=module.vpc

# Destroy apenas um recurso
terraform destroy -target=google_container_cluster.gke_cluster
```

---

## ☸️ Comandos Kubernetes

### Pods e Deployments

```bash
# Listar todos os recursos
kubectl get all -n dx03-dev

# Pods
kubectl get pods -n dx03-dev
kubectl get pods -n dx03-dev -o wide
kubectl describe pod <pod-name> -n dx03-dev

# Deployments
kubectl get deployments -n dx03-dev
kubectl describe deployment dx03-backend -n dx03-dev
kubectl rollout status deployment/dx03-backend -n dx03-dev

# Escalar deployment
kubectl scale deployment dx03-backend --replicas=3 -n dx03-dev

# Restart deployment
kubectl rollout restart deployment/dx03-backend -n dx03-dev
```

### Logs

```bash
# Logs de um pod
kubectl logs -f <pod-name> -n dx03-dev

# Logs de deployment (todos os pods)
kubectl logs -f deployment/dx03-backend -n dx03-dev

# Logs anteriores (crashed pod)
kubectl logs --previous <pod-name> -n dx03-dev

# Logs com timestamp
kubectl logs -f --timestamps <pod-name> -n dx03-dev

# Últimas N linhas
kubectl logs --tail=100 <pod-name> -n dx03-dev
```

### Services e Ingress

```bash
# Services
kubectl get svc -n dx03-dev
kubectl describe svc dx03-backend -n dx03-dev

# Ingress
kubectl get ingress -n dx03-dev
kubectl describe ingress dx03-ingress -n dx03-dev

# Endpoints
kubectl get endpoints -n dx03-dev
```

### ConfigMaps e Secrets

```bash
# ConfigMaps
kubectl get configmap -n dx03-dev
kubectl describe configmap dx03-backend-config -n dx03-dev
kubectl edit configmap dx03-backend-config -n dx03-dev

# Secrets
kubectl get secrets -n dx03-dev
kubectl describe secret dx03-db-secret -n dx03-dev

# Decode secret
kubectl get secret dx03-db-secret -n dx03-dev -o jsonpath='{.data.password}' | base64 -d
```

### Debugging

```bash
# Executar shell no pod
kubectl exec -it <pod-name> -n dx03-dev -- /bin/sh

# Executar comando
kubectl exec <pod-name> -n dx03-dev -- env | grep DATABASE

# Copiar arquivos
kubectl cp <pod-name>:/path/to/file ./local-file -n dx03-dev

# Ver eventos
kubectl get events -n dx03-dev --sort-by='.lastTimestamp'

# Top (recursos)
kubectl top pods -n dx03-dev
kubectl top nodes
```

### Namespaces

```bash
# Listar namespaces
kubectl get namespaces

# Criar namespace
kubectl create namespace staging

# Deletar namespace
kubectl delete namespace staging

# Ver todos os recursos em um namespace
kubectl api-resources --verbs=list --namespaced -o name | \
  xargs -n 1 kubectl get --show-kind --ignore-not-found -n dx03-dev
```

---

## 📊 Observabilidade

### Prometheus

```bash
# Port-forward
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9091:9090

# Ver configuração
kubectl get prometheus -n monitoring
kubectl describe prometheus kube-prometheus-stack-prometheus -n monitoring

# ServiceMonitors
kubectl get servicemonitors -n monitoring
kubectl get servicemonitors -n dx03-dev

# Alertas ativos
kubectl get prometheusrules -n monitoring
```

### Queries Úteis (PromQL)

```promql
# Taxa de requests HTTP
rate(http_requests_total[5m])

# Latência P95
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))

# Memory usage
container_memory_usage_bytes{namespace="dx03-dev"}

# CPU usage
rate(container_cpu_usage_seconds_total{namespace="dx03-dev"}[5m])

# Pods em estado não-running
kube_pod_status_phase{namespace="dx03-dev",phase!="Running"}
```

### Grafana

```bash
# Port-forward
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3001:80

# Ver senha admin
kubectl get secret kube-prometheus-stack-grafana -n monitoring \
  -o jsonpath='{.data.admin-password}' | base64 -d

# Dashboards configurados
- DX03 Application Dashboard
- GKE Nodes Dashboard
- Kubernetes Cluster Monitoring
- Prometheus Stats
```

### Alertmanager

```bash
# Port-forward
kubectl port-forward -n monitoring svc/kube-prometheus-stack-alertmanager 9093:9093

# Ver configuração
kubectl get secret alertmanager-kube-prometheus-stack-alertmanager -n monitoring \
  -o jsonpath='{.data.alertmanager\.yaml}' | base64 -d

# Silenciar alertas (UI)
# http://localhost:9093/#/silences
```

**📚 Documentação:** [OBSERVABILITY.md](OBSERVABILITY.md)

---

## 🔐 Segurança

### OPA Gatekeeper

```bash
# Ver pods
kubectl get pods -n gatekeeper-system

# Constraint Templates
kubectl get constrainttemplates

# Constraints aplicados
kubectl get constraints -A

# Ver violações
kubectl describe constraint required-resources

# Logs
kubectl logs -n gatekeeper-system -l app=gatekeeper-audit -f
kubectl logs -n gatekeeper-system -l app=gatekeeper-controller-manager -f

# Desabilitar constraint (temporário)
kubectl patch constraint required-resources \
  -p '{"spec":{"enforcementAction":"dryrun"}}' --type=merge
```

### Trivy Operator

```bash
# Ver pods
kubectl get pods -n trivy-system

# Vulnerability Reports
kubectl get vulnerabilityreports -n dx03-dev
kubectl describe vr <pod-name> -n dx03-dev

# Config Audit Reports
kubectl get configauditreports -n dx03-dev
kubectl describe car deployment-dx03-backend -n dx03-dev

# RBAC Assessment
kubectl get rbacassessmentreports -n dx03-dev
kubectl get clusterrbacassessmentreports

# Infra Assessment
kubectl get infraassessmentreports -n dx03-dev

# Logs
kubectl logs -n trivy-system -l app.kubernetes.io/name=trivy-operator -f

# Ver scan jobs
kubectl get jobs -n trivy-system
kubectl get pods -n trivy-system | grep scan-
```

### Comandos Úteis

```bash
# Ver todas as políticas ativas
kubectl get constraints -A -o wide

# Vulnerabilidades CRITICAL
kubectl get vr -n dx03-dev -o json | \
  jq '.items[] | select(.report.summary.critical > 0)'

# Exportar relatório de compliance
kubectl get constraints -A -o yaml > compliance-report.yaml

# Forçar scan manual
kubectl annotate pod <pod-name> -n dx03-dev \
  trivy-operator.aquasecurity.github.io/force-scan=$(date +%s)
```

**📚 Documentação:** [SECURITY.md](SECURITY.md) | [k8s/security/README.md](k8s/security/README.md)

---

## �️ Service Mesh (Istio)

### Verificar Istio

```bash
# Status do Istio
kubectl get pods -n istio-system

# Versão do Istio
kubectl get deploy -n istio-system istiod -o yaml | grep image:

# Gateway
kubectl get gateway -n dx03-dev

# VirtualServices
kubectl get virtualservice -n dx03-dev

# DestinationRules
kubectl get destinationrule -n dx03-dev

# PeerAuthentication (mTLS)
kubectl get peerauthentication -n dx03-dev

# AuthorizationPolicies
kubectl get authorizationpolicy -n dx03-dev
```

### Validar mTLS

```bash
# Verificar mTLS entre services
istioctl authn tls-check <pod-name>.<namespace>

# Ver certificados
istioctl proxy-config secret <pod-name> -n dx03-dev

# Testar comunicação
kubectl exec -n dx03-dev <frontend-pod> -- curl -v http://dx03-backend:3000/health
```

### Troubleshooting Istio

```bash
# Verificar sidecar injection
kubectl get pods -n dx03-dev -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].name}{"\n"}{end}'

# Deve mostrar 2/2 containers (app + istio-proxy)
kubectl get pods -n dx03-dev

# Ver logs do sidecar
kubectl logs -n dx03-dev <pod-name> -c istio-proxy

# Analyze configuration
istioctl analyze -n dx03-dev

# Debug proxy config
istioctl proxy-config listener <pod-name> -n dx03-dev
istioctl proxy-config route <pod-name> -n dx03-dev
istioctl proxy-config cluster <pod-name> -n dx03-dev
```

### Restart Pods para Sidecar Injection

```bash
# Restart deployments
kubectl rollout restart deployment/dx03-backend -n dx03-dev
kubectl rollout restart deployment/dx03-frontend -n dx03-dev

# Verificar rollout
kubectl rollout status deployment/dx03-backend -n dx03-dev
kubectl rollout status deployment/dx03-frontend -n dx03-dev

# Verificar pods com sidecars
kubectl get pods -n dx03-dev
# Deve mostrar 2/2 (app + istio-proxy)
```

---

## 🚀 ArgoCD (GitOps)

### Acesso ArgoCD

```bash
# Get admin password
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d

# Port forward
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Get LoadBalancer IP
kubectl get svc argocd-server -n argocd

# Login via CLI
ARGOCD_SERVER=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
ARGOCD_PASSWORD=$(kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d)
argocd login $ARGOCD_SERVER --username admin --password $ARGOCD_PASSWORD --insecure
```

### Gerenciar Applications

```bash
# Listar applications
argocd app list
kubectl get applications -n argocd

# Ver detalhes da application
argocd app get dx03-app
kubectl describe application dx03-app -n argocd

# Sync manual
argocd app sync dx03-app

# Ver diff
argocd app diff dx03-app

# Ver histórico
argocd app history dx03-app

# Rollback
argocd app rollback dx03-app

# Ver logs
argocd app logs dx03-app --follow
```

### Criar Nova Application

```bash
# Via CLI
argocd app create my-app \
  --repo https://github.com/maringelix/tx03.git \
  --path k8s/application \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace my-namespace \
  --sync-policy automated \
  --auto-prune \
  --self-heal

# Via kubectl
kubectl apply -f k8s/argocd/application-my-app.yaml
```

### Gerenciar Repositórios

```bash
# Listar repos
argocd repo list

# Adicionar repo público
argocd repo add https://github.com/user/repo

# Adicionar repo privado
argocd repo add https://github.com/user/repo \
  --username <username> \
  --password <token>

# Remover repo
argocd repo rm https://github.com/user/repo

# Testar conexão
argocd repo get https://github.com/maringelix/tx03.git
```

### Troubleshooting ArgoCD

```bash
# Status dos pods
kubectl get pods -n argocd

# Logs do server
kubectl logs -f deployment/argocd-server -n argocd

# Logs do application controller
kubectl logs -f deployment/argocd-application-controller -n argocd

# Refresh application (force fetch from Git)
argocd app get dx03-app --refresh

# Terminar sync operation travada
argocd app terminate-op dx03-app

# Restart ArgoCD components
kubectl rollout restart deployment/argocd-server -n argocd
kubectl rollout restart deployment/argocd-repo-server -n argocd
kubectl rollout restart deployment/argocd-application-controller -n argocd
```

### Workflows ArgoCD

```bash
# Deploy ArgoCD
gh workflow run deploy-argocd.yml

# Install
gh workflow run deploy-argocd.yml -f action=install

# Upgrade
gh workflow run deploy-argocd.yml -f action=upgrade

# Get password
gh workflow run deploy-argocd.yml -f action=get-password

# Uninstall
gh workflow run deploy-argocd.yml -f action=uninstall
```

---

### Acessar Dashboards Istio

```bash
# Kiali (Service Mesh Topology)
kubectl port-forward -n istio-system svc/kiali 20001:20001
# http://localhost:20001

# Jaeger (Distributed Tracing)
kubectl port-forward -n istio-system svc/tracing 16686:80
# http://localhost:16686

# Grafana Istio
kubectl port-forward -n istio-system svc/grafana 3002:3000
# http://localhost:3002
```

### Métricas Istio

```bash
# Ver métricas Prometheus do Istio
kubectl port-forward -n istio-system svc/prometheus 9090:9090

# Queries úteis:
# - istio_requests_total
# - istio_request_duration_milliseconds
# - istio_tcp_connections_opened_total
```

---


## 💰 Cost Management

### Budget Status

```bash
# Ver budgets configurados
gcloud billing budgets list --billing-account=BILLING_ACCOUNT_ID

# Ver detalhes de um budget
gcloud billing budgets describe BUDGET_ID \
  --billing-account=BILLING_ACCOUNT_ID

# Ver custos estimados (aproximado)
gcloud billing accounts list
```

### Workflow de Cost Analysis

```bash
# Via GitHub Actions
gh workflow run cost-management.yml \
  --field action=analyze \
  --field days=30 \
  --field format=table

# Actions disponíveis:
# - analyze: Cost breakdown atual
# - report: Relatório detalhado
# - recommendations: Sugestões de otimização
# - export: Exportar para CSV

# Ver último report
gh run list --workflow=cost-management.yml --limit 1
gh run download <run-id>
```

### Resource Inventory

```bash
# Listar todos os recursos ativos
# GKE Clusters
gcloud container clusters list --format='table(name,location,status)'

# Cloud SQL Instances
gcloud sql instances list --format='table(name,region,tier,state)'

# Load Balancers
gcloud compute forwarding-rules list

# Persistent Disks
gcloud compute disks list

# Static IPs (cobrança se não estão em uso)
gcloud compute addresses list --filter="status:RESERVED"
```

### Cost Optimization Commands

```bash
# 1. Identificar discos desanexados (custo desnecessário)
gcloud compute disks list --filter="-users:*" \
  --format='table(name,zone,sizeGb,type)'

# Deletar se não necessário
gcloud compute disks delete DISK_NAME --zone=ZONE

# 2. Identificar IPs estáticos não utilizados
gcloud compute addresses list --filter="status:RESERVED" \
  --format='table(name,region,address)'

# Liberar se não necessário (# - istio_tcp_connections_opened_total
```

---
.01/hour = $7/month)
gcloud compute addresses delete IP_NAME --region=REGION

# 3. Verificar tier do Cloud SQL
gcloud sql instances describe INSTANCE_NAME \
  --format='value(settings.tier)'

# Right-size se necessário
gcloud sql instances patch INSTANCE_NAME --tier=db-f1-micro

# 4. Reduzir retention de backups
gcloud sql instances patch INSTANCE_NAME \
  --retained-backups-count=7  # De 30 para 7 dias
```

### Cost Breakdown (Current)

```bash
# Custos mensais estimados (tx03-dev):
# 
# Load Balancer:        $20-25  (34%)
# GKE Autopilot:        $12-15  (19%)
# Cloud SQL:            $12-15  (19%)
# Cloud Armor:          $7-10   (13%)
# Monitoring/Logging:   $5-10   (11%)
# Artifact Registry:    # - istio_tcp_connections_opened_total
```

---
-2    (2%)
# Networking:           # - istio_tcp_connections_opened_total
```

---
-2    (2%)
# ─────────────────────────────────
# TOTAL:                $60-70  (100%)
#
# Budget:               $100
# Utilization:          65%
# Status:               ✅ Within budget
```

### Quick Optimization Tips

```bash
# 💡 Quick Wins (Savings: -$38-48/month / 60% reduction)
#
# 1. Disable Cloud Armor in dev (-$10/month)
#    → Edit terraform/environments/dev/main.tf
#    → Set enable_cloud_armor = false
#
# 2. Use NodePort instead of LoadBalancer (-$20/month)
#    → kubectl patch svc dx03-app -n dx03-dev -p '{"spec":{"type":"NodePort"}}'
#
# 3. Reduce log retention (-$3/month)
#    → gcloud logging sinks update --log-filter='...' --retention-days=7
#
# 4. Delete idle resources (-$5-10/month)
#    → Check for unattached disks and unused IPs
#
# 5. Right-size Cloud SQL (-$7/month)
#    → gcloud sql instances patch INSTANCE --tier=db-f1-micro
```

**📚 Documentação:** [COST-MANAGEMENT.md](COST-MANAGEMENT.md)

---


## �🔄 CI/CD

### GitHub Actions Workflows

```bash
# Listar workflows
gh workflow list

# Listar runs
gh run list

# Ver run específico
gh run view <run-id>

# Ver logs
gh run view <run-id> --log

# Watch run em tempo real
gh run watch

# Rerun failed jobs
gh run rerun <run-id>
```

### Triggers Manuais

```bash
# Deploy infraestrutura
gh workflow run deploy-infrastructure.yml

# Deploy aplicação
gh workflow run deploy-application.yml

# Deploy observability
gh workflow run deploy-observability.yml

# Deploy security
gh workflow run deploy-security.yml

# Deploy ArgoCD
gh workflow run deploy-argocd.yml --field action=install

# Cost Management
gh workflow run cost-management.yml --field action=analyze --field days=30

# Destroy (CUIDADO!)
gh workflow run destroy-infrastructure.yml
```

### Ver Logs de Workflow

```bash
# Últimos 3 runs de cada workflow
gh run list --workflow=deploy-application.yml --limit 3

# Logs do último run
gh run view --log

# Logs de um job específico
gh run view <run-id> --job <job-id> --log
```

---

## 🔧 Troubleshooting

### Pod não inicia

```bash
# Ver status e eventos
kubectl describe pod <pod-name> -n dx03-dev

# Ver logs
kubectl logs <pod-name> -n dx03-dev

# Ver logs anteriores (crashed)
kubectl logs --previous <pod-name> -n dx03-dev

# Verificar imagem
kubectl get pod <pod-name> -n dx03-dev -o jsonpath='{.spec.containers[0].image}'
```

### Problemas de conectividade

```bash
# Testar DNS
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup dx03-backend.dx03-dev.svc.cluster.local

# Testar conectividade HTTP
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- curl http://dx03-backend.dx03-dev.svc.cluster.local:3000/health

# Ver endpoints do service
kubectl get endpoints dx03-backend -n dx03-dev
```

### Database connection issues

```bash
# Verificar secret
kubectl get secret dx03-db-secret -n dx03-dev -o yaml

# Testar conexão (do pod)
kubectl exec -it <backend-pod> -n dx03-dev -- \
  psql -h <cloud-sql-ip> -U dx03user -d dx03db

# Ver variáveis de ambiente do pod
kubectl exec <backend-pod> -n dx03-dev -- env | grep DATABASE
```

### Ingress não responde

```bash
# Ver status do Ingress
kubectl describe ingress dx03-ingress -n dx03-dev

# Ver eventos de LB
kubectl get events -n dx03-dev | grep ingress

# Verificar backend services
gcloud compute backend-services list

# Ver health checks
gcloud compute health-checks list

# Testar diretamente o backend
kubectl port-forward -n dx03-dev svc/dx03-backend 3000:3000
curl http://localhost:3000/health
```

### Workflow failing

```bash
# Ver últimos runs
gh run list --workflow=deploy-application.yml --limit 5

# Ver logs detalhados
gh run view <run-id> --log

# Rerun com debug
gh run rerun <run-id>

# Verificar secrets
gh secret list

# Testar Workload Identity
gcloud iam service-accounts list
gcloud projects get-iam-policy ${PROJECT_ID}
```

---

## 📚 Links Úteis

### Documentação do Projeto

- **README Principal:** [README.md](README.md)
- **Deployment Guide:** [APPLICATION_DEPLOYMENT.md](APPLICATION_DEPLOYMENT.md)
- **Load Balancer Fix:** [LOAD_BALANCER_FIX.md](LOAD_BALANCER_FIX.md)
- **Observability:** [OBSERVABILITY.md](OBSERVABILITY.md)
- **Security:** [SECURITY.md](SECURITY.md)
- **ArgoCD GitOps:** [ARGOCD.md](ARGOCD.md)
- **Cost Management:** [COST-MANAGEMENT.md](COST-MANAGEMENT.md)
- **Terraform Troubleshooting:** [TERRAFORM_PLAN_TROUBLESHOOTING.md](TERRAFORM_PLAN_TROUBLESHOOTING.md)

### Stack Específico

- **Observability Stack:** [k8s/observability/README.md](k8s/observability/README.md)
- **Security Stack:** [k8s/security/README.md](k8s/security/README.md)
- **Service Mesh (Istio):** [k8s/istio/README.md](k8s/istio/README.md)
- **ArgoCD:** [k8s/argocd/README.md](k8s/argocd/README.md)

### Repositórios

- **Infraestrutura (tx03):** https://github.com/maringelix/tx03
- **Aplicação (dx03):** https://github.com/maringelix/dx03

### Aplicação em Produção

- **HTTP:** http://dx03.ddns.net
- **HTTPS:** https://dx03.ddns.net
- **IP Estático:** 34.36.62.164

### SonarCloud

- **Organization:** https://sonarcloud.io/organizations/maringelix
- **tx03 (Infra):** https://sonarcloud.io/project/overview?id=maringelix_tx03
- **dx03 (App):** https://sonarcloud.io/project/overview?id=maringelix_dx03

### GCP Console

- **Projeto:** https://console.cloud.google.com/home/dashboard?project=project-28e61e96-b6ac-4249-a21
- **GKE Clusters:** https://console.cloud.google.com/kubernetes/list
- **Cloud SQL:** https://console.cloud.google.com/sql/instances
- **Load Balancing:** https://console.cloud.google.com/net-services/loadbalancing/list
- **Artifact Registry:** https://console.cloud.google.com/artifacts
- **Cloud Armor:** https://console.cloud.google.com/net-security/securitypolicies/list

### Ferramentas Externas

- **kubectl Cheat Sheet:** https://kubernetes.io/docs/reference/kubectl/cheatsheet/
- **Terraform Docs:** https://registry.terraform.io/providers/hashicorp/google/latest/docs
- **PromQL Guide:** https://prometheus.io/docs/prometheus/latest/querying/basics/
- **Rego Playground:** https://play.openpolicyagent.org/

---

## 🎯 Status Resumido

### ✅ Infraestrutura
- GKE Autopilot: RUNNING
- Cloud SQL PostgreSQL: CONNECTED
- Load Balancer: ACTIVE (34.36.62.164)
- Cloud Armor WAF: PROTECTING
- SSL Certificate: ACTIVE (até 29/03/2026)

### ✅ Aplicação
- Frontend: 2/2 pods RUNNING
- Backend: 2/2 pods RUNNING
- Health Checks: PASSING
- HTTPS: dx03.ddns.net ✅

### ✅ Observabilidade
- Prometheus: RUNNING
- Grafana: ACCESSIBLE (port 3001)
- Alertmanager: CONFIGURED
- Dashboards: 4 ativos

### ✅ Segurança
- Gatekeeper: 2/2 pods RUNNING
- Trivy Operator: 1/1 pod RUNNING
- Políticas: 6 ativas
- Scanning: AUTOMÁTICO

### 🟡 Service Mesh (Istio)
- Istiod: RUNNING
- Istio Ingress Gateway: RUNNING
- Kiali: ACCESSIBLE (port 20001)

### ✅ GitOps (ArgoCD)
- ArgoCD Server: RUNNING
- Repo Server: RUNNING
- Application Controller: RUNNING
- Applications: 1 (dx03-app)
- UI: ACCESSIBLE (LoadBalancer)
- Jaeger: ACCESSIBLE (port 16686)
- Sidecar Injection: PENDING (aguardando restart)

---

**Última atualização:** 31 de Dezembro de 2025  
**Slack:** #tx03-support  
**Equipe:** DevOps @ TX03

