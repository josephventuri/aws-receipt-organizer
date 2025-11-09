variable "function_name" {
  description = "Name of the Lambda function"
  type        = string
}

variable "description" {
  description = "Description of the Lambda function"
  type        = string
  default     = ""
}

variable "image_uri" {
  description = "URI of the Docker image in ECR"
  type        = string
}

variable "role_arn" {
  description = "ARN of the IAM role for Lambda execution"
  type        = string
}

variable "timeout" {
  description = "Function timeout in seconds"
  type        = number
  default     = 30
}

variable "memory_size" {
  description = "Memory size in MB"
  type        = number
  default     = 128
}

variable "environment_variables" {
  description = "Environment variables for the Lambda function"
  type        = map(string)
  default     = {}
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 30
}

variable "s3_trigger" {
  description = "S3 trigger configuration"
  type = object({
    bucket_id      = string
    bucket_arn     = string
    events         = list(string)
    filter_prefix  = optional(string)
    filter_suffix  = optional(string)
  })
  default = null
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}
