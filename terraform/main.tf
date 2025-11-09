terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Uncomment for remote state management
  # backend "s3" {
  #   bucket         = "your-terraform-state-bucket"
  #   key            = "receipt-organizer/terraform.tfstate"
  #   region         = "us-west-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-state-lock"
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = var.tags
  }
}

provider "aws" {
  alias  = "ses_region"
  region = var.ses_region

  default_tags {
    tags = var.tags
  }
}

provider "aws" {
  alias  = "bedrock_region"
  region = var.bedrock_region

  default_tags {
    tags = var.tags
  }
}

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# S3 Buckets
module "s3_receipts" {
  source = "./modules/s3"

  bucket_name = "${local.name_prefix}-receipts"
  environment = var.environment

  enable_versioning = true
  enable_encryption = true

  lifecycle_rules = [
    {
      id      = "archive-old-receipts"
      enabled = true
      transitions = [
        {
          days          = 90
          storage_class = "STANDARD_IA"
        },
        {
          days          = 365
          storage_class = "GLACIER"
        }
      ]
    }
  ]
}

module "s3_frontend" {
  source = "./modules/s3"

  bucket_name       = "${local.name_prefix}-frontend"
  environment       = var.environment
  enable_versioning = false
  enable_encryption = true
  enable_website    = true

  website_config = {
    index_document = "index.html"
    error_document = "index.html"
  }
}

# DynamoDB Table
module "dynamodb_receipts" {
  source = "./modules/dynamodb"

  table_name   = "${local.name_prefix}-receipts"
  environment  = var.environment
  hash_key     = "receiptId"
  billing_mode = "PAY_PER_REQUEST"

  attributes = [
    {
      name = "receiptId"
      type = "S"
    }
  ]

  ttl_enabled        = false
  point_in_time_recovery = true
}

# IAM Roles and Policies
module "iam_lambda" {
  source = "./modules/iam"

  name_prefix         = local.name_prefix
  environment         = var.environment
  receipts_bucket_arn = module.s3_receipts.bucket_arn
  dynamodb_table_arn  = module.dynamodb_receipts.table_arn
  bedrock_region      = var.bedrock_region
}

# Lambda Functions
module "lambda_receipt_ingest" {
  source = "./modules/lambda"

  function_name = "${local.name_prefix}-receipt-ingest"
  description   = "Process uploaded receipts with Textract and AI insights"

  image_uri = var.lambda_receipt_ingest_image
  role_arn  = module.iam_lambda.lambda_role_arn

  environment_variables = {
    TABLE_NAME  = module.dynamodb_receipts.table_name
    SES_FROM    = var.ses_sender_email
    SES_TO      = var.ses_recipient_email
    SES_REGION  = var.ses_region
  }

  timeout     = 60
  memory_size = 256

  # S3 trigger
  s3_trigger = {
    bucket_id  = module.s3_receipts.bucket_id
    bucket_arn = module.s3_receipts.bucket_arn
    events     = ["s3:ObjectCreated:*"]
    filter_prefix = "receipts/"
  }
}

module "lambda_presigned_url" {
  source = "./modules/lambda"

  function_name = "${local.name_prefix}-presigned-url"
  description   = "Generate presigned URLs for S3 uploads"

  image_uri = var.lambda_presigned_url_image
  role_arn  = module.iam_lambda.lambda_role_arn

  environment_variables = {}

  timeout     = 10
  memory_size = 128
}

# API Gateway
module "api_gateway" {
  source = "./modules/api-gateway"

  api_name    = "${local.name_prefix}-api"
  environment = var.environment

  lambda_function_arn  = module.lambda_presigned_url.function_arn
  lambda_function_name = module.lambda_presigned_url.function_name
}

# CloudFront Distribution
module "cloudfront" {
  source = "./modules/cloudfront"

  bucket_domain_name   = module.s3_frontend.bucket_website_endpoint
  bucket_id            = module.s3_frontend.bucket_id
  environment          = var.environment
  price_class          = var.cloudfront_price_class
  comment              = "${local.name_prefix} Frontend Distribution"
}
