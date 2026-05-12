variable "aws_region" {
  description = "Região AWS do cluster EKS."
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Nome lógico do cluster EKS (usado em tags Karpenter e outputs)."
  type        = string
  default     = "inferencia-eks"
}

variable "cluster_version" {
  description = "Versão do Kubernetes no control plane."
  type        = string
  default     = "1.31"
}

variable "vpc_cidr" {
  description = "CIDR da VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "model_bucket_name" {
  description = "Nome do bucket S3 com pesos dos modelos (deve ser globalmente único)."
  type        = string
}

variable "tags" {
  description = "Tags padrão aplicadas aos recursos."
  type        = map(string)
  default     = {}
}

variable "karpenter_version" {
  description = "Versão do chart Helm do Karpenter (OCI)."
  type        = string
  default     = "1.0.8"
}

variable "keda_version" {
  description = "Versão do chart Helm do KEDA."
  type        = string
  default     = "2.16.1"
}

variable "secrets_store_csi_version" {
  description = "Versão do chart secrets-store-csi-driver."
  type        = string
  default     = "1.4.7"
}

variable "mountpoint_s3_csi_version" {
  description = "Versão do chart aws-mountpoint-s3-csi-driver."
  type        = string
  default     = "1.11.0"
}
