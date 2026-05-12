# Diagramas

## Fontes Mermaid (`.mmd`)

| Ficheiro | Conteúdo |
|----------|-----------|
| **`arquitetura-inferencia-eks.mmd`** | Visão global: GitHub Actions, AWS (VPC, EKS, IAM, S3, Secrets Manager), Karpenter, namespaces Kubernetes, vLLM, KEDA, Prometheus, OpenTelemetry, Coralogix. |
| **`pipeline-opentelemetry.mmd`** | Diagrama de sequência: cliente, vLLM, S3, collector, Prometheus, KEDA, Secrets Manager, Coralogix. |

## Imagens PNG (exportadas)

O `README.md` na raiz usa **PNG** (melhor pré-visualização no GitHub que JPEG):

| Origem `.mmd` | Ficheiro PNG no repositório |
|---------------|-----------------------------|
| `arquitetura-inferencia-eks.mmd` | **`general_diagram.png`** |
| `pipeline-opentelemetry.mmd` | **`pipeline-opentelemetry.png`** |

Para regenerar: abra o `.mmd` no [Mermaid Live Editor](https://mermaid.live) (ou use a extensão Mermaid / `@mermaid-js/mermaid-cli`) e exporte como **PNG**, substituindo estes ficheiros com os mesmos nomes.
