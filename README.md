# Arquitetura Zero-ETL AWS

Projeto de Modern Data Stack na AWS com integracao Zero-ETL, orquestracao com Airflow, transformacoes com DBT e analise com Metabase.

## Visao Geral

```
+-------------------------------------------------------------+
|                      AWS Cloud                               |
|                                                              |
|  S3 (Raw) -> RDS Aurora -> Zero-ETL -> Redshift             |
|                                                              |
|  MWAA (Airflow) -> DBT -> Transformacoes                    |
|                                                              |
|  Metabase -> Dashboards & Analytics                         |
+-------------------------------------------------------------+
```

## Componentes Principais

| Componente | Funcao |
|-----------|--------|
| RDS Aurora PostgreSQL | Banco transacional |
| Amazon Redshift | Data Warehouse |
| Zero-ETL | Replicacao em tempo real |
| MWAA (Airflow) | Orquestracao de pipelines |
| DBT | Transformacoes de dados |
| Metabase | Visualizacao e analise |
| S3 | Data Lake |
| Terraform | Infrastructure as Code |

## Quick Start

### Pre-requisitos
- Conta AWS com permissoes de administrador
- Terraform >= 1.0
- Python >= 3.8
- AWS CLI configurado
- Git

### 1. Clone o repositorio
```bash
git clone https://github.com/seu-usuario/arquitetura-zero-etl-aws.git
cd arquitetura-zero-etl-aws
```

### 2. Configure as variaveis
```bash
cd terraform/infra
cp envs/develop.tfvars.example envs/develop.tfvars
# Edite com seus valores
```

### 3. Crie o bucket S3 para o Terraform State
```bash
# O bucket do backend S3 precisa existir ANTES do terraform init
# Isso e necessario porque o Terraform precisa do bucket para armazenar o state
# antes de criar qualquer recurso (problema "ovo e galinha")
aws s3 mb s3://terraform-state-data-handson-mds-dev --region us-east-1
```

### 4. Provisione a infraestrutura
```bash
terraform init -backend-config="backends/develop.hcl"
terraform plan -var-file=envs/develop.tfvars
terraform apply -var-file=envs/develop.tfvars
```

### 5. Executar scripts no EC2 via SSM

O RDS esta em subnet privada, entao os scripts devem ser executados a partir do EC2.

```bash
# 1. Obter o ID da instancia EC2
# - describe-instances: lista instancias EC2
# - filters: filtra por nome da tag e estado "running"
# - query: extrai apenas o InstanceId do JSON de resposta
# - output text: retorna texto puro (sem aspas)
INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=data-handson-mds-ec2-dev" "Name=instance-state-name,Values=running" \
  --query 'Reservations[0].Instances[0].InstanceId' \
  --output text \
  --profile zero-etl-project)

# 2. Converter o script local para base64
# - cat: le o conteudo do arquivo
# - base64 -w 0: codifica em base64 sem quebras de linha
# Isso permite enviar o script como string via SSM
SCRIPT_CONTENT=$(cat code/insert_data_postgres/test_connection.py | base64 -w 0)

# 3. Enviar e executar o script no EC2 via SSM
# - send-command: envia comando para execucao remota
# - instance-ids: ID da instancia EC2 destino
# - document-name: AWS-RunShellScript permite executar comandos shell
# - parameters commands: lista de comandos a executar
#   - echo '$SCRIPT_CONTENT' | base64 -d: decodifica o base64
#   - > /tmp/script.py: salva o script no EC2
#   - python3 /tmp/script.py: executa o script
# - query Command.CommandId: retorna o ID do comando para consultar depois
aws ssm send-command \
  --instance-ids "$INSTANCE_ID" \
  --document-name "AWS-RunShellScript" \
  --parameters "commands=[\"echo '$SCRIPT_CONTENT' | base64 -d > /tmp/script.py && python3 /tmp/script.py\"]" \
  --profile zero-etl-project \
  --region us-east-1 \
  --query 'Command.CommandId' \
  --output text

# 4. Verificar resultado da execucao
# - get-command-invocation: consulta o resultado de um comando enviado
# - command-id: ID retornado pelo send-command
# - instance-id: instancia onde o comando foi executado
# - query StandardOutputContent: retorna apenas o stdout do comando
# Substitua COMMAND_ID pelo valor retornado no passo anterior
aws ssm get-command-invocation \
  --command-id "COMMAND_ID" \
  --instance-id "$INSTANCE_ID" \
  --profile zero-etl-project \
  --region us-east-1 \
  --query 'StandardOutputContent' \
  --output text
```

