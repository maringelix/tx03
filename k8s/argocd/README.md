# ArgoCD Configuration

Configuração do ArgoCD para GitOps no cluster GKE.

## 📋 Estrutura

```
k8s/argocd/
├── argocd-cm.yaml              # ConfigMap principal do ArgoCD
├── argocd-rbac-cm.yaml         # Configurações de RBAC
├── argocd-cmd-params-cm.yaml   # Parâmetros de linha de comando
├── application-dx03.yaml       # Application do dx03
└── README.md                   # Esta documentação
```

## 🚀 Componentes

### 1. ArgoCD ConfigMap (`argocd-cm.yaml`)
- Configurações gerais do ArgoCD
- Timeout de reconciliação: 180s
- Repositórios configurados: dx03 e tx03
- Health checks customizados

### 2. RBAC ConfigMap (`argocd-rbac-cm.yaml`)
Roles configurados:
- **admin**: Acesso completo
- **developer**: Sync, view e update de applications
- **readonly**: Apenas visualização

### 3. Command Params (`argocd-cmd-params-cm.yaml`)
- Modo insecure habilitado (para LoadBalancer)
- Paralelismo: 10 operações simultâneas
- Status processors: 20

### 4. Application dx03 (`application-dx03.yaml`)
- **Source**: `k8s/application/` no repositório tx03
- **Destination**: namespace `dx03-dev`
- **Sync Policy**: Automated com prune e self-heal
- **Retry**: 5 tentativas com backoff exponencial

## 📦 Instalação

Via workflow:
```bash
# Manual trigger
gh workflow run deploy-argocd.yml --ref master
```

Via kubectl:
```bash
# Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.10.0/manifests/install.yaml

# Apply custom configs
kubectl apply -f k8s/argocd/
```

## 🔑 Acesso

### Obter senha do admin:
```bash
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d
```

### Port forward local:
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Acesse: https://localhost:8080
```

### Via LoadBalancer:
```bash
kubectl get svc argocd-server -n argocd
# Pegue o EXTERNAL-IP e acesse: https://<EXTERNAL-IP>
```

## 🔧 ArgoCD CLI

### Instalação:
```bash
VERSION=v2.10.0
curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/download/$VERSION/argocd-linux-amd64
chmod +x argocd
sudo mv argocd /usr/local/bin/
```

### Login:
```bash
ARGOCD_SERVER=<EXTERNAL-IP>
ARGOCD_PASSWORD=$(kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d)

argocd login $ARGOCD_SERVER --username admin --password $ARGOCD_PASSWORD --insecure
```

### Comandos úteis:
```bash
# Listar applications
argocd app list

# Ver status da application
argocd app get dx03-app

# Sync manual
argocd app sync dx03-app

# Ver diff
argocd app diff dx03-app

# Ver logs
argocd app logs dx03-app

# Deletar application
argocd app delete dx03-app
```

## 📊 Monitoramento

### Status dos pods:
```bash
kubectl get pods -n argocd
```

### Logs do server:
```bash
kubectl logs -f deployment/argocd-server -n argocd
```

### Logs do application controller:
```bash
kubectl logs -f deployment/argocd-application-controller -n argocd
```

### Metrics:
```bash
kubectl port-forward svc/argocd-metrics -n argocd 8082:8082
# Acesse: http://localhost:8082/metrics
```

## 🔄 GitOps Workflow

1. **Commit & Push** - Altere arquivos em `k8s/application/`
2. **ArgoCD Detect** - ArgoCD detecta mudanças (polling 3min)
3. **Auto Sync** - Aplica automaticamente (se automated sync ativo)
4. **Health Check** - Verifica se aplicação está saudável
5. **Self Heal** - Reverte mudanças manuais no cluster

## 🎯 Applications Disponíveis

### dx03-app
- **Path**: `k8s/application/`
- **Namespace**: `dx03-dev`
- **Sync**: Automated
- **Prune**: Enabled
- **Self Heal**: Enabled

## ⚙️ Configurações Avançadas

### Adicionar novo repositório privado:
```bash
argocd repo add https://github.com/user/repo \
  --username <username> \
  --password <token>
```

### Criar novo projeto:
```bash
argocd proj create production \
  --dest https://kubernetes.default.svc,prod-* \
  --src https://github.com/maringelix/*
```

### Criar application via CLI:
```bash
argocd app create my-app \
  --repo https://github.com/maringelix/tx03.git \
  --path k8s/application \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace my-namespace \
  --sync-policy automated
```

## 🔒 Segurança

- Modo insecure habilitado (LoadBalancer sem TLS)
- Para produção, configure TLS certificate
- Altere senha do admin após primeiro login
- Configure SSO (OIDC, SAML, etc.)
- Use Projects para isolar teams

## 📚 Referências

- [ArgoCD Official Docs](https://argo-cd.readthedocs.io/)
- [Best Practices](https://argo-cd.readthedocs.io/en/stable/user-guide/best_practices/)
- [Declarative Setup](https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/)
