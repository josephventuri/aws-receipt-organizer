output "receipts_bucket_name" {
  description = "Name of the S3 bucket for receipt storage"
  value       = module.s3_receipts.bucket_name
}

output "frontend_bucket_name" {
  description = "Name of the S3 bucket for frontend hosting"
  value       = module.s3_frontend.bucket_name
}

output "frontend_website_url" {
  description = "S3 website endpoint for frontend"
  value       = module.s3_frontend.bucket_website_endpoint
}

output "cloudfront_distribution_url" {
  description = "CloudFront distribution domain name"
  value       = module.cloudfront.distribution_domain_name
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID (for cache invalidation)"
  value       = module.cloudfront.distribution_id
}

output "api_gateway_url" {
  description = "API Gateway endpoint URL"
  value       = module.api_gateway.api_endpoint
}

output "dynamodb_table_name" {
  description = "DynamoDB table name for receipts"
  value       = module.dynamodb_receipts.table_name
}

output "lambda_receipt_ingest_arn" {
  description = "ARN of the receipt-ingest Lambda function"
  value       = module.lambda_receipt_ingest.function_arn
}

output "lambda_presigned_url_arn" {
  description = "ARN of the presigned-url Lambda function"
  value       = module.lambda_presigned_url.function_arn
}