Ou conecte interativamente via SSM:
```bash
# start-session: abre um terminal interativo no EC2
# Nao precisa de SSH, chave privada ou porta 22 aberta
# Usa o SSM Agent instalado na instancia
aws ssm start-session --target $INSTANCE_ID --profile zero-etl-project --region us-east-1
```

### 6. Acesse os servicos
- Metabase: http://localhost:3000
- Airflow (MWAA): AWS Console -> MWAA
- Redshift: AWS Console -> Redshift

---

## Estrutura do Projeto

```
arquitetura-zero-etl-aws/
|
+-- README.md
+-- .gitignore
|
+-- terraform/
|   +-- infra/
|       +-- main.tf
|       +-- variables.tf
|       +-- terraform.tf
|       +-- backends/
|       +-- envs/
|       +-- modules/
|           +-- vpc/
|           +-- rds/
|           +-- redshift/
|           +-- s3/
|           +-- mwaa/
|           +-- ec2/
|
+-- code/
|   +-- dbt/
|   |   +-- airflow_dags/
|   |   +-- movielens_redshift/
|   +-- insert_data_postgres/
|       +-- script-python-insert-csv-postgres.py
|       +-- test_connection.py
|       +-- create_database.py
|       +-- upload_to_s3.py
|
+-- data/
|   +-- ml-latest-small/
|       +-- ratings.csv
|       +-- tags.csv
|       +-- movies.csv
|       +-- links.csv
|
+-- metabase/
    +-- docker-compose.yml
```

---

## Configuracao Detalhada

### Terraform
```bash
cd terraform/infra

# Inicializar
terraform init -backend-config="backends/develop.hcl"

# Planejar
terraform plan -var-file=envs/develop.tfvars

# Aplicar
terraform apply -var-file=envs/develop.tfvars

# Destruir
terraform destroy -var-file=envs/develop.tfvars
```

### DBT
```bash
cd code/dbt/movielens_redshift

# Instalar dependencias
dbt deps

# Executar modelos
dbt run

# Executar testes
dbt test

# Gerar documentacao
dbt docs generate
```

### Airflow (MWAA)
- Acesse via AWS Console
- DAGs estao em code/dbt/airflow_dags/
- Configuracao em code/dbt/airflow_dags/requirements.txt

### Metabase
```bash
cd metabase

# Iniciar
docker-compose up -d

# Parar
docker-compose down

# Logs
docker-compose logs -f metabase
```

## Dataset

Usando MovieLens Small Dataset:
- 100,000 ratings
- 3,600 movies
- 6,000 users
- 13,000 tags

## Seguranca

Implementado:
- Senhas geradas aleatoriamente
- Credenciais no AWS Secrets Manager
- Encryption em repouso (Redshift)
- .gitignore para arquivos sensiveis

Recomendacoes para producao:
- Mover RDS/Redshift para subnets privadas
- Usar VPC Endpoints
- Implementar Bastion Host
- Adicionar CloudTrail e CloudWatch
- Configurar MFA

## Documentacao

- AWS RDS: https://docs.aws.amazon.com/rds/
- Amazon Redshift: https://docs.aws.amazon.com/redshift/
- AWS MWAA: https://docs.aws.amazon.com/mwaa/
- DBT Documentation: https://docs.getdbt.com/
- Terraform AWS Provider: https://registry.terraform.io/providers/hashicorp/aws/latest/docs
