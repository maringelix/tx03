# Terraform Apply - Troubleshooting Log

## 📋 Resumo Executivo

A primeira implantação da infraestrutura GCP teve **7 problemas críticos** que exigiram 11 execuções do workflow e múltiplas correções manuais. Este documento analisa cada problema, a causa raiz e a solução aplicada.

**Status Final:** ✅ Infraestrutura implantada com sucesso (após correções)
**Total de Workflow Runs:** 11 (10 falhas, 1 sucesso parcial)
**Tempo Total:** ~4 horas de troubleshooting

---

## 🐛 Problema #1: Variável Faltando no Terraform Apply

### Sintoma
```
Terraform apply travava indefinitely (16+ minutos sem progresso)
Nenhum log de erro aparecia durante execução
```

### Causa Raiz
O workflow não estava passando a variável `service_account_email` no comando `terraform apply`:
```yaml
terraform apply -auto-approve \
  -var="project_id=${{ secrets.GCP_PROJECT_ID }}" \
  -var="environment=${{ env.ENVIRONMENT }}" \
  # FALTANDO: -var="service_account_email=..."
```

O Terraform ficava **aguardando input interativo** para a variável, mas como era workflow automatizado, nunca recebia resposta.

### Solução Aplicada
Adicionada a variável faltante:
```yaml
-var="service_account_email=${{ secrets.WIF_SERVICE_ACCOUNT }}"
```

### Lição Aprendida
- ✅ Sempre passar TODAS as variáveis via `-var` no workflow
- ✅ Nunca depender de valores default quando há secrets envolvidos
- ✅ Adicionar timeout para detectar hangs mais rápido

**Commit:** `ddeebe6` - "fix: add missing service_account_email variable to terraform apply"

---

## 🐛 Problema #2: State Lock Não Removido

### Sintoma
```
Error: Error acquiring the state lock
Lock Info:
  ID: 1766878167384516
  Who: runner@runnervmh13bl
```

### Causa Raiz
Quando um workflow é **cancelado ou atinge timeout**, o Terraform não consegue fazer cleanup do lock file no GCS bucket. O lock fica "órfão" e bloqueia próximas execuções.

Isso aconteceu **5+ vezes** durante o troubleshooting, exigindo limpeza manual:
```bash
gsutil rm gs://tfstate-tx03-f9d2e263/terraform/state/dev/default.tflock
```

### Solução Aplicada
Adicionado step automático para limpar locks órfãos antes do apply:
```yaml
- name: Clear Stale Lock (if exists)
  working-directory: terraform/environments/${{ env.ENVIRONMENT }}
  continue-on-error: true
  run: |
    echo "🔓 Checking for stale Terraform lock..."
    gsutil rm gs://${{ secrets.GCS_BUCKET }}/terraform/state/${{ env.ENVIRONMENT }}/default.tflock || echo "No lock file found"
```

**Importante:** `continue-on-error: true` garante que workflow não falhe se lock não existir.

### Lição Aprendida
- ✅ Sempre limpar locks antes de operações críticas
- ✅ Terraform não tem mecanismo built-in para locks expirados
- ✅ Considerar usar DynamoDB (AWS) ou similar para locks mais robustos

**Commit:** `3b4b09b` - "fix: add automatic stale lock cleanup before terraform apply"

---

## 🐛 Problema #3: Permissões Insuficientes do Service Account

### Sintoma
```
Error 403: Permission 'artifactregistry.repositories.create' denied
Error: Invalid request: Invalid Tier (db-f1-micro)
Error 409: Already exists: GKE cluster
```

### Causa Raiz
O service account `github-actions-sa` tinha roles básicos, mas faltavam permissões específicas:

**Roles Iniciais:**
- ❌ `roles/container.developer` - INSUFICIENTE (só read)
- ❌ `roles/compute.networkAdmin` - INSUFICIENTE (sem create VMs)
- ✅ `roles/cloudsql.admin` - OK
- ✅ `roles/storage.admin` - OK

**Permissões Faltando:**
- Artifact Registry: criar repositórios
- Compute: criar instâncias e recursos de rede
- Container: criar e gerenciar clusters GKE (não só acessar)

### Solução Aplicada
Adicionadas roles com permissões completas:
```bash
gcloud projects add-iam-policy-binding project-28e61e96-b6ac-4249-a21 \
  --member="serviceAccount:github-actions-sa@..." \
  --role="roles/compute.admin"

gcloud projects add-iam-policy-binding project-28e61e96-b6ac-4249-a21 \
  --member="serviceAccount:github-actions-sa@..." \
  --role="roles/container.admin"

gcloud projects add-iam-policy-binding project-28e61e96-b6ac-4249-a21 \
  --member="serviceAccount:github-actions-sa@..." \
  --role="roles/artifactregistry.admin"
```

