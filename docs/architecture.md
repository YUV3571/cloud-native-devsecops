# Architecture

```mermaid
flowchart LR
  Dev[Developer Push / Pull Request] --> GHA[GitHub Actions]
  GHA --> Trivy[Trivy]
  GHA --> Checkov[Checkov]
  GHA --> CodeQL[CodeQL]
  GHA --> Infracost[Infracost JSON]
  GHA --> CostGPT[cloud-cost-gpt]
  GHA --> ECR[Amazon ECR]

  Terraform[Terraform] --> VPC[AWS VPC + Private/Public Subnets]
  Terraform --> EKS[Amazon EKS]
  Terraform --> ESO[External Secrets IAM/IRSA]
  Terraform --> Secrets[AWS Secrets Manager]

  Argo[Argo CD] --> App[shared-app overlays]
  Argo --> Policies[Kyverno policies]
  Argo --> KEDA[KEDA scaler]
  Argo --> Monitoring[Prometheus / Grafana / Jaeger]

  Secrets --> ESO
  ESO --> App
  Monitoring --> KEDA
  App --> Monitoring
  ECR --> Argo
```

## Scope

- The AWS path in this repository is deployment-ready and validated in CI.
- The AKS half of the original resume project is intentionally not represented as active Terraform here until it can be maintained to the same standard as the EKS path.
- `cloud-cost-gpt` consumes AWS Cost Explorer data and optionally enriches recommendations with Infracost pull request estimates.
