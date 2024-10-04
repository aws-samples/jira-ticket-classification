provider "aws" {
  region = "us-west-2"  # Change to your desired AWS region
}

# Random string for unique resource naming
resource "random_string" "random_suffix" {
  length  = 8
  special = false
  upper   = false
}


#################################
# IAM
#################################

# Create IAM Role for start-glue-job Lambda
resource "aws_iam_role" "lambda_role_start_glue" {
  name = "lambda_execution_role_start_glue_${random_string.random_suffix.result}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action    = "sts:AssumeRole"
    }]
  })
}

# Attach IAM policy to allow Lambda to start Glue jobs and access S3 and CloudWatch logs
resource "aws_iam_role_policy" "lambda_policy_start_glue" {
  role = aws_iam_role.lambda_role_start_glue.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${aws_lambda_function.start_glue_job_lambda.function_name}:*"
      },
      {
        Effect = "Allow"
        Action = "logs:CreateLogGroup"
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"
      },
      {
        Effect = "Allow"
        Action = "s3:GetObject"
        Resource = "${aws_s3_bucket.bucket.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "glue:StartJobRun",
          "glue:GetJob",
          "glue:GetJobRun"
        ]
        Resource = [
          "arn:aws:glue:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:job/${aws_glue_job.jira_etl_job.name}"
        ]
      }
    ]
  })
}

# Create IAM Role for classify-tickets Lambda
resource "aws_iam_role" "lambda_role_classify_tickets" {
  name = "lambda_execution_role_classify_tickets_${random_string.random_suffix.result}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action    = "sts:AssumeRole"
    }]
  })
}

# Attach IAM policy to allow classify-tickets Lambda to access S3 and CloudWatch logs
resource "aws_iam_role_policy" "lambda_policy_classify_tickets" {
  role = aws_iam_role.lambda_role_classify_tickets.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${aws_lambda_function.classify_tickets_lambda.function_name}:*"
      },
      {
        Effect = "Allow"
        Action = "logs:CreateLogGroup"
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          "${aws_s3_bucket.bucket.arn}",
          "${aws_s3_bucket.bucket.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel"
        ]
        Resource = "*"
      }
    ]
  })
}

# Create IAM Role for fetch-jira-issues Lambda
resource "aws_iam_role" "lambda_role_fetch_jira_issues" {
  name = "lambda_execution_role_fetch_jira_issues_${random_string.random_suffix.result}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

# Attach IAM policy to allow fetch-jira-issues Lambda to access S3, CloudWatch logs, and Secrets Manager
# Update the IAM policy for fetch-jira-issues Lambda
resource "aws_iam_role_policy" "lambda_policy_fetch_jira_issues" {
  role = aws_iam_role.lambda_role_fetch_jira_issues.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${aws_lambda_function.classify_tickets_lambda.function_name}:*"
      },
      {
        Effect = "Allow"
        Action = "logs:CreateLogGroup"
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          "${aws_s3_bucket.bucket.arn}",
          "${aws_s3_bucket.bucket.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = aws_secretsmanager_secret.jira_credentials.arn
      }
    ]
  })
}

# IAM Role for Glue Job
resource "aws_iam_role" "glue_service_role" {
  name = "glue-service-role-${random_string.random_suffix.result}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = {
        Service = "glue.amazonaws.com"
      }
      Action    = "sts:AssumeRole"
    }]
  })
}

# IAM Policy for Glue Job
# IAM Policy for Glue Job
resource "aws_iam_role_policy" "glue_policy" {
  role = aws_iam_role.glue_service_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = [
          "${aws_s3_bucket.bucket.arn}/unprocessed/*",
          "${aws_s3_bucket.bucket.arn}/staged/*",
          "${aws_s3_bucket.bucket.arn}/scripts/*"
        ]
      },
      {
        Effect = "Allow"
        Action = "s3:ListBucket"
        Resource = aws_s3_bucket.bucket.arn
        Condition = {
          StringLike = {
            "s3:prefix": [
              "unprocessed/*",
              "staged/*",
              "scripts/*"
            ]
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws-glue/jobs/output:*"
      },
      {
        Effect = "Allow"
        Action = "logs:CreateLogGroup"
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"
      }
    ]
  })
}


# Required data sources to get current region and account ID
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}


###################
# Secrets Manager
###################

# Create the secret in AWS Secrets Manager
#tfsec:ignore:aws-ssm-secret-use-customer-key
resource "aws_secretsmanager_secret" "jira_credentials" {
  name = "jira-secret-credentials-${random_string.random_suffix.result}"
}

