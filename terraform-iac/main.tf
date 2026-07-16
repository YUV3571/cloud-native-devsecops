provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  cluster_name           = var.project_name
  azs                    = slice(data.aws_availability_zones.available.names, 0, 3)
  prometheus_secret_name = "${var.project_name}/prod/monitoring/prometheus"

  tags = merge(
    {
      Project     = var.project_name
      ManagedBy   = "Terraform"
      Environment = "portfolio"
    },
    var.tags,
  )
}

data "archive_file" "secret_rotation_zip" {
  type        = "zip"
  source_file = "${path.module}/rotation/rotate_secret.py"
  output_path = "${path.module}/rotation/rotate_secret.zip"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.19.0"

  name = "${var.project_name}-vpc"
  cidr = "10.0.0.0/16"

  azs             = local.azs
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway             = true
  single_nat_gateway             = true
  manage_default_security_group  = true
  default_security_group_ingress = []
  default_security_group_egress  = []

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }

  tags = local.tags
}

#checkov:skip=CKV2_AWS_19: NAT gateway EIPs are intentionally allocated for managed egress, not direct EC2 attachment.
#checkov:skip=CKV_AWS_39: Demo cluster keeps public endpoint enabled for GitHub Actions and local kubectl bootstrap.
#checkov:skip=CKV_AWS_38: Public endpoint exposure is intentional for bootstrap access in this portfolio environment.
#checkov:skip=CKV2_AWS_5: EKS module security groups are attached indirectly by managed control-plane and node-group resources.
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.24.2"

  cluster_name               = local.cluster_name
  cluster_version            = var.kubernetes_version
  enable_irsa                = true
  create_cni_ipv6_iam_policy = false

  cluster_endpoint_public_access           = true
  enable_cluster_creator_admin_permissions = true
  cluster_enabled_log_types                = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  cloudwatch_log_group_retention_in_days   = 365
  cloudwatch_log_group_kms_key_id          = aws_kms_key.secrets.arn

  cluster_encryption_config = {
    resources        = ["secrets"]
    provider_key_arn = aws_kms_key.secrets.arn
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  eks_managed_node_groups = {
    default = {
      instance_types = var.node_instance_types
      min_size       = var.node_min_size
      max_size       = var.node_max_size
      desired_size   = var.node_desired_size
      capacity_type  = "ON_DEMAND"
    }
  }

  cluster_addons = {
    coredns    = {}
    kube-proxy = {}
    vpc-cni = {
      most_recent = true
    }
  }

  tags = local.tags
}

resource "aws_ecr_repository" "shared_app" {
  name                 = "${var.project_name}/shared-app"
  image_tag_mutability = "IMMUTABLE"

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = aws_kms_key.ecr.arn
  }

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = local.tags
}

#checkov:skip=CKV_AWS_356: AWS KMS key policies require "*" as the resource to refer to the key itself.
#checkov:skip=CKV_AWS_109: Root access in the default KMS key policy is intentionally constrained to this account root principal.
#checkov:skip=CKV_AWS_111: Root access in the default KMS key policy is intentionally constrained to this account root principal.
data "aws_iam_policy_document" "kms_key_default" {
  statement {
    sid    = "EnableRootPermissions"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }

    actions   = ["kms:*"]
    resources = ["*"]
  }
}

resource "aws_kms_key" "ecr" {
  description             = "KMS key for ECR image encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.kms_key_default.json

  tags = local.tags
}

resource "aws_kms_alias" "ecr" {
  name          = "alias/${var.project_name}-ecr"
  target_key_id = aws_kms_key.ecr.key_id
}

resource "aws_kms_key" "secrets" {
  description             = "KMS key for Secrets Manager secrets"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.kms_key_default.json

  tags = local.tags
}

resource "aws_kms_alias" "secrets" {
  name          = "alias/${var.project_name}-secrets"
  target_key_id = aws_kms_key.secrets.key_id
}

resource "aws_secretsmanager_secret" "prometheus_token" {
  name        = local.prometheus_secret_name
  description = "Prometheus bearer token consumed by KEDA via External Secrets"
  kms_key_id  = aws_kms_key.secrets.arn

  tags = local.tags
}

