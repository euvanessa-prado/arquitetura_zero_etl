import json
import os
import sys
import boto3
import pandas as pd
from sqlalchemy import create_engine, text


def get_session():
    """Retorna sessao boto3 (profile local ou IAM Role)"""
    try:
        session = boto3.Session(profile_name='zero-etl-project')
        session.client('sts').get_caller_identity()
        return session, "profile: zero-etl-project"
    except Exception:
        return boto3.Session(), "IAM Role"


def get_db_credentials(secrets_client, secret_name):
    """Busca credenciais do Secrets Manager"""
    response = secrets_client.get_secret_value(SecretId=secret_name)
    return json.loads(response['SecretString'])


def main():
    session, auth_method = get_session()
    secrets_client = session.client('secretsmanager', region_name='us-east-1')
    s3_client = session.client('s3')

    secret_name = os.getenv("DB_SECRET_NAME", "datahandsonmds-database-dev")
    s3_bucket = os.getenv("S3_BUCKET", "data-handson-mds-raw-dev")
    s3_path = os.getenv("S3_PATH", "movielens")
    db_schema = "movielens_database"

    print(f"Autenticacao: {auth_method}")
    print(f"Secret: {secret_name}")
    print(f"S3 Bucket: {s3_bucket}")
    print("-" * 50)

    try:
        # Obter credenciais
        creds = get_db_credentials(secrets_client, secret_name)
        db_name = creds.get('dbname', 'transactional')

        print(f"Host: {creds['host']}")
        print(f"Database: {db_name}")
        print(f"Schema: {db_schema}")
        print("-" * 50)

        # Criar conexao
        conn_str = (
            f"postgresql://{creds['username']}:{creds['password']}"
            f"@{creds['host']}:{creds['port']}/{db_name}"
        )
        engine = create_engine(conn_str)

        # Criar schema
        print("Criando schema...")
        with engine.connect() as conn:
            conn.execute(text(f"CREATE SCHEMA IF NOT EXISTS {db_schema}"))
            conn.commit()
        print(f"Schema {db_schema} pronto")
        print("-" * 50)

        # Inserir dados do S3
        csv_files = ["ratings", "tags", "movies", "links"]
        print("Inserindo dados do S3...")

        for csv_name in csv_files:
            file_key = f"{s3_path}/{csv_name}/{csv_name}.csv"
            obj = s3_client.get_object(Bucket=s3_bucket, Key=file_key)
            df = pd.read_csv(obj['Body'])

            df.to_sql(
                csv_name,
                engine,
                schema=db_schema,
                if_exists="replace",
                index=False
            )
            print(f"  {db_schema}.{csv_name}: {len(df):,} registros")

        print("-" * 50)

        # Adicionar primary keys para Zero-ETL
        print("Adicionando primary keys...")
        pk_sqls = [
            (
                f'ALTER TABLE {db_schema}.ratings '
                f'ADD PRIMARY KEY ("userId", "movieId", "timestamp");'
            ),
            (
                f'ALTER TABLE {db_schema}.tags '
                f'ADD PRIMARY KEY ("userId", "movieId", "tag");'
            ),
            f'ALTER TABLE {db_schema}.movies ADD PRIMARY KEY ("movieId");',
            f'ALTER TABLE {db_schema}.links ADD PRIMARY KEY ("movieId");'
        ]

        with engine.connect() as conn:
            for sql in pk_sqls:
                table_name = sql.split('.')[1].split()[0]
                try:
                    conn.execute(text(sql))
                    print(f"  {table_name}: PK adicionada")
                except Exception as e:
                    if "already exists" in str(e):
                        print(f"  {table_name}: PK ja existe")
                    else:
                        print(f"  {table_name}: {e}")
            conn.commit()

        print("-" * 50)
        print("ETL concluido com sucesso")
        return True

    except Exception as e:
        print(f"Erro: {e}")
        return False


if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
