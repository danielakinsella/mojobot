################################################################################
# S3 Bucket for Diary Entries (Source Data)
################################################################################

resource "aws_s3_bucket" "mojobot_diary" {
  bucket        = "${var.app_name}-diary-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "mojobot_diary" {
  bucket = aws_s3_bucket.mojobot_diary.id
  versioning_configuration {
    status = "Enabled"
  }
}

################################################################################
# Bedrock Knowledge Base with S3 Vectors (via CloudFormation)
################################################################################

resource "aws_cloudformation_stack" "mojobot_knowledge_base" {
  name = "${var.app_name}-kb-stack"

  template_body = jsonencode({
    AWSTemplateFormatVersion = "2010-09-09"
    Description              = "Bedrock Knowledge Base with S3 Vectors for Mojobot"
    Resources = {
      VectorBucket = {
        Type = "AWS::S3Vectors::VectorBucket"
        Properties = {
          VectorBucketName = "${var.app_name}-vectors-${data.aws_caller_identity.current.account_id}"
        }
      }
      VectorIndex = {
        Type      = "AWS::S3Vectors::Index"
        DependsOn = ["VectorBucket"]
        Properties = {
          VectorBucketName = "${var.app_name}-vectors-${data.aws_caller_identity.current.account_id}"
          IndexName        = "${var.app_name}-kb-index"
          DataType         = "float32"
          Dimension        = 1024
          DistanceMetric   = "cosine"
        }
      }
      KnowledgeBase = {
        Type = "AWS::Bedrock::KnowledgeBase"
        DependsOn = ["VectorIndex"]
        Properties = {
          Name    = "${var.app_name}_diary_kb"
          RoleArn = aws_iam_role.mojobot_kb_role.arn
          KnowledgeBaseConfiguration = {
            Type = "VECTOR"
            VectorKnowledgeBaseConfiguration = {
              EmbeddingModelArn = "arn:aws:bedrock:${data.aws_region.current.id}::foundation-model/amazon.titan-embed-text-v2:0"
            }
          }
          StorageConfiguration = {
            Type = "S3_VECTORS"
            S3VectorsConfiguration = {
              IndexArn = { "Fn::GetAtt" = ["VectorIndex", "IndexArn"] }
            }
          }
        }
      }
      DataSource = {
        Type = "AWS::Bedrock::DataSource"
        Properties = {
          Name               = "${var.app_name}_diary_source"
          KnowledgeBaseId    = { "Fn::GetAtt" = ["KnowledgeBase", "KnowledgeBaseId"] }
          DataDeletionPolicy = "DELETE"
          DataSourceConfiguration = {
            Type = "S3"
            S3Configuration = {
              BucketArn = aws_s3_bucket.mojobot_diary.arn
            }
          }
        }
      }
    }
    Outputs = {
      KnowledgeBaseId = {
        Value = { "Fn::GetAtt" = ["KnowledgeBase", "KnowledgeBaseId"] }
      }
      DataSourceId = {
        Value = { "Fn::GetAtt" = ["DataSource", "DataSourceId"] }
      }
      VectorBucketArn = {
        Value = { "Fn::GetAtt" = ["VectorBucket", "VectorBucketArn"] }
      }
      IndexArn = {
        Value = { "Fn::GetAtt" = ["VectorIndex", "IndexArn"] }
      }
    }
  })

  depends_on = [aws_iam_role_policy.mojobot_kb_policy]
}

################################################################################
# IAM Role for Knowledge Base
################################################################################

