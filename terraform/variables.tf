variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "receipt-organizer"
}

variable "environment" {
  description = "Environment name (dev, prod)"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-west-1"
}

variable "ses_region" {
  description = "AWS region for SES (must be where email is verified)"
  type        = string
  default     = "us-west-2"
}

variable "bedrock_region" {
  description = "AWS region for Bedrock (Claude AI)"
  type        = string
  default     = "us-west-2"
}

variable "ses_sender_email" {
  description = "Verified SES sender email address"
  type        = string
}

variable "ses_recipient_email" {
  description = "Email address to receive receipt notifications"
  type        = string
}

variable "lambda_receipt_ingest_image" {
  description = "Docker image URI for receipt-ingest Lambda"
  type        = string
}

variable "lambda_presigned_url_image" {
  description = "Docker image URI for presigned-url Lambda"
  type        = string
}

variable "cloudfront_price_class" {
  description = "CloudFront price class"
  type        = string
  default     = "PriceClass_100" # US, Canada, Europe
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Project   = "ReceiptOrganizer"
    ManagedBy = "Terraform"
  }
}