# Create the secret version with placeholder values
resource "aws_secretsmanager_secret_version" "jira_credentials" {
  secret_id     = aws_secretsmanager_secret.jira_credentials.id
  secret_string = jsonencode({
    api_key   = "your-jira-api-key-here",
    email     = "your-jira-email@example.com",
    base_url  = "https://your-jira-instance.atlassian.net"
  })
}

#################################
# Simple Storage Service (S3)
#################################

# Create S3 bucket with unique name
#tfsec:ignore:tfsec:ignore:aws-s3-enable-bucket-logging
resource "aws_s3_bucket" "bucket" {
  bucket = "jira-tickets-${random_string.random_suffix.result}"
  
  tags = {
    Name = "MyS3Bucket"
  }
}

# Enable versioning on the S3 bucket
resource "aws_s3_bucket_versioning" "bucket_versioning" {
  bucket = aws_s3_bucket.bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Add public access block to S3 bucket
resource "aws_s3_bucket_public_access_block" "bucket_public_access_block" {
  bucket = aws_s3_bucket.bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable default encryption for S3 bucket
#tfsec:ignore:aws-s3-encryption-customer-key
resource "aws_s3_bucket_server_side_encryption_configuration" "bucket_encryption" {
  bucket = aws_s3_bucket.bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

#################################
# Lambda Resources Packaging
#################################

# Install dependencies in Lambda function
resource "null_resource" "install_lambda_dependencies_fetch_jira_issues" {
  provisioner "local-exec" {
    command = "pip install -r ${path.module}/../src/lambda/fetch-jira-issues/requirements.txt -t ${path.module}/../src/lambda/fetch-jira-issues/"
  }

  triggers = {
    dependencies_versions = filemd5("${path.module}/../src/lambda/fetch-jira-issues/requirements.txt")
  }
}

# Archive Lambda function (zip the source files) for start-glue-job
data "archive_file" "lambda_package_start_glue" {
  type        = "zip"
  source_dir  = "${path.module}/../src/lambda/start-glue-job"
  output_path = "${path.module}/lambda_function_start_glue_payload.zip"
}

# Archive Lambda function (zip the source files) for classify-tickets
data "archive_file" "lambda_package_classify_tickets" {
  type        = "zip"
  source_dir  = "${path.module}/../src/lambda/classify-tickets"
  output_path = "${path.module}/lambda_function_classify_tickets_payload.zip"
}

data "archive_file" "lambda_package_fetch_jira_issues" {
  type        = "zip"
  source_dir  = "${path.module}/../src/lambda/fetch-jira-issues"
  output_path = "${path.module}/lambda_function_fetch_jira_issues_payload.zip"
  depends_on  = [null_resource.install_lambda_dependencies_fetch_jira_issues]

}


#################################
# Lambda
#################################

# Lambda function resource for start-glue-job
#tfsec:ignore:aws-lambda-enable-tracing
resource "aws_lambda_function" "start_glue_job_lambda" {
  function_name    = "start-glue-job-lambda-${random_string.random_suffix.result}"
  filename         = data.archive_file.lambda_package_start_glue.output_path
  handler          = "main.handler"
  runtime          = "python3.12"
  role             = aws_iam_role.lambda_role_start_glue.arn
  source_code_hash = data.archive_file.lambda_package_start_glue.output_base64sha256

  environment {
    variables = {
      LOG_LEVEL     = "DEBUG"
      GLUE_JOB_NAME = aws_glue_job.jira_etl_job.name
    }
  }

  timeout     = 30
  memory_size = 128
}

# Lambda function resource for classify-tickets
#tfsec:ignore:aws-lambda-enable-tracing
resource "aws_lambda_function" "classify_tickets_lambda" {
  function_name    = "classify-tickets-lambda-${random_string.random_suffix.result}"
  filename         = data.archive_file.lambda_package_classify_tickets.output_path
  handler          = "main.handler"
  runtime          = "python3.12"
  role             = aws_iam_role.lambda_role_classify_tickets.arn
  source_code_hash = data.archive_file.lambda_package_classify_tickets.output_base64sha256

  environment {
    variables = {
      LOG_LEVEL = "DEBUG"
      BUCKET_NAME = aws_s3_bucket.bucket.id
    }
  }

  timeout     = 120
  memory_size = 128
}

# Lambda Permission for S3 to invoke the start-glue-job function
resource "aws_lambda_permission" "allow_s3_invoke_start_glue" {
  statement_id  = "AllowExecutionFromS3ForStartGlue"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.start_glue_job_lambda.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.bucket.arn
}

# Lambda Permission for S3 to invoke the classify-tickets function
resource "aws_lambda_permission" "allow_s3_invoke_classify_tickets" {
  statement_id  = "AllowExecutionFromS3ForClassifyTickets"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.classify_tickets_lambda.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.bucket.arn
}

# Lambda function resource for fetch-jira-issues
#tfsec:ignore:aws-lambda-enable-tracing
resource "aws_lambda_function" "fetch_jira_issues_lambda" {
  function_name    = "fetch-jira-issues-lambda-${random_string.random_suffix.result}"
  filename         = data.archive_file.lambda_package_fetch_jira_issues.output_path
  handler          = "main.lambda_handler"
  runtime          = "python3.12"
  role             = aws_iam_role.lambda_role_fetch_jira_issues.arn
  source_code_hash = data.archive_file.lambda_package_fetch_jira_issues.output_base64sha256

  environment {
    variables = {
      LOG_LEVEL                     = "DEBUG"
      BUCKET_NAME                   = aws_s3_bucket.bucket.id
      JIRA_CREDENTIALS_SECRET       = aws_secretsmanager_secret.jira_credentials.name
      S3_PREFIX                     = "unprocessed"
      PROJECT_IDS_COMMA_SEPARATED   = "TannerTest"
    }
  }

  timeout     = 300
  memory_size = 256
}

#################################
# Lambda Event Triggers
#################################

# S3 Bucket Notification for both Lambda functions
resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.start_glue_job_lambda.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "unprocessed/"
  }

  lambda_function {
    lambda_function_arn = aws_lambda_function.classify_tickets_lambda.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "staged/"
  }

  depends_on = [
    aws_lambda_permission.allow_s3_invoke_start_glue,
    aws_lambda_permission.allow_s3_invoke_classify_tickets
  ]
}

# CloudWatch Events Rule
resource "aws_cloudwatch_event_rule" "daily_jira_fetch" {
  name                = "daily-jira-fetch-${random_string.random_suffix.result}"
  description         = "Triggers the Jira fetch Lambda function daily"
  schedule_expression = "cron(0 1 * * ? *)"  # Runs at 1:00 AM UTC every day
}

# CloudWatch Events Target
resource "aws_cloudwatch_event_target" "fetch_jira_issues_lambda_target" {
  rule      = aws_cloudwatch_event_rule.daily_jira_fetch.name
  target_id = "FetchJiraIssuesLambda"
  arn       = aws_lambda_function.fetch_jira_issues_lambda.arn
}

# Lambda Permission for CloudWatch to invoke the function
resource "aws_lambda_permission" "allow_cloudwatch_to_call_fetch_jira_issues" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.fetch_jira_issues_lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_jira_fetch.arn
}



