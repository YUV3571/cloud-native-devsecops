# Secrets Management

This project now uses an AWS-native runtime secret flow for EKS:

1. Terraform provisions:
   - EKS with IRSA enabled
   - an IAM role for External Secrets Operator
   - an AWS Secrets Manager secret for the KEDA Prometheus bearer token
   - the External Secrets Operator Helm release
2. Argo CD applies the manifests in [`platform-secrets/prod`](/Users/yuv/PycharmProjects/uni/GITHUB/cloud-native-devsecops/platform-secrets/prod).
3. External Secrets Operator reads from AWS Secrets Manager and creates a Kubernetes `Secret` named `prometheus-secret` in namespace `prod`.
4. KEDA reads that Kubernetes secret through `TriggerAuthentication`.

## Current Runtime Secret

- AWS secret name: `cloud-native-devsecops/prod/monitoring/prometheus`
- Kubernetes secret: `prod/prometheus-secret`
- Key exposed to Kubernetes: `token`

## Bootstrap

After Terraform finishes, store the real bearer token in AWS Secrets Manager:

```bash
aws secretsmanager put-secret-value \
  --region ap-southeast-2 \
  --secret-id cloud-native-devsecops/prod/monitoring/prometheus \
  --secret-string '{"token":"REPLACE_ME"}'
```

Then let Argo CD reconcile, or force a refresh:

```bash
kubectl annotate application platform-secrets-prod -n argocd \
  argocd.argoproj.io/refresh=hard --overwrite
```

## Current Scope

- GitHub Actions secrets are still stored in GitHub Secrets.
- Runtime application and platform secrets in EKS should use AWS Secrets Manager plus External Secrets Operator.
- No Azure Key Vault wiring remains in the active repo layout.
