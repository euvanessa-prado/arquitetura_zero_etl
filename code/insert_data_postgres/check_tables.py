#!/usr/bin/env python3
import json
import boto3
from sqlalchemy import create_engine, text

print("Verificando tabelas no PostgreSQL Aurora...")

secrets = boto3.client('secretsmanager', region_name='us-east-1')
response = secrets.get_secret_value(SecretId='datahandsonmds-database-dev')
creds = json.loads(response['SecretString'])

conn_str = f"postgresql://{creds['username']}:{creds['password']}@{creds['host']}:{creds['port']}/transactional"
engine = create_engine(conn_str)

print("Tabelas no schema movielens_database:")
print("-" * 40)

tables = ['ratings', 'tags', 'movies', 'links']
for table in tables:
    with engine.connect() as conn:
        result = conn.execute(text(f"SELECT COUNT(*) FROM movielens_database.{table}"))
        count = result.fetchone()[0]
        print(f"  {table}: {count:,} registros")

print("-" * 40)
print("Verificacao concluida com sucesso")
