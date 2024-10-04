import boto3
import csv
from datetime import datetime
import io
from typing import List, Dict

class S3Handler:
    def __init__(self, bucket_name: str):
        self.s3 = boto3.client('s3')
        self.bucket_name = bucket_name

    def read_csv(self, key: str) -> List[Dict[str, str]]:
        response = self.s3.get_object(Bucket=self.bucket_name, Key=key)
        file_content = response['Body'].read()
        csv_file = io.StringIO(file_content.decode('utf-8'))
        reader = csv.DictReader(csv_file)
        return [row for row in reader]

    def upload_csv(self, data: List[Dict[str, str]]) -> None:
        csv_buffer = io.StringIO()
        writer = csv.DictWriter(csv_buffer, fieldnames=data[0].keys())
        writer.writeheader()
        writer.writerows(data)

        current_time = datetime.now().strftime("%Y%m%d_%H%M%S")
        filename = f"processed/processed_{current_time}.csv"

        self.s3.put_object(
            Bucket=self.bucket_name,
            Key=filename,
            Body=csv_buffer.getvalue()
        )

        print(f"File {filename} uploaded to {self.bucket_name}")
