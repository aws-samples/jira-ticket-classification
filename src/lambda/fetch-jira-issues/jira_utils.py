import json
import requests
from requests.auth import HTTPBasicAuth
from typing import Dict, Any
from datetime import datetime, timedelta

jira_mappings = {
    "Id": ["id"],
    "Key": ["key"],
    "Parent": ["fields.parent.key"],
    "Summary": ["fields.summary"],
    "Description": ["fields.description.content.0.content.0.text"],
    "Labels": ["fields.labels"]
}

def get_value_from_path(data: Any, path: str) -> Any:
    keys = path.split('.')
    for key in keys:
        if isinstance(data, dict):
            if key in data:
                data = data[key]
            else:
                return None
        elif isinstance(data, list):
            try:
                index = int(key)
                if 0 <= index < len(data):
                    data = data[index]
                else:
                    return None
            except ValueError:
                return None
        else:
            return None
    return data

def parse_json_with_map(json_data: Dict[str, Any], field_map: Dict[str, list]) -> Dict[str, Any]:
    result = {}
    for field, paths in field_map.items():
        for path in paths:
            value = get_value_from_path(json_data, path)
            if value is not None:
                result[field] = value
                break  # Use the first matching path
    return result

def fetch_jira_issues(base_url, project_id, email, api_key):
    url = f"{base_url}/rest/api/3/search"

    # Calculate the date 8 days ago
    eight_days_ago = (datetime.now() - timedelta(days=8)).strftime("%Y-%m-%d")
    
    # Create JQL
    jql = f"project = {project_id} AND created >= '{eight_days_ago}' ORDER BY created DESC"

    # Pass into params of request.
    params = {
        "jql": jql,
        "startAt": 0
    }
    all_issues = []

    auth = HTTPBasicAuth(email, api_key)
    headers = {"Accept": "application/json"}

    while True:
        response = requests.get(url, headers=headers, params=params, auth=auth)
        if response.status_code != 200:
            raise Exception(f"Failed to fetch issues for project {project_id}: {response.text}")
        
        data = json.loads(response.text)
        issues = data['issues']
        all_issues.extend(issues)
        
        if len(all_issues) >= data['total']:
            break
        
        params['startAt'] = len(all_issues)

    return all_issues