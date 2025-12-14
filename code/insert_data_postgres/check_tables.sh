#!/bin/bash
###############################################################################
# Executa check_tables.py na EC2 via SSM
# Substitua [INSTANCE_ID] e [COMMAND_ID] pelos valores reais
###############################################################################

aws s3 cp code/insert_data_postgres/check_tables.py s3://data-handson-mds-scripts-dev/ --profile zero-etl-project

aws ssm send-command \
  --profile zero-etl-project \
  --region us-east-1 \
  --instance-ids [INSTANCE_ID] \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=[
    "python3 -c \"import boto3; s3=boto3.client('"'"'s3'"'"'); s3.download_file('"'"'data-handson-mds-scripts-dev'"'"', '"'"'check_tables.py'"'"', '"'"'/tmp/check_tables.py'"'"')\"",
    "/tmp/venv/bin/python /tmp/check_tables.py"
  ]' \
  --query 'Command.CommandId' \
  --output text

# Substitua [COMMAND_ID] pelo ID retornado acima
aws ssm get-command-invocation \
  --profile zero-etl-project \
  --region us-east-1 \
  --command-id [COMMAND_ID] \
  --instance-id [INSTANCE_ID] \
  --query '[Status,StandardOutputContent]' \
  --output text