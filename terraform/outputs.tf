output "cluster_name" {
  description = "Nome do cluster EKS."
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint da API do Kubernetes."
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "CA do cluster (base64)."
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "configure_kubectl" {
  description = "Comando para configurar kubeconfig local."
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "private_subnet_ids" {
  value = module.vpc.private_subnets
}

output "model_bucket_name" {
  description = "Bucket S3 criado para armazenar / servir modelos via Mountpoint."
  value       = aws_s3_bucket.models.bucket
}

output "model_bucket_arn" {
  value = aws_s3_bucket.models.arn
}

output "karpenter_node_iam_role_name" {
  description = "Nome da IAM role dos nós do Karpenter (use no EC2NodeClass .spec.role)."
  value       = module.karpenter.node_iam_role_name
}

output "karpenter_controller_iam_role_arn" {
  description = "ARN da role IRSA do controlador Karpenter."
  value       = module.karpenter.iam_role_arn
}

output "karpenter_interruption_queue_name" {
  value = module.karpenter.queue_name
}

output "vllm_irsa_role_arn" {
  description = "ARN da role IRSA da ServiceAccount inferencia/vllm (S3 modelos)."
  value       = module.vllm_irsa.iam_role_arn
}

output "otel_irsa_role_arn" {
  description = "ARN da role IRSA da ServiceAccount observability/otel-collector (Secrets Manager)."
  value       = try(module.otel_irsa[0].iam_role_arn, null)
}
