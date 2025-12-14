#!/usr/bin/env python3
###############################################################################
# Insere dados do S3 no Aurora PostgreSQL (versão simplificada)
#
# Faz parte do pipeline Zero-ETL:
#   CSV (local) → S3 → Aurora PostgreSQL → Zero-ETL → Redshift → dbt
#
# Uso: python insert_postgres_simple.py
# Requer: AWS profile 'zero-etl-project' ou IAM Role
#
# IMPORTANTE: Aurora e S3 devem estar criados antes de executar!
#   Aurora: transactional.movielens_database
#   S3: data-handson-mds-raw-dev/movielens/
#   Criados via Terraform em: terraform/infra/modules/rds e s3
#   Credenciais em: Secrets Manager (datahandsonmds-database-dev)
###############################################################################

import json
import boto3
import pandas as pd
from sqlalchemy import create_engine, text

print("Iniciando ETL...")

# Obter credenciais
secrets = boto3.client('secretsmanager', region_name='us-east-1')
response = secrets.get_secret_value(SecretId='datahandsonmds-database-dev')
creds = json.loads(response['SecretString'])

print(f"Conectando em {creds['host']}...")

# Conectar
conn_str = f"postgresql://{creds['username']}:{creds['password']}@{creds['host']}:{creds['port']}/transactional"
engine = create_engine(conn_str)

# Criar schema
with engine.connect() as conn:
    conn.execute(text("CREATE SCHEMA IF NOT EXISTS movielens_database"))
    conn.commit()
print("✓ Schema criado")

# Inserir dados do S3
s3 = boto3.client('s3')
csv_files = ["ratings", "tags", "movies", "links"]

for csv_name in csv_files:
    obj = s3.get_object(Bucket='data-handson-mds-raw-dev', Key=f'movielens/{csv_name}/{csv_name}.csv')
    df = pd.read_csv(obj['Body'])
    df.to_sql(csv_name, engine, schema='movielens_database', if_exists='replace', index=False)
    print(f" {csv_name}: {len(df):,} registros")

# Adicionar PKs
pk_sqls = [
    'ALTER TABLE movielens_database.ratings ADD PRIMARY KEY ("userId", "movieId", "timestamp");',
    'ALTER TABLE movielens_database.tags ADD PRIMARY KEY ("userId", "movieId", "tag");',
    'ALTER TABLE movielens_database.movies ADD PRIMARY KEY ("movieId");',
    'ALTER TABLE movielens_database.links ADD PRIMARY KEY ("movieId");'
]

with engine.connect() as conn:
    for sql in pk_sqls:
        try:
            conn.execute(text(sql))
        except Exception as e:
            if "already exists" not in str(e):
                print(f"Aviso: {e}")
    conn.commit()

print("ETL concluído com sucesso!")
