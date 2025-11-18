FROM python:3.11-slim

WORKDIR /usr/app/src

COPY karpenter-sqs-reader.py ./

RUN pip install --no-cache-dir boto3 prometheus_client

CMD [ "python", "./karpenter-sqs-reader.py" ]