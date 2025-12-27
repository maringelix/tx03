# Guia de Configuração: Workload Identity Federation

## Índice
- [O que é Workload Identity Federation?](#o-que-é-workload-identity-federation)
- [Por que usar WIF?](#por-que-usar-wif)
- [Pré-requisitos](#pré-requisitos)
- [Configuração Passo a Passo](#configuração-passo-a-passo)
- [GitHub Secrets](#github-secrets)
- [Validação](#validação)
- [Troubleshooting](#troubleshooting)

## O que é Workload Identity Federation?

Workload Identity Federation (WIF) permite que serviços externos (como GitHub Actions) se autentiquem no GCP **sem usar service account keys estáticas**.

### Fluxo de Autenticação

```
┌─────────────┐
│   GitHub    │
│   Actions   │
└──────┬──────┘
       │ 1. Request OIDC token
       │
       ▼
┌─────────────────┐
│ GitHub OIDC     │
│ Token Service   │
└──────┬──────────┘
       │ 2. JWT token (signed by GitHub)
       │
       ▼
┌──────────────────────────────┐
│ GCP Workload Identity Pool   │
│  • Validates JWT signature   │
│  • Maps claims to attributes │
└──────┬───────────────────────┘
       │ 3. Federated token
       │
       ▼
┌──────────────────────────────┐
│  GCP Service Account Token   │
│  • Short-lived token         │
│  • Scoped to SA permissions  │
└──────────────────────────────┘
```

## Por que usar WIF?

### ❌ Problema com Service Account Keys

```bash
# Keys estáticas (NÃO RECOMENDADO)
{
  "type": "service_account",
  "private_key_id": "abc123...",
  "private_key": "-----BEGIN PRIVATE KEY-----...",
  # Este arquivo pode vazar, é difícil de rotacionar
}
```

**Riscos**:
- Keys podem vazar via logs, commits acidentais
- Difícil rotacionar (requer atualizar em todos os lugares)
- Não expira automaticamente
- Sem auditoria de uso

### ✅ Solução: Workload Identity Federation

- ✅ Sem secrets estáticos no GitHub
- ✅ Tokens temporários (expiram em 1h)
- ✅ Autenticação baseada em OIDC (padrão da indústria)
- ✅ Auditável via Cloud Audit Logs
- ✅ Roteação automática
- ✅ Princípio do menor privilégio (scope limitado)

## Pré-requisitos

### 1. GCP CLI Instalado

```bash
gcloud --version
# Google Cloud SDK 480.0.0 ou superior
```

### 2. Projeto GCP Criado

```bash
export PROJECT_ID="tx03-prod"
gcloud config set project $PROJECT_ID
```

### 3. APIs Habilitadas

```bash
gcloud services enable \
  iam.googleapis.com \
  iamcredentials.googleapis.com \
  sts.googleapis.com \
  cloudresourcemanager.googleapis.com
```

### 4. Obter Project Number

```bash
export PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format="value(projectNumber)")
echo "Project Number: $PROJECT_NUMBER"
# Output: 123456789012
```

## Configuração Passo a Passo

### Passo 1: Criar Workload Identity Pool

```bash
gcloud iam workload-identity-pools create "github-pool" \
  --project="$PROJECT_ID" \
  --location="global" \
  --display-name="GitHub Actions Pool" \
  --description="Pool for GitHub Actions workflows"

# Verificar
gcloud iam workload-identity-pools describe "github-pool" \
  --project="$PROJECT_ID" \
  --location="global"
```

**Output esperado**:
```yaml
name: projects/123456789012/locations/global/workloadIdentityPools/github-pool
state: ACTIVE
displayName: GitHub Actions Pool
```

### Passo 2: Criar Workload Identity Provider (OIDC)

```bash
gcloud iam workload-identity-pools providers create-oidc "github-provider" \
  --project="$PROJECT_ID" \
  --location="global" \
  --workload-identity-pool="github-pool" \
  --display-name="GitHub Provider" \
  --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository,attribute.repository_owner=assertion.repository_owner" \
  --attribute-condition="assertion.repository_owner == 'maringelix'" \
  --issuer-uri="https://token.actions.githubusercontent.com"

# Verificar
gcloud iam workload-identity-pools providers describe "github-provider" \
  --project="$PROJECT_ID" \
  --location="global" \
  --workload-identity-pool="github-pool"
```

**Explicação do attribute-mapping**:
- `google.subject`: Identificador único do GitHub Actions job
- `attribute.repository`: Nome completo do repositório (owner/repo)
- `attribute.repository_owner`: Owner do repositório
- `attribute.actor`: Usuário que disparou o workflow

**attribute-condition**:
- Restringe acesso apenas a repositórios do owner `maringelix`
- Previne que forks não autorizados usem as credenciais

### Passo 3: Criar Service Account

```bash
gcloud iam service-accounts create "github-actions-sa" \
  --project="$PROJECT_ID" \
  --display-name="GitHub Actions Service Account" \
  --description="Service account for GitHub Actions CI/CD"

# Verificar
gcloud iam service-accounts describe "github-actions-sa@$PROJECT_ID.iam.gserviceaccount.com"
```

### Passo 4: Conceder Permissões IAM

```bash
# Roles necessários para deploy de infraestrutura
ROLES=(
  "roles/container.developer"           # GKE: criar/atualizar clusters
  "roles/compute.networkAdmin"          # VPC, subnets, firewall rules
  "roles/compute.loadBalancerAdmin"     # Load Balancer
  "roles/cloudsql.admin"                # Cloud SQL
  "roles/artifactregistry.writer"       # Push de imagens Docker
  "roles/storage.objectAdmin"           # Terraform state (GCS)
  "roles/iam.serviceAccountUser"        # Usar service accounts
  "roles/resourcemanager.projectIamAdmin" # IAM bindings
  "roles/serviceusage.serviceUsageAdmin" # Habilitar APIs
)

for ROLE in "${ROLES[@]}"; do
  gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:github-actions-sa@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="$ROLE" \
    --condition=None
done

# Verificar permissões
gcloud projects get-iam-policy "$PROJECT_ID" \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:github-actions-sa@$PROJECT_ID.iam.gserviceaccount.com" \
  --format="table(bindings.role)"
```

### Passo 5: Bind Workload Identity ao Service Account

```bash
# Permitir que o Workload Identity Pool use o Service Account
gcloud iam service-accounts add-iam-policy-binding \
  "github-actions-sa@$PROJECT_ID.iam.gserviceaccount.com" \
  --project="$PROJECT_ID" \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/projects/$PROJECT_NUMBER/locations/global/workloadIdentityPools/github-pool/attribute.repository/maringelix/tx03"

# Verificar binding
gcloud iam service-accounts get-iam-policy \
  "github-actions-sa@$PROJECT_ID.iam.gserviceaccount.com" \
  --project="$PROJECT_ID"
```

**Explicação do member**:
- `principalSet://...`: Conjunto de principals que podem assumir o SA
- `attribute.repository/maringelix/tx03`: Apenas workflows do repo `maringelix/tx03`

### Passo 6: Obter Workload Identity Provider ID

```bash
export WIF_PROVIDER=$(gcloud iam workload-identity-pools providers describe "github-provider" \
  --project="$PROJECT_ID" \
  --location="global" \
  --workload-identity-pool="github-pool" \
  --format="value(name)")

echo "WIF_PROVIDER: $WIF_PROVIDER"
# Output: projects/123456789012/locations/global/workloadIdentityPools/github-pool/providers/github-provider
```

## GitHub Secrets

### Configurar no GitHub

1. Acesse: `https://github.com/maringelix/tx03/settings/secrets/actions`

2. Clique em **New repository secret**

3. Adicione os seguintes secrets:

| Secret Name | Valor | Exemplo |
|------------|-------|---------|
| `GCP_PROJECT_ID` | Project ID | `tx03-prod` |
| `GCP_PROJECT_NUMBER` | Project Number | `123456789012` |
| `WIF_PROVIDER` | Workload Identity Provider | `projects/123456789012/locations/global/workloadIdentityPools/github-pool/providers/github-provider` |
| `WIF_SERVICE_ACCOUNT` | Service Account Email | `github-actions-sa@tx03-prod.iam.gserviceaccount.com` |
| `GCS_BUCKET` | Terraform State Bucket | `tfstate-tx03-abc123` |

### Obter Valores via CLI

```bash
# GCP_PROJECT_ID
echo "GCP_PROJECT_ID: $(gcloud config get-value project)"

# GCP_PROJECT_NUMBER
echo "GCP_PROJECT_NUMBER: $(gcloud projects describe $(gcloud config get-value project) --format='value(projectNumber)')"

# WIF_PROVIDER
gcloud iam workload-identity-pools providers describe "github-provider" \
  --project="$(gcloud config get-value project)" \
  --location="global" \
  --workload-identity-pool="github-pool" \
  --format="value(name)"

# WIF_SERVICE_ACCOUNT
echo "WIF_SERVICE_ACCOUNT: github-actions-sa@$(gcloud config get-value project).iam.gserviceaccount.com"

# GCS_BUCKET (após executar bootstrap)
gcloud storage buckets list --filter="name:tfstate-tx03-*" --format="value(name)"
```

## Validação

### Teste Local (Simulação)

```bash
# 1. Obter um token do Workload Identity Pool
gcloud auth application-default print-access-token \
  --impersonate-service-account="github-actions-sa@$PROJECT_ID.iam.gserviceaccount.com"
```

Se retornar um token (JWT), a configuração está correta!

### Teste via GitHub Actions

1. Crie um workflow de teste: `.github/workflows/test-wif.yml`

```yaml
name: Test Workload Identity

on:
  workflow_dispatch:

permissions:
  contents: read
  id-token: write  # Required for OIDC

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - name: Authenticate to Google Cloud
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ secrets.WIF_PROVIDER }}
          service_account: ${{ secrets.WIF_SERVICE_ACCOUNT }}
      
      - name: Setup Cloud SDK
        uses: google-github-actions/setup-gcloud@v2
      
      - name: Test GCP Access
        run: |
          gcloud projects describe ${{ secrets.GCP_PROJECT_ID }}
          echo "✅ Workload Identity working!"
```

2. Execute o workflow: **Actions → Test Workload Identity → Run workflow**

3. Se o output mostrar os detalhes do projeto, **sucesso!** 🎉

## Troubleshooting

### Erro: "Permission denied"

**Sintoma**:
```
ERROR: (gcloud.xxx) User [github-actions-sa@PROJECT.iam] does not have permission to access resource
```

**Solução**:
```bash
# Verificar roles do Service Account
gcloud projects get-iam-policy "$PROJECT_ID" \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:github-actions-sa@*"

# Adicionar role faltante
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:github-actions-sa@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/MISSING_ROLE"
```

### Erro: "Failed to generate Google Cloud credentials"

**Sintoma**:
```
Error: google-github-actions/auth failed with: failed to generate Google Cloud credentials
```

**Possíveis causas**:
1. `WIF_PROVIDER` incorreto
2. `WIF_SERVICE_ACCOUNT` incorreto
3. Workload Identity binding não configurado
4. `id-token: write` permission faltando

**Solução**:
```bash
# Verificar Workload Identity binding
gcloud iam service-accounts get-iam-policy \
  "github-actions-sa@$PROJECT_ID.iam.gserviceaccount.com"

# Deve conter:
# members:
# - principalSet://iam.googleapis.com/projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/github-pool/attribute.repository/maringelix/tx03
```

### Erro: "Invalid repository"

**Sintoma**:
```
Error: The repository 'other-user/forked-repo' is not allowed
```

**Causa**: O `attribute-condition` restringe acesso ao owner `maringelix`.

**Solução**:
- Se for um fork legítimo, ajuste o attribute-condition:
```bash
gcloud iam workload-identity-pools providers update-oidc "github-provider" \
  --project="$PROJECT_ID" \
  --location="global" \
  --workload-identity-pool="github-pool" \
  --attribute-condition="assertion.repository_owner == 'maringelix' || assertion.repository_owner == 'other-user'"
```

### Erro: "API not enabled"

**Sintoma**:
```
ERROR: (gcloud.iam.workload-identity-pools.create) FAILED_PRECONDITION: API [iam.googleapis.com] not enabled
```

**Solução**:
```bash
gcloud services enable iam.googleapis.com iamcredentials.googleapis.com sts.googleapis.com
```

## Segurança: Best Practices

### 1. Princípio do Menor Privilégio

✅ Conceda apenas as roles necessárias:
```bash
# Exemplo: Para um workflow que só faz deploy de imagens
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:deploy-only-sa@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/artifactregistry.writer"  # Somente push de imagens
```

### 2. Attribute Conditions Restritivos

✅ Limite acesso a repositórios específicos:
```bash
--attribute-condition="assertion.repository == 'maringelix/tx03'"
```

### 3. Auditoria

Monitore uso do Workload Identity:
```bash
# Ver logs de autenticação
gcloud logging read "protoPayload.serviceName=sts.googleapis.com" \
  --limit 50 \
  --format json
```

### 4. Rotação de Service Accounts

Se um SA for comprometido:
```bash
# Desabilitar SA
gcloud iam service-accounts disable "github-actions-sa@$PROJECT_ID.iam.gserviceaccount.com"

# Criar novo SA e reconfigurar bindings
```

## Referências

- [Workload Identity Federation Official Docs](https://cloud.google.com/iam/docs/workload-identity-federation)
- [GitHub Actions OIDC](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)
- [google-github-actions/auth](https://github.com/google-github-actions/auth)
- [Security Best Practices](https://cloud.google.com/iam/docs/best-practices-for-using-workload-identity-federation)

---

**Última atualização**: 2025-01-01  
**Autor**: maringelix + GitHub Copilot
