output "cluster_name" {
  description = "EKS cluster name."
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Public endpoint for the EKS control plane."
  value       = module.eks.cluster_endpoint
}

output "cluster_version" {
  description = "Kubernetes version running on the EKS control plane."
  value       = module.eks.cluster_version
}

output "configure_kubectl" {
  description = "Command to update kubeconfig locally."
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

output "shared_app_repository_url" {
  description = "ECR repository URL for the shared app image."
  value       = aws_ecr_repository.shared_app.repository_url
}

output "external_secrets_role_arn" {
  description = "IAM role assumed by External Secrets Operator via IRSA."
  value       = aws_iam_role.external_secrets.arn
}

output "prometheus_secret_arn" {
  description = "AWS Secrets Manager secret ARN for the KEDA Prometheus token."
  value       = aws_secretsmanager_secret.prometheus_token.arn
}

output "prometheus_secret_name" {
  description = "AWS Secrets Manager secret name for the KEDA Prometheus token."
  value       = aws_secretsmanager_secret.prometheus_token.name
}
