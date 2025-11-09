# Receipt Organizer - Deployment Guide

Complete guide for deploying the AI-powered receipt organizer using Docker and Terraform.

## Prerequisites

- AWS CLI configured with appropriate credentials
- Docker installed and running
- Terraform >= 1.0 installed
- AWS account with access to:
  - Lambda
  - S3
  - DynamoDB
  - API Gateway
  - CloudFront
  - Textract
  - SES (Simple Email Service)
  - Bedrock (Claude AI)

## Quick Start

### 1. Verify SES Email Addresses

Before deploying, verify your email addresses in AWS SES:

```bash
# Verify sender email
aws ses verify-email-identity --email-address your-email@example.com --region us-west-2

# Check verification status
aws ses get-identity-verification-attributes \
  --identities your-email@example.com \
  --region us-west-2
```

Click the verification link sent to your email.

### 2. Build and Push Docker Images

```bash
cd docker

# Build both Lambda functions locally
./build.sh all

# Build and push to ECR
./build.sh all --push
```

This will:
- Build Docker images for both Lambda functions
- Create ECR repositories if they don't exist
- Push images to ECR
- Output the image URIs (save these for step 3)

### 3. Configure Terraform

```bash
cd ../terraform

# Copy example variables file
cp terraform.tfvars.example terraform.tfvars

# Edit with your values
vim terraform.tfvars
```

Update `terraform.tfvars` with:
- Your verified SES email addresses
- Docker image URIs from step 2
- AWS region preferences

Example:
```hcl
ses_sender_email    = "you@example.com"
ses_recipient_email = "you@example.com"

lambda_receipt_ingest_image  = "123456789012.dkr.ecr.us-west-1.amazonaws.com/receipt-ingest:latest"
lambda_presigned_url_image   = "123456789012.dkr.ecr.us-west-1.amazonaws.com/presigned-url:latest"
```

### 4. Deploy Infrastructure

```bash
# Initialize Terraform
terraform init

# Review the execution plan
terraform plan

# Deploy infrastructure
terraform apply

# Save outputs (especially the CloudFront URL and API Gateway endpoint)
terraform output > outputs.txt
```

### 5. Deploy Frontend

```bash
# Get the frontend bucket name from Terraform output
FRONTEND_BUCKET=$(terraform output -raw frontend_bucket_name)
CLOUDFRONT_ID=$(terraform output -raw cloudfront_distribution_id)

# Upload frontend files
cd ../frontend
aws s3 sync . s3://${FRONTEND_BUCKET}/ \
  --exclude "*.md" \
  --cache-control "public,max-age=3600"

# Invalidate CloudFront cache
aws cloudfront create-invalidation \
  --distribution-id ${CLOUDFRONT_ID} \
  --paths "/*"
```

### 6. Update Frontend API Endpoint

Get your API Gateway URL:
```bash
cd ../terraform
terraform output api_gateway_url
```

Update `frontend/app.js` with your API Gateway endpoint:
```javascript
const API_ENDPOINT = 'https://your-api-id.execute-api.us-west-1.amazonaws.com/upload-url';
```

Re-upload the frontend:
```bash
cd ../frontend
aws s3 cp app.js s3://${FRONTEND_BUCKET}/app.js
aws cloudfront create-invalidation --distribution-id ${CLOUDFRONT_ID} --paths "/app.js"
```

## Architecture Overview

```
┌─────────────────┐
│  iPhone Camera  │
│    (Frontend)   │
└────────┬────────┘
         │ HTTPS
         ▼
┌─────────────────┐
│   CloudFront    │ ◄── CDN for Frontend
└────────┬────────┘
         │
         ▼
┌─────────────────┐     ┌──────────────────┐
│  API Gateway    │────►│ presigned-url    │
│                 │     │ Lambda (Docker)  │
└─────────────────┘     └──────────────────┘
                               │
                               ▼
         ┌────────────────────────────────┐
         │      S3 Receipts Bucket        │
         └────────┬───────────────────────┘
                  │ Event Trigger
                  ▼
         ┌────────────────────────────────┐
         │   receipt-ingest Lambda        │
         │      (Docker + AI)             │
         └─┬──────┬────────┬──────────┬───┘
           │      │        │          │
     ┌─────▼──┐ ┌─▼─────┐ ┌▼────────┐ ┌▼──────┐
     │Textract│ │Bedrock│ │DynamoDB │ │  SES  │
     │  (OCR) │ │ (AI)  │ │(Storage)│ │(Email)│
     └────────┘ └───────┘ └─────────┘ └───────┘
```

