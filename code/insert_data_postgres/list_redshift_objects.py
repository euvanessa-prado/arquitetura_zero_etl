#!/usr/bin/env python3
###############################################################################
# Lista todos os objetos do Redshift (databases, schemas, tabelas, views)
#
# Faz parte do pipeline Zero-ETL:
#   CSV (local) → S3 → Aurora PostgreSQL → Zero-ETL → Redshift → dbt
#
# Uso: python list_redshift_objects.py
# Requer: AWS profile 'zero-etl-project' ou IAM Role
#
# IMPORTANTE: O cluster Redshift deve estar criado antes de executar!
#   Cluster: data-handson-mds
#   Criado via Terraform em: terraform/infra/modules/redshift
#   Credenciais em: Secrets Manager (data-handson-mds-credentials)
###############################################################################

import json
import boto3
import redshift_connector

print("Conectando ao Redshift...")

secrets = boto3.client('secretsmanager', region_name='us-east-1')
response = secrets.get_secret_value(SecretId='data-handson-mds-credentials')
creds = json.loads(response['SecretString'])

host = creds['host'].split(':')[0]
port = creds['port']
user = creds['username']
password = creds['password']

conn = redshift_connector.connect(
    host=host,
    port=port,
    database='dev',
    user=user,
    password=password
)

cursor = conn.cursor()

print("\n" + "="*60)
print("DATABASES")
print("="*60)
cursor.execute("SELECT datname FROM pg_database ORDER BY datname")
for row in cursor.fetchall():
    print(f"  {row[0]}")

print("\n" + "="*60)
print("SCHEMAS")
print("="*60)
cursor.execute("SELECT schema_name FROM information_schema.schemata ORDER BY schema_name")
for row in cursor.fetchall():
    print(f"  {row[0]}")

print("\n" + "="*60)
print("TABELAS POR SCHEMA")
print("="*60)

cursor.execute("""
    SELECT table_schema, table_name 
    FROM information_schema.tables 
    WHERE table_schema NOT IN ('pg_catalog', 'information_schema')
    ORDER BY table_schema, table_name
""")

current_schema = None
for row in cursor.fetchall():
    schema, table = row
    if schema != current_schema:
        print(f"\n{schema}:")
        current_schema = schema
    
    cursor.execute(f"SELECT COUNT(*) FROM {schema}.{table}")
    count = cursor.fetchone()[0]
    print(f"  {table}: {count:,} registros")

print("\n" + "="*60)
print("VIEWS")
print("="*60)

cursor.execute("""
    SELECT table_schema, table_name 
    FROM information_schema.views 
    WHERE table_schema NOT IN ('pg_catalog', 'information_schema')
    ORDER BY table_schema, table_name
""")

views = cursor.fetchall()
if views:
    for schema, view in views:
        print(f"  {schema}.{view}")
else:
    print("  Nenhuma view encontrada")

print("\n" + "="*60)
print("COLUNAS - movielens_raw.movielens_database")
print("="*60)

try:
    cursor.execute("""
        SELECT table_name, column_name, data_type, is_nullable
        FROM information_schema.columns
        WHERE table_schema = 'movielens_database' AND table_catalog = 'movielens_raw'
        ORDER BY table_name, ordinal_position
    """)
    
    current_table = None
    for row in cursor.fetchall():
        table, column, dtype, nullable = row
        if table != current_table:
            print(f"\n{table}:")
            current_table = table
        nullable_str = "NULL" if nullable == "YES" else "NOT NULL"
        print(f"  {column}: {dtype} {nullable_str}")
except Exception as e:
    print(f"  Erro ao listar colunas: {e}")

conn.close()
print("\n" + "="*60)
print("Consulta concluida!")
print("="*60)
