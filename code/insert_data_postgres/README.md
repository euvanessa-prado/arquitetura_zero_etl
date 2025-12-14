# ETL - MovieLens para Aurora PostgreSQL

Este guia explica como carregar os dados do MovieLens no pipeline Zero-ETL.

## Pré-requisitos

Antes de começar, você precisa ter:

1. **Infraestrutura AWS criada** via Terraform (`terraform/infra/`)
2. **AWS CLI configurado** com o profile `zero-etl-project`
3. **Python 3.8+** instalado
4. **Dependências Python** instaladas:
   ```bash
   pip install boto3 pandas sqlalchemy psycopg2-binary redshift-connector
   ```

## Passo a Passo

### Passo 1: Enviar os arquivos CSV para o S3

Este script pega os arquivos CSV do MovieLens (que estão em `data/ml-latest-small/`) e envia para o bucket S3.

```bash
python code/insert_data_postgres/upload_to_s3.py
```

**O que acontece:**
- Os arquivos `ratings.csv`, `movies.csv`, `tags.csv` e `links.csv` são enviados para o S3
- Destino: `s3://data-handson-mds-raw-dev/movielens/`

---

### Passo 2: Criar o database no Aurora

Este script cria o database `transactional` no Aurora PostgreSQL (se ainda não existir).

```bash
python code/insert_data_postgres/create_database.py
```

**O que acontece:**
- Conecta no Aurora usando credenciais do Secrets Manager
- Cria o database `transactional`

---

### Passo 3: Inserir os dados no Aurora

Este script lê os CSVs do S3 e insere no Aurora PostgreSQL.

> **Nota:** Como o Aurora está em subnet privada, este script deve ser executado na EC2 via SSM (Systems Manager).

**Opção A - Executar localmente (se tiver acesso direto ao Aurora):**
```bash
python code/insert_data_postgres/insert_postgres_simple.py
```

**Opção B - Executar via EC2/SSM:**
```bash
# 1. Enviar script para S3
aws s3 cp code/insert_data_postgres/insert_postgres_simple.py \
    s3://data-handson-mds-scripts-dev/ --profile zero-etl-project

# 2. Executar na EC2 via SSM (substitua [INSTANCE_ID] pelo ID da sua EC2)
aws ssm send-command \
  --profile zero-etl-project \
  --region us-east-1 \
  --instance-ids [INSTANCE_ID] \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=[
    "python3 -c \"import boto3; s3=boto3.client('s3'); s3.download_file('data-handson-mds-scripts-dev', 'insert_postgres_simple.py', '/tmp/insert.py')\"",
    "/tmp/venv/bin/python /tmp/insert.py"
  ]'
```

**O que acontece:**
- Cria o schema `movielens_database`
- Insere os dados nas tabelas: `ratings`, `movies`, `tags`, `links`
- Adiciona as Primary Keys (necessário para o Zero-ETL funcionar)

---

### Passo 4: Verificar se os dados foram inseridos

```bash
python code/insert_data_postgres/check_tables.py
```

**Resultado esperado:**
```
Tabelas no schema movielens_database:
----------------------------------------
  ratings: 100,836 registros
  tags: 3,683 registros
  movies: 9,742 registros
  links: 9,742 registros
```

---

### Passo 5: Aguardar a replicação Zero-ETL

Após inserir os dados no Aurora, o Zero-ETL replica automaticamente para o Redshift.

- Tempo estimado: 1-5 minutos
- Você pode acompanhar no console AWS: **RDS > Zero-ETL integrations**

---

### Passo 6: Verificar os dados no Redshift

```bash
python code/insert_data_postgres/test_redshift_connection.py
```

**O que acontece:**
- Conecta no Redshift
- Lista os schemas e tabelas replicadas
- Mostra a contagem de registros

---

### Passo 7: Listar todos os objetos do Redshift (opcional)

```bash
python code/insert_data_postgres/list_redshift_objects.py
```

**O que acontece:**
- Lista todos os databases, schemas, tabelas e views do Redshift
- Útil para debug e verificação

---

## Resumo dos Scripts

| Script | Função |
|--------|--------|
| `upload_to_s3.py` | Envia CSVs locais para o S3 |
| `create_database.py` | Cria database no Aurora |
| `insert_postgres_simple.py` | Insere dados do S3 no Aurora |
| `script-python-insert-csv-postgres.py` | Versão completa com mais validações |
| `check_tables.py` | Verifica tabelas no Aurora |
| `test_connection.py` | Testa conexão com Aurora |
| `test_redshift_connection.py` | Testa conexão com Redshift |
| `list_redshift_objects.py` | Lista objetos do Redshift |

---

## Fluxo Completo do Pipeline

```
┌─────────────────┐
│  CSVs locais    │  data/ml-latest-small/
└────────┬────────┘
         │ upload_to_s3.py
         ▼
┌─────────────────┐
│      S3         │  s3://data-handson-mds-raw-dev/movielens/
└────────┬────────┘
         │ insert_postgres_simple.py
         ▼
┌─────────────────┐
│ Aurora PostgreSQL│  transactional.movielens_database
└────────┬────────┘
         │ Zero-ETL (automático)
         ▼
┌─────────────────┐
│    Redshift     │  movielens_zeroetl.movielens_database
└────────┬────────┘
         │ dbt (via MWAA/Airflow)
         ▼
┌─────────────────┐
│    Redshift     │  analytics_movie_insights
└─────────────────┘
```

---

## Troubleshooting

### Erro: "Bucket não existe"
- Verifique se a infraestrutura foi criada via Terraform
- Execute: `terraform apply -var-file=envs/develop.tfvars`

### Erro: "Conexão recusada" no Aurora
- O Aurora está em subnet privada
- Execute os scripts via EC2/SSM ou configure VPN

### Erro: "Database não existe" no Redshift
- O database `movielens_zeroetl` é criado automaticamente pelo Zero-ETL
- Aguarde alguns minutos após criar a integração

### Erro: "Tabela não encontrada" no Redshift
- Verifique se o Zero-ETL está ativo no console AWS
- As tabelas precisam ter Primary Key no Aurora para serem replicadas
