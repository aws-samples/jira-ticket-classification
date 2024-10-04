import json
import boto3

# Initialize AWS clients
session = boto3.session.Session()
secrets_client = session.client(service_name='secretsmanager')
s3_client = session.client('s3')

def get_secret(secret_name):
    try:
        get_secret_value_response = secrets_client.get_secret_value(SecretId=secret_name)
        return json.loads(get_secret_value_response['SecretString'])
    except Exception as e:
        raise Exception(f"Failed to retrieve Jira credentials: {str(e)}")

def upload_to_s3(csv_string, bucket, key):
    try:
        s3_client.put_object(
            Bucket=bucket,
            Key=key,
            Body=csv_string,
            ContentType='text/csv'
        )
    except Exception as e:
        raise Exception(f"Failed to upload CSV to S3: {str(e)}")