### Lição Aprendida
- ✅ Testar permissões localmente ANTES de usar no CICD
- ✅ Documentar roles necessários no README
- ✅ Usar `roles/*Admin` para CICD (não `*Developer` ou `*User`)

**Comandos Executados:** ~3 comandos gcloud

---

## 🐛 Problema #4: Cloud SQL Tier Incompatível

### Sintoma (3 iterações de erro)
```
# Tentativa 1:
Error: Invalid Tier (db-f1-micro) for (ENTERPRISE_PLUS) Edition

# Tentativa 2:
Error: Invalid Tier (db-custom-1-3840) for (ENTERPRISE_PLUS) Edition

# Tentativa 3:
Error: Invalid Tier (db-perf-optimized-N-2) for (ENTERPRISE_PLUS) Edition
```

### Causa Raiz
PostgreSQL 16 no GCP usa **automaticamente** a **Enterprise Plus Edition**, que tem restrições de tier:

1. **db-f1-micro** (0.6GB RAM, shared CPU) - ❌ Não suportado (é um tier antigo)
2. **db-custom-1-3840** (1 vCPU, 3.75GB RAM) - ❌ Enterprise Plus não aceita custom tiers pequenos
3. **db-perf-optimized-N-2** (2 vCPU, 16GB RAM) - ❌ Funciona mas MUITO CARO (~$150/mês)

### Solução Final
Downgrade para **PostgreSQL 14** com tier **db-g1-small**:
- ✅ PostgreSQL 14 = Standard Edition (não Enterprise Plus)
- ✅ db-g1-small = 1 vCPU shared, 1.7GB RAM
- ✅ Custo: ~$15-20/mês (vs $150/mês do PostgreSQL 16)
- ✅ Compatível com Free Tier ($300 créditos = 15+ meses)

### Arquivos Modificados
```
terraform/modules/cloudsql/variables.tf - database_version: POSTGRES_14
terraform/environments/dev/main.tf - database_version: POSTGRES_14
terraform/environments/dev/terraform.tfvars - database_tier: db-g1-small
```

### Lição Aprendida
- ✅ PostgreSQL 16 é CARO no GCP (Enterprise Plus obrigatório)
- ✅ Para projetos de estudo/dev, usar PostgreSQL 14 ou 13
- ✅ Sempre consultar pricing antes de escolher versões
- ✅ Testar tiers com `gcloud sql tiers list` antes de configurar

**Commits:** 
- `8df39cb` - "fix: update Cloud SQL tier to db-custom-1-3840..."
- `f5df2b2` - "fix: use db-perf-optimized-N-2 tier..."
- `ba990af` - "fix: downgrade to PostgreSQL 14 with db-g1-small" ✅

---

## 🐛 Problema #5: GKE Cluster Criado Localmente

### Sintoma
```
Error 409: Already exists: clusters/tx03-gke-cluster
```

### Causa Raiz
Durante troubleshooting, executamos `terraform plan` e `terraform apply` **localmente** usando credenciais pessoais do usuário. Isso criou o GKE cluster fora do CICD.

Quando o workflow tentou criar, encontrou recurso já existente.

### Solução Aplicada (Gambiarra)
Import manual do recurso existente:
```bash
cd terraform/environments/dev
terraform import module.gke.google_container_cluster.primary \
  projects/project-28e61e96-b6ac-4249-a21/locations/us-central1/clusters/tx03-gke-cluster
```

### Problema com Esta Solução
⚠️ **O workflow NÃO pode recriar o cluster do zero** - ele espera que já exista.

Se destruir e tentar recriar, precisa:
1. Deletar do state: `terraform state rm module.gke.google_container_cluster.primary`
2. Deletar do GCP: `gcloud container clusters delete tx03-gke-cluster`
3. Executar workflow novamente

### Solução Correta (Para Futuro)
Nunca criar recursos localmente durante testes. Usar apenas:
```bash
terraform plan -out=tfplan  # Validar sintaxe
# NÃO EXECUTAR: terraform apply
```

### Lição Aprendida
- ❌ NUNCA executar `terraform apply` localmente em recursos gerenciados por CICD
- ✅ Usar apenas `plan` para validação local
- ✅ Se precisar testar apply, usar environment separado (staging)

**Status:** ⚠️ Cluster importado manualmente, não gerenciado 100% pelo CICD

---

## 🐛 Problema #6: Cloud SQL Instance Criada com Erro

