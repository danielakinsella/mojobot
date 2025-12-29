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
