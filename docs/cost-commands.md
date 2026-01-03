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

# Liberar se não necessário ($0.01/hour = $7/month)
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
# Artifact Registry:    $1-2    (2%)
# Networking:           $1-2    (2%)
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
