# Setup S3 backend for Terraform state (PowerShell version)
# This script automatically fetches the AWS account ID and configures S3 backend

param(
    [string]$ProjectName = "demo-devops",
    [string]$Region = "ap-south-1"
)

Write-Host "🔧 Setting up Terraform S3 backend..." -ForegroundColor Green

# Get AWS account ID
try {
    $AccountId = aws sts get-caller-identity --query Account --output text
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to retrieve AWS account ID"
    }
} catch {
    Write-Host "❌ Failed to get AWS account ID. Ensure AWS CLI is configured." -ForegroundColor Red
    exit 1
}

Write-Host "✓ AWS Account ID: $AccountId" -ForegroundColor Green

# Set variables
$BucketName = "terraform-state-${ProjectName}-${AccountId}"
$DynamoDBTable = "terraform-state-lock"
$StateKey = "infrastructure.tfstate"
$Date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

# Create backend-config.hcl
$BackendConfig = @"
# Backend configuration for S3 state storage
# Auto-generated on $Date
# Account ID: $AccountId

bucket         = "$BucketName"
key            = "$StateKey"
region         = "$Region"
encrypt        = true
dynamodb_table = "$DynamoDBTable"
"@

$BackendConfig | Out-File -FilePath "backend-config.hcl" -Encoding UTF8

Write-Host "✓ Created backend-config.hcl with Account ID: $AccountId" -ForegroundColor Green
Write-Host "✓ S3 Bucket: $BucketName" -ForegroundColor Green
Write-Host ""
Write-Host "📋 Next steps:" -ForegroundColor Cyan
Write-Host "1. Create S3 bucket and DynamoDB table:"
Write-Host "   terraform apply -target=module.tf_state" -ForegroundColor Yellow
Write-Host ""
Write-Host "2. Initialize Terraform with S3 backend:"
Write-Host "   terraform init -backend-config=backend-config.hcl" -ForegroundColor Yellow
Write-Host ""
Write-Host "✅ Setup complete!" -ForegroundColor Green
