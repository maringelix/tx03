# tx03 - Google Cloud Platform Infrastructure

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Terraform](https://img.shields.io/badge/Terraform-1.9+-purple.svg)](https://www.terraform.io/)
[![GCP](https://img.shields.io/badge/GCP-Cloud-blue.svg)](https://cloud.google.com/)

> Infraestrutura como Código (IaC) para aplicação fullstack no Google Cloud Platform usando Terraform, GKE, Cloud SQL, Cloud Armor e GitHub Actions.

## 📋 Índice

- [Sobre o Projeto](#sobre-o-projeto)
- [Pré-requisitos](#pré-requisitos)
- [Arquitetura](#arquitetura)
- [Quick Start](#quick-start)
- [Estrutura do Projeto](#estrutura-do-projeto)
- [Workflows CI/CD](#workflows-cicd)
- [Custos Estimados](#custos-estimados)
- [Documentação](#documentação)
- [Troubleshooting](#troubleshooting)
- [Contribuindo](#contribuindo)
- [Licença](#licença)

## 🎯 Sobre o Projeto

Este repositório contém a infraestrutura do **tx03**, o terceiro projeto da série de implementações multi-cloud:

- **tx01/dx01**: AWS (EKS, RDS, ALB, WAF)
- **tx02/dx02**: Azure (AKS, Azure SQL, App Gateway)
- **tx03/dx03**: GCP (GKE, Cloud SQL, Cloud Armor) ← **Você está aqui**

### Objetivos

- ✅ Provisionar infraestrutura GCP de forma automatizada
- ✅ Utilizar Free Tier e $300 USD de créditos eficientemente
- ✅ Implementar segurança com Cloud Armor (WAF)
- ✅ GitOps com GitHub Actions e Workload Identity Federation
- ✅ Observabilidade com Cloud Monitoring e Logging
- ✅ Documentação completa e reprodutível

## 🔧 Pré-requisitos

### Ferramentas Necessárias

```bash
# Terraform
terraform --version  # >= 1.9.0

# Google Cloud SDK
gcloud --version     # >= 480.0.0

# kubectl
kubectl version      # >= 1.29.0

# Git
git --version        # >= 2.40.0
```

### Conta GCP

1. **Criar conta GCP**: https://console.cloud.google.com/
2. **Ativar Free Trial**: $300 USD em créditos (90 dias)
3. **Criar projeto**: `gcloud projects create tx03-prod --name="TX03 Production"`
4. **Habilitar billing**: Vincular projeto à conta de billing

### GitHub

1. **Repositórios**:
   - tx03 (infraestrutura): https://github.com/maringelix/tx03
   - dx03 (aplicação): https://github.com/maringelix/dx03

2. **Secrets necessários**:
   - `GCP_PROJECT_ID`: ID do projeto GCP
   - `GCP_PROJECT_NUMBER`: Número do projeto
   - `WIF_PROVIDER`: Workload Identity Provider (configurado no bootstrap)
   - `WIF_SERVICE_ACCOUNT`: Service Account email

## 🏗️ Arquitetura

### Diagrama de Alto Nível

```
┌─────────────────────────────────────────────────────────┐
│                       Internet                           │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│          Cloud Load Balancer (HTTPS/SSL)                │
│              (External, Global)                          │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│         Cloud Armor (WAF + DDoS Protection)             │
│   • XSS Protection                                       │
│   • SQL Injection Protection                            │
│   • Rate Limiting                                       │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│                    GKE Autopilot                         │
│  ┌────────────────────────────────────────────────┐    │
│  │   Ingress Controller (GKE Native)              │    │
│  └────────────────┬───────────────────────────────┘    │
│                   │                                      │
│  ┌────────────────┼───────────────────────────────┐    │
│  │  Pods (Managed by Autopilot)                   │    │
│  │                │                                │    │
│  │  ┌─────────────▼─────────────┐                 │    │
│  │  │  Frontend (React)         │                 │    │
│  │  │  • Nginx                  │                 │    │
│  │  │  • Static Assets          │                 │    │
│  │  └──────────────┬────────────┘                 │    │
│  │                 │                               │    │
│  │  ┌──────────────▼────────────┐                 │    │
│  │  │  Backend (Node.js)        │                 │    │
│  │  │  • Express API            │                 │    │
│  │  │  • Business Logic         │                 │    │
│  │  └──────────────┬────────────┘                 │    │
│  └─────────────────┼────────────────────────────────┘  │
└────────────────────┼────────────────────────────────────┘
                     │
                     │ Private IP (VPC Peering)
                     ▼
┌─────────────────────────────────────────────────────────┐
│           Cloud SQL for PostgreSQL                       │
│  • Version: 16                                           │
│  • Instance: db-f1-micro (0.6GB RAM)                    │
│  • High Availability: ZONAL                             │
│  • Backups: Automated (Daily 3am UTC)                   │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│         Supporting Services                              │
│  • Artifact Registry: Docker images                     │
│  • Cloud Storage: Terraform state                       │
│  • Cloud Logging: Centralized logs                      │
│  • Cloud Monitoring: Metrics & Alerts                   │
│  • Secret Manager: Credentials                          │
└─────────────────────────────────────────────────────────┘
```

### Componentes Principais

| Componente | Tecnologia | Propósito |
|-----------|-----------|----------|
| **Kubernetes** | GKE Autopilot | Orquestração de containers |
| **Database** | Cloud SQL PostgreSQL 16 | Banco de dados relacional |
| **Container Registry** | Artifact Registry | Armazenamento de imagens Docker |
| **WAF** | Cloud Armor | Proteção contra ataques web |
| **Load Balancer** | Cloud Load Balancer | Distribuição de tráfego HTTPS |
| **Networking** | VPC + Private Service Connect | Rede privada isolada |
| **Observability** | Cloud Monitoring + Logging | Monitoramento e logs |
| **IaC** | Terraform | Infraestrutura como código |
| **CI/CD** | GitHub Actions | Automação de deploy |

## 🚀 Quick Start

### 1. Clone o Repositório

```bash
git clone https://github.com/maringelix/tx03.git
cd tx03
```

### 2. Configure Credenciais GCP

```bash
# Login
gcloud auth login
gcloud auth application-default login

# Set project
gcloud config set project YOUR_PROJECT_ID

# Habilitar APIs necessárias
gcloud services enable \
  container.googleapis.com \
  compute.googleapis.com \
  sqladmin.googleapis.com \
  artifactregistry.googleapis.com \
  cloudresourcemanager.googleapis.com \
  servicenetworking.googleapis.com \
  iam.googleapis.com \
  iamcredentials.googleapis.com \
  sts.googleapis.com
```

### 3. Bootstrap do Terraform Backend

```bash
cd terraform/bootstrap

# Inicializar
terraform init

# Planejar
terraform plan -out=tfplan

# Aplicar
terraform apply tfplan
```

### 4. Configurar Workload Identity Federation

Siga o guia: [WORKLOAD_IDENTITY_SETUP.md](docs/WORKLOAD_IDENTITY_SETUP.md)

### 5. Deploy da Infraestrutura

#### Via GitHub Actions (Recomendado)
```bash
# Push para main branch
git add .
git commit -m "feat: initial infrastructure"
git push origin main

# Workflow .github/workflows/terraform-apply.yml será executado
```

#### Via Local (Desenvolvimento)
```bash
cd terraform/environments/dev

# Inicializar com backend remoto
terraform init \
  -backend-config="bucket=YOUR_BUCKET_NAME" \
  -backend-config="prefix=terraform/state"

# Planejar mudanças
terraform plan -var-file="dev.tfvars"

# Aplicar infraestrutura
terraform apply -var-file="dev.tfvars"
```

### 6. Acessar o Cluster

```bash
# Get credentials
gcloud container clusters get-credentials tx03-gke \
  --region us-central1

# Verificar nodes
kubectl get nodes

# Verificar pods
kubectl get pods -A
```

## 📁 Estrutura do Projeto

```
tx03/
├── .github/
│   └── workflows/
│       ├── bootstrap.yml              # Setup Terraform backend
│       ├── terraform-apply.yml        # Deploy infra (main)
│       ├── terraform-plan.yml         # Plan on PR
│       └── destroy.yml                # Destroy resources
│
├── terraform/
│   ├── bootstrap/                     # Terraform backend setup
│   │   ├── main.tf
│   │   ├── outputs.tf
│   │   └── variables.tf
│   │
│   ├── modules/
│   │   ├── gke/                       # GKE Autopilot module
│   │   ├── cloudsql/                  # Cloud SQL module
│   │   ├── networking/                # VPC, Subnets, Firewall
│   │   ├── artifact-registry/         # Container registry
│   │   ├── load-balancer/             # LB + Cloud Armor
│   │   └── iam/                       # Service accounts & roles
│   │
│   └── environments/
│       ├── dev/
│       │   ├── main.tf
│       │   ├── backend.tf
│       │   ├── providers.tf
│       │   ├── variables.tf
│       │   └── dev.tfvars
│       └── prod/
│           └── (similar structure)
│
├── k8s/                               # Kubernetes manifests
│   ├── base/                          # Kustomize base
│   │   ├── namespace.yaml
│   │   ├── configmap.yaml
│   │   └── secrets.yaml
│   └── overlays/
│       ├── dev/
│       └── prod/
│
├── docs/
│   ├── ARCHITECTURE.md                # Arquitetura detalhada ✅
│   ├── DEPLOYMENT_GUIDE.md            # Guia de deploy
│   ├── WORKLOAD_IDENTITY_SETUP.md     # Setup WIF
│   ├── TROUBLESHOOTING.md             # Solução de problemas
│   ├── SECURITY.md                    # Práticas de segurança
│   └── COST_OPTIMIZATION.md           # Otimização de custos
│
├── scripts/
│   ├── setup-wif.sh                   # Configurar WIF
│   ├── enable-apis.sh                 # Habilitar GCP APIs
│   └── cleanup.sh                     # Limpeza de recursos
│
├── .gitignore
├── README.md                          # Você está aqui ✅
└── LICENSE
```

## ⚙️ Workflows CI/CD

### 1. Bootstrap Workflow

**Trigger**: Manual (`workflow_dispatch`)  
**Arquivo**: `.github/workflows/bootstrap.yml`

```yaml
# Cria:
# - GCS bucket para Terraform state
# - Workload Identity Pool & Provider
# - Service Account para GitHub Actions
```

**Uso**:
```bash
# Via GitHub UI: Actions → Bootstrap → Run workflow
```

### 2. Terraform Plan (PR)

**Trigger**: Pull Request  
**Arquivo**: `.github/workflows/terraform-plan.yml`

- Executa `terraform plan`
- Comenta resultado no PR
- Valida sintaxe e formatação

### 3. Terraform Apply (Deploy)

**Trigger**: Push to `main`  
**Arquivo**: `.github/workflows/terraform-apply.yml`

- Executa `terraform apply -auto-approve`
- Deploy completo da infraestrutura
- Atualiza outputs no PR

### 4. Destroy Workflow

**Trigger**: Manual  
**Arquivo**: `.github/workflows/destroy.yml`

- Destrói recursos GCP
- Preserva Terraform backend (opcional)
- Requer confirmação "destroy"

## 💰 Custos Estimados

### Breakdown Mensal (DEV)

| Recurso | Configuração | Custo/Mês (USD) |
|---------|-------------|-----------------|
| **GKE Autopilot** | 1 cluster, workload pequeno | $10-15 |
| **Cloud SQL** | db-f1-micro (0.6GB RAM) | $10-15 |
| **Artifact Registry** | ~5GB imagens | $1-2 |
| **Cloud Armor** | WAF + 5 regras | $7-10 |
| **Load Balancer** | External HTTPS LB | $20-25 |
| **Cloud Storage** | < 5GB (Free Tier) | $0 |
| **Monitoring/Logging** | Basic usage | $5-10 |
| **Networking** | Egress (moderado) | $5-10 |
| **TOTAL** | | **$58-87** |

### Duração dos Créditos

- **Créditos GCP**: $300 USD
- **Consumo mensal**: ~$70 USD
- **Duração**: ~4 meses

### Otimizações

Para reduzir custos:

1. **Desabilitar Cloud Armor** em DEV: -$10/mês
2. **Usar Preemptible instances** (GKE Standard): -40%
3. **Reduzir retention de logs**: -30%
4. **Desligar infra fora do horário comercial**: -50%

Ver mais: [COST_OPTIMIZATION.md](docs/COST_OPTIMIZATION.md)

## 📚 Documentação

### Guias

- [Arquitetura Detalhada](ARCHITECTURE.md) ✅ **Leitura obrigatória**
- [Setup Workload Identity](docs/WORKLOAD_IDENTITY_SETUP.md) 🔥 **Passo-a-passo completo**
- [Guia de Deploy](docs/DEPLOYMENT_GUIDE.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)
- [Práticas de Segurança](docs/SECURITY.md)
- [Otimização de Custos](docs/COST_OPTIMIZATION.md)

### Links Úteis

- [Terraform Google Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [GKE Documentation](https://cloud.google.com/kubernetes-engine/docs)
- [Cloud SQL for PostgreSQL](https://cloud.google.com/sql/docs/postgres)
- [Workload Identity Federation](https://cloud.google.com/iam/docs/workload-identity-federation)
- [Cloud Armor Documentation](https://cloud.google.com/armor/docs)

### Projetos Relacionados

- [dx03 - Aplicação](https://github.com/maringelix/dx03): Frontend React + Backend Node.js
- [tx01 - AWS Infrastructure](https://github.com/maringelix/tx01)
- [tx02 - Azure Infrastructure](https://github.com/maringelix/tx02)

---

## 🎯 Progresso do Projeto

### ✅ Conquistas Implementadas

#### Fase 1: Fundação (Concluída)
- [x] **✅ Workload Identity Federation**: Autenticação segura sem service account keys (OIDC)
- [x] **✅ Terraform Backend**: GCS bucket com versionamento e lifecycle policies
- [x] **✅ GitHub Actions CI/CD**: Workflows automatizados (bootstrap, plan, apply, destroy)
- [x] **✅ Documentação Completa**: ARCHITECTURE.md, WORKLOAD_IDENTITY_SETUP.md, README.md

#### Fase 2: Módulos Terraform (Concluída)
- [x] **✅ Networking Module**: VPC, subnets, Cloud NAT, firewall rules, private service connection
- [x] **✅ GKE Module**: Autopilot cluster (FREE tier), Workload Identity, monitoring, logging
- [x] **✅ Cloud SQL Module**: PostgreSQL 16, db-f1-micro, private IP, automated backups
- [x] **✅ Artifact Registry Module**: Docker repository com cleanup policies
- [x] **✅ Cloud Armor Module**: WAF com proteção OWASP Top 10, rate limiting, DDoS protection

#### Fase 3: Segurança (Concluída)
- [x] **✅ WAF (Cloud Armor)**: Proteção contra SQL Injection, XSS, RCE, LFI/RFI, scanners
- [x] **✅ Rate Limiting**: 100 requests/min por IP, ban automático (10 min)
- [x] **✅ Adaptive Protection**: Proteção contra DDoS com ML
- [x] **✅ Private Networking**: GKE → Cloud SQL via VPC peering (sem internet)
- [x] **✅ RBAC**: Service Account com least privilege (roles específicos)

#### Fase 4: Aplicação (dx03 - Concluída)
- [x] **✅ Frontend**: React 18 + TypeScript + Vite
- [x] **✅ Backend**: Node.js 20 + Express + PostgreSQL
- [x] **✅ Health Checks**: /health, /health/ready, /health/live
- [x] **✅ Metrics API**: /api/metrics, /api/health-history
- [x] **✅ Docker**: Multi-stage builds (frontend 50MB, backend 150MB)
- [x] **✅ Kubernetes**: 7 manifests (namespace, deployments, services, ingress)
- [x] **✅ CI/CD**: Workflows para lint, test, build, deploy

### 🚀 Próximos Passos

#### Fase 5: Infraestrutura Deployment
- [ ] **Terraform Apply**: Provisionar toda infraestrutura no GCP
  - GKE Autopilot cluster (us-central1)
  - Cloud SQL PostgreSQL (db-f1-micro)
  - VPC com private networking
  - Cloud Armor WAF
  - Artifact Registry
  - Estimativa: ~15-20 minutos

#### Fase 6: Application Deployment
- [ ] **Deploy dx03**: Aplicar manifests Kubernetes no GKE
  - Build e push de Docker images para Artifact Registry
  - Deploy de frontend e backend (2 replicas cada)
  - Configurar Ingress com Load Balancer
  - Criar Kubernetes Secrets (database credentials)
  - Estimativa: ~10 minutos

#### Fase 7: Observabilidade
- [ ] **Cloud Monitoring**: Dashboards customizados para GKE e Cloud SQL
- [ ] **Cloud Logging**: Agregação de logs de aplicação e infraestrutura
- [ ] **Uptime Checks**: Monitoramento de disponibilidade com alertas
- [ ] **Alerting Policies**: Notificações para CPU, memória, latência, erros

#### Fase 8: Otimizações
- [ ] **Cost Optimization**: Budget alerts, committed use discounts
- [ ] **Performance**: CDN com Cloud CDN, caching strategies
- [ ] **Certificate Management**: cert-manager com Let's Encrypt
- [ ] **GitOps**: ArgoCD para continuous delivery
- [ ] **Service Mesh**: Anthos Service Mesh (Istio) com mTLS

#### Fase 9: Avançado
- [ ] **Blue/Green Deployment**: Estratégia de deploy sem downtime
- [ ] **Disaster Recovery**: Backup automatizado de Cloud SQL e volumes
- [ ] **Multi-Region**: Expandir para alta disponibilidade global
- [ ] **Chaos Engineering**: Implementar testes de resiliência
- [ ] **Security Scanning**: Integrar Trivy, tfsec, Gitleaks no pipeline

---

## 🐛 Troubleshooting

### Problemas Comuns

#### 1. Terraform State Lock
**Erro:** `Error acquiring the state lock`

**Solução:**
```bash
# Remove lock órfão (o workflow faz isso automaticamente agora)
gsutil rm gs://tfstate-tx03-f9d2e263/terraform/state/dev/default.tflock
```

#### 2. Recursos Já Existem
**Erro:** `Error 409: Already exists`

**Solução:**
```bash
# Importar recurso existente para o state
cd terraform/environments/dev
terraform import module.gke.google_container_cluster.primary \
  projects/PROJECT_ID/locations/REGION/clusters/CLUSTER_NAME
```

#### 3. Permissões Insuficientes
**Erro:** `Error 403: Permission denied`

**Solução:** Verificar roles do service account:
```bash
gcloud projects get-iam-policy PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:github-actions-sa@"
```

Roles necessários:
- `roles/compute.admin`
- `roles/container.admin`
- `roles/cloudsql.admin`
- `roles/artifactregistry.admin`
- `roles/storage.admin`
- `roles/iam.serviceAccountUser`

#### 4. Cloud SQL Tier Incompatível
**Erro:** `Invalid Tier (db-f1-micro) for (ENTERPRISE_PLUS) Edition`

**Solução:** Usar tier compatível:
- PostgreSQL 14: `db-g1-small` (recomendado, barato)
- PostgreSQL 16: `db-perf-optimized-N-2` (caro, ~$150/mês)

#### 5. kubectl Auth Plugin Faltando
**Erro:** `executable gke-gcloud-auth-plugin not found`

**Solução:** O workflow instala automaticamente agora. Para uso local:
```bash
gcloud components install gke-gcloud-auth-plugin
```

### Documentação Detalhada

Para análise completa de todos os problemas encontrados durante primeira implantação:
📄 **[TERRAFORM_APPLY_TROUBLESHOOTING.md](./TERRAFORM_APPLY_TROUBLESHOOTING.md)**

Este documento contém:
- 7 problemas críticos documentados
- Causa raiz de cada erro
- Soluções aplicadas
- Lições aprendidas
- Recomendações para evitar no futuro

## 🐛 Troubleshooting

### Problema: "API not enabled"

```bash
# Habilitar APIs necessárias
./scripts/enable-apis.sh
```

### Problema: "Permission denied" no Terraform

```bash
# Verificar IAM roles
gcloud projects get-iam-policy YOUR_PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:github-actions-sa@*"
```

### Problema: GKE Autopilot cluster creation timeout

- Timeout normal: 15-20 minutos
- Se > 30 min: Verificar quotas do projeto
- Consultar: [GKE Troubleshooting](https://cloud.google.com/kubernetes-engine/docs/troubleshooting)

### Mais problemas?

Consulte: [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)

## 🤝 Contribuindo

Contribuições são bem-vindas! Por favor:

1. Fork o projeto
2. Crie uma branch (`git checkout -b feature/AmazingFeature`)
3. Commit suas mudanças (`git commit -m 'feat: add AmazingFeature'`)
4. Push para a branch (`git push origin feature/AmazingFeature`)
5. Abra um Pull Request

### Convenções

- Commits: [Conventional Commits](https://www.conventionalcommits.org/)
- Terraform: [Style Guide](https://www.terraform.io/docs/language/syntax/style.html)
- Documentação: Markdown com links relativos

## 📄 Licença

Este projeto está sob a licença MIT. Veja [LICENSE](LICENSE) para mais detalhes.

## 👤 Autor

**maringelix**

- GitHub: [@maringelix](https://github.com/maringelix)
- LinkedIn: [maringelix](https://linkedin.com/in/maringelix)

## 🙏 Agradecimentos

- HashiCorp Terraform
- Google Cloud Platform
- GitHub Actions
- Comunidade Open Source

---

**Status do Projeto**: 🚧 Em Desenvolvimento  
**Última Atualização**: 2025-01-01  
**Versão**: 0.1.0
