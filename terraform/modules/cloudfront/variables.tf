variable "bucket_domain_name" {
  description = "Domain name of the S3 bucket website endpoint"
  type        = string
}

variable "bucket_id" {
  description = "ID of the S3 bucket"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "price_class" {
  description = "CloudFront price class"
  type        = string
  default     = "PriceClass_100"
}

variable "comment" {
  description = "Comment for the CloudFront distribution"
  type        = string
  default     = "Managed by Terraform"
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}
