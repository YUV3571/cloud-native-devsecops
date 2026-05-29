# Terraform AWS/EKS Baseline

This directory provisions the AWS foundation for the portfolio platform:

- VPC with public and private subnets
- EKS control plane
- EKS managed node group
- ECR repository for `shared-app`
- External Secrets Operator with IRSA
- AWS Secrets Manager secret metadata for runtime secrets

## Prerequisites

- Terraform 1.6+
- AWS credentials with permission to create VPC, EKS, IAM, CloudWatch, and ECR resources
- AWS CLI configured locally

## Quick Start

```bash
cd terraform-iac
terraform init
terraform plan
terraform apply
```

After apply, configure `kubectl` with:

```bash
aws eks update-kubeconfig --region ap-southeast-2 --name cloud-native-devsecops
```

Populate the KEDA Prometheus token in AWS Secrets Manager after the infrastructure is created:

```bash
aws secretsmanager put-secret-value \
  --region ap-southeast-2 \
  --secret-id cloud-native-devsecops/prod/monitoring/prometheus \
  --secret-string '{"token":"REPLACE_ME"}'
```

## Notes

- The backend is currently local for simplicity. Move to S3 before team or long-lived use.
- The EKS and VPC resources are built with the maintained `terraform-aws-modules` modules to keep the repo concise and portfolio-friendly.
- The default region is `ap-southeast-2`; override with `-var aws_region=<region>` if needed.
- Runtime Kubernetes secrets should come from AWS Secrets Manager through External Secrets Operator rather than being committed or manually created in-cluster.