#################################
# AWS Glue
#################################

# Upload Glue ETL script to S3 (no zip)
resource "aws_s3_object" "etl_script_upload" {
  bucket = aws_s3_bucket.bucket.id
  key    = "scripts/etl_script.py"
  source = "${path.module}/../src/glue/etl_script.py"
}


# Glue ETL Job resource
resource "aws_glue_job" "jira_etl_job" {
  name        = "jira-etl-${random_string.random_suffix.result}"
  role_arn    = aws_iam_role.glue_service_role.arn
  command {
    name            = "glueetl"
    script_location = "s3://${aws_s3_bucket.bucket.bucket}/scripts/etl_script.py"
    python_version  = "3"
  }
  
  default_arguments = {
    "--job-bookmark-option" = "job-bookmark-enable"
  }
  
  max_retries     = 0
  glue_version    = "4.0"
  worker_type     = "G.1X"
  number_of_workers = 2
  timeout         = 10
  tags = {
    Name = "JiraETLJob"
  }
}


#################################
# Outputs
#################################

# Outputs
output "s3_bucket_name" {
  value = aws_s3_bucket.bucket.bucket
}

output "start_glue_job_lambda_arn" {
  value = aws_lambda_function.start_glue_job_lambda.arn
}

output "classify_tickets_lambda_arn" {
  value = aws_lambda_function.classify_tickets_lambda.arn
}

output "glue_job_name" {
  value = aws_glue_job.jira_etl_job.name
}

# Output the new Lambda function ARN
output "fetch_jira_issues_lambda_arn" {
  value = aws_lambda_function.fetch_jira_issues_lambda.arn
}