### Sintoma
```
Error: Error waiting for Create Instance
Error, failed to create instance tx03-postgres-2f0f334b
```

### Causa Raiz
Cloud SQL foi criada durante um workflow com tier incompatível. O recurso foi criado no GCP mas Terraform falhou antes de salvar no state.

Situação: **Recurso existe no GCP mas NÃO no Terraform state**

### Solução Aplicada (Gambiarra)
Import manual da instância existente:
```bash
terraform import module.cloudsql.google_sql_database_instance.postgres \
  project-28e61e96-b6ac-4249-a21/tx03-postgres-2f0f334b
```

### Problema com Esta Solução
⚠️ **O workflow assume que instância já existe** após import.

Para recriar do zero:
1. Deletar do state: `terraform state rm module.cloudsql.google_sql_database_instance.postgres`
2. Deletar do GCP: `gcloud sql instances delete tx03-postgres-2f0f334b`
3. Executar workflow novamente

### Solução Correta (Para Futuro)
Terraform deveria ter mecanismo de **reconciliação automática**:
```hcl
# Não implementado - seria ideal ter:
lifecycle {
  prevent_destroy = false
  create_before_destroy = false
  ignore_changes = []
}
```

### Lição Aprendida
- ✅ Cloud SQL leva 5-10 minutos para criar
- ✅ Aumentar timeout do workflow para 30+ minutos
- ⚠️ Se falhar durante criação, verificar se recurso existe antes de retry

**Status:** ⚠️ Instância importada manualmente, não gerenciada 100% pelo CICD

---

## 🐛 Problema #7: kubectl Auth Plugin Faltando

### Sintoma
```
Error: executable gke-gcloud-auth-plugin not found
Unable to connect to the server: getting credentials
```

### Causa Raiz
GKE usa **Workload Identity** e requer plugin adicional do gcloud:
- Workflow tem `gcloud` instalado
- Mas NÃO tem `gke-gcloud-auth-plugin` (componente separado)

Sem o plugin, `kubectl` não consegue autenticar no cluster.

### Solução Aplicada
Instalação automática do plugin no workflow:
```yaml
- name: Configure kubectl
  run: |
    echo "⚙️  Configuring kubectl..."
    
    # Install gke-gcloud-auth-plugin
    gcloud components install gke-gcloud-auth-plugin --quiet
    
    gcloud container clusters get-credentials ...
```

### Lição Aprendida
- ✅ GKE Autopilot requer plugin adicional
- ✅ Adicionar `--quiet` para evitar prompts interativos
- ✅ Testar kubectl localmente antes de implementar no CICD

**Commit:** `3a640a7` - "fix: install gke-gcloud-auth-plugin for kubectl access"

---

## 📊 Estatísticas do Troubleshooting

| Métrica | Valor |
|---------|-------|
| **Total de Workflows Executados** | 11 runs |
| **Workflows com Falha** | 10 (90.9%) |
| **Workflows com Sucesso Parcial** | 1 (9.1%) |
| **Tempo Total de Troubleshooting** | ~4 horas |
| **Commits de Correção** | 8 commits |
| **Imports Manuais** | 2 (GKE + Cloud SQL) |
| **Locks Manuais Removidos** | 5+ vezes |
| **Mudanças de Configuração** | 3 (tier + versão PostgreSQL) |

---

## ✅ Correções Aplicadas ao Workflow

### 1. Variáveis Completas
```yaml
terraform apply -auto-approve \
  -var="project_id=${{ secrets.GCP_PROJECT_ID }}" \
  -var="environment=${{ env.ENVIRONMENT }}" \
  -var="service_account_email=${{ secrets.WIF_SERVICE_ACCOUNT }}" \
  -parallelism=10
```

### 2. Lock Cleanup Automático
```yaml
- name: Clear Stale Lock (if exists)
  continue-on-error: true
  run: |
    gsutil rm gs://${{ secrets.GCS_BUCKET }}/terraform/state/${{ env.ENVIRONMENT }}/default.tflock || true
```

### 3. Timeout Adequado
```yaml
- name: Terraform Apply
  timeout-minutes: 30  # Suficiente para Cloud SQL (5-10min)
```

### 4. Auth Plugin Instalado
```yaml
- name: Configure kubectl
  run: |
    gcloud components install gke-gcloud-auth-plugin --quiet
    gcloud container clusters get-credentials ...
```

### 5. Permissões Corretas Documentadas
```yaml
# Service Account Roles Required:
# - roles/compute.admin
# - roles/container.admin
# - roles/cloudsql.admin
# - roles/artifactregistry.admin
# - roles/storage.admin
# - roles/iam.serviceAccountUser
```

