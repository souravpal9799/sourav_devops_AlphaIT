#!/bin/bash

# Setup S3 backend for Terraform state
# This script automatically fetches the AWS account ID and configures S3 backend

set -e

echo "🔧 Setting up Terraform S3 backend..."

# Get AWS account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

if [ -z "$ACCOUNT_ID" ]; then
    echo "❌ Failed to get AWS account ID. Ensure AWS CLI is configured."
    exit 1
fi

echo "✓ AWS Account ID: $ACCOUNT_ID"

# Set variables
BUCKET_NAME="terraform-state-demo-devops-${ACCOUNT_ID}"
REGION="ap-south-1"
DYNAMODB_TABLE="terraform-state-lock"
STATE_KEY="infrastructure.tfstate"

# Create backend-config.hcl
cat > backend-config.hcl << EOF
# Backend configuration for S3 state storage
# Auto-generated on $(date)
# Account ID: $ACCOUNT_ID

bucket         = "$BUCKET_NAME"
key            = "$STATE_KEY"
region         = "$REGION"
encrypt        = true
dynamodb_table = "$DYNAMODB_TABLE"
EOF

echo "✓ Created backend-config.hcl with Account ID: $ACCOUNT_ID"
echo "✓ S3 Bucket: $BUCKET_NAME"
echo ""
echo "📋 Next steps:"
echo "1. Create S3 bucket and DynamoDB table:"
echo "   terraform apply -target=module.tf_state"
echo ""
echo "2. Initialize Terraform with S3 backend:"
echo "   terraform init -backend-config=backend-config.hcl"
echo ""
echo "✅ Setup complete!"
