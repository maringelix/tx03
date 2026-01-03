# 💰 Cost Management Guide

> Gestão completa de custos no GCP com budgets, alertas, análises e otimizações

## 📋 Índice

- [Visão Geral](#visão-geral)
- [Arquitetura de Cost Management](#arquitetura-de-cost-management)
- [Budget Configuration](#budget-configuration)
- [Cost Monitoring](#cost-monitoring)
- [Análise de Custos](#análise-de-custos)
- [Otimização](#otimização)
- [Alertas e Notificações](#alertas-e-notificações)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)

---

## Visão Geral

### O que é Cost Management?

Cost Management é a prática de controlar, analisar e otimizar gastos em cloud computing. No GCP, isso inclui:

- **Budgets & Alerts**: Limites de gastos com notificações automáticas
- **Cost Analysis**: Análise detalhada por serviço, região, label
- **Recommendations**: Sugestões de otimização baseadas em ML
- **Forecasting**: Previsão de gastos futuros
- **Resource Optimization**: Identificação de recursos ociosos ou over-provisioned

### Por que implementar?

✅ **Controle Financeiro**: Evita surpresas na fatura  
✅ **Visibilidade**: Entende onde o dinheiro está sendo gasto  
✅ **Otimização**: Identifica oportunidades de redução de custos  
✅ **Compliance**: Mantém gastos dentro do orçamento aprovado  
✅ **Forecasting**: Planeja investimentos futuros com precisão

---

## Arquitetura de Cost Management

```
┌─────────────────────────────────────────────────────────────┐
│                     GCP Billing Account                     │
│                                                             │
│  ┌──────────────┐      ┌──────────────┐     ┌───────────┐ │
│  │   Projects   │──────│   Budgets    │─────│  Alerts   │ │
│  │              │      │              │     │           │ │
│  │  • tx03-dev  │      │  • Monthly   │     │  • Email  │ │
│  │  • tx03-prod │      │  • Quarterly │     │  • Pub/Sub│ │
│  └──────────────┘      └──────────────┘     └───────────┘ │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│              BigQuery Billing Export (Optional)             │
│                                                             │
│  • Detailed cost breakdown                                  │
│  • Custom queries and analysis                              │
│  • Integration with Data Studio                             │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                   Cost Analysis Tools                       │
│                                                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │   Workflow   │  │  Recommender │  │  Monitoring  │     │
│  │              │  │              │  │              │     │
│  │ • Reports    │  │ • CUD        │  │ • Dashboards │     │
│  │ • Forecasts  │  │ • Right-size │  │ • Alerts     │     │
│  │ • Exports    │  │ • Idle       │  │ • Metrics    │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
└─────────────────────────────────────────────────────────────┘
```

---

## Budget Configuration

### 1. Terraform Module

O módulo `billing-budget` cria budgets automaticamente:

```hcl
# terraform/environments/dev/main.tf

module "billing_budget" {
  source = "../../modules/billing-budget"

  project_id             = var.project_id
  project_number         = var.project_number
  project_name           = "tx03"
  environment            = "dev"
  billing_account_name   = "My Billing Account"
  budget_amount          = 100  # USD per month
  
  alert_emails = [
    "admin@example.com",
    "billing@example.com"
  ]
  
  enable_pubsub              = true
  enable_cost_spike_alerts   = true
  cost_spike_threshold       = 10  # USD per 5min
  
  # Filter by labels (optional)
  filter_labels = {
    environment = ["dev"]
    project     = ["tx03"]
  }
  
  # Filter by services (optional)
  # Get service IDs: gcloud billing accounts list --filter="displayName:'GKE'"
  filter_services = []
}
```

### 2. Alert Thresholds

O módulo configura alertas em múltiplos thresholds:

| Threshold | Type | Action |
|-----------|------|--------|
| **50%** | Current spend | Email notification |
| **75%** | Current spend | Email notification |
| **90%** | Current spend | Email notification + Review |
| **100%** | Current spend | Email notification + Action required |
| **110%** | Forecasted spend | Early warning |

### 3. Notification Channels

**Email Notifications:**
```hcl
alert_emails = [
  "team-lead@company.com",
  "finance@company.com",
  "devops@company.com"
]
```

**Pub/Sub Integration:**
```hcl
enable_pubsub = true

# Subscribe to budget alerts
resource "google_pubsub_subscription" "budget_alerts" {
  name  = "budget-alerts-subscription"
  topic = module.billing_budget.pubsub_topic_id
  
  # Can trigger Cloud Functions for automated actions
  push_config {
    push_endpoint = "https://my-function.cloudfunctions.net/handle-budget-alert"
  }
}
```

### 4. Deploy Budget

```bash
cd terraform/environments/dev

# Get billing account name
gcloud billing accounts list

# Get project number
gcloud projects describe PROJECT_ID --format="value(projectNumber)"

# Add to terraform.tfvars
echo 'billing_account_name = "My Billing Account"' >> terraform.tfvars
echo 'project_number = "123456789012"' >> terraform.tfvars

# Deploy
terraform init
terraform plan
terraform apply
```

---

## Cost Monitoring

### 1. GitHub Actions Workflow

O workflow `cost-management.yml` automatiza análises de custo:

```bash
# Via GitHub UI
Actions → Cost Management → Run workflow

# Select action:
# - analyze: Current cost breakdown
# - report: Detailed cost report
# - recommendations: Optimization suggestions
# - export: Export data to CSV

# Select period:
# - 7 days
# - 30 days (default)
# - 90 days
```

### 2. Scheduled Reports

O workflow roda automaticamente toda segunda-feira às 9 AM UTC:

```yaml
schedule:
  - cron: '0 9 * * 1'  # Weekly on Mondays
```

### 3. Manual Analysis

```bash
# Current month costs
gcloud billing accounts list

# Cost breakdown by service (requires BigQuery export)
bq query --use_legacy_sql=false '
SELECT
  service.description,
  SUM(cost) AS total_cost
FROM
  `project.dataset.gcp_billing_export_v1_BILLING_ACCOUNT_ID`
WHERE
  EXTRACT(MONTH FROM usage_start_time) = EXTRACT(MONTH FROM CURRENT_DATE())
GROUP BY
  service.description
ORDER BY
  total_cost DESC
LIMIT 10
'

# Cost by label
bq query --use_legacy_sql=false '
SELECT
  labels.value AS environment,
  SUM(cost) AS total_cost
FROM
  `project.dataset.gcp_billing_export_v1_BILLING_ACCOUNT_ID`,
  UNNEST(labels) AS labels
WHERE
  labels.key = "environment"
GROUP BY
  environment
'
```

---

## Análise de Custos

### Breakdown por Serviço (tx03-dev)

| Serviço | Configuração | Custo/Mês | % Total |
|---------|-------------|-----------|---------|
| **Load Balancer** | External HTTPS LB | $20-25 | 34% |
| **GKE Autopilot** | Small workloads | $12-15 | 19% |
| **Cloud SQL** | db-g1-small (1.7GB) | $12-15 | 19% |
| **Cloud Armor** | WAF + 5 rules | $7-10 | 13% |
| **Monitoring/Logs** | Standard retention | $5-10 | 11% |
| **Artifact Registry** | ~5GB images | $1-2 | 2% |
| **Networking** | Egress traffic | $1-2 | 2% |
| **TOTAL** | | **$60-70** | **100%** |

### Cost Drivers

#### 1. Load Balancer (34%)
**Por que é caro?**
- Forwarding rules: $0.025/hour = $18/month
- Bandwidth egress: Variável
- SSL/TLS processing

**Otimização:**
```bash
# Use NodePort em dev (remove LB)
kubectl patch svc my-service -p '{"spec":{"type":"NodePort"}}'

# Savings: -$20/month
```

#### 2. GKE Autopilot (19%)
**Por que é caro?**
- Pay per pod resources (CPU/RAM)
- Managed control plane
- Auto-scaling overhead

**Otimização:**
```yaml
# Set resource requests conservatively
resources:
  requests:
    cpu: 100m      # vs 250m default
    memory: 128Mi  # vs 256Mi default

# Savings: -30% GKE costs = -$4/month
```

#### 3. Cloud SQL (19%)
**Por que é caro?**
- Always-on instance
- High availability (standby replica)
- Automated backups

**Otimização:**
```bash
# Right-size tier
gcloud sql instances patch INSTANCE \
  --tier=db-f1-micro  # From db-g1-small
  # Savings: -$7/month

# Reduce backup retention
gcloud sql instances patch INSTANCE \
  --backup-start-time=03:00 \
  --retained-backups-count=7  # From 30
  # Savings: -$2/month
```

#### 4. Cloud Armor (13%)
**Por que é caro?**
- Policy fee: $5/month
- Rules: $1/rule/month
- Request processing

**Otimização:**
```bash
# Disable in dev
terraform apply -var="enable_cloud_armor=false"
# Savings: -$10/month
```

---

## Otimização

### Quick Wins (Immediate Savings)

#### 1. Disable Cloud Armor in Dev (-$10/month)
```hcl
# terraform/environments/dev/main.tf
variable "enable_cloud_armor" {
  default = false  # Only enable in production
}
```

#### 2. Use NodePort Instead of LoadBalancer (-$20/month)
```bash
# Dev environment only
kubectl patch svc dx03-app -n dx03-dev -p '{"spec":{"type":"NodePort"}}'

# Access via port-forward
kubectl port-forward svc/dx03-app 8080:80 -n dx03-dev
```

#### 3. Reduce Log Retention (-$3/month)
```hcl
# terraform/modules/monitoring/main.tf
resource "google_logging_project_sink" "default" {
  retention_days = 7  # From 30
}
```

#### 4. Delete Unused Resources (-$5-10/month)
```bash
# Find unattached disks
gcloud compute disks list --filter="-users:*"

# Delete if unused
gcloud compute disks delete DISK_NAME --zone=ZONE

# Find unused static IPs ($0.01/hour = $7/month each)
gcloud compute addresses list --filter="status:RESERVED"

# Release if unused
gcloud compute addresses delete IP_NAME --region=REGION
```

**Total Quick Wins: -$38-48/month (60% reduction!)**

---

### Medium-term Optimizations

#### 1. Right-size Cloud SQL
```bash
# Monitor CPU/RAM utilization
gcloud sql operations list --instance=INSTANCE --limit=10

# If utilization < 50%, downgrade tier
gcloud sql instances patch INSTANCE --tier=db-f1-micro
```

#### 2. Implement Autoscaling
```yaml
# k8s/application/hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: dx03-app
spec:
  minReplicas: 1  # Scale to 0 in dev
  maxReplicas: 5
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

#### 3. Schedule Dev Environment Shutdowns
```yaml
# .github/workflows/schedule-shutdown.yml
on:
  schedule:
    - cron: '0 19 * * 1-5'  # 7 PM weekdays (shutdown)
    - cron: '0 7 * * 1-5'   # 7 AM weekdays (startup)

jobs:
  shutdown:
    runs-on: ubuntu-latest
    steps:
      - name: Scale down dev
        run: |
          # Scale all deployments to 0
          kubectl scale deployment --all --replicas=0 -n dx03-dev
          
          # Stop Cloud SQL
          gcloud sql instances patch INSTANCE --no-activation-policy
```

**Savings: -50% on dev costs during off-hours**

---

### Long-term Optimizations

#### 1. Committed Use Discounts (CUD)

**What are CUDs?**
- Commit to use specific resources for 1-3 years
- Get up to 57% discount on compute resources
- Ideal for stable, predictable workloads

```bash
# Analyze eligibility
gcloud recommender recommendations list \
  --project=PROJECT_ID \
  --location=global \
  --recommender=google.compute.commitment.UsageCommitmentRecommender

# Purchase CUD (example)
gcloud compute commitments create my-commitment \
  --region=us-central1 \
  --plan=12-month \
  --resources=vcpu=8,memory=30GB
```

**Estimated Savings: -25-40% on GKE/Compute**

#### 2. Sustained Use Discounts (SUD)

Automatic discounts for running resources > 25% of the month:

| Usage % | Discount |
|---------|----------|
| 25-50% | 20% |
| 50-75% | 40% |
| 75-100% | 60% |

**No action required** - automatically applied!

#### 3. Preemptible VMs (GKE Standard only)

```hcl
# terraform/modules/gke/main.tf
resource "google_container_node_pool" "preemptible" {
  node_config {
    preemptible  = true
    machine_type = "e2-medium"
  }
}
```

**Savings: -70-80% on compute costs**  
**Tradeoff: VMs can be terminated at any time (max 24h uptime)**

#### 4. Cloud CDN for Static Assets

```hcl
resource "google_compute_backend_service" "cdn" {
  enable_cdn = true
  
  cdn_policy {
    cache_mode = "CACHE_ALL_STATIC"
    default_ttl = 3600
  }
}
```

**Savings: -50-70% on egress bandwidth costs**

#### 5. Migrate to Cloud Run (for applicable workloads)

```bash
# Cloud Run vs GKE Autopilot
# Pay only when requests are being processed
# Scales to zero automatically

gcloud run deploy dx03-app \
  --image=gcr.io/PROJECT/dx03-app \
  --min-instances=0 \
  --max-instances=10

# Estimated savings: -40-60% for low-traffic apps
```

---

## Alertas e Notificações

### 1. Budget Alerts

**Automatic Email Alerts:**
- 50% of budget consumed
- 75% of budget consumed
- 90% of budget consumed
- 100% of budget consumed
- 110% forecasted spend

**Example Email:**
```
Subject: Budget Alert: tx03-dev has exceeded 90% of budget

Your project tx03-dev has consumed $90 of the $100 monthly budget (90%).

Current spending rate: $3.50/day
Forecasted monthly cost: $105

Recommended actions:
1. Review cost breakdown in GCP Console
2. Identify top cost drivers
3. Consider implementing cost optimizations
4. Adjust budget if needed

View details: https://console.cloud.google.com/billing
```

### 2. Cost Spike Alerts

Monitoring alert when cost rate exceeds threshold:

```hcl
resource "google_monitoring_alert_policy" "cost_spike" {
  display_name = "Cost Spike Alert"
  
  conditions {
    display_name = "Spending rate > $10 per 5 minutes"
    
    condition_threshold {
      threshold_value = 10  # USD
      duration        = "300s"
      comparison      = "COMPARISON_GT"
    }
  }
  
  notification_channels = [...]
  
  documentation {
    content = <<-EOT
      ## Action Required: Cost Spike Detected
      
      Spending rate has exceeded $10 per 5 minutes.
      
      Common causes:
      - Unintended resource deployment
      - Autoscaling event
      - Data processing job
      - DDoS attack (check Cloud Armor logs)
      
      Investigate immediately!
    EOT
  }
}
```

### 3. Pub/Sub Integration

**Automated Actions via Cloud Functions:**

```javascript
// cloud-function/index.js
exports.handleBudgetAlert = async (message, context) => {
  const data = JSON.parse(Buffer.from(message.data, 'base64').toString());
  
  if (data.costAmount >= data.budgetAmount) {
    // Budget exceeded - take action
    
    // Option 1: Send Slack notification
    await sendSlackAlert(data);
    
    // Option 2: Scale down dev environment
    if (data.budgetName.includes('dev')) {
      await scaleDownDevResources();
    }
    
    // Option 3: Create Jira ticket
    await createJiraTicket({
      summary: `Budget Alert: ${data.budgetName}`,
      description: `Budget exceeded: $${data.costAmount}/$${data.budgetAmount}`
    });
  }
};
```

---

## Best Practices

### 1. Tagging Strategy

**Label all resources for cost tracking:**

```hcl
resource "google_container_cluster" "primary" {
  resource_labels = {
    environment = "dev"
    project     = "tx03"
    cost_center = "engineering"
    owner       = "devops-team"
    managed_by  = "terraform"
  }
}
```

**Benefits:**
- Cost breakdown by environment (dev vs prod)
- Chargeback to business units
- Identify orphaned resources

### 2. Multi-Environment Budgets

```hcl
# Dev budget
module "budget_dev" {
  source = "../../modules/billing-budget"
  
  environment   = "dev"
  budget_amount = 75  # Lower budget for dev
}

# Prod budget
module "budget_prod" {
  source = "../../modules/billing-budget"
  
  environment   = "prod"
  budget_amount = 300  # Higher budget for prod
}
```

### 3. Regular Reviews

**Weekly:**
- Review cost workflow reports
- Check for anomalies
- Validate autoscaling behavior

**Monthly:**
- Deep dive into cost breakdown
- Implement optimization recommendations
- Adjust budgets if needed

**Quarterly:**
- Evaluate CUD opportunities
- Review architecture for cost efficiency
- Update forecasts

### 4. Cost-Aware Architecture

**Design Principles:**
- **Right-sizing**: Don't over-provision resources
- **Auto-scaling**: Scale based on demand
- **Serverless**: Use Cloud Run/Functions for sporadic workloads
- **Caching**: Implement caching to reduce compute/db load
- **Data transfer**: Minimize cross-region/cross-zone traffic

### 5. FinOps Culture

**Shared Responsibility:**
- Developers: Write efficient code, optimize queries
- DevOps: Right-size infrastructure, implement auto-scaling
- Product: Balance features vs cost
- Finance: Monitor budgets, forecast spending

---

## Troubleshooting

### Budget not sending alerts

**Problem:** Budget created but no email alerts received

**Solution:**
```bash
# 1. Verify billing account has billing export enabled
gcloud billing accounts list

# 2. Check notification channels
gcloud alpha monitoring channels list

# 3. Verify IAM permissions
gcloud projects get-iam-policy PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.role:roles/billing.budgets.admin"

# 4. Test notification channel
gcloud alpha monitoring channels test CHANNEL_ID
```

### Cost data not available in BigQuery

**Problem:** Unable to query cost data in BigQuery

**Solution:**
```bash
# Enable billing export
gcloud billing accounts describe BILLING_ACCOUNT_ID

# Configure export to BigQuery
# Visit: Cloud Console → Billing → Billing Export
# Enable "Detailed usage cost" and "Pricing"

# Wait 24-48 hours for data to appear
```

### Workflow fails with permissions error

**Problem:** Cost management workflow fails with "403 Forbidden"

**Solution:**
```bash
# Grant required IAM roles to Workload Identity SA
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:SA_EMAIL" \
  --role="roles/billing.viewer"

gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:SA_EMAIL" \
  --role="roles/recommender.viewer"

gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:SA_EMAIL" \
  --role="roles/monitoring.viewer"
```

### Inaccurate cost forecasts

**Problem:** Forecasted costs don't match actual spend

**Solution:**
- Forecasts based on recent trends (past 30 days)
- Large variations in usage will skew forecasts
- Seasonal patterns not accounted for
- Use as guideline, not absolute truth
- Supplement with your own capacity planning

### Budget alerts delayed

**Problem:** Budget alerts arrive hours after threshold crossed

**Solution:**
- Budget data updated every few hours (not real-time)
- For real-time alerts, use Monitoring + custom metrics
- Consider cost spike alerts for immediate notification

---

## Cost Summary (Current State)

### Monthly Costs (tx03-dev)

```
Total Monthly Cost: $60-70
Budget: $100
Utilization: 65%
Status: ✅ Within budget
```

### Optimization Potential

| Optimization | Savings | Difficulty | Priority |
|--------------|---------|------------|----------|
| Disable Cloud Armor (dev) | -$10/month | Easy | ⭐⭐⭐ High |
| Use NodePort (dev) | -$20/month | Easy | ⭐⭐⭐ High |
| Reduce log retention | -$3/month | Easy | ⭐⭐ Medium |
| Delete idle resources | -$5-10/month | Easy | ⭐⭐ Medium |
| Right-size Cloud SQL | -$7/month | Medium | ⭐⭐ Medium |
| Schedule shutdowns | -$15/month | Medium | ⭐ Low |
| Committed Use Discounts | -$15-25/month | Hard | ⭐ Low |
| **TOTAL POTENTIAL** | **-$75-90/month** | | |

**Recommendation:** Implement Quick Wins first → Save $38-48/month (60% reduction)

---

## Recursos Adicionais

### GCP Documentation
- [Billing Budgets Guide](https://cloud.google.com/billing/docs/how-to/budgets)
- [Cost Management Best Practices](https://cloud.google.com/architecture/cost-efficiency-on-google-cloud)
- [Recommender Documentation](https://cloud.google.com/recommender/docs)
- [BigQuery Billing Export](https://cloud.google.com/billing/docs/how-to/export-data-bigquery)

### Tools
- [GCP Pricing Calculator](https://cloud.google.com/products/calculator)
- [Cost Management Dashboard](https://console.cloud.google.com/billing/reports)
- [Recommender Hub](https://console.cloud.google.com/home/recommendations)

### Community
- [FinOps Foundation](https://www.finops.org/)
- [GCP Cost Optimization Guide (GitHub)](https://github.com/GoogleCloudPlatform/cost-optimization)

---

**Última atualização:** 2026-01-03  
**Autor:** GitHub Copilot + maringelix  
**Versão:** 1.0
