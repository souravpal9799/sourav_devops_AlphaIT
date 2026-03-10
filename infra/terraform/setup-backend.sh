#!/bin/bash

# Setup S3 backend for Terraform state
# This script automatically fetches the AWS account ID and configures S3 backend

set -e

echo "[INFO] Setting up Terraform S3 backend..."

# Get AWS account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

if [ -z "$ACCOUNT_ID" ]; then
    echo "[ERROR] Failed to get AWS account ID. Ensure AWS CLI is configured."
    exit 1
fi

echo "[OK] AWS Account ID: $ACCOUNT_ID"

# Set variables
BUCKET_NAME="terraform-state-demo-devops-${ACCOUNT_ID}"
REGION="ap-south-1"
DYNAMODB_TABLE="terraform-state-lock"
STATE_KEY="infrastructure.tfstate"

# 1. Create S3 Bucket if it doesn't exist
if aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
    echo "[OK] S3 Bucket $BUCKET_NAME already exists."
else
    echo "[INFO] Creating S3 Bucket $BUCKET_NAME..."
    aws s3api create-bucket \
        --bucket "$BUCKET_NAME" \
        --region "$REGION" \
        --create-bucket-configuration LocationConstraint="$REGION"
    
    # Enable versioning
    aws s3api put-bucket-versioning \
        --bucket "$BUCKET_NAME" \
        --versioning-configuration Status=Enabled
    
    # Enable encryption
    aws s3api put-bucket-encryption \
        --bucket "$BUCKET_NAME" \
        --server-side-encryption-configuration '{
            "Rules": [
                {
                    "ApplyServerSideEncryptionByDefault": {
                        "SSEAlgorithm": "AES256"
                    }
                }
            ]
        }'
    
    # Block public access
    aws s3api put-public-access-block \
        --bucket "$BUCKET_NAME" \
        --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
    
    echo "[OK] S3 Bucket created and secured."
fi

# 2. Create DynamoDB Table if it doesn't exist
if aws dynamodb describe-table --table-name "$DYNAMODB_TABLE" --region "$REGION" 2>/dev/null; then
    echo "[OK] DynamoDB table $DYNAMODB_TABLE already exists."
else
    echo "[INFO] Creating DynamoDB table $DYNAMODB_TABLE..."
    aws dynamodb create-table \
        --table-name "$DYNAMODB_TABLE" \
        --region "$REGION" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5
    
    echo "[INFO] Waiting for DynamoDB table to be ready..."
    aws dynamodb wait table-exists --table-name "$DYNAMODB_TABLE" --region "$REGION"
    echo "[OK] DynamoDB table created."
fi

# 3. Create backend-config.hcl
cat > backend-config.hcl << EOF
# Backend configuration for S3 state storage
# Auto-generated on $(date)
# Account ID: $ACCOUNT_ID

bucket         = "$BUCKET_NAME"
key            = "$STATE_KEY"
region         = "$REGION"
encrypt        = true
#dynamodb_table = "$DYNAMODB_TABLE"
EOF

echo "[OK] Created backend-config.hcl"
echo "[OK] S3 Bucket: $BUCKET_NAME"
echo ""
echo "[INFO] Next steps:"
echo "1. Initialize Terraform with S3 backend:"
echo "   terraform init -backend-config=backend-config.hcl"
echo ""
echo "[OK] Setup complete!"
