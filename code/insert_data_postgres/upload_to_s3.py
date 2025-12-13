import boto3
import os
import sys


def get_session():
    """Retorna sessao boto3 (profile local ou IAM Role)"""
    try:
        session = boto3.Session(profile_name='zero-etl-project')
        session.client('sts').get_caller_identity()
        return session, "profile: zero-etl-project"
    except Exception:
        return boto3.Session(), "IAM Role"


def upload_csv_to_s3():
    """Upload arquivos CSV do MovieLens para S3"""
    session, auth_method = get_session()
    s3_client = session.client('s3', region_name='us-east-1')

    bucket_name = os.getenv("S3_BUCKET", "data-handson-mds-raw-dev")
    base_path = "data/ml-latest-small"
    s3_prefix = "movielens"

    files_to_upload = {
        'ratings.csv': f'{s3_prefix}/ratings/',
        'tags.csv': f'{s3_prefix}/tags/',
        'movies.csv': f'{s3_prefix}/movies/',
        'links.csv': f'{s3_prefix}/links/'
    }

    print(f"Autenticacao: {auth_method}")
    print(f"Bucket: {bucket_name}")
    print(f"Prefixo: {s3_prefix}")
    print("-" * 50)

    uploaded = []
    failed = []

    for filename, s3_folder in files_to_upload.items():
        filepath = os.path.join(base_path, filename)

        if not os.path.exists(filepath):
            print(f"  {filename}: arquivo nao encontrado")
            failed.append(filename)
            continue

        try:
            s3_key = f"{s3_folder}{filename}"
            s3_client.upload_file(filepath, bucket_name, s3_key)
            print(f"  {filename}: enviado para s3://{bucket_name}/{s3_key}")
            uploaded.append(s3_key)
        except Exception as e:
            print(f"  {filename}: erro - {e}")
            failed.append(filename)

    print("-" * 50)
    print(f"Enviados: {len(uploaded)}")
    print(f"Falhas: {len(failed)}")

    if not failed:
        print("Upload concluido com sucesso")

    return len(failed) == 0


if __name__ == "__main__":
    success = upload_csv_to_s3()
    sys.exit(0 if success else 1)
