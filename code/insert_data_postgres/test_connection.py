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


def test_db_connection():
    """Testa a conexão com o banco de dados PostgreSQL"""
    session, auth_method = get_session()
    secrets_client = session.client('secretsmanager', region_name='us-east-1')
    secret_name = os.getenv("DB_SECRET_NAME", "datahandsonmds-database-dev")

    print(f"Autenticacao: {auth_method}")
    print(f"Secret: {secret_name}")
    print("-" * 50)

    try:
        # Obter credenciais
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
        print(f"Port: {db_config['port']}")
        print(f"User: {db_config['user']}")
        print(f"Database: {db_config['database']}")
        print("-" * 50)

        # Testar conexão (usa 'postgres' como database padrão)
        conn_str = (
            f"postgresql://{db_config['user']}:{db_config['password']}"
            f"@{db_config['host']}:{db_config['port']}/postgres"
        )
        engine = create_engine(conn_str)

        with engine.connect() as conn:
            result = conn.execute(text("SELECT version();"))
            version = result.fetchone()[0]
            print(f"Conexao: OK")
            print(f"Versao: {version.split(',')[0]}")

        print("-" * 50)
        print("Teste concluido com sucesso")
        return True

    except Exception as e:
        print(f"Erro: {e}")
        return False


if __name__ == "__main__":
    success = test_db_connection()
    sys.exit(0 if success else 1)
