#!/bin/bash

# Build script for Lambda Docker images
# Usage: ./build.sh [function-name] or ./build.sh all

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
AWS_REGION=${AWS_REGION:-us-west-1}
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

# Function to build and push Docker image
build_and_push() {
    local FUNCTION_NAME=$1
    local DOCKERFILE_DIR=$2
    local SOURCE_FILE=$3

    echo -e "${BLUE}Building ${FUNCTION_NAME}...${NC}"

    # Copy source files to Docker context
    cp "../${SOURCE_FILE}" "${DOCKERFILE_DIR}/"

    # Build image
    docker build -t "${FUNCTION_NAME}:latest" "${DOCKERFILE_DIR}"

    # Tag for ECR
    docker tag "${FUNCTION_NAME}:latest" "${ECR_REGISTRY}/${FUNCTION_NAME}:latest"

    echo -e "${GREEN}✓ Built ${FUNCTION_NAME}${NC}"

    # Push to ECR if --push flag is set
    if [[ "$PUSH_TO_ECR" == "true" ]]; then
        echo -e "${BLUE}Pushing ${FUNCTION_NAME} to ECR...${NC}"

        # Login to ECR
        aws ecr get-login-password --region ${AWS_REGION} | \
            docker login --username AWS --password-stdin ${ECR_REGISTRY}

        # Create repository if it doesn't exist
        aws ecr describe-repositories --repository-names ${FUNCTION_NAME} --region ${AWS_REGION} 2>/dev/null || \
            aws ecr create-repository --repository-name ${FUNCTION_NAME} --region ${AWS_REGION}

        # Push image
        docker push "${ECR_REGISTRY}/${FUNCTION_NAME}:latest"

        echo -e "${GREEN}✓ Pushed ${FUNCTION_NAME} to ECR${NC}"
    fi

    # Cleanup
    rm "${DOCKERFILE_DIR}/${SOURCE_FILE}"
}

# Parse arguments
PUSH_TO_ECR=false
FUNCTION=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --push)
            PUSH_TO_ECR=true
            shift
            ;;
        *)
            FUNCTION=$1
            shift
            ;;
    esac
done

# Build functions
if [[ "$FUNCTION" == "all" ]] || [[ -z "$FUNCTION" ]]; then
    echo -e "${BLUE}Building all Lambda functions...${NC}"
    build_and_push "receipt-ingest" "./receipt-ingest" "handler.py"
    build_and_push "presigned-url" "./presigned-url" "generate_presigned_url.py"
elif [[ "$FUNCTION" == "receipt-ingest" ]]; then
    build_and_push "receipt-ingest" "./receipt-ingest" "handler.py"
elif [[ "$FUNCTION" == "presigned-url" ]]; then
    build_and_push "presigned-url" "./presigned-url" "generate_presigned_url.py"
else
    echo "Unknown function: $FUNCTION"
    echo "Usage: ./build.sh [all|receipt-ingest|presigned-url] [--push]"
    exit 1
fi

echo -e "${GREEN}✓ Build complete!${NC}"

if [[ "$PUSH_TO_ECR" == "true" ]]; then
    echo -e "${GREEN}✓ Images pushed to ECR${NC}"
    echo "ECR Registry: ${ECR_REGISTRY}"
fi
