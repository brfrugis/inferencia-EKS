# GitHub Actions — variáveis e segredos

Toda a execução (Terraform, render/aplicação de manifests, benchmarks) corre em **GitHub Actions**. Não são usados scripts `.sh` no repositório.

## Segredos (Settings → Secrets and variables → Actions → Secrets)

| Nome | Uso |
|------|-----|
| `AWS_ROLE_ARN` | ARN da role IAM para [OIDC](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services) (`sts:AssumeRoleWithWebIdentity` a partir do GitHub). A role deve permitir `eks:DescribeCluster`, `eks:ListClusters`, credenciais para Terraform na conta alvo, e políticas equivalentes às que usa o seu utilizador local. |

## Variáveis de repositório (Actions → Variables)

Usadas pelo workflow **Kubernetes deploy** e, quando indicado, pelo **Terraform apply**.

| Nome | Exemplo | Descrição |
|------|---------|-----------|
| `AWS_REGION` | `us-east-1` | Região do cluster e da API AWS. |
| `CLUSTER_NAME` | `inferencia-eks` | Nome do cluster EKS. |
| `KARPENTER_NODE_IAM_ROLE_NAME` | *(output Terraform `karpenter_node_iam_role_name`)* | Valor do campo `spec.role` nos `EC2NodeClass`. |
| `VLLM_IRSA_ROLE_ARN` | *(output `vllm_irsa_role_arn`)* | Anotação IRSA da `ServiceAccount` `inferencia/vllm`. |
| `OTEL_IRSA_ROLE_ARN` | *(output `otel_irsa_role_arn`)* | Anotação IRSA da `ServiceAccount` `observability/otel-collector`. |
| `MODEL_BUCKET` | *(output `model_bucket_name`)* | Nome do bucket S3 dos modelos (Mountpoint). |
| `MODEL_DIR` | `Meta-Llama-3-8B-Instruct` | Pasta sob `/models` no mount (alinhada ao prefixo no S3). |
| `CORALOGIX_SECRET_ARN` | `arn:aws:secretsmanager:...:secret:...` | ARN do segredo com chave JSON `private_key`. |
| `CORALOGIX_OTLP_HOST` | `ingress.coralogix.us:443` | Host:porta OTLP gRPC para a Coralogix. |

## Variáveis para Terraform apply (opcional)

O workflow **Terraform apply** usa, quando definidas:

| Nome | Mapeamento Terraform |
|------|----------------------|
| `TF_MODEL_BUCKET_NAME` | `TF_VAR_model_bucket_name` |
| `TF_CORALOGIX_SECRET_ARN` | `TF_VAR_coralogix_secret_arn` (opcional; pode ficar vazio) |

Se `TF_MODEL_BUCKET_NAME` não estiver definida, o job de apply falha na validação — defina-a antes de correr o apply na Actions.

## Ficheiro de confiança OIDC na AWS (resumo)

1. Criar um provedor OIDC `token.actions.githubusercontent.com` (se ainda não existir).
2. Criar uma role IAM com política de confiança que restrinja `StringEquals` / `StringLike` a `repo:ORG/REPO:ref:refs/heads/main` (ou o ramo que usar para apply).
3. Anexar políticas para Terraform (VPC, EKS, IAM, S3, etc.) e para `eks:DescribeCluster` / atualização de kubeconfig.

## Workflows disponíveis

| Ficheiro | Gatilho | Função |
|----------|---------|--------|
| `terraform-validate.yml` | `pull_request` (alterações em `terraform/**`) | `terraform fmt -check`, `init -backend=false`, `validate`. |
| `terraform-plan.yml` | `pull_request` | `plan` com bucket placeholder (sem alterar a sua infra). |
| `terraform-apply.yml` | `workflow_dispatch` | `terraform apply -auto-approve` (requer backend remoto configurado no código Terraform para estado partilhado). |
| `kubernetes-deploy.yml` | `workflow_dispatch` | Render `REPLACE_*` + `kubectl apply` (EKS via OIDC). |
| `vllm-benchmarks.yml` | `workflow_dispatch` | Carga com `hey` + medição de latência com `curl`/`jq`. |

**Nota sobre estado Terraform:** em CI o diretório de trabalho é efémero. Para `terraform apply` na Actions configure um **backend remoto** (por exemplo S3 + DynamoDB lock) em `terraform/backend.tf` (não incluído por defeito) ou use Terraform Cloud.
