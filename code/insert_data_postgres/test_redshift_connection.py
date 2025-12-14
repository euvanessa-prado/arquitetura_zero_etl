###############################################################################
# Testa conexão com o Redshift e lista tabelas replicadas via Zero-ETL
#
# Faz parte do pipeline Zero-ETL:
#   CSV (local) → S3 → Aurora PostgreSQL → Zero-ETL → Redshift → dbt
#
# Uso: python test_redshift_connection.py
# Requer: AWS profile 'zero-etl-project' ou IAM Role
#
# IMPORTANTE: O cluster Redshift deve estar criado antes de executar!
#   Cluster: data-handson-mds
#   Database: movielens_zeroetl (criado pela integração Zero-ETL)
#   Criado via Terraform em: terraform/infra/modules/redshift
#   Credenciais em: Secrets Manager (data-handson-mds-credentials)
###############################################################################

import boto3
import json
import sys

try:
    import redshift_connector
except ImportError:
    print("Instalando redshift_connector...")
    import subprocess
    subprocess.check_call([sys.executable, "-m", "pip", "install", "redshift-connector", "--quiet", "--break-system-packages"])
    import redshift_connector

session = boto3.Session()
secrets_client = session.client('secretsmanager', region_name='us-east-1')

response = secrets_client.get_secret_value(SecretId="data-handson-mds-credentials")
secret = json.loads(response['SecretString'])

host = secret['host'].split(':')[0]
port = secret['port']
database = 'movielens_zeroetl'
user = secret['username']
password = secret['password']

print(f"Host: {host}")
print(f"Port: {port}")
print(f"Database: {database}")
print(f"User: {user}")
print("-" * 50)

conn = redshift_connector.connect(
    host=host,
    port=port,
    database=database,
    user=user,
    password=password
)

cursor = conn.cursor()

# Listar schemas
print("Schemas disponiveis:")
cursor.execute("SELECT schema_name FROM information_schema.schemata ORDER BY schema_name")
for row in cursor.fetchall():
    print(f"  {row[0]}")

print("-" * 50)

# Listar tabelas do schema movielens
print("Tabelas no schema movielens_database:")
cursor.execute("""
    SELECT table_name 
    FROM information_schema.tables 
    WHERE table_schema = 'movielens_database'
    ORDER BY table_name
""")
tables = cursor.fetchall()

if tables:
    for table in tables:
        cursor.execute(f"SELECT COUNT(*) FROM movielens_database.{table[0]}")
        count = cursor.fetchone()[0]
        print(f"  {table[0]}: {count:,} registros")
else:
    print("  Nenhuma tabela encontrada")

conn.close()
print("-" * 50)
print("Conexao OK")
