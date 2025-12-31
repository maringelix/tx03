# Security Stack - TX03/DX03

> Stack de segurança completo para GKE com OPA Gatekeeper e Trivy Operator

**Status:** 🟢 PRODUÇÃO  
**Última atualização:** 31 de Dezembro de 2025

---

## 📋 Índice

- [Visão Geral](#visão-geral)
- [Componentes](#componentes)
- [Políticas de Segurança](#políticas-de-segurança)
- [Vulnerability Scanning](#vulnerability-scanning)
- [Code Quality & Security Analysis](#code-quality--security-analysis)
- [Configuração e Deploy](#configuração-e-deploy)
- [Monitoramento](#monitoramento)
- [Troubleshooting](#troubleshooting)
- [Compliance](#compliance)

---

## 🎯 Visão Geral

O **Security Stack** do TX03 implementa defesa em profundidade com duas ferramentas complementares:

### 🔐 OPA Gatekeeper
- **Policy-as-Code** enforcement
- **Admission webhooks** para validação proativa
- **Rego language** para políticas customizadas
- **Constraint templates** reutilizáveis

### 🔍 Trivy Operator
- **Vulnerability scanning** contínuo
- **Config audit** de recursos Kubernetes
- **RBAC assessment** automático
- **Infrastructure assessment**

### Arquitetura

```
┌─────────────────────────────────────────────────────────┐
│                    GKE Autopilot Cluster                │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌──────────────────┐       ┌──────────────────────┐   │
│  │  OPA Gatekeeper  │       │   Trivy Operator     │   │
│  │  ────────────────│       │  ─────────────────── │   │
│  │  • Audit         │       │  • Scan Jobs         │   │
│  │  • Controller    │       │  • Operator          │   │
│  │                  │       │  • CRD Reports       │   │
│  └────────┬─────────┘       └──────────┬───────────┘   │
│           │                            │               │
│           └────────────┬───────────────┘               │
│                        │                               │
│        ┌───────────────▼──────────────┐                │
│        │  dx03-dev namespace          │                │
│        │  • frontend (2 pods)         │                │
│        │  • backend (2 pods)          │                │
│        └──────────────────────────────┘                │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## 🔧 Componentes

### 1. OPA Gatekeeper

**Namespace:** `gatekeeper-system`  
**Helm Chart:** `gatekeeper/gatekeeper` v3.18.1  
**Pods:** 2 (audit + controller-manager)

#### Componentes

1. **Gatekeeper Audit**
   - Auditoria periódica de recursos existentes
   - Detecta violações em recursos já deployados
   - Gera relatórios de compliance

2. **Gatekeeper Controller Manager**
   - Admission webhook para recursos novos
   - Valida recursos antes do deployment
   - Rejeita recursos não-conformes

#### Configuração

```yaml
# GKE Autopilot Compatibility
disableValidatingWebhook: false
validatingWebhookFailurePolicy: Ignore  # Permite falhas sem bloquear
validatingWebhookTimeoutSeconds: 3
validatingWebhookCustomRules:
  namespaceSelector:
    matchExpressions:
    - key: admission.gatekeeper.sh/ignore
      operator: DoesNotExist

# Excluded Namespaces
excludedNamespaces:
  - kube-system
  - kube-public
  - kube-node-lease
  - gatekeeper-system
  - trivy-system
```

---

### 2. Trivy Operator

**Namespace:** `trivy-system`  
**Helm Chart:** `aqua/trivy-operator` v0.31.0  
**Pods:** 1 operator + N scan jobs (ephemeral)

#### Componentes

1. **Trivy Operator Controller**
   - Monitora recursos Kubernetes
   - Cria scan jobs automaticamente
   - Gera CRDs com reports

2. **Scan Jobs**
   - Jobs efêmeros que executam scans
   - TTL: 3600s (1 hora) após conclusão
   - Auto-scaling baseado em recursos

#### Configuração

```yaml
# Scanning Configuration
vulnerabilityScans:
  autoScan: true
  scanOnlyCurrentRevisions: true

configAudits:
  autoScan: true

rbacAssessments:
  autoScan: true

infraAssessments:
  autoScan: true

# Report Settings
reportSeverities: CRITICAL,HIGH,MEDIUM
reports.retention: 24h
reportIncludeFixed: false
```

---

## 🛡️ Políticas de Segurança

### 1. Required Resources

**Objetivo:** Prevenir resource starvation e instabilidade

**Política:**
```yaml
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sRequiredResources
metadata:
  name: required-resources
spec:
  match:
    kinds:
      - apiGroups: [""]
        kinds: ["Pod"]
    namespaces:
      - dx03-dev
  parameters:
    resources:
      - requests.cpu
      - requests.memory
      - limits.cpu
      - limits.memory
```

**Enforçada em:** dx03-dev  
**Impacto:** 🔴 BLOCKING - Rejeita deploy sem resources definidos

**Exemplo de violação:**
```yaml
# ❌ Será rejeitado
containers:
- name: app
  image: nginx:1.21
  # Faltam resources!
```

**Correção:**
```yaml
# ✅ Aprovado
containers:
- name: app
  image: nginx:1.21
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 500m
      memory: 512Mi
```

---

### 2. Image Pull Policy

**Objetivo:** Garantir imagens atualizadas e evitar cache obsoleto

**Política:**
```yaml
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sImagePullPolicy
metadata:
  name: image-pull-policy
spec:
  match:
    kinds:
      - apiGroups: [""]
        kinds: ["Pod"]
    namespaces:
      - dx03-dev
  parameters:
    allowedPullPolicies:
      - Always
```

**Enforçada em:** dx03-dev  
**Impacto:** 🟡 WARNING - Recomendado mas não bloqueia

---

### 3. No Privileged Containers

**Objetivo:** Prevenir escalação de privilégios e reduzir superfície de ataque

**Política:**
```yaml
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sNoPrivileged
metadata:
  name: no-privileged
spec:
  match:
    kinds:
      - apiGroups: [""]
        kinds: ["Pod"]
    excludedNamespaces:
      - kube-system
      - gatekeeper-system
```

**Enforçada em:** Todos exceto system namespaces  
**Impacto:** 🔴 BLOCKING - Rejeita containers privilegiados

**Exemplo de violação:**
```yaml
# ❌ Será rejeitado
securityContext:
  privileged: true  # BLOQUEADO!
```

**Correção:**
```yaml
# ✅ Aprovado
securityContext:
  privileged: false
  allowPrivilegeEscalation: false
  runAsNonRoot: true
  runAsUser: 1000
```

---

### 4. Block Latest Image Tag

**Objetivo:** Forçar versionamento explícito de imagens

**Política:**
```yaml
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sBlockLatestImage
metadata:
  name: block-latest-image
spec:
  match:
    kinds:
      - apiGroups: [""]
        kinds: ["Pod"]
    namespaces:
      - dx03-dev
```

**Enforçada em:** dx03-dev  
**Impacto:** 🔴 BLOCKING - Rejeita tag `:latest`

**Exemplo de violação:**
```yaml
# ❌ Será rejeitado
containers:
- name: app
  image: nginx:latest  # BLOQUEADO!
```

**Correção:**
```yaml
# ✅ Aprovado
containers:
- name: app
  image: nginx:1.21.6  # Versão explícita
```

---

### 5. Required Security Context

**Objetivo:** Enforçar security best practices em todos os pods

**Política:**
```yaml
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sRequiredSecurityContext
metadata:
  name: required-security-context
spec:
  match:
    kinds:
      - apiGroups: [""]
        kinds: ["Pod"]
    namespaces:
      - dx03-dev
  parameters:
    requiredFields:
      - runAsNonRoot
      - runAsUser
      - allowPrivilegeEscalation
```

**Enforçada em:** dx03-dev  
**Impacto:** 🔴 BLOCKING - Rejeita pods sem securityContext

**Exemplo completo:**
```yaml
# ✅ Completo e aprovado
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  runAsGroup: 3000
  fsGroup: 2000
  allowPrivilegeEscalation: false
  capabilities:
    drop:
      - ALL
  readOnlyRootFilesystem: true
```

---

### 6. Required Labels

**Objetivo:** Facilitar gestão, rastreamento e troubleshooting

**Política:**
```yaml
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sRequiredLabels
metadata:
  name: required-labels
spec:
  match:
    kinds:
      - apiGroups: ["apps"]
        kinds: ["Deployment", "StatefulSet"]
    namespaces:
      - dx03-dev
  parameters:
    labels:
      - key: app
      - key: version
```

**Enforçada em:** dx03-dev (Deployments e StatefulSets)  
**Impacto:** 🟡 WARNING - Recomendado

**Exemplo:**
```yaml
# ✅ Aprovado
metadata:
  labels:
    app: dx03-backend
    version: "1.2.3"
    environment: dev
```

---

## 🔍 Vulnerability Scanning

### Tipos de Reports

#### 1. Vulnerability Reports (VR)

Escaneia imagens de containers para CVEs conhecidos.

**Comando:**
```bash
# Listar vulnerability reports
kubectl get vulnerabilityreports -n dx03-dev

# Detalhar report específico
kubectl describe vr <pod-name> -n dx03-dev

# Ver vulnerabilidades CRITICAL em JSON
kubectl get vr <pod-name> -n dx03-dev -o json | \
  jq '.report.vulnerabilities[] | select(.severity=="CRITICAL")'
```

**Exemplo de output:**
```json
{
  "vulnerabilityID": "CVE-2024-1234",
  "severity": "CRITICAL",
  "title": "Buffer overflow in libssl",
  "primaryLink": "https://nvd.nist.gov/vuln/detail/CVE-2024-1234",
  "score": 9.8,
  "installedVersion": "1.1.1k",
  "fixedVersion": "1.1.1l"
}
```

---

#### 2. Config Audit Reports (CAR)

Valida configurações de segurança contra best practices.

**Comando:**
```bash
# Listar config audit reports
kubectl get configauditreports -n dx03-dev

# Ver checks falhados
kubectl get car deployment-dx03-backend -n dx03-dev -o json | \
  jq '.report.checks[] | select(.success==false)'
```

**Checks comuns:**
- ✅ Container runs as non-root
- ✅ Liveness probe configured
- ✅ Resource limits defined
- ❌ readOnlyRootFilesystem enabled
- ❌ seccomp profile applied

---

#### 3. RBAC Assessment Reports

Analisa permissões excessivas e riscos de escalação.

**Comando:**
```bash
# Listar RBAC assessments
kubectl get rbacassessmentreports -n dx03-dev

# Cluster-wide
kubectl get clusterrbacassessmentreports | head -20
```

**Riscos detectados:**
- 🔴 Cluster-admin role binding a service accounts
- 🟡 Wildcard permissions (`*` em resources/verbs)
- 🟡 Acesso a secrets em múltiplos namespaces

---

#### 4. Infra Assessment Reports

Avalia configurações de segurança da infraestrutura.

**Comando:**
```bash
# Listar infra assessments
kubectl get infraassessmentreports -n dx03-dev
```

**Checks:**
- Network policies configuradas
- Pod Security Standards (PSS)
- Storage security
- API server configuration

---

## 📊 Code Quality & Security Analysis

### SonarCloud Integration

**Plataforma:** https://sonarcloud.io/organizations/maringelix/projects

#### Projetos Monitorados

##### 1. tx03 (Infraestrutura)

**URL:** https://sonarcloud.io/project/overview?id=maringelix_tx03

```
Lines of Code:      3.8k
Languages:          YAML, Terraform, HCL
Last Analysis:      31/12/2025, 2:58 AM

Security:           E (10 issues) 🔴
Reliability:        A (0 issues) ✅
Maintainability:    A (0 issues) ✅
Hotspots Reviewed:  E (0.0%) 🔴
Duplications:       0.0% ✅
```

**Issues Detectados:**
- 🔴 10 Security issues (principalmente em configurações de secrets e permissões)
- ✅ 0 Reliability bugs
- ✅ 0 Code smells
- 🔴 Security Hotspots não revisados (requer análise manual)

**Prioridades:**
1. Revisar os 10 security issues identificados
2. Analisar Security Hotspots (configurações sensíveis)
3. Implementar correções recomendadas
4. Re-executar análise para validar fixes

---

##### 2. dx03 (Aplicação)

**URL:** https://sonarcloud.io/project/overview?id=maringelix_dx03

```
Lines of Code:      1.5k
Languages:          JavaScript, YAML
Last Analysis:      31/12/2025, 2:58 AM

Security:           C (4 issues) 🟡
Reliability:        A (4 issues) ✅
Maintainability:    A (19 issues) ✅
Hotspots Reviewed:  E (0.0%) 🔴
Duplications:       0.0% ✅
```

**Issues Detectados:**
- 🟡 4 Security issues (validações, exposição de dados)
- 🟡 4 Reliability issues (error handling)
- 🟢 19 Maintainability code smells (minor)
- 🔴 Security Hotspots não revisados

**Prioridades:**
1. Corrigir 4 security issues (validação de inputs)
2. Melhorar error handling (4 issues)
3. Refatorar code smells de baixa prioridade
4. Revisar Security Hotspots

---

#### Quality Gates

**Status Atual:** ❌ Failed (ambos projetos)

**Critérios do Quality Gate:**
- ✅ Security Rating: A (objetivo)
- ✅ Reliability Rating: A (objetivo)
- ✅ Maintainability Rating: A (objetivo)
- ❌ Coverage: > 80% (objetivo)
- ✅ Duplications: < 3%
- ❌ Security Hotspots Reviewed: 100%

**Ações Corretivas:**
1. **tx03:** Reduzir de E para A em Security (10 issues)
2. **dx03:** Melhorar de C para A em Security (4 issues)
3. **Ambos:** Revisar 100% dos Security Hotspots
4. **dx03:** Adicionar testes unitários (coverage atual baixa)

---

#### Integração CI/CD

**Workflows GitHub Actions:**

```yaml
# .github/workflows/sonarcloud.yml
name: SonarCloud Analysis
on:
  push:
    branches: [master, develop]
  pull_request:
    branches: [master]

jobs:
  sonarcloud:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
        with:
          fetch-depth: 0  # Shallow clones desabilitados para análise completa
      
      - name: SonarCloud Scan
        uses: SonarSource/sonarcloud-github-action@master
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
        with:
          args: >
            -Dsonar.projectKey=maringelix_tx03
            -Dsonar.organization=maringelix
```

**Automatização:**
- ✅ Análise automática em cada push/PR
- ✅ Quality Gate check antes de merge
- ✅ Comentários automáticos em PRs
- ✅ Badge de status no README

---

#### Métricas e Dashboards

**Principais Métricas:**

```bash
# Ver métricas via API
curl -u "${SONAR_TOKEN}:" \
  "https://sonarcloud.io/api/measures/component?component=maringelix_tx03&metricKeys=security_rating,reliability_rating,sqale_rating,vulnerabilities,bugs,code_smells"

# Resposta (exemplo)
{
  "component": {
    "key": "maringelix_tx03",
    "measures": [
      {"metric": "security_rating", "value": "5.0"},      # E
      {"metric": "reliability_rating", "value": "1.0"},   # A
      {"metric": "sqale_rating", "value": "1.0"},         # A (Maintainability)
      {"metric": "vulnerabilities", "value": "10"},
      {"metric": "bugs", "value": "0"},
      {"metric": "code_smells", "value": "0"}
    ]
  }
}
```

**Dashboards Disponíveis:**
1. **Overview:** Issues por severidade e tipo
2. **Security:** Vulnerabilidades e security hotspots
3. **Reliability:** Bugs por severidade
4. **Maintainability:** Technical debt e code smells
5. **Coverage:** Test coverage por arquivo/componente
6. **Duplications:** Código duplicado detectado

---

#### Trend Analysis

**Evolução Histórica:**
- 📈 Lines of Code: Crescimento controlado
- 📉 Security Issues: tx03 (10) e dx03 (4) - requerem atenção
- ✅ Reliability: Mantido em A para ambos
- ✅ Maintainability: Estável em A
- ❌ Coverage: Necessita implementação de testes

**Objetivo Q1 2026:**
- 🎯 Security Rating: A para ambos projetos (zero issues)
- 🎯 Coverage: > 80% para dx03
- 🎯 Security Hotspots: 100% revisados
- 🎯 Quality Gate: PASSED para todos os projetos

---

## ⚙️ Configuração e Deploy

### Pré-requisitos

```bash
# 1. Autenticar no GCP
gcloud auth login

# 2. Configurar projeto
gcloud config set project project-28e61e96-b6ac-4249-a21

# 3. Conectar ao cluster
gcloud container clusters get-credentials tx03-gke-cluster \
  --region us-central1 \
  --project project-28e61e96-b6ac-4249-a21

# 4. Adicionar repos Helm
helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts
helm repo add aqua https://aquasecurity.github.io/helm-charts/
helm repo update
```

---

### Deploy Manual

#### OPA Gatekeeper

```bash
# Criar namespace
kubectl create namespace gatekeeper-system

# Instalar Gatekeeper
helm upgrade --install gatekeeper gatekeeper/gatekeeper \
  --namespace gatekeeper-system \
  --values k8s/security/gatekeeper-values.yaml \
  --wait

# Aplicar policies
kubectl apply -f k8s/security/gatekeeper-policies.yaml
kubectl apply -f k8s/security/gatekeeper-constraints.yaml

# Verificar instalação
kubectl get pods -n gatekeeper-system
kubectl get constrainttemplates
kubectl get constraints -A
```

#### Trivy Operator

```bash
# Criar namespace
kubectl create namespace trivy-system

# Instalar Trivy Operator
helm upgrade --install trivy-operator aqua/trivy-operator \
  --namespace trivy-system \
  --values k8s/security/trivy-operator-values.yaml \
  --wait

# Aplicar configuração
kubectl apply -f k8s/security/trivy-operator-config.yaml

# Verificar instalação
kubectl get pods -n trivy-system
kubectl api-resources | grep aquasecurity.github.io
```

---

### Deploy via CI/CD

**Workflow:** `.github/workflows/deploy-security.yml`

```bash
# Trigger workflow manualmente
gh workflow run deploy-security.yml

# Monitorar execução
gh run watch

# Ver logs
gh run view --log
```

**Inputs disponíveis:**
- `action`: install (padrão) | uninstall
- `gatekeeper-namespace`: gatekeeper-system (padrão)
- `trivy-namespace`: trivy-system (padrão)

---

## 📊 Monitoramento

### SonarCloud - Code Quality & Security Analysis

**Plataforma:** https://sonarcloud.io/organizations/maringelix/projects

#### Projetos Monitorados

##### 1. tx03 (Infraestrutura)

**URL:** https://sonarcloud.io/project/overview?id=maringelix_tx03

```
Lines of Code:      3.8k
Languages:          YAML, Terraform, HCL
Last Analysis:      31/12/2025, 2:58 AM

Security:           E (10 issues) 🔴
Reliability:        A (0 issues) ✅
Maintainability:    A (0 issues) ✅
Hotspots Reviewed:  E (0.0%) 🔴
Duplications:       0.0% ✅
```

**Issues Detectados:**
- 10 Security issues (principalmente em configurações de secrets e permissões)
- 0 Reliability bugs
- 0 Code smells
- Security Hotspots não revisados (requer análise manual)

**Próximas Ações:**
1. Revisar os 10 security issues identificados
2. Analisar Security Hotspots (configurações sensíveis)
3. Implementar correções recomendadas
4. Re-executar análise para validar fixes

##### 2. dx03 (Aplicação)

**URL:** https://sonarcloud.io/project/overview?id=maringelix_dx03

```
Lines of Code:      1.5k
Languages:          JavaScript, YAML
Last Analysis:      31/12/2025, 2:58 AM

Security:           C (4 issues) 🟡
Reliability:        A (4 issues) ✅
Maintainability:    A (19 issues) ✅
Hotspots Reviewed:  E (0.0%) 🔴
Duplications:       0.0% ✅
```

**Issues Detectados:**
- 4 Security issues (validações, exposição de dados)
- 4 Reliability issues (error handling)
- 19 Maintainability code smells (minor)
- Security Hotspots não revisados

**Próximas Ações:**
1. Corrigir 4 security issues (validação de inputs)
2. Melhorar error handling (4 issues)
3. Refatorar code smells de baixa prioridade
4. Revisar Security Hotspots

#### Integração CI/CD

**Workflows GitHub Actions:**

```yaml
# .github/workflows/sonarcloud.yml (exemplo)
name: SonarCloud Analysis
on:
  push:
    branches: [master, develop]
  pull_request:
    branches: [master]

jobs:
  sonarcloud:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
        with:
          fetch-depth: 0  # Shallow clones desabilitados
      
      - name: SonarCloud Scan
        uses: SonarSource/sonarcloud-github-action@master
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
```

#### Quality Gates

**Status Atual:** ❌ Failed (ambos projetos)

**Critérios do Quality Gate:**
- Security Rating: A (objetivo)
- Reliability Rating: A (objetivo)
- Maintainability Rating: A (objetivo)
- Coverage: > 80% (objetivo)
- Duplications: < 3%
- Security Hotspots Reviewed: 100%

**Ações Corretivas:**
1. **tx03:** Reduzir de E para A em Security (10 issues)
2. **dx03:** Melhorar de C para A em Security (4 issues)
3. **Ambos:** Revisar 100% dos Security Hotspots
4. **dx03:** Adicionar testes unitários (coverage atual baixa)

#### Métricas e Tendências

```bash
# Ver todas as métricas via API
curl -u "${SONAR_TOKEN}:" \
  "https://sonarcloud.io/api/measures/component?component=maringelix_tx03&metricKeys=security_rating,reliability_rating,sqale_rating,vulnerabilities,bugs,code_smells"
```

**Dashboards:**
- Overview: Issues por severidade
- Security: Vulnerabilidades e hotspots
- Reliability: Bugs e code smells
- Maintainability: Technical debt

---

### Health Checks

```bash
# Gatekeeper
kubectl get pods -n gatekeeper-system
kubectl logs -n gatekeeper-system -l app=gatekeeper-audit -f
kubectl logs -n gatekeeper-system -l app=gatekeeper-controller-manager -f

# Trivy
kubectl get pods -n trivy-system
kubectl logs -n trivy-system -l app.kubernetes.io/name=trivy-operator -f

# Scan jobs
kubectl get jobs -n trivy-system
kubectl get pods -n trivy-system | grep scan-
```

---

### Métricas Prometheus

**Gatekeeper Metrics:**

```promql
# Violações por constraint
gatekeeper_violations{enforcement_action="deny"}

# Audit runs
gatekeeper_audit_last_run_time

# Webhook latency
gatekeeper_validation_request_duration_seconds
```

**Trivy Metrics:**

```promql
# Total de vulnerabilidades
trivy_vulnerabilities_total{severity="CRITICAL"}

# Pods com CVEs críticos
count(trivy_vulnerabilities_total{severity="CRITICAL"} > 0)

# Scan duration
trivy_scan_duration_seconds
```

---

### Alertas Configurados

```yaml
# Alertmanager rules
groups:
  - name: security
    interval: 1m
    rules:
      - alert: CriticalVulnerabilityDetected
        expr: trivy_vulnerabilities_total{severity="CRITICAL"} > 0
        for: 5m
        annotations:
          summary: "Critical CVE detected"
          description: "Pod {{ $labels.pod }} has {{ $value }} CRITICAL vulnerabilities"

      - alert: PolicyViolationHigh
        expr: sum(gatekeeper_violations{enforcement_action="deny"}) > 10
        for: 10m
        annotations:
          summary: "High number of policy violations"
```

---

### Slack Notifications

Integrado via Alertmanager webhook:

**Canais:**
- `#alerts` - Alertas críticos de segurança
- `#monitoring` - Status de deployments

**Mensagens enviadas:**
- ✅ Security stack deployed
- ❌ Security deployment failed
- 🔴 Critical vulnerability detected
- 🟡 Policy violation detected

---

## 🔧 Troubleshooting

### Gatekeeper

#### Pod não inicia (ImagePullBackOff)

```bash
# Verificar eventos
kubectl describe pod -n gatekeeper-system <pod-name>

# Logs
kubectl logs -n gatekeeper-system <pod-name>
```

**Solução:** Verificar conectividade com ghcr.io e docker.io

---

#### Webhook bloqueando deployments

```bash
# Ver erro detalhado
kubectl describe pod <pod-name> -n dx03-dev

# Ver constraints violados
kubectl get constraints -A

# Desabilitar constraint temporariamente
kubectl patch constraint <constraint-name> \
  -p '{"spec":{"enforcementAction":"dryrun"}}' --type=merge
```

---

#### Policy não aplicando

```bash
# Verificar constraint template
kubectl get constrainttemplates

# Ver status do constraint
kubectl describe constraint <constraint-name>

# Forçar audit
kubectl annotate constraint <constraint-name> \
  audit.gatekeeper.sh/last-run-time-
```

---

### Trivy Operator

#### Scan jobs não executam

```bash
# Ver operator logs
kubectl logs -n trivy-system -l app.kubernetes.io/name=trivy-operator

# Verificar RBAC
kubectl auth can-i create jobs --as=system:serviceaccount:trivy-system:trivy-operator

# Verificar configuração
kubectl get cm trivy-operator-config -n trivy-system -o yaml
```

---

#### Reports não aparecem

```bash
# Verificar CRDs instalados
kubectl get crd | grep aquasecurity

# Listar todos os reports
kubectl get vulnerabilityreports -A
kubectl get configauditreports -A

# Forçar scan manual
kubectl annotate pod <pod-name> -n dx03-dev \
  trivy-operator.aquasecurity.github.io/force-scan=$(date +%s)
```

---

#### Scan jobs ficam pendentes

```bash
# Ver recursos do job
kubectl describe job -n trivy-system <job-name>

# Ver quotas
kubectl describe resourcequota -n trivy-system

# Ver node resources
kubectl top nodes
```

**Solução:** Aumentar resources ou ajustar scan concurrency

---

## 📋 Compliance

### Standards Suportados

- ✅ **CIS Kubernetes Benchmark** v1.8
- ✅ **NSA/CISA Kubernetes Hardening Guide**
- ✅ **OWASP Top 10 for Containers**
- ✅ **PCI-DSS** requirements (parcial)
- ✅ **SOC 2** Type II controls

---

### Audit Trail

Todos os eventos de segurança são registrados:

```bash
# Gatekeeper audit logs
kubectl logs -n gatekeeper-system -l app=gatekeeper-audit --tail=100

# Violações recentes
kubectl get constraints -A -o json | \
  jq '.items[] | select(.status.totalViolations > 0)'

# Trivy scan history
kubectl get vulnerabilityreports -A --sort-by='.metadata.creationTimestamp'
```

---

### Relatórios de Compliance

**Geração manual:**

```bash
# Export de todas as políticas
kubectl get constraints -A -o yaml > compliance-policies.yaml

# Export de violações
kubectl get constraints -A -o json | \
  jq '.items[] | {name: .metadata.name, violations: .status.totalViolations}' \
  > compliance-violations.json

# Export de vulnerabilidades
kubectl get vulnerabilityreports -A -o json > security-vulns.json
```

---

## 📚 Referências

### Documentação

- **OPA Gatekeeper:** https://open-policy-agent.github.io/gatekeeper/
- **Trivy Operator:** https://aquasecurity.github.io/trivy-operator/
- **Rego Language:** https://www.openpolicyagent.org/docs/latest/policy-language/
- **GKE Security Best Practices:** https://cloud.google.com/kubernetes-engine/docs/how-to/hardening-your-cluster

### Arquivos de Configuração

- [k8s/security/gatekeeper-values.yaml](k8s/security/gatekeeper-values.yaml)
- [k8s/security/gatekeeper-policies.yaml](k8s/security/gatekeeper-policies.yaml)
- [k8s/security/gatekeeper-constraints.yaml](k8s/security/gatekeeper-constraints.yaml)
- [k8s/security/trivy-operator-values.yaml](k8s/security/trivy-operator-values.yaml)
- [k8s/security/trivy-operator-config.yaml](k8s/security/trivy-operator-config.yaml)
- [.github/workflows/deploy-security.yml](.github/workflows/deploy-security.yml)

---

## 🎯 Roadmap

### Q1 2026

- [ ] **Custom Policies**
  - Container registry whitelist
  - Ingress TLS enforcement
  - Service mesh policies

- [ ] **Advanced Scanning**
  - SBOM generation
  - License compliance
  - Secret detection

- [ ] **Automation**
  - Auto-remediation de CVEs
  - Policy updates via GitOps
  - Scheduled compliance reports

### Q2 2026

- [ ] **Integration**
  - SIEM integration (Splunk/Elastic)
  - Ticketing (Jira)
  - CI/CD gate (fail on CRITICAL)

- [ ] **Multi-cluster**
  - Centralized policy management
  - Cross-cluster compliance
  - Federation

---

**Última atualização:** 31 de Dezembro de 2025  
**Mantido por:** DevOps Team @ TX03  
**Slack:** #security-stack
