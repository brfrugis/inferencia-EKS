# inferencia-EKS

Infraestrutura como código e manifests Kubernetes para servir modelos LLM (Llama 3, Mistral, etc.) no **Amazon EKS**, com **vLLM** (PagedAttention e continuous batching via motor padrão), **Karpenter** (nós GPU P7/P5/P4 e inf2), **KEDA** (escala por métricas Prometheus da fila), observabilidade com **OpenTelemetry Collector** e exportação **OTLP** para **Coralogix**.

A **execução operacional** (validação Terraform, plan, apply, deploy Kubernetes, benchmarks) está feita em **GitHub Actions**; não há scripts `.sh` no repositório.

## Esclarecimento: armazenamento de modelos (S3 vs EBS)

- **O Amazon EBS não é montado pelo driver CSI do S3.** São integrações distintas: **EBS CSI** para volumes de bloco por AZ, e **Mountpoint for Amazon S3 CSI** para montar um **bucket S3** como sistema de ficheiros nos pods.
- Este projeto usa o **Mountpoint for Amazon S3** para um **caminho partilhado** (`ReadWriteMany` lógico) com os pesos dos modelos, reutilizável por todos os pods de inferência, com credenciais por **IRSA** na `ServiceAccount` `inferencia/vllm`.
- O addon **aws-ebs-csi-driver** continua disponível no cluster para PVCs EBS quando precisar de volumes de bloco (cache local, discos dedicados, etc.).

## Estrutura

| Pasta | Conteúdo |
|-------|-----------|
| `terraform/` | VPC, EKS, bucket S3 de modelos, IRSA (vLLM, OTel, EBS CSI), módulo Karpenter (fila de interrupção, role de nós), Helm: Karpenter, Secret Store CSI (+ provider AWS), Mountpoint S3 CSI, KEDA. |
| `k8s/` | Namespaces, vLLM (GPU + template Neuron), Karpenter `NodePool`/`EC2NodeClass`, KEDA `ScaledObject`, Prometheus mínimo para o KEDA, NVIDIA device plugin, manifests do OTel + `kustomization` que referencia `otel/config.yaml`. |
| `otel/config.yaml` | Pipelines OTLP + scrape Prometheus do `/metrics` do vLLM, processadores `k8sattributes`, `resourcedetection` (ec2), `resource` (região e nome do cluster via placeholders substituídos no deploy). |
| `.github/workflows/` | CI/CD: Terraform validate/plan/apply, deploy Kubernetes, benchmarks vLLM. |
| `.github/DEPLOYMENT.md` | Segredos OIDC, variáveis de repositório e ambientes GitHub necessários. |

## GitHub Actions (visão geral)

1. Configure **OIDC na AWS** e o segredo `AWS_ROLE_ARN`, e as **variáveis de repositório** descritas em [`.github/DEPLOYMENT.md`](.github/DEPLOYMENT.md).
2. Crie o ambiente **`production`** no GitHub (Settings → Environments) se quiser aprovações manuais antes de apply/deploy.
3. Fluxos disponíveis:

| Workflow | Quando corre | O quê |
|----------|----------------|--------|
| [`terraform-validate.yml`](.github/workflows/terraform-validate.yml) | PR com alterações em `terraform/**` | `fmt -check`, `init -backend=false`, `validate`. |
| [`terraform-plan.yml`](.github/workflows/terraform-plan.yml) | PR com alterações em `terraform/**` | `terraform plan` com bucket placeholder (não é o bucket de produção). |
| [`terraform-apply.yml`](.github/workflows/terraform-apply.yml) | `workflow_dispatch` | `terraform apply` (requer **backend remoto** no código Terraform para estado persistente). |
| [`kubernetes-deploy.yml`](.github/workflows/kubernetes-deploy.yml) | `workflow_dispatch` | Substitui `REPLACE_*`, corre `kubectl apply` no EKS. |
| [`vllm-benchmarks.yml`](.github/workflows/vllm-benchmarks.yml) | `workflow_dispatch` | Latência (`curl` + `jq`) e carga (`hey`); o URL tem de ser acessível a partir dos runners GitHub (Internet ou runner self-hosted). |