resource "aws_iam_role" "mojobot_kb_role" {
  name = "${var.app_name}-kb-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRole"
      Principal = {
        Service = "bedrock.amazonaws.com"
      }
      Condition = {
        StringEquals = {
          "aws:SourceAccount" = data.aws_caller_identity.current.account_id
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "mojobot_kb_policy" {
  role = aws_iam_role.mojobot_kb_role.id
  name = "${var.app_name}-kb-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3DataSourceAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.mojobot_diary.arn,
          "${aws_s3_bucket.mojobot_diary.arn}/*"
        ]
      },
      {
        Sid    = "BedrockEmbeddings"
        Effect = "Allow"
        Action = ["bedrock:InvokeModel"]
        Resource = [
          "arn:aws:bedrock:${data.aws_region.current.id}::foundation-model/amazon.titan-embed-text-v2:0"
        ]
      },
      {
        Sid    = "S3VectorsAccess"
        Effect = "Allow"
        Action = [
          "s3vectors:CreateIndex",
          "s3vectors:DeleteIndex",
          "s3vectors:GetIndex",
          "s3vectors:ListIndexes",
          "s3vectors:PutVectors",
          "s3vectors:GetVectors",
          "s3vectors:DeleteVectors",
          "s3vectors:QueryVectors"
        ]
        Resource = "*"
      }
    ]
  })
}

################################################################################
# Lambda for Auto-Sync on S3 Upload
################################################################################

resource "aws_lambda_function" "kb_sync" {
  function_name = "${var.app_name}-kb-sync"
  runtime       = "python3.12"
  handler       = "index.handler"
  role          = aws_iam_role.kb_sync_role.arn
  timeout       = 30

  filename         = data.archive_file.kb_sync_lambda.output_path
  source_code_hash = data.archive_file.kb_sync_lambda.output_base64sha256

  environment {
    variables = {
      KNOWLEDGE_BASE_ID = aws_cloudformation_stack.mojobot_knowledge_base.outputs["KnowledgeBaseId"]
      DATA_SOURCE_ID    = aws_cloudformation_stack.mojobot_knowledge_base.outputs["DataSourceId"]
    }
  }
}

data "archive_file" "kb_sync_lambda" {
  type        = "zip"
  output_path = "${path.module}/kb_sync_lambda.zip"

  source {
    content  = <<-EOF
      import boto3
      import os
      import logging

      logger = logging.getLogger()
      logger.setLevel(logging.INFO)

      def handler(event, context):
          client = boto3.client('bedrock-agent')
          try:
              response = client.start_ingestion_job(
                  knowledgeBaseId=os.environ['KNOWLEDGE_BASE_ID'],
                  dataSourceId=os.environ['DATA_SOURCE_ID']
              )
              ingestion_job_id = response.get('ingestionJob', {}).get('ingestionJobId')
              logger.info("Started ingestion job: %s", ingestion_job_id)
              return {
                  'statusCode': 200,
                  'body': f"Started ingestion job: {ingestion_job_id}"
              }
          except Exception as e:
              logger.error("Failed to start ingestion job", exc_info=True)
              return {
                  'statusCode': 500,
                  'body': "Failed to start ingestion job"
              }
    EOF
    filename = "index.py"
  }
}

resource "aws_iam_role" "kb_sync_role" {
  name = "${var.app_name}-kb-sync-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRole"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "kb_sync_policy" {
  role = aws_iam_role.kb_sync_role.id
  name = "${var.app_name}-kb-sync-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["bedrock-agent:StartIngestionJob"]
        Resource = "arn:aws:bedrock:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:knowledge-base/*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.app_name}-kb-sync*"
      }
    ]
  })
}

resource "aws_lambda_permission" "s3_invoke" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.kb_sync.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.mojobot_diary.arn
}

resource "aws_s3_bucket_notification" "diary_notification" {
  bucket = aws_s3_bucket.mojobot_diary.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.kb_sync.arn
    events              = ["s3:ObjectCreated:*", "s3:ObjectRemoved:*"]
  }

  depends_on = [aws_lambda_permission.s3_invoke]
}

################################################################################
# Outputs
################################################################################

output "knowledge_base_id" {
  description = "Knowledge Base ID"
  value       = aws_cloudformation_stack.mojobot_knowledge_base.outputs["KnowledgeBaseId"]
}

output "diary_bucket_name" {
  description = "S3 bucket for diary entries"
  value       = aws_s3_bucket.mojobot_diary.id
}

output "vector_bucket_arn" {
  description = "S3 Vector bucket ARN"
  value       = aws_cloudformation_stack.mojobot_knowledge_base.outputs["VectorBucketArn"]
}
