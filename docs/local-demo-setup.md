# Local Demo Setup

This project can be demonstrated locally at zero cloud cost.

## Installed Tools

- `colima`
- `docker`
- `kind`
- `kubectl`
- `helm`
- `argocd`
- `terraform`

## Start The Local Runtime

```bash
colima start --cpu 4 --memory 8 --disk 60
```

## Create The Local Cluster

```bash
kind create cluster --config kind-config.yaml
kubectl get nodes --context kind-devsecops
```

## Install Argo CD

```bash
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl get pods -n argocd --context kind-devsecops
```

## Access Argo CD

Forward the Argo CD API server locally:

```bash
kubectl port-forward svc/argocd-server -n argocd 8081:443 --context kind-devsecops
```

Then open:

```text
https://localhost:8081
```

Login details:

- username: `admin`
- password: read from `argocd-initial-admin-secret`

## Current Cluster Shape

- 1 control-plane node
- 2 worker nodes
- host port `8080` mapped to cluster port `80`
- host port `8443` mapped to cluster port `443`

## Why This Exists

The repo targets AWS/EKS as production-style infrastructure, but the live demo path is local `kind` so the portfolio can be shown without any cloud spend.

## Default Delivery Mode

This repository defaults to the no-cost local demo path.

- application images are built locally
- images are loaded into the `kind` cluster directly
- AWS/ECR release automation stays disabled unless repository variable `ENABLE_AWS_RELEASE=true` is set

Release local changes with one command:

```bash
./scripts/local-release.sh
```
