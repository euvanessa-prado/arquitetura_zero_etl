# 🏗️ Terraform - Infraestrutura AWS

Este guia explica como provisionar toda a infraestrutura do projeto usando Terraform.

## 📋 Pré-requisitos

1. **Terraform** >= 1.0 instalado
2. **AWS CLI** configurado com profile `zero-etl-project`
3. **Permissões AWS** para criar: VPC, RDS, Redshift, S3, EC2, MWAA, IAM

## 🗂️ Estrutura

```
terraform/infra/
├── main.tf              # Recursos principais
├── variables.tf         # Variáveis do projeto
├── terraform.tf         # Configuração do provider
├── backends/            # Configuração do state remoto
│   └── develop.hcl
├── envs/                # Variáveis por ambiente
│   └── develop.tfvars
├── modules/             # Módulos reutilizáveis
│   ├── vpc/             # VPC, Subnets, NAT Gateway
│   ├── rds/             # Aurora PostgreSQL
│   ├── redshift/        # Cluster Redshift
│   ├── s3/              # Buckets S3
│   ├── ec2/             # Instância EC2
│   └── mwaa/            # Airflow gerenciado
└── scripts/             # Scripts de bootstrap
```

## 🚀 Passo a Passo

### 1. Criar o bucket para Terraform State

O Terraform precisa de um bucket S3 para armazenar o state **antes** de criar os recursos.

```bash
aws s3 mb s3://terraform-state-data-handson-mds-dev --region us-east-1 --profile zero-etl-project
```

### 2. Configurar as variáveis

Edite o arquivo `envs/develop.tfvars` com seus valores:

```hcl
environment       = "dev"
region            = "us-east-1"
project_name      = "data-handson-mds"
s3_bucket_raw     = "data-handson-mds-raw-dev"
s3_bucket_scripts = "data-handson-mds-scripts-dev"
s3_bucket_curated = "data-handson-mds-curated-dev"
```

### 3. Inicializar o Terraform

```bash
cd terraform/infra
terraform init -backend-config="backends/develop.hcl"
```

### 4. Visualizar o plano

```bash
terraform plan -var-file=envs/develop.tfvars
```

### 5. Aplicar a infraestrutura

```bash
terraform apply -var-file=envs/develop.tfvars
```

Digite `yes` quando solicitado.

### 6. Destruir a infraestrutura (quando necessário)

```bash
terraform destroy -var-file=envs/develop.tfvars
```

## 📦 Módulos

### VPC
- CIDR: `10.0.0.0/16`
- 2 Subnets públicas: `10.0.1.0/24`, `10.0.2.0/24`
- 2 Subnets privadas: `10.0.3.0/24`, `10.0.4.0/24`
- NAT Gateway para acesso à internet das subnets privadas
- Internet Gateway para subnets públicas

### RDS (Aurora PostgreSQL)
- Engine: Aurora PostgreSQL 16.4
- Instance: `db.t4g.large`
- Database: `transactional`
- Schema: `movielens_database`
- Credenciais: AWS Secrets Manager

### Redshift
- Cluster: `data-handson-mds`
- Node Type: `ra3.large`
- Nodes: 1 (single-node)
- Database: `datahandsonmds`
- Credenciais: AWS Secrets Manager

### S3
- `data-handson-mds-raw-dev` - Dados brutos (CSVs)
- `data-handson-mds-scripts-dev` - Scripts Python
- `data-handson-mds-curated-dev` - Dados processados
- `data-handson-mds-mwaa-dev` - DAGs do Airflow

### EC2
- AMI: Ubuntu
- Instance Type: `t3a.2xlarge`
- Acesso via SSM (sem SSH)
- IAM Role com permissões para S3 e Secrets Manager

### MWAA (Airflow)
- Versão: 2.10.3
- Environment Class: `mw1.small`
- Workers: 1-2
- Acesso: PUBLIC_ONLY

## ⚙️ Variáveis

| Variável | Descrição | Default |
|----------|-----------|---------|
| `environment` | Ambiente (dev, staging, prod) | `dev` |
| `region` | Região AWS | `us-east-1` |
| `project_name` | Nome do projeto | `data-handson-mds` |
| `s3_bucket_raw` | Bucket para dados brutos | - |
| `s3_bucket_scripts` | Bucket para scripts | - |
| `s3_bucket_curated` | Bucket para dados processados | - |

## 🔐 Segurança

- RDS e Redshift em **subnets privadas**
- EC2 em subnet pública com acesso via **SSM** (sem SSH)
- Credenciais no **AWS Secrets Manager**
- Security Groups restritivos
- Tags padrão em todos os recursos

## 💰 Custos Estimados

| Recurso | Tipo | Custo/hora |
|---------|------|------------|
| Aurora | db.t4g.large | ~$0.12 |
| Redshift | ra3.large | ~$0.36 |
| EC2 | t3a.2xlarge | ~$0.30 |
| NAT Gateway | - | ~$0.045 |
| MWAA | mw1.small | ~$0.49 |

**Total estimado**: ~$1.30/hora (~$31/dia)

> ⚠️ Lembre-se de destruir os recursos quando não estiver usando!

## 🐛 Troubleshooting

### Erro: "Bucket não existe"
O bucket do state precisa existir antes do `terraform init`:
```bash
aws s3 mb s3://terraform-state-data-handson-mds-dev --region us-east-1
```

### Erro: "Access Denied"
Verifique se o profile AWS está configurado:
```bash
aws sts get-caller-identity --profile zero-etl-project
```

### Erro: "Resource already exists"
Importe o recurso existente:
```bash
terraform import module.s3.aws_s3_bucket.raw data-handson-mds-raw-dev
```

### Erro ao destruir MWAA
O MWAA pode demorar até 30 minutos para ser destruído. Se ficar travado em UPDATING, abra um ticket no AWS Support.

## 📚 Referências

- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS VPC](https://docs.aws.amazon.com/vpc/)
- [Aurora PostgreSQL](https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/)
- [Amazon Redshift](https://docs.aws.amazon.com/redshift/)
- [MWAA](https://docs.aws.amazon.com/mwaa/)