**Estado Terraform em CI:** o runner é efémero. Para `terraform apply` na Actions, configure um backend remoto (por exemplo S3 + tabela DynamoDB para lock) no diretório `terraform/`.

## Pré-requisitos (conta e cluster)

- Conta AWS com quotas para **p7d/p5/p4** e **inf2** na região escolhida.
- Imagem `vllm/vllm-openai` compatível com a sua GPU e modelo; para **inf2** é necessária imagem própria com vLLM+Neuron (`k8s/inferencia/deployment-vllm-neuron.yaml`).

## Quotas e limites na AWS (Service Quotas)

No console **Service Quotas** (ou API `service-quotas`), verifique e solicite aumento onde aplicável:

- **EC2**: `Running On-Demand P instances`, `Running On-Demand Inf instances` (ou equivalentes por família **p7d**, **p5**, **p4d**, **inf2**).
- **EC2**: `All Standard (HDD or SSD) EBS volumes` e **IOPS** se usar discos grandes nos `EC2NodeClass`.
- **EKS**, **NAT Gateways**, **Elastic IPs** conforme a topologia de rede.
- **S3**: pedidos por segundo à medida que o tráfego de leitura dos pesos crescer.

## Segredo Coralogix (Secrets Manager)

Crie um segredo no **AWS Secrets Manager** com a chave **`private_key`** (ingestão Coralogix), por exemplo:

```json
{
  "private_key": "cgprt_xxxxxxxx"
}
```

Defina `coralogix_secret_arn` no Terraform (`terraform/terraform.tfvars.example`) para criar a IRSA `observability/otel-collector`. A variável de repositório `CORALOGIX_SECRET_ARN` no workflow de Kubernetes deve apontar para o mesmo ARN.

O host OTLP (`CORALOGIX_OTLP_HOST`, por exemplo `ingress.coralogix.us:443`) depende da região/domínio da sua conta Coralogix.

## Após Terraform apply (dados para variáveis GitHub)

Após o primeiro `terraform apply` (local ou via Actions com backend remoto), preencha as variáveis de repositório com os outputs: `karpenter_node_iam_role_name`, `vllm_irsa_role_arn`, `otel_irsa_role_arn`, `model_bucket_name`, etc. (ver [`.github/DEPLOYMENT.md`](.github/DEPLOYMENT.md)).

Carregue os pesos do modelo para o bucket S3 (prefixo alinhado com `MODEL_DIR`).

## Variáveis de tracing no vLLM

O deployment define `OTEL_EXPORTER_OTLP_ENDPOINT` para `otel-collector.observability.svc.cluster.local:4317` (gRPC). Ajuste conforme a versão do vLLM e a documentação oficial de OpenTelemetry.

## KEDA: fila e latência

- O `ScaledObject` em `k8s/keda/scaledobject-vllm.yaml` usa **Prometheus** com `vllm_num_requests_waiting` (valide o nome em `/metrics` na sua versão).
- Para latência, pode acrescentar outro trigger `prometheus` após confirmar histogramas no Prometheus interno.

## Referências úteis

- [Karpenter](https://karpenter.sh/docs/)
- [KEDA Prometheus scaler](https://keda.sh/docs/latest/scalers/prometheus/)
- [Mountpoint S3 CSI](https://github.com/awslabs/mountpoint-s3-csi-driver)
- [Secrets Store CSI Driver](https://secrets-store-csi-driver.sigs.k8s.io/)
- [vLLM](https://docs.vllm.ai/)
- [GitHub Actions OIDC com AWS](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)

## Licença

O código de infraestrutura deste repositório segue a licença do projeto raiz; componentes externos (imagens, charts) mantêm as respetivas licenças.
