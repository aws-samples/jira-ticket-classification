import json
from ticket_classifier import TicketClassifier
from s3_handler import S3Handler

def handler(event, context):
    print(f"Received event: {json.dumps(event)}")

    try:
        s3_event = event['Records'][0]['s3']
        s3_bucket = s3_event['bucket']['name']
        s3_key = s3_event['object']['key']
    except KeyError as e:
        print(f"Error parsing S3 event: {str(e)}")
        raise

    print(f"Reading CSV from S3 - Bucket: {s3_bucket}, Key: {s3_key}")

    s3_handler = S3Handler(s3_bucket)
    tickets = s3_handler.read_csv(s3_key)

    classifier = TicketClassifier()
    classified_tickets = classifier.classify_tickets(tickets)

    s3_handler.upload_csv(classified_tickets)

    return {
        'statusCode': 200,
        'body': json.dumps('CSV processed successfully')
    }