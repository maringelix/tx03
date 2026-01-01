# Trivy Operator - GKE Autopilot Compatibility Fix

**Date**: 2025-12-31  
**Status**: ✅ Resolved  
**Component**: Security Stack / Trivy Operator

---

## Problem

The **Trivy Operator** installation was failing on **GKE Autopilot** with webhook admission errors during the security stack deployment workflow.

### Error Message

```
Error: UPGRADE FAILED: failed to create resource: admission webhook "admissionwebhookcontroller.common-webhooks.networking.gke.io" denied the request: GKE Admission Webhook Controller: the following (group,resource) pairs are not allowed in webhook rules: ('*','*'),('*','nodes/proxy'), see: https://cloud.google.com/kubernetes-engine/docs/concepts/autopilot-security#built-in-security
```

### Failed Workflow Runs

- **Run #20612715228**: 2025-12-31T05:23:52Z - Failed
- **Run #20612830367**: 2025-12-31T05:31:48Z - Failed
- **Run #20612909242**: 2025-12-31T05:37:51Z - ✅ **Success**

---

## Root Cause

**GKE Autopilot** has strict security constraints that prevent certain webhook configurations:

1. **Wildcard Resource Rules**: Webhook rules with `('*','*')` are blocked for security reasons
2. **Node Proxy Access**: Direct node proxy access `('*','nodes/proxy')` is prohibited
3. **Admission Webhook Controller**: GKE's built-in webhook validates and blocks insecure configurations

The initial Trivy Operator Helm chart configuration attempted to use overly permissive webhook rules that violated these constraints.

---

## Solution

### What Was Done

1. **Helm Chart Configuration Update**: Modified Trivy Operator values to avoid wildcard webhook rules
2. **Namespace-Scoped Scanning**: Configured Trivy to scan specific namespaces instead of cluster-wide wildcards
3. **Resource-Specific Webhooks**: Defined explicit resource types instead of catch-all patterns

### Configuration Changes

**File**: `k8s/security/trivy-operator-values.yaml`

Key changes:
- Removed wildcard resource selectors
- Limited webhook scope to application namespaces
- Aligned with GKE Autopilot security best practices

### Workflow Execution

```bash
# Successful deployment after fix
gh workflow run deploy-security.yml
```

---

## Verification

### Check Trivy Operator Status

```bash
# Check Trivy Operator pod
kubectl get pods -n trivy-system

# Expected output:
# NAME                              READY   STATUS    RESTARTS   AGE
# trivy-operator-7c695b7b64-pk7qb   1/1     Running   0          5m
```

### Check Vulnerability Reports

```bash
# List vulnerability reports across all namespaces
kubectl get vulnerabilityreports --all-namespaces -o wide

# Check config audit reports
kubectl get configauditreports --all-namespaces -o wide
```

### Check Trivy Operator Logs

```bash
# View operator logs
kubectl logs -n trivy-system deployment/trivy-operator

# Check for scanning activity
kubectl logs -n trivy-system deployment/trivy-operator | grep -i "scan"
```

---

## GKE Autopilot Security Constraints

### Blocked Webhook Patterns

❌ **Not Allowed**:
- `resources: ["*"]` with `apiGroups: ["*"]`
- `resources: ["nodes/proxy"]`
- Cluster-wide webhooks without namespace selectors

✅ **Allowed**:
- Specific resource types: `["pods", "deployments", "services"]`
- Namespace-scoped webhooks with `namespaceSelector`
- Resource-specific mutations and validations

### Best Practices for Autopilot

1. **Explicit Resource Types**: Always specify exact resources instead of wildcards
2. **Namespace Scoping**: Use namespace selectors to limit webhook scope
3. **Least Privilege**: Request only the minimum required permissions
4. **Test Incrementally**: Deploy with minimal permissions first, then expand as needed

---

## Related Issues

### Similar GKE Autopilot Constraints

This is the **second** GKE Autopilot security constraint encountered in this project:

1. **Istio Sidecar Injection**: Blocked by GKE Warden (see [GKE-WARDEN-ISSUE.md](GKE-WARDEN-ISSUE.md))
   - Issue: `istio-proxy` sidecar security configurations violated Autopilot policies
   - Resolution: Removed `istio-injection` label from namespace
   - Status: App running without service mesh (1/1 containers)

2. **Trivy Operator Webhooks**: Blocked by Admission Webhook Controller (this issue)
   - Issue: Wildcard webhook rules not allowed
   - Resolution: Updated Helm values to use explicit resource types
   - Status: ✅ Trivy scanning operational

---

## Lessons Learned

### GKE Autopilot Security Model

1. **Opinionated Security**: Autopilot enforces strict security boundaries
2. **Admission Controllers**: Multiple layers of validation (Warden, Webhook Controller, Policy Controller)
3. **Chart Compatibility**: Not all Helm charts work out-of-the-box with Autopilot
4. **Documentation is Key**: Always check GKE Autopilot compatibility notes

### Debugging Workflow

1. **Check Event Logs**: `kubectl get events -n <namespace> --sort-by='.lastTimestamp'`
2. **Examine Webhook Errors**: Look for "admission webhook" messages
3. **Review GKE Docs**: Consult https://cloud.google.com/kubernetes-engine/docs/concepts/autopilot-security
4. **Incremental Changes**: Make one config change at a time and test

---

## Timeline

| Time (UTC) | Event |
|------------|-------|
| 05:23:52 | First failure - wildcard webhook blocked |
| 05:31:48 | Second failure - configuration not yet updated |
| 05:37:51 | ✅ **Success** - proper webhook configuration applied |
| 05:39:05 | Trivy Operator pod ready and scanning |

Total Resolution Time: **~14 minutes** (3 workflow runs)

---

## Next Steps

### Immediate ✅ Complete

- [x] Trivy Operator deployed and operational
- [x] Vulnerability scanning active across namespaces
- [x] ConfigMap deployed with proper configuration

### Future Enhancements

- [ ] Configure Trivy scan schedules (currently manual)
- [ ] Set up Slack/email notifications for critical vulnerabilities
- [ ] Integrate Trivy reports with security dashboards
- [ ] Implement automated remediation policies based on scan results

---

## References

- **GKE Autopilot Security**: https://cloud.google.com/kubernetes-engine/docs/concepts/autopilot-security
- **Trivy Operator Docs**: https://aquasecurity.github.io/trivy-operator/
- **Admission Webhook Best Practices**: https://kubernetes.io/docs/reference/access-authn-authz/extensible-admission-controllers/
- **Related Issue**: [GKE-WARDEN-ISSUE.md](GKE-WARDEN-ISSUE.md) - Istio sidecar blocking

---

## Status Summary

🟢 **Trivy Operator**: Operational  
🟢 **Vulnerability Scanning**: Active  
🟢 **Config Auditing**: Active  
🟢 **GKE Autopilot**: Compatible configuration applied  

**Last Updated**: 2025-12-31 05:39 UTC  
**Deployed Version**: Trivy Operator (latest from aqua/trivy-operator Helm chart)
