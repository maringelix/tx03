# Security Stack for DX03 - OPA Gatekeeper + Trivy Operator

## 📚 Componentes

### OPA Gatekeeper
- **Policy-as-Code** enforcement controller
- **Admission webhooks** para validar recursos
- **Custom policies** (Rego language)
- **Constraint templates** reutilizáveis

### Trivy Operator
- **Vulnerability scanning** de containers
- **Config audit** de recursos Kubernetes
- **RBAC assessment** e análise de permissões
- **Infrastructure assessment** de segurança
- **CRD-based reports** armazenadas no cluster

## 🚀 Políticas Implementadas

### OPA Gatekeeper Policies

1. **Required Resources**
   - Força definição de `requests` e `limits`
   - Previne resource starvation

2. **Image Pull Policy**
   - Enforça `imagePullPolicy: Always`
   - Garante que sempre busca imagens atualizadas

3. **No Privileged**
   - Bloqueia containers privilegiados
   - Reduz surface de ataque

4. **Block Latest Image**
   - Proíbe uso da tag `:latest`
   - Força versionamento explícito de imagens

5. **Required Security Context**
   - Exige `securityContext` definido
   - Força execução como non-root
   - Aplica LSCs (Linux Security Contexts)

6. **Required Labels**
   - Exige labels `app` e `version`
   - Facilita gerenciamento e rastreamento

### Trivy Operator Scanning

1. **Vulnerability Reports**
   - CVE detection e severity
   - Base image scanning
   - Package vulnerability tracking

2. **Config Audit Reports**
   - Security best practices
   - Insecure configurations
   - Policy violations

3. **RBAC Assessment**
   - Overly permissive roles
   - Service account permissions
   - Privilege escalation risks

4. **Infra Assessment**
   - Network policies
   - Storage security
   - Pod security standards

## 🔧 Configuração

### Namespaces Excluídos

```yaml
excludedNamespaces:
  - gatekeeper-system  # Sistema do Gatekeeper
  - kube-system        # Sistema do Kubernetes
  - kube-public        # Namespace público
  - kube-node-lease    # Lease objects
  - trivy-system       # Sistema do Trivy
```

### Severidades Reportadas

- **CRITICAL** - Vulnerabilidades críticas
- **HIGH** - Vulnerabilidades altas
- **MEDIUM** - Médias (configurável)

### Retenção de Relatórios

- **Vulnerability Reports**: 24h
- **Config Audit Reports**: 24h
- **RBAC Assessment**: 24h
- **Infra Assessment**: 24h

## 📊 Acessando Relatórios

### Listar Vulnerability Reports

```bash
# Global vulnerability reports
kubectl get vulnerabilityreports -n dx03-dev

# Por pod
kubectl get vulnerabilityreports dx03-backend-xxxxx -n dx03-dev -o json

# Descrição detalhada
kubectl describe vr dx03-backend-xxxxx -n dx03-dev
```

### Listar Config Audit Reports

```bash
kubectl get configauditreports -n dx03-dev
kubectl describe car deployment-dx03-backend -n dx03-dev
```

### Listar RBAC Assessment Reports

```bash
kubectl get rbacassessmentreports -n dx03-dev
kubectl get clusterrbacassessmentreports | head -20
```

### Filtrar por Severidade

```bash
# Apenas CRITICAL
kubectl get vr -n dx03-dev -o json | jq '.items[] | select(.report.summary.critical > 0)'

# JSON formatado
kubectl get vr dx03-backend-xxxxx -n dx03-dev -o json | jq '.report.vulnerabilities[] | select(.severity=="CRITICAL")'
```

## 🔍 Monitorando Compliance

### Violações de Gatekeeper

```bash
# Ver violações
kubectl describe constraint required-resources

# Por namespace
kubectl get K8sRequiredResources -o wide

# Status dos constraints
kubectl get constraints -A
```

### Trivy Scan Status

```bash
# Ver configuração do Trivy
kubectl get cm trivy-operator-config -n trivy-system -o yaml

# Logs do operator
kubectl logs -n trivy-system -l app.kubernetes.io/name=trivy-operator -f

# Status das scans
kubectl get vulnerabilityreports -n dx03-dev --sort-by='.metadata.creationTimestamp'
```

## 🛡️ Integrações

### Com Prometheus

Trivy expõe métricas Prometheus:

```promql
# Vulnerabilidades por severidade
trivy_vulnerabilities_total{severity="CRITICAL"}

# Pods com vulnerabilidades
count(trivy_vulnerabilities_total{severity=~"CRITICAL|HIGH"} > 0)
```

### Com Slack/Alertas

Configure alertas via Prometheus/Alertmanager:

```yaml
- alert: CriticalVulnerabilityDetected
  expr: trivy_vulnerabilities_total{severity="CRITICAL"} > 0
  for: 5m
  annotations:
    summary: "Critical vulnerability detected in {{ $labels.image }}"
```

## 📋 Próximos Passos

1. **Policy Refinement**
   - Adicionar políticas customizadas
   - Ajustar severity levels
   - Configurar exceções per-namespace

2. **Integration**
   - Integrar com CI/CD para falhar builds
   - Enviar relatórios para SIEM
   - Sincronizar com ticketing systems

3. **Automation**
   - Auto-remediation de vulnerabilidades
   - Policy updates via GitOps
   - Scheduled compliance scans

4. **Compliance**
   - SOC 2, ISO 27001, PCI-DSS
   - Audit trails de violações
   - Compliance reporting

---

**Última atualização**: 31/12/2025

