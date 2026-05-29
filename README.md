# Cloud-Native DevSecOps Portfolio Platform

This repository is being rebuilt into a deployable DevOps portfolio project with concrete proof, not just architecture claims. The target end state is an AWS/EKS platform with GitOps, policy enforcement, observability, and focused AI features that solve real operations problems.

## Current Direction

The project is being narrowed to a credible MVP:

- **GitOps**: Argo CD deploys the sample application from this repo
- **Application**: a small Node.js service with health and Prometheus endpoints
- **Security**: Kyverno policies for signed images and hardened pods
- **Secrets**: AWS Secrets Manager synced into EKS with External Secrets Operator
- **Autoscaling**: KEDA-based scaling plus an AI autoscaling advisor concept
- **Observability**: Prometheus, Grafana, and tracing/logging integration
- **AI Cost Optimization**: GitHub Action that generates AWS cost recommendations
- **Infrastructure**: Terraform-managed AWS VPC, EKS, and ECR

## Current Status

This repo is mid-modernization. Some directories were older experiments and did not match the README. The first cleanup pass focuses on making the repository internally consistent:

- Added real Kubernetes manifests for the sample app
- Added Argo CD `Application` resources for `dev`, `stage`, and `prod`
- Rewrote this README around a proof-driven MVP
- Removed committed secrets, local state, and Azure-only leftovers from the tracked repo
- Replaced the Terraform baseline with AWS/EKS scaffolding
- Reworked the AI cost analyzer around AWS Cost Explorer

## Repository Layout

```text
cloud-native-devsecops/
├── .github/workflows/       # CI, security scans, and AI cost analysis workflow
├── argo-cd-gitops/          # Argo CD applications for each environment
├── cloud-cost-gpt/          # AI cost analysis GitHub Action
├── docs/                    # Modernization notes and portfolio roadmap
├── keda-openai-scaler/      # KEDA manifests and AI autoscaling experiments
├── kyverno-policies/        # Admission and image verification policies
├── observability-stack/     # Helmfile-based monitoring stack
├── platform-secrets/        # External Secrets manifests for runtime secrets
├── shared-app/              # Demo application and Kubernetes manifests
└── terraform-iac/           # AWS infrastructure for VPC, EKS, and ECR
```

## What Makes This Portfolio-Worthy

The goal is to show working evidence:

- successful GitHub Actions runs
- Argo CD sync status
- deployed application URL
- Kyverno policy enforcement output
- KEDA scaling evidence
- Grafana dashboards and traces
- AI-generated cost optimization reports

If a feature cannot be demonstrated, it should not be presented as complete.

## Deployable App Baseline

The sample app now includes Kubernetes manifests under [`shared-app/k8s`](/Users/yuv/PycharmProjects/uni/GITHUB/cloud-native-devsecops/shared-app/k8s) with:

- base deployment and service
- environment overlays for `dev`, `stage`, and `prod`
- Argo CD applications in [`argo-cd-gitops`](/Users/yuv/PycharmProjects/uni/GITHUB/cloud-native-devsecops/argo-cd-gitops)

Apply the Argo CD applications once Argo CD is installed:

```bash
kubectl apply -f argo-cd-gitops/
```

The AWS infrastructure baseline lives in [`terraform-iac`](/Users/yuv/PycharmProjects/uni/GITHUB/cloud-native-devsecops/terraform-iac) and now targets:

- VPC and subnet layout for EKS
- managed EKS node group
- ECR repository for the app image
- External Secrets Operator with IRSA for AWS Secrets Manager access

## Secret Management

Runtime secrets are now intended to flow through AWS Secrets Manager into Kubernetes:

- AWS Secrets Manager stores the source secret values
- External Secrets Operator runs in EKS with IRSA
- Argo CD applies `ExternalSecret` manifests from [`platform-secrets`](/Users/yuv/PycharmProjects/uni/GITHUB/cloud-native-devsecops/platform-secrets)
- Kubernetes workloads consume ordinary `Secret` objects created by the operator

The current production wiring creates a `prometheus-secret` in namespace `prod` from the AWS secret `cloud-native-devsecops/prod/monitoring/prometheus`.

## AI Features

The project is being repositioned around two credible AI features:

1. **AI Cost Optimization**
   Uses AWS Cost Explorer data and an LLM to generate actionable cost reduction recommendations.

2. **AI Autoscaling Advisor**
   Advises on better scaling thresholds from observed metrics and traffic patterns.
   The advisor should recommend settings, not directly own production scaling decisions.

## Next Major Fixes

- deploy the AWS/EKS platform and collect proof artifacts
- add proof artifacts and screenshots after deployment
- tighten the GitHub Actions workflow
- instrument the app and dashboards for scaling demonstrations

## Roadmap

The modernization plan is tracked in [`docs/portfolio-roadmap.md`](/Users/yuv/PycharmProjects/uni/GITHUB/cloud-native-devsecops/docs/portfolio-roadmap.md).
