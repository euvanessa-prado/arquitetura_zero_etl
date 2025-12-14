# Arquitetura Zero-ETL - MovieLens Data Pipeline

## Visão Geral

Pipeline de dados completo que replica dados do Aurora PostgreSQL para Redshift via Zero-ETL e aplica transformações com dbt.

## Componentes

### 1. Fonte de Dados - Aurora PostgreSQL

Database: `transactional`
Schema: `movielens_database`
Tabelas:
- ratings: 100,836 registros
- tags: 3,683 registros
- movies: 9,742 registros
- links: 9,742 registros

Credenciais:
- Host: [AURORA_CLUSTER_ENDPOINT]
- Port: 5432
- User: [DB_USER]
- Password: (Secrets Manager: datahandsonmds-database-dev)

### 2. Replicação - Zero-ETL Integration

Integração AWS que replica dados do Aurora para Redshift em tempo real.

Status: Ativo
Source: Aurora (transactional.movielens_database)
Target: Redshift (movielens_raw.movielens_database)

Tabelas replicadas:
- movielens_raw.movielens_database.ratings
- movielens_raw.movielens_database.tags
- movielens_raw.movielens_database.movies
- movielens_raw.movielens_database.links

### 3. Data Warehouse - Amazon Redshift

Cluster: data-handson-mds
Node Type: ra3.large
Cluster Type: single-node

Credenciais:
- Host: [REDSHIFT_CLUSTER_ENDPOINT]
- Port: 5439
- User: [REDSHIFT_USER]
- Password: (Secrets Manager: data-handson-mds-credentials)

Databases:
- datahandsonmds (padrão)
- movielens_raw (dados replicados via Zero-ETL)
- analytics_movie_insights (dados transformados via dbt)

### 4. Transformação - dbt

Ferramenta: dbt (Data Build Tool)
Executor: MWAA (Managed Workflows for Apache Airflow)
Projeto: code/dbt/movielens_redshift

Modelos:
- Staging: stg_ratings, stg_tags, stg_movies, stg_links
- Intermediate: int_movie_ratings, int_user_profiles
- Analytics: analytics_movie_insights, analytics_user_engagement

Output: analytics_movie_insights database no Redshift

## Fluxo de Dados

```
MovieLens CSV Files (local)
    ↓
S3 (data-handson-mds-raw-dev)
    ↓
Aurora PostgreSQL (transactional.movielens_database)
    ↓
Zero-ETL Integration
    ↓
Redshift (movielens_raw.movielens_database)
    ↓
dbt Transformations
    ↓
Redshift (analytics_movie_insights)
```

## Infraestrutura AWS

### VPC
- CIDR: 10.0.0.0/16
- Subnets Públicas: 10.0.1.0/24, 10.0.2.0/24
- Subnets Privadas: 10.0.3.0/24, 10.0.4.0/24
- NAT Gateway: 1 (para acesso à internet das subnets privadas)
- VPC Endpoints: S3, ECR, CloudWatch Logs, SQS, Monitoring

### Armazenamento S3
- data-handson-mds-raw-dev: Dados brutos (MovieLens CSVs)
- data-handson-mds-scripts-dev: Scripts de execução
- data-handson-mds-curated-dev: Dados curados (futuro)

### Computação
- EC2: t3a.2xlarge (para execução de scripts via SSM)
- Aurora: db.t4g.large (1 instância)
- Redshift: ra3.large (1 nó)

### Orquestração
- MWAA: Airflow 2.10.3 (quando ativado)
- DAG: dag_movielens_dbt_redshift_mwaa.py

## Credenciais

### Aurora PostgreSQL
Secret: datahandsonmds-database-dev
- username: [DB_USER]
- password: (Secrets Manager)
- host: [AURORA_CLUSTER_ENDPOINT]
- port: 5432
- dbname: transactional

### Redshift
Secret: data-handson-mds-credentials
- username: [REDSHIFT_USER]
- password: (Secrets Manager)
- host: [REDSHIFT_CLUSTER_ENDPOINT]
- port: 5439
- dbname: datahandsonmds

## Procedimentos

### 1. Upload de Dados para S3
```bash
python code/insert_data_postgres/upload_to_s3.py
```

### 2. Inserir Dados no Aurora
```bash
bash code/insert_data_postgres/check_tables.sh
```

### 3. Verificar Dados no Aurora
```bash
bash code/insert_data_postgres/check_tables.sh
```

### 4. Verificar Replicação no Redshift
```bash
python code/insert_data_postgres/test_redshift_connection.py
```

### 5. Executar dbt Transformations
```bash
# Via MWAA (quando ativado)
# Acesse a UI do Airflow e execute o DAG: dag_dbt_movielens_zeroetl_cosmos
```

## Monitoramento

### Aurora
- CloudWatch Metrics: CPU, Storage, Connections
- RDS Enhanced Monitoring

### Redshift
- CloudWatch Metrics: CPU, Storage, Query Performance
- Redshift Query Editor: Consultar dados

### Zero-ETL
- AWS Console: Integrations > Zero-ETL Integrations
- Status: Ativo/Inativo
- Latência de replicação

## Troubleshooting

### Erro: Database não existe
Solução: Criar o database manualmente
```sql
CREATE DATABASE analytics_movie_insights;
```

### Erro: Conexão recusada
Solução: Verificar security groups e VPC endpoints

### Erro: Zero-ETL não replicando
Solução: Verificar status da integração no console AWS

## Próximos Passos

1. Ativar MWAA para orquestração automática
2. Configurar alertas no CloudWatch
3. Implementar data quality checks
4. Adicionar mais modelos dbt
5. Configurar backup e disaster recovery

## Referências

- AWS Zero-ETL: https://docs.aws.amazon.com/redshift/latest/mgmt/zero-etl.html
- dbt Documentation: https://docs.getdbt.com/
- MWAA: https://docs.aws.amazon.com/mwaa/
- Redshift: https://docs.aws.amazon.com/redshift/
- Aurora: https://docs.aws.amazon.com/rds/latest/userguide/Aurora.html
