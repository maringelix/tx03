# ArgoCD - GitOps Continuous Delivery

[![ArgoCD](https://img.shields.io/badge/ArgoCD-v2.10.0-blue.svg)](https://argo-cd.readthedocs.io/)
[![GitOps](https://img.shields.io/badge/GitOps-Enabled-brightgreen.svg)](https://www.gitops.tech/)

> Implementação do ArgoCD para GitOps continuous delivery no GKE. Deploy declarativo e automatizado de aplicações Kubernetes.

## 📋 Índice

- [Visão Geral](#visão-geral)
- [Arquitetura](#arquitetura)
- [Instalação](#instalação)
- [Configuração](#configuração)
- [Applications](#applications)
- [Acesso e Autenticação](#acesso-e-autenticação)
- [GitOps Workflow](#gitops-workflow)
- [Comandos CLI](#comandos-cli)
- [Monitoramento](#monitoramento)
- [Troubleshooting](#troubleshooting)
- [Segurança](#segurança)
- [Best Practices](#best-practices)

## 🎯 Visão Geral

### O que é ArgoCD?

ArgoCD é uma ferramenta declarativa de continuous delivery para Kubernetes que implementa GitOps:

- **Declarativo**: Configuração em Git como fonte única da verdade
- **Automatizado**: Sincronização contínua entre Git e cluster
- **Auditável**: Histórico completo de deployments
- **Rollback**: Reversão facilitada para versões anteriores

### Por que usar ArgoCD?

✅ **GitOps Native** - Git como única fonte da verdade  
✅ **Automated Sync** - Deploy automático de mudanças  
✅ **Self-Healing** - Corrige drift automático  
✅ **Multi-Cluster** - Gerencia múltiplos clusters  
✅ **RBAC Integrado** - Controle de acesso granular  
✅ **Web UI** - Interface visual para applications  
✅ **Rollback Fácil** - Volta para qualquer versão anterior  
✅ **Health Status** - Monitora saúde das applications  

### Componentes Instalados

```
argocd namespace:
├── argocd-server              # API server e Web UI
├── argocd-repo-server         # Git repository manager
├── argocd-application-controller  # Application controller
├── argocd-dex-server         # Identity provider (SSO)
├── argocd-redis              # Cache e queue
└── argocd-applicationset-controller  # ApplicationSet controller
```

## 🏗️ Arquitetura

### Fluxo GitOps

```
┌─────────────┐      ┌──────────────┐      ┌─────────────┐
│   Git Repo  │─────▶│   ArgoCD     │─────▶│ Kubernetes  │
│  (tx03/dx03)│      │  Controller  │      │   Cluster   │
└─────────────┘      └──────────────┘      └─────────────┘
       │                     │                     │
       │                     ▼                     │
       │             ┌──────────────┐             │
       │             │  Sync Status │◀────────────┘
       │             └──────────────┘
       │                     │
       └─────────────────────┘
           (Git Pull)
```

### Componentes

1. **API Server** - Interface REST e Web UI
2. **Repository Server** - Clona e mantém cache de repos Git
3. **Application Controller** - Monitora applications e sincroniza
4. **Redis** - Cache de manifest e estado das applications
5. **Dex** - Identity provider para SSO (opcional)

## 📦 Instalação

### Via Workflow (Recomendado)

```bash
# Trigger workflow manualmente
gh workflow run deploy-argocd.yml --ref master

# Ou via push de mudanças em k8s/argocd/
git add k8s/argocd/
git commit -m "feat: update argocd config"
git push
```

### Via kubectl (Manual)

```bash
# 1. Create namespace
kubectl create namespace argocd

# 2. Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.10.0/manifests/install.yaml

# 3. Wait for pods to be ready
kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s

# 4. Apply custom configurations
kubectl apply -f k8s/argocd/

# 5. Expose server via LoadBalancer
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'
```

### Verificar Instalação

```bash
# Check pods
kubectl get pods -n argocd

# Check services
kubectl get svc -n argocd

# Check applications
kubectl get applications -n argocd
```

## ⚙️ Configuração

### ConfigMaps Customizados

#### 1. `argocd-cm.yaml` - Configurações Gerais

```yaml
data:
  timeout.reconciliation: 180s    # Sync interval
  repositories: |                 # Repos permitidos
    - url: https://github.com/maringelix/dx03.git
    - url: https://github.com/maringelix/tx03.git
```

#### 2. `argocd-rbac-cm.yaml` - RBAC Policies

```yaml
data:
  policy.default: role:readonly   # Default: somente leitura
  policy.csv: |
    p, role:admin, *, *, */*, allow
    p, role:developer, applications, sync, */*, allow
    p, role:readonly, applications, get, */*, allow
```

#### 3. `argocd-cmd-params-cm.yaml` - Parâmetros

```yaml
data:
  server.insecure: "true"              # HTTP mode (LoadBalancer)
  controller.operation.processors: "10" # Paralelismo
```

### Estrutura de Arquivos

```
k8s/argocd/
├── argocd-cm.yaml                 # Config geral
├── argocd-rbac-cm.yaml           # RBAC policies
├── argocd-cmd-params-cm.yaml     # Command params
├── application-dx03.yaml          # Application dx03
└── README.md                      # Docs
```

## 🚀 Applications

### Application dx03

Sincroniza automaticamente a aplicação dx03:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: dx03-app
  namespace: argocd
spec:
  source:
    repoURL: https://github.com/maringelix/tx03.git
    path: k8s/application
    targetRevision: HEAD
  destination:
    server: https://kubernetes.default.svc
    namespace: dx03-dev
  syncPolicy:
    automated:
      prune: true         # Remove recursos deletados
      selfHeal: true      # Corrige drift automaticamente
```

### Criar Nova Application

#### Via Web UI

1. Acesse ArgoCD UI
2. Click em **"+ NEW APP"**
3. Preencha:
   - Application Name: `my-app`
   - Project: `default`
   - Sync Policy: `Automatic`
   - Repository URL: `https://github.com/user/repo`
   - Path: `k8s/manifests`
   - Cluster URL: `https://kubernetes.default.svc`
   - Namespace: `my-namespace`

#### Via CLI

```bash
argocd app create my-app \
  --repo https://github.com/maringelix/tx03.git \
  --path k8s/application \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace my-namespace \
  --sync-policy automated \
  --auto-prune \
  --self-heal
```

#### Via YAML

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/maringelix/tx03.git
    path: k8s/application
    targetRevision: HEAD
  destination:
    server: https://kubernetes.default.svc
    namespace: my-namespace
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

## 🔑 Acesso e Autenticação

### Obter Senha do Admin

```bash
# Via kubectl
kubectl get secret argocd-initial-admin-secret \
  -n argocd \
  -o jsonpath='{.data.password}' | base64 -d

# Via workflow
gh workflow run deploy-argocd.yml -f action=get-password
```

### Acessar Web UI

#### Port Forward (Local)

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Acesse: https://localhost:8080
# Username: admin
# Password: (obtida acima)
```

#### LoadBalancer (Produção)

```bash
# Obter IP externo
kubectl get svc argocd-server -n argocd

# Acesse: https://<EXTERNAL-IP>
```

### Login via CLI

```bash
# Get server IP
ARGOCD_SERVER=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Get password
ARGOCD_PASSWORD=$(kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d)

# Login
argocd login $ARGOCD_SERVER \
  --username admin \
  --password $ARGOCD_PASSWORD \
  --insecure
```

### Alterar Senha

```bash
# Via CLI
argocd account update-password \
  --current-password <OLD_PASSWORD> \
  --new-password <NEW_PASSWORD>

# Via Web UI
# Settings → Accounts → admin → Update Password
```

## 🔄 GitOps Workflow

### Fluxo Completo

1. **Desenvolvedor** faz mudança no código
2. **CI/CD** builda imagem e atualiza manifests no Git
3. **ArgoCD** detecta mudança no repositório (polling 3min)
4. **ArgoCD** compara desired state (Git) vs current state (cluster)
5. **ArgoCD** aplica mudanças automaticamente (se auto-sync)
6. **ArgoCD** verifica health status da application
7. **Self-heal** corrige qualquer drift manual

### Exemplo Prático

```bash
# 1. Altere um manifest
vim k8s/application/backend-deployment.yaml
# Altere replicas: 2 → 3

# 2. Commit e push
git add k8s/application/backend-deployment.yaml
git commit -m "scale: increase backend replicas to 3"
git push

# 3. ArgoCD detecta e sincroniza automaticamente
# Acompanhe no Web UI ou:
argocd app get dx03-app
argocd app wait dx03-app --sync
```

### Sync Manual

```bash
# Via CLI
argocd app sync dx03-app

# Via Web UI
# Click na application → SYNC → SYNCHRONIZE
```

### Rollback

```bash
# Via CLI - voltar para versão anterior
argocd app rollback dx03-app

# Via CLI - voltar para versão específica
argocd app rollback dx03-app --revision 5

# Via Web UI
# Application → History → Select revision → ROLLBACK
```

## 🛠️ Comandos CLI

### Instalação do CLI

```bash
VERSION=v2.10.0
curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/download/$VERSION/argocd-linux-amd64
chmod +x argocd
sudo mv argocd /usr/local/bin/
argocd version --client
```

### Comandos Essenciais

```bash
# Login
argocd login <ARGOCD-SERVER> --username admin --password <PASSWORD> --insecure

# Listar applications
argocd app list

# Ver detalhes da application
argocd app get dx03-app

# Ver status de sync
argocd app sync-status dx03-app

# Sync manual
argocd app sync dx03-app

# Ver diff entre Git e cluster
argocd app diff dx03-app

# Ver histórico de deployments
argocd app history dx03-app

# Ver logs
argocd app logs dx03-app

# Delete application
argocd app delete dx03-app
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
```

### Gerenciar Clusters

```bash
# Listar clusters
argocd cluster list

# Adicionar cluster
argocd cluster add <CONTEXT-NAME>

# Remover cluster
argocd cluster rm <CLUSTER-URL>
```

### Projects

```bash
# Listar projects
argocd proj list

# Criar project
argocd proj create production \
  --dest https://kubernetes.default.svc,prod-* \
  --src https://github.com/maringelix/*

# Ver detalhes do project
argocd proj get default
```

## 📊 Monitoramento

### Status dos Pods

```bash
# Todos os pods do ArgoCD
kubectl get pods -n argocd

# Status detalhado
kubectl describe pods -n argocd

# Resources usage
kubectl top pods -n argocd
```

### Logs

```bash
# Server logs
kubectl logs -f deployment/argocd-server -n argocd

# Application controller logs
kubectl logs -f deployment/argocd-application-controller -n argocd

# Repo server logs
kubectl logs -f deployment/argocd-repo-server -n argocd

# Application specific logs
argocd app logs dx03-app --follow
```

### Metrics

```bash
# Port forward metrics endpoint
kubectl port-forward svc/argocd-metrics -n argocd 8082:8082

# Acesse: http://localhost:8082/metrics
```

### Health Checks

```bash
# Application health
argocd app get dx03-app --output json | jq '.status.health'

# Sync status
argocd app get dx03-app --output json | jq '.status.sync'

# Operation state
argocd app get dx03-app --output json | jq '.status.operationState'
```

### Prometheus Integration

ArgoCD expõe métricas no formato Prometheus:

```yaml
# ServiceMonitor para Prometheus Operator
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: argocd-metrics
  namespace: argocd
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: argocd-metrics
  endpoints:
  - port: metrics
```

## 🔧 Troubleshooting

### Application não sincroniza

```bash
# Verificar sync policy
argocd app get dx03-app | grep -A5 "Sync Policy"

# Forçar sync
argocd app sync dx03-app --force

# Ver diff
argocd app diff dx03-app

# Refresh (force fetch from Git)
argocd app get dx03-app --refresh
```

### Application unhealthy

```bash
# Ver recursos unhealthy
argocd app get dx03-app --show-params

# Ver logs do pod problemático
kubectl logs -n dx03-dev <POD-NAME>

# Descrever recurso
kubectl describe -n dx03-dev deployment/<NAME>
```

### Sync travado

```bash
# Terminar sync operation
argocd app terminate-op dx03-app

# Limpar finalizers
kubectl patch app dx03-app -n argocd -p '{"metadata":{"finalizers":[]}}' --type merge
```

### Repository não acessa

```bash
# Testar conexão com repo
argocd repo get https://github.com/maringelix/tx03.git

# Re-adicionar repo
argocd repo rm https://github.com/maringelix/tx03.git
argocd repo add https://github.com/maringelix/tx03.git --username <user> --password <token>
```

### Pods não sobem

```bash
# Ver eventos do namespace
kubectl get events -n argocd --sort-by='.lastTimestamp'

# Ver logs do pod
kubectl logs -n argocd <POD-NAME> --previous

# Restart deployment
kubectl rollout restart deployment/argocd-server -n argocd
```

### Debug Mode

```bash
# Habilitar debug logging
kubectl set env deployment/argocd-server -n argocd ARGOCD_LOG_LEVEL=debug

# Ver logs debug
kubectl logs -f deployment/argocd-server -n argocd
```

## 🔒 Segurança

### Alterar Senha Admin

```bash
# Primeira coisa após instalação!
argocd account update-password
```

### Configurar RBAC

Roles disponíveis:
- **admin**: Acesso total
- **developer**: Sync e view
- **readonly**: Apenas visualização

```yaml
# argocd-rbac-cm.yaml
policy.csv: |
  p, role:developer, applications, sync, default/*, allow
  p, role:developer, applications, get, default/*, allow
  g, alice@example.com, role:developer
```

### SSO com OIDC

```yaml
# argocd-cm.yaml
data:
  url: https://argocd.example.com
  oidc.config: |
    name: Google
    issuer: https://accounts.google.com
    clientID: $OIDC_CLIENT_ID
    clientSecret: $OIDC_CLIENT_SECRET
```

### Repositórios Privados

```bash
# Via token
argocd repo add https://github.com/user/private-repo \
  --username <username> \
  --password <github-token>

# Via SSH key
argocd repo add git@github.com:user/private-repo.git \
  --ssh-private-key-path ~/.ssh/id_rsa
```

### TLS Certificate

```bash
# Para produção, configure certificado TLS
kubectl create -n argocd secret tls argocd-server-tls \
  --cert=path/to/cert.crt \
  --key=path/to/cert.key

# Disable server.insecure
kubectl patch configmap argocd-cmd-params-cm -n argocd \
  --type merge \
  -p '{"data":{"server.insecure":"false"}}'
```

## ✅ Best Practices

### 1. Repository Structure

```
repo/
├── apps/                    # Applications
│   ├── app1/
│   ├── app2/
│   └── app3/
├── base/                    # Base configs (Kustomize)
├── overlays/                # Environment overlays
│   ├── dev/
│   ├── staging/
│   └── prod/
└── argocd/                  # ArgoCD applications
    ├── app1.yaml
    ├── app2.yaml
    └── app3.yaml
```

### 2. Sync Strategies

**Automated Sync** - Para dev/staging:
```yaml
syncPolicy:
  automated:
    prune: true
    selfHeal: true
```

**Manual Sync** - Para produção:
```yaml
syncPolicy:
  syncOptions:
    - CreateNamespace=true
```

### 3. Projects para Isolamento

```bash
# Dev project
argocd proj create dev \
  --dest https://kubernetes.default.svc,dev-* \
  --src https://github.com/maringelix/*

# Prod project
argocd proj create prod \
  --dest https://kubernetes.default.svc,prod-* \
  --src https://github.com/maringelix/*
```

### 4. Health Checks Customizados

```yaml
resource.customizations: |
  apps/Deployment:
    health.lua: |
      hs = {}
      if obj.status.readyReplicas == obj.spec.replicas then
        hs.status = "Healthy"
      else
        hs.status = "Progressing"
      end
      return hs
```

### 5. Notifications

Configure notificações via Slack, Email, etc:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-notifications-cm
data:
  service.slack: |
    token: $slack-token
  trigger.on-deployed: |
    - send: [app-deployed]
```

## 📚 Referências

### Documentação Oficial
- [ArgoCD Docs](https://argo-cd.readthedocs.io/)
- [Getting Started](https://argo-cd.readthedocs.io/en/stable/getting_started/)
- [User Guide](https://argo-cd.readthedocs.io/en/stable/user-guide/)
- [Operator Manual](https://argo-cd.readthedocs.io/en/stable/operator-manual/)

### Best Practices
- [GitOps Best Practices](https://www.gitops.tech/)
- [ArgoCD Best Practices](https://argo-cd.readthedocs.io/en/stable/user-guide/best_practices/)
- [Security Best Practices](https://argo-cd.readthedocs.io/en/stable/operator-manual/security/)

### Tutoriais
- [ArgoCD Tutorial](https://redhat-scholars.github.io/argocd-tutorial/)
- [GitOps with ArgoCD](https://www.youtube.com/watch?v=MeU5_k9ssrs)

### Repositório tx03
- [Workflow](../.github/workflows/deploy-argocd.yml)
- [Manifests](../k8s/argocd/)
- [README](../k8s/argocd/README.md)

---

**Status**: ✅ Implementado  
**Versão**: v2.10.0  
**Namespace**: argocd  
**Applications**: 1 (dx03-app)  
**Última Atualização**: 2026-01-03