## Environment-Specific Deployments

### Development Environment

```bash
# Use separate tfvars for dev
terraform workspace new dev
terraform apply -var-file="environments/dev/terraform.tfvars"
```

### Production Environment

```bash
# Production deployment
terraform workspace new prod
terraform apply -var-file="environments/prod/terraform.tfvars"
```

## Updating Lambda Functions

When you update Lambda code:

```bash
# Rebuild Docker images
cd docker
./build.sh all --push

# Update Lambda functions
cd ../terraform
terraform apply -target=module.lambda_receipt_ingest
terraform apply -target=module.lambda_presigned_url
```

## Monitoring and Logs

### View Lambda Logs

```bash
# Receipt ingestion logs
aws logs tail /aws/lambda/receipt-organizer-dev-receipt-ingest --follow

# Presigned URL logs
aws logs tail /aws/lambda/receipt-organizer-dev-presigned-url --follow
```

### View API Gateway Logs

```bash
aws logs tail /aws/apigateway/receipt-organizer-dev-api --follow
```

### DynamoDB Data

```bash
# Scan recent receipts
aws dynamodb scan \
  --table-name receipt-organizer-dev-receipts \
  --limit 10
```

## Cost Optimization

### Estimated Monthly Costs (Low Usage - 100 receipts/month)

- **Lambda**: ~$0.20
- **S3**: ~$0.50
- **DynamoDB**: ~$0.25
- **API Gateway**: ~$0.10
- **CloudFront**: ~$0.50
- **Textract**: ~$15.00 (150 pages)
- **Bedrock (Claude)**: ~$0.30 (100 calls)
- **Total**: ~$17/month

### Cost Saving Tips

1. Enable S3 lifecycle policies (already configured)
2. Use PAY_PER_REQUEST for DynamoDB (already configured)
3. Set Lambda memory appropriately (128MB for presigned-url, 256MB for receipt-ingest)
4. Use CloudFront caching effectively

## Troubleshooting

### Email Not Receiving

1. Check SES verification status:
   ```bash
   aws ses get-identity-verification-attributes \
     --identities your-email@example.com \
     --region us-west-2
   ```

2. Check Lambda logs for errors:
   ```bash
   aws logs tail /aws/lambda/receipt-organizer-dev-receipt-ingest --since 10m
   ```

### Upload Failing

1. Check API Gateway endpoint in frontend
2. Verify CORS configuration
3. Check Lambda permissions for S3 PutObject

### AI Insights Not Generating

1. Verify Bedrock access in your AWS region
2. Check IAM permissions for Bedrock
3. Ensure Claude model is available in us-west-2

## Cleanup

To destroy all resources:

```bash
cd terraform
terraform destroy
```

**Warning**: This will delete:
- All S3 buckets and receipts
- DynamoDB table and data
- Lambda functions
- API Gateway
- CloudFront distribution

## Security Best Practices

1. **Enable CloudTrail** for audit logging
2. **Use secrets manager** for sensitive configuration
3. **Enable MFA Delete** on S3 buckets
4. **Restrict IAM permissions** to least privilege
5. **Enable encryption** on all data stores (already configured)
6. **Use VPC** for Lambda functions in production
7. **Implement WAF** rules on CloudFront for production

## Next Steps

1. Set up CI/CD pipeline (GitHub Actions)
2. Add custom domain with Route53
3. Implement monthly summary emails
4. Add budget alerts in AWS
5. Set up monitoring with CloudWatch dashboards

## Support

For issues or questions:
- GitHub Issues: [josephventuri/aws-receipt-organizer/issues](https://github.com/josephventuri/aws-receipt-organizer/issues)
- Documentation: README.md
