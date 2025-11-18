import boto3
import json
import time
import uuid
import os
from datetime import datetime
from prometheus_client import Counter, start_http_server

# Inicializa servidor de métricas Prometheus na porta 8000
start_http_server(8000)

# Cria contador de pagamentos processados
payments_processed_total = Counter('payments_processed_total', 'Total de pagamentos processados no DynamoDB')

# create a function to add numbers
starttime = time.time()

# Lê configuração das variáveis de ambiente
queue_url = os.environ.get('SQS_QUEUE_URL', 'https://sqs.us-east-1.amazonaws.com/794038226274/keda-demo-queue.fifo')
aws_region = os.environ.get('AWS_REGION', 'us-east-1')
dynamodb_table = os.environ.get('DYNAMODB_TABLE', 'payments')

print(f"📋 Configuração:")
print(f"   SQS Queue: {queue_url}")
print(f"   AWS Region: {aws_region}")
print(f"   DynamoDB Table: {dynamodb_table}")
        

def receive_message():
    try:
        print("Start fn receive message")
        sqs_client = boto3.client("sqs", region_name=aws_region)
        response = sqs_client.receive_message(
            QueueUrl= queue_url,
            AttributeNames=[
            'SentTimestamp'
            ],
            MaxNumberOfMessages=1,
            MessageAttributeNames=[
            'All'
            ],
            WaitTimeSeconds=0,
            VisibilityTimeout=60
        )
        print(f"Number of messages received: {len(response.get('Messages', []))}")
        
        #for message in response.get("Messages", []):
        if len(response.get('Messages', [])) != 0:
            message = response['Messages'][0]
            message_body = message["Body"]
            print(f"message_body : {message_body}")

            receipt_handle = message['ReceiptHandle']
            
            save_data(message_body)

            print(f"Receipt Handle: {message['ReceiptHandle']}")
            print(f"Deleting Message : {message_body}")
            # Delete received message from queue
            sqs_client.delete_message(
                QueueUrl=queue_url,
                ReceiptHandle=receipt_handle
            )

            
        print("End fn receive message")
    except Exception as ex:
        print(f"Error happened in receive_message : {ex} ")
    

def save_data(_message):
    try:
        print(f'save data src msg :{_message}')
        jsonMessage = json.loads(_message)
        print(f'Src Message :{jsonMessage["msg"]},{jsonMessage["srcStamp"]}')
        #current_dateTime = json.dumps(datetime.now(),default= str)
        date_format = '%Y-%m-%d %H:%M:%S.%f'
        current_dateTime = datetime.utcnow().strftime(date_format)
        _id=str(uuid.uuid1())
        print(f"id:{_id}")
        dynamodb = boto3.resource('dynamodb', region_name=aws_region)
        table = dynamodb.Table(dynamodb_table)
        
        
        messageProcessingTime = datetime.utcnow() - datetime.strptime(jsonMessage["srcStamp"],date_format) 
        print(f'messageProcessingTime: {messageProcessingTime.total_seconds()}')

        response = table.put_item(
            Item={
            'id': _id,
            'data': jsonMessage["msg"],
            'srcStamp':jsonMessage["srcStamp"],
            'destStamp':current_dateTime,
            'messageProcessingTime':str(messageProcessingTime.total_seconds())
            }
        )
        status_code = response['ResponseMetadata']['HTTPStatusCode']
        print(f"Data Save Status : {status_code}")
        
        # Incrementa contador Prometheus após salvar com sucesso
        payments_processed_total.inc()
        print(f"✅ Pagamento processado! Total: {payments_processed_total._value._value}")
    except Exception as error:
        print(f"Error has happened : {error}")

    
      

while True:
    t = time.localtime()
    time.sleep(1.0 - ((time.time() - starttime) % 1.0)) #sleep for  sec
    currenttime = time.strftime("%H:%M:%S", t)
    print(f"Start SQS Call : {currenttime}")

    receive_message()
    #save_data("hi there")

    ## Date format working
    #date_format = '%Y-%m-%d %H:%M:%S.%f'
    #currentDateAndTime = datetime.now().strftime(date_format)#"2023-03-23 17:49:25.651555"
    #currentDateAndTime = '2023-03-23 18:38:42.536417'
    #print("The current date and time is", currentDateAndTime)
    #currentDate = datetime.strptime(currentDateAndTime, date_format)
    #x = datetime.now() - currentDate
    #print("diff",x)
    #print("The current time is", currentDate)
    '''i = 0
    while i < 20:
        i = i+1'''
    currenttime = time.strftime("%H:%M:%S", t)
    print(f"End SQS Call {currenttime}")