resource "aws_iam_role" "secret_rotation_lambda" {
  name = "${var.project_name}-secret-rotation-lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "secret_rotation_lambda_basic" {
  role       = aws_iam_role.secret_rotation_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "secret_rotation_lambda_vpc" {
  role       = aws_iam_role.secret_rotation_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

data "aws_iam_policy_document" "secret_rotation_lambda_access" {
  statement {
    actions = [
      "secretsmanager:PutSecretValue",
      "secretsmanager:DescribeSecret",
    ]
    resources = [aws_secretsmanager_secret.prometheus_token.arn]
  }
}

resource "aws_iam_policy" "secret_rotation_lambda_access" {
  name   = "${var.project_name}-secret-rotation-lambda-access"
  policy = data.aws_iam_policy_document.secret_rotation_lambda_access.json

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "secret_rotation_lambda_access" {
  role       = aws_iam_role.secret_rotation_lambda.name
  policy_arn = aws_iam_policy.secret_rotation_lambda_access.arn
}

resource "aws_sqs_queue" "secret_rotation_dlq" {
  name                      = "${var.project_name}-secret-rotation-dlq"
  kms_master_key_id         = aws_kms_key.secrets.arn
  message_retention_seconds = 1209600

  tags = local.tags
}

data "aws_iam_policy_document" "secret_rotation_lambda_dlq" {
  statement {
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.secret_rotation_dlq.arn]
  }
}

resource "aws_iam_policy" "secret_rotation_lambda_dlq" {
  name   = "${var.project_name}-secret-rotation-lambda-dlq"
  policy = data.aws_iam_policy_document.secret_rotation_lambda_dlq.json

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "secret_rotation_lambda_dlq" {
  role       = aws_iam_role.secret_rotation_lambda.name
  policy_arn = aws_iam_policy.secret_rotation_lambda_dlq.arn
}

resource "aws_security_group" "secret_rotation_lambda" {
  name        = "${var.project_name}-secret-rotation-lambda"
  description = "Security group for the secret rotation Lambda"
  vpc_id      = module.vpc.vpc_id

  egress {
    description = "Allow outbound HTTPS for AWS APIs"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.tags
}

resource "aws_lambda_function" "secret_rotation" {
  function_name                  = "${var.project_name}-secret-rotation"
  role                           = aws_iam_role.secret_rotation_lambda.arn
  handler                        = "rotate_secret.lambda_handler"
  runtime                        = "python3.12"
  filename                       = data.archive_file.secret_rotation_zip.output_path
  source_code_hash               = data.archive_file.secret_rotation_zip.output_base64sha256
  timeout                        = 30
  kms_key_arn                    = aws_kms_key.secrets.arn
  reserved_concurrent_executions = 2

  dead_letter_config {
    target_arn = aws_sqs_queue.secret_rotation_dlq.arn
  }

  tracing_config {
    mode = "Active"
  }

  vpc_config {
    subnet_ids         = module.vpc.private_subnets
    security_group_ids = [aws_security_group.secret_rotation_lambda.id]
  }

  environment {
    variables = {
      SECRET_ID = aws_secretsmanager_secret.prometheus_token.name
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.secret_rotation_lambda_basic,
    aws_iam_role_policy_attachment.secret_rotation_lambda_vpc,
    aws_iam_role_policy_attachment.secret_rotation_lambda_access,
    aws_iam_role_policy_attachment.secret_rotation_lambda_dlq,
  ]

  tags = local.tags
}

resource "aws_secretsmanager_secret_rotation" "prometheus_token" {
  secret_id           = aws_secretsmanager_secret.prometheus_token.id
  rotation_lambda_arn = aws_lambda_function.secret_rotation.arn

  rotation_rules {
    automatically_after_days = 30
  }
}

resource "aws_lambda_permission" "allow_secrets_manager" {
  statement_id   = "AllowExecutionFromSecretsManager"
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.secret_rotation.function_name
  principal      = "secretsmanager.amazonaws.com"
  source_account = data.aws_caller_identity.current.account_id
  source_arn     = aws_secretsmanager_secret.prometheus_token.arn
}

data "aws_eks_cluster" "this" {
  name = module.eks.cluster_name

  depends_on = [module.eks]
}

data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_name

  depends_on = [module.eks]
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.this.token
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.this.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

data "aws_iam_policy_document" "external_secrets_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:${var.external_secrets_namespace}:external-secrets"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "external_secrets" {
  name               = "${var.project_name}-external-secrets"
  assume_role_policy = data.aws_iam_policy_document.external_secrets_assume_role.json

  tags = local.tags
}

data "aws_iam_policy_document" "external_secrets_access" {
  statement {
    actions = [
      "secretsmanager:DescribeSecret",
      "secretsmanager:GetSecretValue",
      "secretsmanager:ListSecretVersionIds",
    ]
    resources = [aws_secretsmanager_secret.prometheus_token.arn]
  }
}

resource "aws_iam_policy" "external_secrets_access" {
  name        = "${var.project_name}-external-secrets-access"
  description = "Allows External Secrets Operator to read runtime secrets from AWS Secrets Manager"
  policy      = data.aws_iam_policy_document.external_secrets_access.json

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "external_secrets_access" {
  role       = aws_iam_role.external_secrets.name
  policy_arn = aws_iam_policy.external_secrets_access.arn
}

resource "helm_release" "external_secrets" {
  count            = var.enable_external_secrets_helm ? 1 : 0
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  version          = var.external_secrets_chart_version
  namespace        = var.external_secrets_namespace
  create_namespace = true

  set {
    name  = "installCRDs"
    value = "true"
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "external-secrets"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.external_secrets.arn
  }

  set {
    name  = "webhook.create"
    value = "false"
  }

  set {
    name  = "certController.create"
    value = "false"
  }

  depends_on = [
    module.eks,
    aws_iam_role_policy_attachment.external_secrets_access,
  ]
}