---

## ⚠️ Limitações Atuais

### 1. Recursos Importados Manualmente
**GKE Cluster** e **Cloud SQL Instance** foram importados ao Terraform state manualmente. 

**Implicação:** Se destruir infraestrutura e recriar do zero, workflow pode falhar novamente.

**Mitigação:** Sempre usar `terraform destroy` antes de `terraform apply` para garantir estado limpo.

### 2. Workflow Não é Totalmente Idempotente
Primeira execução vs execuções subsequentes têm comportamentos diferentes:
- **1ª execução:** Cria tudo do zero (se resources não existirem)
- **2ª+ execução:** Atualiza recursos existentes

**Mitigação:** Adicionar checks no workflow para detectar se recursos existem:
```bash
if gcloud container clusters describe $CLUSTER_NAME &>/dev/null; then
  echo "Cluster exists, updating..."
else
  echo "Cluster doesn't exist, creating..."
fi
```

### 3. Dependência de Ordem de Criação
Recursos têm dependências implícitas:
1. ✅ VPC Network (primeiro)
2. ✅ Private VPC Connection (segundo)
3. ✅ Cloud SQL (depende de #2)
4. ✅ GKE (depende de #1)

Se criação falhar no meio, precisa import manual.

---

## 🚀 Recomendações para Futuro

### Curto Prazo (Próxima Sprint)
1. ✅ Adicionar step de validação pré-apply:
   ```yaml
   - name: Validate Infrastructure State
     run: |
       # Check if resources exist
       # Offer to import or recreate
   ```

2. ✅ Implementar rollback automático em caso de falha:
   ```yaml
   on:
     workflow_run:
       workflows: ["Deploy Infrastructure"]
       types: [failed]
   jobs:
     rollback:
       runs-on: ubuntu-latest
       steps:
         - name: Rollback Infrastructure
           run: terraform destroy -auto-approve
   ```

3. ✅ Criar workflow separado para `terraform destroy`:
   - Proteger com approval manual
   - Backup de state antes de destruir

### Médio Prazo
1. ✅ Implementar **Terraform Workspaces** para múltiplos ambientes:
   - `dev` (atual)
   - `staging` (para testes de CICD)
   - `prod` (protegido)

2. ✅ Adicionar **testes automatizados** da infraestrutura:
   - Terratest para validar outputs
   - Inspec para compliance checks

3. ✅ Migrar state para **Terraform Cloud** (vs GCS bucket):
   - Lock management built-in
   - State versioning
   - Run history
   - Cost estimation

### Longo Prazo
1. ✅ Implementar **Policy as Code**:
   - Open Policy Agent (OPA)
   - Sentinel (Terraform Cloud)
   - Validar custos antes de apply

2. ✅ Adicionar **Observabilidade do CICD**:
   - Métricas de tempo de execução
   - Taxa de sucesso/falha
   - Alertas em caso de falha

---

## 📝 Checklist para Próxima Execução

Antes de rodar `terraform-apply.yml` novamente:

- [ ] Verificar que todos os secrets estão configurados
- [ ] Confirmar que service account tem todas as permissões
- [ ] Verificar se há lock órfão no GCS bucket
- [ ] Validar que `terraform plan` funciona localmente
- [ ] Confirmar que PostgreSQL 14 está configurado (não 16)
- [ ] Verificar tier do Cloud SQL (db-g1-small)
- [ ] Garantir que gke-gcloud-auth-plugin está no workflow
- [ ] Aumentar timeout para 30+ minutos se criar Cloud SQL do zero
- [ ] Ter backup do Terraform state antes de mudanças grandes

---

## 🎓 Lições Aprendidas Principais

1. **NUNCA misturar execução local com CICD** - escolha um ou outro
2. **Testar permissões ANTES de configurar CICD** - validar com gcloud CLI
3. **PostgreSQL 16 é CARO no GCP** - usar versões mais antigas para dev
4. **Terraform state locks não expiram automaticamente** - implementar cleanup
5. **GKE Autopilot requer auth plugin separado** - não é óbvio da documentação
6. **Timeouts devem considerar recursos lentos** - Cloud SQL leva 5-10min
7. **Sempre passar variáveis explicitamente** - não depender de defaults
8. **Imports manuais quebram idempotência** - evitar ao máximo

---

**Data:** 2025-12-28
**Duração Total:** ~4 horas
**Status Final:** ✅ Infraestrutura operacional (com gambiarras documentadas)
**Próximo Passo:** Deploy da aplicação dx03 no GKE
