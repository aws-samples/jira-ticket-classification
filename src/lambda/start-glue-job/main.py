import json
import boto3
import os

# Initialize Boto3 Glue client
glue_client = boto3.client('glue')

def handler(event, context):
    # Print event for debugging
    print(f"Received event: {json.dumps(event)}")

    # Get bucket name and object key (file name) from the S3 event
    try:
        s3_event = event['Records'][0]['s3']
        s3_bucket = s3_event['bucket']['name']
        s3_key = s3_event['object']['key']
    except KeyError as e:
        print(f"Error parsing S3 event: {str(e)}")
        raise

    # Check if the uploaded file is a CSV
    if not s3_key.lower().endswith('.csv'):
        print(f"Uploaded file '{s3_key}' is not a CSV file. Failing the Lambda function.")
        raise ValueError(f"Uploaded file '{s3_key}' is not a CSV file")

    # Get the Glue job name from the environment variables
    glue_job_name = os.environ.get('GLUE_JOB_NAME')
    if not glue_job_name:
        raise ValueError("GLUE_JOB_NAME environment variable not set")

    # Start the Glue job and pass in the bucket and new CSV file as arguments
    try:
        response = glue_client.start_job_run(
            JobName=glue_job_name,
            Arguments={
                '--S3_BUCKET': s3_bucket,
                '--NEW_CSV_FILE': s3_key
            }
        )
        print(f"Glue job '{glue_job_name}' started successfully with JobRunId: {response['JobRunId']}")
    except Exception as e:
        print(f"Error starting Glue job: {str(e)}")
        raise

    return {
        'statusCode': 200,
        'body': json.dumps(f"Glue job started successfully with JobRunId: {response['JobRunId']}")
    }
    