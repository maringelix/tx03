# Arquitetura GCP - tx03/dx03

## Índice
- [Visão Geral](#visão-geral)
- [Comparação com Projetos Anteriores](#comparação-com-projetos-anteriores)
- [Free Tier e Créditos](#free-tier-e-créditos)
- [Serviços GCP](#serviços-gcp)
- [Estimativa de Custos](#estimativa-de-custos)
- [Autenticação e Segurança](#autenticação-e-segurança)
- [Arquitetura de Rede](#arquitetura-de-rede)
- [CI/CD](#cicd)

## Visão Geral

Este projeto implementa uma aplicação fullstack no Google Cloud Platform (GCP) usando:
- **tx03**: Repositório de infraestrutura (Terraform)
- **dx03**: Repositório da aplicação (React + Node.js + PostgreSQL)

### Objetivos
- Replicar a stack completa usada em AWS (tx01/dx01) e Azure (tx02/dx02)
- Utilizar Free Tier e $300 USD de créditos do GCP de forma eficiente
- Implementar GitOps com GitHub Actions
- Seguir best practices de segurança e observabilidade

## Comparação com Projetos Anteriores

| Componente | AWS (tx01) | Azure (tx02) | GCP (tx03) |
|-----------|-----------|-------------|-----------|
| Kubernetes | EKS | AKS | GKE |
| Container Registry | ECR | ACR | Artifact Registry |
| Database | RDS PostgreSQL | Azure Database | Cloud SQL PostgreSQL |
| WAF | AWS WAF | App Gateway WAF | Cloud Armor |
| Load Balancer | ALB | App Gateway | Cloud Load Balancer |
| Terraform Backend | S3 + DynamoDB | Storage Account | GCS Bucket |
| CI/CD Auth | OIDC | Workload Identity | Workload Identity Federation |

## Free Tier e Créditos

### Créditos Disponíveis
- **$300 USD** em créditos (válidos por 90 dias)
- Não há cobrança até ativação da conta paga

### Always Free Tier
Recursos que NÃO consomem créditos (permanentes):
- **Compute Engine**: 1 x e2-micro instance/mês (US only)
- **Cloud Storage**: 5 GB Standard Storage
- **Cloud Run**: 2 milhões de requests/mês
- **Cloud Build**: 120 build-minutes/dia
- **BigQuery**: 1 TB queries/mês
- **Operations (Monitoring/Logging)**: Quotas mensais

### GKE Free Tier
- **1 Zonal ou Autopilot cluster** por mês: GRÁTIS (management fee waived)
- Nodes: Pagos normalmente (use e2-micro para minimizar custos)

### Importante
⚠️ **Cloud SQL NÃO tem Free Tier** - Menor instância: db-f1-micro (~$10/mês)

## Serviços GCP

### 1. Google Kubernetes Engine (GKE)

#### Opções de Cluster
```hcl
# Opção A: Autopilot (Recomendado para POC)
resource "google_container_cluster" "autopilot" {
  enable_autopilot = true
  # GKE gerencia nodes automaticamente
  # Paga apenas pelos pods em execução
}

# Opção B: Standard Zonal (Máximo controle)
resource "google_container_cluster" "standard" {
  location = "us-central1-a"  # Zonal cluster
  
  # Free Tier elegível
  initial_node_count       = 1
  remove_default_node_pool = true
}

resource "google_container_node_pool" "primary" {
  node_count = 1
  
  node_config {
    machine_type = "e2-micro"  # Always Free Tier
    preemptible  = true        # 80% mais barato (para DEV)
  }
}
```

#### Decisão: **Autopilot**
- Management fee GRÁTIS (1 cluster/mês)
- Sem necessidade de gerenciar nodes
- Auto-scaling nativo
- Menor custo operacional

#### Custos GKE
- **Cluster Management**: $0.00 (1 cluster free)
- **Nodes Autopilot**: ~$0.04/GB RAM + ~$0.04/vCPU por hora
- **Estimativa**: ~$10-20/mês (workload pequeno)

### 2. Cloud SQL for PostgreSQL

#### Configuração Recomendada
```hcl
resource "google_sql_database_instance" "main" {
  database_version = "POSTGRES_16"
  region           = "us-central1"
  
  settings {
    tier = "db-f1-micro"  # 0.6GB RAM, Shared CPU
    
    # High Availability: NÃO (cara)
    availability_type = "ZONAL"
    
    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.main.id
      # Private IP: OBRIGATÓRIO para segurança
    }
    
    backup_configuration {
      enabled            = true
      start_time         = "03:00"
      point_in_time_recovery_enabled = false  # Economizar
    }
  }
}
```

#### Custos Cloud SQL
- **db-f1-micro**: ~$7-10/mês (0.6GB RAM)
- **Storage**: $0.17/GB/mês
- **Backups**: $0.08/GB/mês
- **Estimativa Total**: ~$10-15/mês

### 3. Artifact Registry

```hcl
resource "google_artifact_registry_repository" "docker" {
  location      = "us-central1"
  repository_id = "dx03-app"
  format        = "DOCKER"
}
```

#### Custos
- **Storage**: $0.10/GB/mês
- **Network egress**: Variável
- **Estimativa**: ~$1-2/mês (imagens pequenas)

### 4. Cloud Armor (WAF)

```hcl
resource "google_compute_security_policy" "waf" {
  name = "tx03-waf-policy"
  
  rule {
    action   = "deny(403)"
    priority = "1000"
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('xss-stable')"
      }
    }
  }
  
  rule {
    action   = "allow"
    priority = "2147483647"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
  }
}
```

#### Custos
- **Policy**: $5/mês por política
- **Rules**: $1/mês por regra
- **Requests**: $0.75/milhão de requests
- **Estimativa**: ~$7-10/mês

### 5. Cloud Load Balancer

```hcl
# External HTTP(S) Load Balancer
resource "google_compute_global_forwarding_rule" "https" {
  name       = "tx03-https-lb"
  target     = google_compute_target_https_proxy.default.id
  port_range = "443"
}

resource "google_compute_backend_service" "app" {
  name                  = "tx03-backend"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  
  backend {
    group = google_compute_region_network_endpoint_group.gke.id
  }
  
  security_policy = google_compute_security_policy.waf.id
}
```

#### Custos
- **Forwarding rules**: $0.025/hora (~$18/mês)
- **Ingress/Egress**: Variável
- **Estimativa**: ~$20-25/mês

### 6. Cloud Storage (Backend Terraform)

```hcl
resource "google_storage_bucket" "terraform_state" {
  name     = "tfstate-tx03-${random_id.suffix.hex}"
  location = "US"
  
  versioning {
    enabled = true
  }
  
  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      num_newer_versions = 5
    }
  }
}
```

#### Custos
- **Standard Storage**: $0.02/GB/mês (5GB free)
- **Operations**: Mínimas
- **Estimativa**: $0.00 (dentro do free tier)

## Estimativa de Custos

### Cenário: Desenvolvimento/POC
| Serviço | Custo Mensal (USD) |
|---------|-------------------|
| GKE Autopilot | $10-15 |
| Cloud SQL (db-f1-micro) | $10-15 |
| Artifact Registry | $1-2 |
| Cloud Armor | $7-10 |
| Load Balancer | $20-25 |
| Cloud Storage | $0 (free tier) |
| Monitoring/Logging | $5-10 |
| **TOTAL ESTIMADO** | **$53-77/mês** |

### Duração dos Créditos
- **$300 USD / ~$65/mês = ~4-5 meses** de infraestrutura

### Otimizações Possíveis
1. **Usar Preemptible VMs no GKE Standard**: -80% nos nodes
2. **Desabilitar Cloud Armor (DEV)**: -$10/mês
3. **Usar Cloud Run em vez de GKE**: -$20/mês
4. **Backups reduzidos**: -$3-5/mês

## Autenticação e Segurança

### Workload Identity Federation (GitHub Actions)

❌ **NÃO usar Service Account Keys (JSON)**
- Keys estáticas são vulneráveis
- Difícil de rotacionar

✅ **Usar Workload Identity Federation**
- Sem secrets estáticos
- OIDC token exchange
- Auditável

#### Setup
```bash
# 1. Criar Workload Identity Pool
gcloud iam workload-identity-pools create "github-pool" \
  --location="global" \
  --display-name="GitHub Actions Pool"

# 2. Criar Provider
gcloud iam workload-identity-pools providers create-oidc "github-provider" \
  --location="global" \
  --workload-identity-pool="github-pool" \
  --issuer-uri="https://token.actions.githubusercontent.com" \
  --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository"

# 3. Service Account
gcloud iam service-accounts create "github-actions-sa" \
  --display-name="GitHub Actions Service Account"

# 4. IAM Bindings
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:github-actions-sa@PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/container.developer"

# 5. Bind Workload Identity
gcloud iam service-accounts add-iam-policy-binding \
  "github-actions-sa@PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/github-pool/attribute.repository/maringelix/tx03"
```

#### GitHub Actions Workflow
```yaml
- name: Authenticate to Google Cloud
  uses: google-github-actions/auth@v2
  with:
    workload_identity_provider: 'projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/github-pool/providers/github-provider'
    service_account: 'github-actions-sa@PROJECT_ID.iam.gserviceaccount.com'
```

### IAM Roles Necessários
```hcl
# Service Account para GitHub Actions
resource "google_service_account" "github_actions" {
  account_id   = "github-actions-sa"
  display_name = "GitHub Actions Service Account"
}

# Roles mínimos
resource "google_project_iam_member" "roles" {
  for_each = toset([
    "roles/container.developer",        # GKE
    "roles/artifactregistry.writer",    # Artifact Registry
    "roles/cloudsql.client",            # Cloud SQL
    "roles/compute.networkAdmin",       # Networking
    "roles/iam.serviceAccountUser",     # Service Account
  ])
  
  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.github_actions.email}"
}
```

## Arquitetura de Rede

### VPC Design

```hcl
resource "google_compute_network" "main" {
  name                    = "tx03-vpc"
  auto_create_subnetworks = false
}

# GKE Subnet
resource "google_compute_subnetwork" "gke" {
  name          = "gke-subnet"
  ip_cidr_range = "10.0.0.0/20"
  region        = "us-central1"
  network       = google_compute_network.main.id
  
  secondary_ip_range {
    range_name    = "gke-pods"
    ip_cidr_range = "10.4.0.0/14"  # 262k IPs para pods
  }
  
  secondary_ip_range {
    range_name    = "gke-services"
    ip_cidr_range = "10.8.0.0/20"  # 4k IPs para services
  }
}

# Cloud SQL Private IP
resource "google_compute_global_address" "private_ip" {
  name          = "private-ip-address"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.main.id
}

resource "google_service_networking_connection" "private_vpc" {
  network                 = google_compute_network.main.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip.name]
}
```

### Fluxo de Tráfego
```
Internet
   ↓
Cloud Load Balancer (HTTPS)
   ↓
Cloud Armor (WAF) ← Regras de Segurança
   ↓
GKE Ingress
   ↓
Kubernetes Service
   ↓
Pods (Frontend + Backend)
   ↓
Cloud SQL (Private IP)
```

### Firewall Rules
```hcl
# Permitir tráfego do Load Balancer
resource "google_compute_firewall" "allow_lb" {
  name    = "allow-lb-to-gke"
  network = google_compute_network.main.name
  
  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }
  
  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]  # GCP LB ranges
  target_tags   = ["gke-node"]
}

# Permitir health checks
resource "google_compute_firewall" "allow_health_checks" {
  name    = "allow-health-checks"
  network = google_compute_network.main.name
  
  allow {
    protocol = "tcp"
  }
  
  source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
}
```

## CI/CD

### Workflows Planejados

#### 1. Bootstrap (.github/workflows/bootstrap.yml)
```yaml
name: Bootstrap Terraform Backend

on:
  workflow_dispatch:
    inputs:
      action:
        description: 'create or destroy'
        required: true
        type: choice
        options:
          - create
          - destroy

jobs:
  bootstrap:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Authenticate to GCP
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ secrets.WIF_PROVIDER }}
          service_account: ${{ secrets.WIF_SERVICE_ACCOUNT }}
      
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
      
      - name: Terraform Init & Apply
        run: |
          cd terraform/bootstrap
          terraform init
          terraform apply -auto-approve
```

#### 2. Infrastructure (.github/workflows/terraform-apply.yml)
```yaml
name: Deploy Infrastructure

on:
  push:
    branches: [main]
    paths:
      - 'terraform/**'
  pull_request:
    branches: [main]

jobs:
  terraform:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Authenticate to GCP
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ secrets.WIF_PROVIDER }}
          service_account: ${{ secrets.WIF_SERVICE_ACCOUNT }}
      
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
      
      - name: Terraform Init
        run: |
          cd terraform/environments/dev
          terraform init \
            -backend-config="bucket=${{ secrets.GCS_BUCKET }}" \
            -backend-config="prefix=terraform/state"
      
      - name: Terraform Plan
        run: terraform plan -out=tfplan
      
      - name: Terraform Apply
        if: github.ref == 'refs/heads/main'
        run: terraform apply tfplan
```

#### 3. Application Build & Deploy (dx03/.github/workflows/deploy.yml)
```yaml
name: Build and Deploy Application

on:
  push:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Authenticate to GCP
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ secrets.WIF_PROVIDER }}
          service_account: ${{ secrets.WIF_SERVICE_ACCOUNT }}
      
      - name: Setup Cloud SDK
        uses: google-github-actions/setup-gcloud@v2
      
      - name: Configure Docker
        run: gcloud auth configure-docker us-central1-docker.pkg.dev
      
      - name: Build and Push
        run: |
          docker build -t us-central1-docker.pkg.dev/PROJECT_ID/dx03-app/backend:${{ github.sha }} ./server
          docker build -t us-central1-docker.pkg.dev/PROJECT_ID/dx03-app/frontend:${{ github.sha }} ./client
          docker push us-central1-docker.pkg.dev/PROJECT_ID/dx03-app/backend:${{ github.sha }}
          docker push us-central1-docker.pkg.dev/PROJECT_ID/dx03-app/frontend:${{ github.sha }}
      
      - name: Deploy to GKE
        run: |
          gcloud container clusters get-credentials tx03-gke --region us-central1
          kubectl set image deployment/backend backend=us-central1-docker.pkg.dev/PROJECT_ID/dx03-app/backend:${{ github.sha }}
          kubectl set image deployment/frontend frontend=us-central1-docker.pkg.dev/PROJECT_ID/dx03-app/frontend:${{ github.sha }}
```

## Próximos Passos

### Fase 1: Setup Inicial
- [ ] Criar projetos GitHub (tx03, dx03)
- [ ] Configurar Workload Identity Federation
- [ ] Criar GitHub Secrets

### Fase 2: Bootstrap
- [ ] Workflow de bootstrap do Terraform
- [ ] Criar GCS bucket para state
- [ ] Habilitar APIs necessárias

### Fase 3: Infraestrutura
- [ ] Provisionar VPC e subnets
- [ ] Criar GKE Autopilot cluster
- [ ] Provisionar Cloud SQL PostgreSQL
- [ ] Configurar Artifact Registry
- [ ] Implementar Cloud Armor + Load Balancer

### Fase 4: Aplicação
- [ ] Criar aplicação React (frontend)
- [ ] Criar API Node.js (backend)
- [ ] Kubernetes manifests
- [ ] CI/CD pipelines

### Fase 5: Observabilidade
- [ ] Cloud Logging
- [ ] Cloud Monitoring
- [ ] Uptime checks
- [ ] Alerting policies

## Referências

### Documentação Oficial
- [GKE Free Tier](https://cloud.google.com/kubernetes-engine/pricing#cluster_management_fee_and_free_tier)
- [Cloud SQL Pricing](https://cloud.google.com/sql/pricing)
- [Terraform Google Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [Workload Identity Federation](https://cloud.google.com/iam/docs/workload-identity-federation)

### Projetos Anteriores
- [tx01 (AWS)](../tx01/README.md)
- [tx02 (Azure)](../tx02/README.md)

---

**Última atualização**: 2025-01-01  
**Autor**: GitHub Copilot + maringelix  
**Licença**: MIT
