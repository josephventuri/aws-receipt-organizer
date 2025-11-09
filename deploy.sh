#!/bin/bash

# Automated deployment script for Receipt Organizer
# Usage: ./deploy.sh [dev|prod]

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

ENVIRONMENT=${1:-dev}

echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Receipt Organizer - Deployment Script        ║${NC}"
echo -e "${BLUE}║  Environment: ${ENVIRONMENT}                               ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
echo ""

# Step 1: Build and Push Docker Images
echo -e "${YELLOW}[1/5] Building and pushing Docker images...${NC}"
cd docker
./build.sh all --push
cd ..
echo -e "${GREEN}✓ Docker images built and pushed${NC}"
echo ""

# Step 2: Initialize Terraform
echo -e "${YELLOW}[2/5] Initializing Terraform...${NC}"
cd terraform
terraform init
echo -e "${GREEN}✓ Terraform initialized${NC}"
echo ""

# Step 3: Plan Infrastructure
echo -e "${YELLOW}[3/5] Planning infrastructure changes...${NC}"
terraform plan -out=tfplan
echo -e "${GREEN}✓ Terraform plan created${NC}"
echo ""

# Step 4: Apply Infrastructure
echo -e "${YELLOW}[4/5] Deploying infrastructure...${NC}"
echo -e "${RED}This will create/modify AWS resources. Continue? (yes/no)${NC}"
read -r CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo -e "${RED}Deployment cancelled${NC}"
    exit 1
fi

terraform apply tfplan
echo -e "${GREEN}✓ Infrastructure deployed${NC}"
echo ""

# Step 5: Deploy Frontend
echo -e "${YELLOW}[5/5] Deploying frontend to S3...${NC}"
FRONTEND_BUCKET=$(terraform output -raw frontend_bucket_name)
CLOUDFRONT_ID=$(terraform output -raw cloudfront_distribution_id)
API_ENDPOINT=$(terraform output -raw api_gateway_url)

echo -e "${BLUE}Frontend Bucket: ${FRONTEND_BUCKET}${NC}"
echo -e "${BLUE}CloudFront ID: ${CLOUDFRONT_ID}${NC}"
echo -e "${BLUE}API Endpoint: ${API_ENDPOINT}${NC}"
echo ""

# Update API endpoint in frontend
cd ../frontend
sed -i.bak "s|const API_ENDPOINT = .*|const API_ENDPOINT = '${API_ENDPOINT}/upload-url';|" app.js
rm app.js.bak

# Sync to S3
aws s3 sync . "s3://${FRONTEND_BUCKET}/" \
  --exclude "*.md" \
  --exclude "*.bak" \
  --cache-control "public,max-age=3600"

# Invalidate CloudFront cache
aws cloudfront create-invalidation \
  --distribution-id "${CLOUDFRONT_ID}" \
  --paths "/*"

echo -e "${GREEN}✓ Frontend deployed${NC}"
echo ""

# Show outputs
cd ../terraform
echo -e "${GREEN}╔════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║          Deployment Complete! 🎉                ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Application URL:${NC}"
terraform output cloudfront_distribution_url
echo ""
echo -e "${BLUE}API Endpoint:${NC}"
terraform output api_gateway_url
echo ""
echo -e "${BLUE}Next Steps:${NC}"
echo "1. Open the CloudFront URL in your browser"
echo "2. Add to iPhone home screen for app-like experience"
echo "3. Take a photo of a receipt and upload!"
echo ""
echo -e "${YELLOW}Note: CloudFront may take 10-15 minutes to fully propagate${NC}"
