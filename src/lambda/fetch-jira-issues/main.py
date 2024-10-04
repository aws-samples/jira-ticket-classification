import os
import json
from datetime import datetime
from jira_utils import fetch_jira_issues, parse_json_with_map, jira_mappings
from aws_utils import get_secret, upload_to_s3
from csv_utils import create_csv

def process_project(project_id, jira_creds, s3_bucket, s3_prefix):
    """Process a single project and return the result."""
    issues = fetch_jira_issues(jira_creds['base_url'], project_id.strip(), jira_creds['email'], jira_creds['api_key'])
    formatted_issues = [parse_json_with_map(i, jira_mappings) for i in issues]
    
    csv_string = create_csv(formatted_issues)
    
    current_date = datetime.now().strftime('%Y%m%d_%H%M%S_%f')
    s3_key = f"{s3_prefix}/{project_id.strip()}_{current_date}.csv"
    
    upload_to_s3(csv_string, s3_bucket, s3_key)
    
    return {
        'project_id': project_id.strip(),
        'issues_count': len(issues),
        's3_path': f"s3://{s3_bucket}/{s3_key}"
    }

def lambda_handler(event, context):
    # Retrieve environment variables
    s3_bucket = os.environ['BUCKET_NAME']
    s3_prefix = os.environ['S3_PREFIX']
    secret_name = os.environ['JIRA_CREDENTIALS_SECRET']
    project_ids = os.environ['PROJECT_IDS_COMMA_SEPARATED'].split(',')

    if not project_ids:
        return {
            'statusCode': 400,
            'body': json.dumps("No project IDs provided")
        }

    try:

        jira_creds = get_secret(secret_name)
        
        results = []
        for project_id in project_ids:
            try:
                result = process_project(project_id, jira_creds, s3_bucket, s3_prefix)
                results.append(result)
            except Exception as e:
                results.append({
                    'project_id': project_id.strip(),
                    'error': str(e)
                })
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': "Processing complete",
                'results': results
            })
        }
    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps({
                'message': "An error occurred",
                'error': str(e)
            })
        }