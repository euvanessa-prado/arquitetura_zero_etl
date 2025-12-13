# ETL - Inserção de Dados no PostgreSQL Aurora

Este diretório contém scripts para fazer upload dos dados MovieLens para S3 e inserir no PostgreSQL Aurora.

## Arquitetura

Os dados seguem o seguinte fluxo:

1. Arquivos CSV locais (MovieLens)
2. Amazon S3 (data-handson-mds-raw-dev)
3. EC2 (execução via AWS Systems Manager)
4. Aurora PostgreSQL (banco transactional)
5. Schema movielens_database

## Pré-requisitos

- AWS CLI configurado com profile zero-etl-project
- Acesso ao AWS Secrets Manager para credenciais do Aurora
- EC2 com SSM Agent habilitado
- Python 3.8 ou superior
- Dependências: boto3, pandas, sqlalchemy, psycopg2-binary

## Scripts Disponíveis

### upload_to_s3.py

Realiza o upload dos arquivos CSV do MovieLens para o Amazon S3.

Execução:
```bash
python upload_to_s3.py
```

Funcionalidade:
- Lê arquivos CSV de data/ml-latest-small/
- Faz upload para s3://data-handson-mds-raw-dev/movielens/
- Organiza arquivos por tipo: ratings, tags, movies, links

### insert_postgres_simple.py

Insere os dados do S3 no Aurora PostgreSQL. Este script deve ser executado na EC2 via AWS Systems Manager, pois o banco está em subnet privada.

Execução via EC2:
```bash
aws s3 cp insert_postgres_simple.py s3://data-handson-mds-scripts-dev/ --profile zero-etl-project

aws ssm send-command \
  --profile zero-etl-project \
  --region us-east-1 \
  --instance-ids i-0b84eb1b7f2825d46 \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=[
    "/tmp/venv/bin/python -m boto3",
    "python3 -c \"import boto3; s3=boto3.client('"'"'s3'"'"'); s3.download_file('"'"'data-handson-mds-scripts-dev'"'"', '"'"'insert_postgres_simple.py'"'"', '"'"'/tmp/insert.py'"'"')\"",
    "/tmp/venv/bin/python /tmp/insert.py"
  ]' \
  --query 'Command.CommandId' \
  --output text
```

Funcionalidade:
- Conecta ao Aurora usando credenciais do Secrets Manager
- Cria schema movielens_database
- Baixa arquivos CSV do S3
- Insere dados nas tabelas
- Adiciona primary keys (necessário para Zero-ETL)

### test_connection.py

Valida a conectividade com o Aurora PostgreSQL.

Execução via EC2:
```bash
aws s3 cp test_connection.py s3://data-handson-mds-scripts-dev/ --profile zero-etl-project

aws ssm send-command \
  --profile zero-etl-project \
  --region us-east-1 \
  --instance-ids i-0b84eb1b7f2825d46 \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=[
    "python3 -c \"import boto3; s3=boto3.client('"'"'s3'"'"'); s3.download_file('"'"'data-handson-mds-scripts-dev'"'"', '"'"'test_connection.py'"'"', '"'"'/tmp/test.py'"'"')\"",
    "/tmp/venv/bin/python /tmp/test.py"
  ]' \
  --query 'Command.CommandId' \
  --output text
```

### script-python-insert-csv-postgres.py

Script original com validações adicionais. Oferece mais controle sobre o processo de inserção.

## Procedimento Completo

Passo 1: Upload para S3
```bash
python upload_to_s3.py
```

Passo 2: Preparar EC2 (executar uma única vez)
```bash
aws ssm send-command \
  --profile zero-etl-project \
  --region us-east-1 \
  --instance-ids i-0b84eb1b7f2825d46 \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=[
    "apt-get update",
    "apt-get install -y python3.12-venv",
    "python3 -m venv /tmp/venv",
    "/tmp/venv/bin/pip install boto3 pandas sqlalchemy psycopg2-binary"
  ]'
```

