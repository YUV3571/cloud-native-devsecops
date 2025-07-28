# Cloud-Native DevSecOps Platform

A comprehensive cloud-native DevSecOps platform featuring GitOps, CI/CD pipelines, security policies, autoscaling, observability, and cost optimization.

## 🏗️ Architecture Overview

This repository contains a complete cloud-native DevSecOps stack with:

- **GitOps**: Argo CD for declarative deployments
- **CI/CD**: Tekton pipelines for cloud-native builds
- **Security**: Kyverno policies for admission control
- **Autoscaling**: KEDA with OpenAI sentiment analysis
- **Observability**: Comprehensive monitoring stack
- **Infrastructure**: Terraform for EKS provisioning
- **Cost Optimization**: AI-powered cost analysis

## 📁 Project Structure

```
cloud-native-devsecops/
├── argo-cd-gitops/          # GitOps configurations
├── tekton-pipeline/         # CI/CD pipeline definitions
├── kyverno-policies/        # Security and compliance policies
├── keda-openai-scaler/      # AI-powered autoscaling
├── observability-stack/     # Monitoring and logging
├── terraform-iac/          # Infrastructure as Code
├── cloud-cost-gpt/         # Cost optimization tools
├── shared-app/             # Sample application
└── .github/workflows/      # GitHub Actions
```

## 🚀 Quick Start

1. **Prerequisites**
   - Kubernetes cluster (EKS recommended)
   - kubectl configured
   - Helm 3.x
   - Terraform
   - GitHub Actions secrets configured

2. **Deploy Infrastructure**
   ```bash
   cd terraform-iac
   terraform init
   terraform plan
   terraform apply
   ```

3. **Install GitOps**
   ```bash
   kubectl apply -k argo-cd-gitops/
   ```

4. **Deploy Pipelines**
   ```bash
   kubectl apply -f tekton-pipeline/
   ```

## 🔐 Required Secrets

Configure these secrets in GitHub Actions:

| Secret Name | Purpose |
|-------------|---------|
| `TF_API_TOKEN` | Terraform Cloud authentication |
| `OPENAI_API_KEY` | GPT-based features (cost, logs) |
| `SOPS_AGE_KEY` | SOPS private key (base64 encoded) |
| `AZURE_CLIENT_ID` | Azure SDK authentication |
| `AZURE_CLIENT_SECRET` | Azure SDK authentication |

## 📊 Features

- ✅ **GitOps Workflow**: Automated deployments with Argo CD
- ✅ **Cloud-Native CI/CD**: Tekton pipelines
- ✅ **Security Policies**: Kyverno admission controllers
- ✅ **AI-Powered Scaling**: KEDA with sentiment analysis
- ✅ **Full Observability**: Prometheus, Grafana, Jaeger
- ✅ **Cost Optimization**: AI-driven cost analysis
- ✅ **Infrastructure as Code**: Terraform EKS modules

## 🛠️ Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests and security scans
5. Submit a pull request

## 📝 License

MIT License - see [LICENSE](LICENSE) file for details.
