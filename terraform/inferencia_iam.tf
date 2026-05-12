variable "coralogix_secret_arn" {
  description = "ARN do segredo no AWS Secrets Manager com a private key da Coralogix (opcional; se vazio, o IRSA do OTel não é criado)."
  type        = string
  default     = ""
}

resource "aws_iam_policy" "vllm_model_bucket_read" {
  name_prefix = "${var.cluster_name}-vllm-s3-"
  description = "Leitura do bucket de modelos para o Mountpoint S3 / cache."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ListBucket"
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = aws_s3_bucket.models.arn
      },
      {
        Sid    = "GetObjects"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion"
        ]
        Resource = "${aws_s3_bucket.models.arn}/*"
      }
    ]
  })

  tags = var.tags
}

module "vllm_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.39"

  role_name = "${var.cluster_name}-vllm"

  role_policy_arns = {
    models = aws_iam_policy.vllm_model_bucket_read.arn
  }

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["inferencia:vllm"]
    }
  }

  tags = var.tags
}

resource "aws_iam_policy" "otel_secrets_read" {
  count = var.coralogix_secret_arn != "" ? 1 : 0

  name_prefix = "${var.cluster_name}-otel-sm-"
  description = "Leitura do segredo Coralogix para o Secret Store CSI."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = var.coralogix_secret_arn
      }
    ]
  })

  tags = var.tags
}

module "otel_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.39"

  count = var.coralogix_secret_arn != "" ? 1 : 0

  role_name = "${var.cluster_name}-otel"

  role_policy_arns = {
    coralogix = aws_iam_policy.otel_secrets_read[0].arn
  }

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["observability:otel-collector"]
    }
  }

  tags = var.tags
}
