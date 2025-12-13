import boto3
import json
import os
import sys
from sqlalchemy import create_engine, text


def get_session():
    """Retorna sessão boto3 (profile local ou IAM Role)"""
    try:
        session = boto3.Session(profile_name='zero-etl-project')
        session.client('sts').get_caller_identity()
        return session, "profile: zero-etl-project"
    except Exception:
        return boto3.Session(), "IAM Role"


def create_database():
    """Cria o database transactional no PostgreSQL"""
    session, auth_method = get_session()
    secrets_client = session.client('secretsmanager', region_name='us-east-1')
    secret_name = os.getenv("DB_SECRET_NAME", "datahandsonmds-database-dev")

    print(f"Autenticacao: {auth_method}")
    print(f"Secret: {secret_name}")
    print("-" * 50)

    try:
        response = secrets_client.get_secret_value(SecretId=secret_name)
        secret = json.loads(response['SecretString'])

        db_config = {
            'user': secret['username'],
            'password': secret['password'],
            'host': secret['host'],
            'port': secret['port'],
            'database': secret.get('dbname', 'transactional')
        }

        print(f"Host: {db_config['host']}")
        print(f"Database a criar: {db_config['database']}")
        print("-" * 50)

        # Conectar ao postgres (default)
        conn_str = (
            f"postgresql://{db_config['user']}:{db_config['password']}"
            f"@{db_config['host']}:{db_config['port']}/postgres"
        )
        engine = create_engine(conn_str, isolation_level="AUTOCOMMIT")

        with engine.connect() as conn:
            # Verificar se database existe
            result = conn.execute(
                text("SELECT 1 FROM pg_database WHERE datname = :db"),
                {"db": db_config['database']}
            )
            exists = result.fetchone() is not None

            if exists:
                print(f"Database '{db_config['database']}' ja existe")
            else:
                conn.execute(text(f"CREATE DATABASE {db_config['database']}"))
                print(f"Database '{db_config['database']}' criado com sucesso")

        print("-" * 50)
        print("Operacao concluida")
        return True

    except Exception as e:
        print(f"Erro: {e}")
        return False


if __name__ == "__main__":
    success = create_database()
    sys.exit(0 if success else 1)
