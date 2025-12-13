#!/bin/bash

aws s3 cp code/insert_data_postgres/check_tables.py s3://data-handson-mds-scripts-dev/ --profile zero-etl-project

aws ssm send-command \
  --profile zero-etl-project \
  --region us-east-1 \
  --instance-ids i-0b84eb1b7f2825d46 \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=[
    "python3 -c \"import boto3; s3=boto3.client('"'"'s3'"'"'); s3.download_file('"'"'data-handson-mds-scripts-dev'"'"', '"'"'check_tables.py'"'"', '"'"'/tmp/check_tables.py'"'"')\"",
    "/tmp/venv/bin/python /tmp/check_tables.py"
  ]' \
  --query 'Command.CommandId' \
  --output text

aws ssm get-command-invocation \
  --profile zero-etl-project \
  --region us-east-1 \
  --command-id e7c14fea-9e26-4596-b47f-22deb2b14fe8 \
  --instance-id i-0b84eb1b7f2825d46 \
  --query '[Status,StandardOutputContent]' \
  --output text