Passo 3: Inserir dados no Aurora
```bash
aws s3 cp insert_postgres_simple.py s3://data-handson-mds-scripts-dev/ --profile zero-etl-project

aws ssm send-command \
  --profile zero-etl-project \
  --region us-east-1 \
  --instance-ids i-0b84eb1b7f2825d46 \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=[
    "python3 -c \"import boto3; s3=boto3.client('"'"'s3'"'"'); s3.download_file('"'"'data-handson-mds-scripts-dev'"'"', '"'"'insert_postgres_simple.py'"'"', '"'"'/tmp/insert.py'"'"')\"",
    "/tmp/venv/bin/python /tmp/insert.py"
  ]'
```

## Configuração do Banco de Dados

Aurora PostgreSQL

- Host: transactional.cluster-c29gca8kizzb.us-east-1.rds.amazonaws.com
- Port: 5432
- Database: transactional
- Schema: movielens_database
- User: datahandsonmds
- Credenciais: Armazenadas no AWS Secrets Manager

Tabelas Criadas

- ratings: 100,836 registros
- tags: 3,683 registros
- movies: 9,742 registros
- links: 9,742 registros

Primary Keys

```sql
ALTER TABLE movielens_database.ratings ADD PRIMARY KEY ("userId", "movieId", "timestamp");
ALTER TABLE movielens_database.tags ADD PRIMARY KEY ("userId", "movieId", "tag");
ALTER TABLE movielens_database.movies ADD PRIMARY KEY ("movieId");
ALTER TABLE movielens_database.links ADD PRIMARY KEY ("movieId");
```

## Conexão ao Aurora

Via psql

```bash
aws secretsmanager get-secret-value \
  --secret-id datahandsonmds-database-dev \
  --profile zero-etl-project \
  --query 'SecretString' \
  --output text | jq -r 'to_entries[] | "\(.key)=\(.value)"'

psql -h transactional.cluster-c29gca8kizzb.us-east-1.rds.amazonaws.com \
     -U datahandsonmds \
     -d transactional \
     -p 5432
```

Via Python

```python
import json
import boto3
from sqlalchemy import create_engine

secrets = boto3.client('secretsmanager', region_name='us-east-1')
response = secrets.get_secret_value(SecretId='datahandsonmds-database-dev')
creds = json.loads(response['SecretString'])

conn_str = f"postgresql://{creds['username']}:{creds['password']}@{creds['host']}:{creds['port']}/transactional"
engine = create_engine(conn_str)

with engine.connect() as conn:
    result = conn.execute("SELECT * FROM movielens_database.movies LIMIT 5")
    for row in result:
        print(row)
```

## Próximas Etapas

1. Criar database no Redshift:
```sql
CREATE DATABASE analytics_movie_insights;
```

2. Configurar Zero-ETL para replicação de dados do Aurora para Redshift

3. Executar transformações dbt no Redshift

## Resolução de Problemas

Banco em subnet privada

O Aurora está configurado em subnet privada. Use a EC2 (que está na VPC) para executar scripts via AWS Systems Manager.

Módulo Python não encontrado

Instale as dependências no virtualenv:
```bash
/tmp/venv/bin/pip install boto3 pandas sqlalchemy psycopg2-binary
```

Conexão recusada

Verifique:
- Status do Aurora: aws rds describe-db-clusters --profile zero-etl-project
- Acesso da EC2 à VPC privada
- Regras de security group na porta 5432

## Variáveis de Ambiente

```bash
export DB_SECRET_NAME="datahandsonmds-database-dev"
export S3_BUCKET="data-handson-mds-raw-dev"
export S3_PATH="movielens"
```

## Referências

- MovieLens Dataset: https://grouplens.org/datasets/movielens/
- AWS Secrets Manager: https://docs.aws.amazon.com/secretsmanager/
- AWS Systems Manager: https://docs.aws.amazon.com/systems-manager/
- SQLAlchemy PostgreSQL: https://docs.sqlalchemy.org/en/20/dialects/postgresql.html
