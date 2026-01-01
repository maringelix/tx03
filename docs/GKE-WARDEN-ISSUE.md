# GKE Warden Bloqueando Pods com Istio Sidecar

**Data**: 01 de Janeiro de 2026  
**Status**: 🔴 BLOCKER CRÍTICO  
**Causa**: GKE Autopilot Warden rejeitando pods com sidecars do Istio

---

## 🔴 Problema Identificado

### Sintoma
```
Error creating: admission webhook "warden-validating.common-webhooks.networking.gke.io" 
denied the request: GKE Warden rejected the request because it violates one or more constraints....
```

### Status Atual
- **Deployments**: Existem (dx03-backend, dx03-frontend)
- **ReplicaSets**: Criados (múltiplos devido a várias tentativas)
- **Pods**: **0 pods running** ❌
- **Causa**: GKE Warden admission webhook bloqueando criação

### Timeline
1. 31/12 20:45 - Force delete executado
2. 31/12 20:45 - Pods deletados com sucesso
3. 31/12 20:45-01/01 13:42 - **~17 horas** tentando recriar pods
4. 01/01 13:42 - Descoberto: GKE Warden bloqueando

---

## 🔍 Análise

### O que é GKE Warden?
GKE Autopilot tem políticas de segurança mais restritivas que GKE Standard:
- Bloqueia containers privilegiados
- Bloqueia certos securityContext
- Bloqueia volumes hostPath
- **Pode bloquear configurações do Istio sidecar**

### Por que está bloqueando?
O Istio injeta sidecars com configurações específicas que podem violar políticas do Autopilot:
- Init containers com NET_ADMIN capability
- Volume mounts específicos
- Security contexts que Autopilot não permite

---

## 💡 Soluções Possíveis

### Opção 1: Remover Istio Injection (MAIS RÁPIDO)
Remover label `istio-injection=enabled` para que pods voltem a funcionar sem sidecars.

**Prós**:
- ✅ Pods voltam a funcionar imediatamente
- ✅ Aplicação continua rodando

**Contras**:
- ❌ Perde funcionalidades do service mesh
- ❌ Não tem mTLS
- ❌ Não tem circuit breaking
- ❌ Não tem distributed tracing

**Comando**:
```bash
kubectl label namespace dx03-dev istio-injection-
```

### Opção 2: Configurar Istio para GKE Autopilot (RECOMENDADO)
GKE Autopilot requer configuração específica do Istio.

**Passos**:
1. Reinstalar Istio com profile `ambient` ou configuração específica para Autopilot
2. Ou usar **Istio Ambient Mesh** (sem sidecars)
3. Ou migrar para **GKE Service Mesh** (Istio gerenciado pelo Google)

**Documentação**:
- https://cloud.google.com/service-mesh/docs/unified-install/install-anthos-service-mesh
- https://istio.io/latest/docs/ops/ambient/getting-started/

### Opção 3: Migrar para GKE Standard
Autopilot tem limitações. GKE Standard dá controle total.

**Prós**:
- ✅ Controle completo sobre políticas
- ✅ Istio funciona sem restrições

**Contras**:
- ❌ Custo maior (gerenciar nodes)
- ❌ Mais complexo de operar
- ❌ Precisa recriar cluster

### Opção 4: Usar ASM (Anthos Service Mesh)
GKE tem suporte nativo para Anthos Service Mesh (Istio gerenciado).

**Prós**:
- ✅ Otimizado para GKE Autopilot
- ✅ Suporte do Google
- ✅ Funcionalidades completas

**Contras**:
- ❌ Custo adicional
- ❌ Precisa migrar configurações

---

## 🎯 Recomendação

### Curto Prazo (AGORA)
**Remover Istio injection** para desbloquear aplicação:

```bash
# Remove namespace label
kubectl label namespace dx03-dev istio-injection-

# Force recreate dos deployments
kubectl rollout restart deployment/dx03-backend -n dx03-dev
kubectl rollout restart deployment/dx03-frontend -n dx03-dev
```

Resultado esperado: Pods voltam a funcionar com 1/1 containers (sem sidecar).

### Médio Prazo (DEPOIS)
Escolher entre:

1. **Istio Ambient Mesh** (sem sidecars, usa eBPF)
   - Compatível com GKE Autopilot
   - Menos overhead
   - Feature preview

2. **ASM (Anthos Service Mesh)**
   - Istio gerenciado pelo Google
   - Totalmente compatível com Autopilot
   - Production-ready

3. **Aceitar sem Service Mesh**
   - Usar features nativas do GKE
   - Cloud Load Balancer
   - Cloud Armor
   - Cloud Monitoring

---

## 📝 Próximos Passos

### Passo 1: Remover Injection (URGENTE)
```yaml
# Workflow: istio-remove-injection.yml
- Remove istio-injection label
- Restart deployments
- Validar pods 1/1 running
```

### Passo 2: Documentar Decisão
- Atualizar README com status
- Explicar limitação do GKE Autopilot
- Documentar alternativas

### Passo 3: Avaliar Alternativas
- Pesquisar Istio Ambient Mesh
- Verificar custo/benefício do ASM
- Considerar migração para GKE Standard (se necessário)

---

## 🔗 Referências

- [GKE Autopilot Limitations](https://cloud.google.com/kubernetes-engine/docs/concepts/autopilot-overview#limits)
- [Istio on GKE Autopilot](https://istio.io/latest/docs/setup/platform-setup/gke/)
- [Anthos Service Mesh](https://cloud.google.com/service-mesh/docs)
- [Istio Ambient Mesh](https://istio.io/latest/docs/ops/ambient/)
- [GKE Warden Policies](https://cloud.google.com/kubernetes-engine/docs/how-to/warden)

---

**Conclusão**: GKE Autopilot está bloqueando Istio sidecar injection. Precisamos remover a injection para desbloquear a aplicação e depois avaliar alternativas compatíveis com Autopilot.

**Decisão Necessária**: Usuário precisa escolher entre:
1. Remover Istio e voltar aplicação a funcionar (RÁPIDO)
2. Investigar Istio Ambient Mesh ou ASM (DEMORADO)
3. Migrar para GKE Standard (COMPLEXO)
