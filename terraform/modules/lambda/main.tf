resource "aws_lambda_function" "this" {
  function_name = var.function_name
  description   = var.description
  role          = var.role_arn

  package_type = "Image"
  image_uri    = var.image_uri

  timeout     = var.timeout
  memory_size = var.memory_size

  environment {
    variables = var.environment_variables
  }

  tags = merge(
    var.tags,
    {
      Name = var.function_name
    }
  )
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = var.log_retention_days

  tags = merge(
    var.tags,
    {
      Name = "/aws/lambda/${var.function_name}"
    }
  )
}

# S3 Trigger (if configured)
resource "aws_lambda_permission" "s3" {
  count = var.s3_trigger != null ? 1 : 0

  statement_id  = "AllowExecutionFromS3"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = var.s3_trigger.bucket_arn
}

resource "aws_s3_bucket_notification" "this" {
  count  = var.s3_trigger != null ? 1 : 0
  bucket = var.s3_trigger.bucket_id

  lambda_function {
    lambda_function_arn = aws_lambda_function.this.arn
    events              = var.s3_trigger.events
    filter_prefix       = lookup(var.s3_trigger, "filter_prefix", null)
    filter_suffix       = lookup(var.s3_trigger, "filter_suffix", null)
  }

  depends_on = [aws_lambda_permission.s3]
}
