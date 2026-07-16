variable "project_name" {
  description = "Base name used for AWS resources."
  type        = string
  default     = "cloud-native-devsecops"
}

variable "aws_region" {
  description = "AWS region for the EKS cluster."
  type        = string
  default     = "ap-southeast-2"
}

variable "kubernetes_version" {
  description = "Kubernetes version for the EKS control plane."
  type        = string
  default     = "1.30"
}

variable "node_instance_types" {
  description = "Instance types for the default managed node group."
  type        = list(string)
  default     = ["t3.micro"]
}

variable "node_desired_size" {
  description = "Desired number of worker nodes."
  type        = number
  default     = 1
}

variable "node_min_size" {
  description = "Minimum number of worker nodes."
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum number of worker nodes."
  type        = number
  default     = 1
}

variable "tags" {
  description = "Additional tags to apply to AWS resources."
  type        = map(string)
  default     = {}
}

variable "external_secrets_namespace" {
  description = "Namespace where External Secrets Operator is installed."
  type        = string
  default     = "external-secrets"
}

variable "external_secrets_chart_version" {
  description = "Helm chart version for External Secrets Operator."
  type        = string
  default     = "0.10.5"
}

variable "enable_external_secrets_helm" {
  description = "Whether to install the External Secrets Operator chart into the cluster."
  type        = bool
  default     = false
}
