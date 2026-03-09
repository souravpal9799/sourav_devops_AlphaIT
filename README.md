# DevOps EKS Solution

A production-ready DevOps MVP project on AWS. This repository provisions infrastructure via Terraform and deploys a full-stack application to Amazon EKS using a modern CI/CD pipeline.

---

## Submission Note

*   **Access Endpoints:** Both **Frontend** and **Backend** URLs are dynamically generated. To view them:
    *   **CI/CD:** Check the `Terraform Apply` step in the GitHub Actions workflow logs.
    *   **Locally:** Run `terraform output` from the `infra/terraform` directory.
*   **CI/CD used:** GitHub Actions (Automated: Triggers on every push/commit to the `main` branch).
*   **How backend connects to RDS:** The FastAPI application uses **IAM Roles for Service Accounts (IRSA)** to securely retrieve database credentials from **AWS Secrets Manager** at runtime.
*   **CloudWatch dashboard:** `demo-devops-dashboard` (Provides metrics for EKS Node CPU/Memory and RDS Performance).
*   **Assumptions:**
    *   Deployment is performed in the `ap-south-1` (Mumbai) region.
    *   The AWS Load Balancer Controller is installed via Helm to manage the ALB Ingress.
    *   Pods are deployed in private subnets and exposed via an internet-facing ALB in public subnets.
    *   Database schema is automatically initialized by the backend on its first successful connection to RDS.

---

## Architecture Overview

The system architecture follows AWS best practices for security, scalability, and high availability:

*   **VPC Infrastructure**: Multi-AZ VPC with Public and Private subnets.
*   **EKS Cluster**: Managed Kubernetes service hosting the application pods in private subnets.
*   **ALB Ingress**: AWS Application Load Balancer routes traffic to the target services (Path-based: `/api` for Backend, `/` for Frontend).
*   **RDS Database**: Managed PostgreSQL/MySQL located in private subnets, accessible only from the EKS nodes.
*   **Security**: IAM Roles for Service Accounts (IRSA) grant pods least-privileged access to AWS Secrets Manager.
*   **Logs & Metrics**: CloudWatch Logs and Metrics for comprehensive visibility.

---

## Deploying in a new AWS account (Alpha)

### Prerequisites
Before you begin, ensure you have the following installed and configured:
*   [AWS CLI](https://aws.amazon.com/cli/) (authenticated with your target account)
*   [Terraform](https://www.terraform.io/downloads.html) (>= 1.0)
*   [kubectl](https://kubernetes.io/docs/tasks/tools/)
*   [Helm](https://helm.sh/docs/intro/install/)
*   A domain (optional, if using custom SSL/TLS)

### 1. Required Terraform Variables (`terraform.tfvars`)
Create a file named `infra/terraform/terraform.tfvars` with the following:
```hcl
project_name = "your-project-name"
aws_region   = "ap-south-1"
environment  = "production"
```

### 2. Required AWS Permissions & Roles
*   **Deployment Identity:** Ensure your AWS CLI/Terraform user has at least the following policies attached for successful provisioning:
    *   `AmazonDynamoDBFullAccess`
    *   `AmazonEC2ContainerRegistryFullAccess`
    *   `AmazonRDSFullAccess`
    *   `AmazonS3FullAccess`
    *   `AmazonVPCFullAccess`
    *   `SecretsManagerReadWrite`
    *   `IAMFullAccess`
    *   `AmazonEKSClusterPolicy`
*   **EKS Standard Roles:** The project creates specific IAM roles for the EKS Cluster and Node Groups with policies like `AmazonEKSClusterPolicy`, `AmazonEKSWorkerNodePolicy`, and `AmazonEC2ContainerRegistryReadOnly`.
*   **IRSA:** Pod-level security is managed via IAM OpenID Connect (OIDC) providers.

### 3. CI/CD Variables
If using the provided GitHub Actions pipeline, set the following **Secrets** in your repository:
*   `AWS_ACCESS_KEY_ID`: Your AWS access key.
*   `AWS_SECRET_ACCESS_KEY`: Your AWS secret key.

> [!NOTE]
> The setup is fully automated. Any code push or merged pull request to the **main** branch will automatically trigger the CI/CD pipeline, starting a full deployment (Lint -> Build -> Push -> Terraform -> Kubernetes -> Smoke Test).

### 4. Step-by-Step Deployment Commands

#### A. Infrastructure Provisioning (Terraform)
```bash
cd infra/terraform

# 1. Initialize AWS Backend (S3 Bucket + DynamoDB Table)
# This script creates the S3 bucket and DynamoDB lock table via AWS CLI
# to avoid circular dependencies in Terraform.
bash setup-backend.sh 

# 2. Deploy Infrastructure
terraform init -backend-config=backend-config.hcl -lock=false
terraform plan
terraform apply --auto-approve -lock=false
```

> [!TIP]
> After `terraform apply` finishes, the **Frontend** and **Backend URLs** (Public DNS) will be automatically displayed in the Terraform outputs. If running via GitHub Actions, check the `Terraform Apply` step in the workflow logs for these endpoints.

#### B. Kubernetes Configuration & Deployment
After Terraform finishes, update your local kubeconfig:
```bash
# Update cluster name if you changed it in tfvars
aws eks update-kubeconfig --name demo-devops-cluster --region ap-south-1
```

```bash
# 1. Fetch the dynamic RDS Secret name from Terraform outputs
export RDS_SECRET_NAME=$(terraform output -raw rds_secret_name)

# 2. Apply Kubernetes Manifests (Injecting variables)
export BACKEND_IMAGE="your-account-id.dkr.ecr.ap-south-1.amazonaws.com/backend-app:latest"
export FRONTEND_IMAGE="your-account-id.dkr.ecr.ap-south-1.amazonaws.com/frontend-app:latest"

kubectl apply -f infra/kubernetes/namespace.yaml
kubectl apply -f infra/kubernetes/service.yaml
kubectl apply -f infra/kubernetes/cluster-secret-store.yaml

# Use envsubst to inject secret names and images
envsubst < infra/kubernetes/external-secret.yaml | kubectl apply -f -
envsubst < infra/kubernetes/backend-deployment.yaml | kubectl apply -f -
envsubst < infra/kubernetes/frontend-deployment.yaml | kubectl apply -f -
kubectl apply -f infra/kubernetes/ingress.yaml
```

---

## Verification & Observability

### 1. Verification Steps
*   **Health Checks**: Access `http://<ALB_URL>/health` and `http://<ALB_URL>/api/health`.
*   **Pod Status**: Run `kubectl get pods -n demo-namespace` to ensure all pods are `Running`.
*   **Ingress Status**: Run `kubectl get ingress -n demo-namespace` to verify the ALB address is assigned.

### 2. CloudWatch Dashboard
The project provisions a comprehensive dashboard (`demo-devops-dashboard`) containing:
*   **ALB Metrics**: Request Count, Target Response Time, and Target 5XX Error Count (via Search expressions).
*   **RDS Metrics**: CPU Utilization, Database Connections, and Free Storage Space.
*   **EKS Node Metrics**: Node CPU and Memory Utilization.

---

## Runbook & Troubleshooting

### 1. Where to check logs
*   **Pod Logs**: `kubectl logs -l app=backend -n demo-namespace` or `kubectl logs -l app=frontend -n demo-namespace`.
*   **CloudWatch Logs**: Navigate to Log Group `/aws/containerinsights/demo-devops-cluster/application`.
*   **ALB Controller Logs**: `kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller`.

### 2. Troubleshooting Unhealthy Targets
If the ALB Target Group shows targets as "Unhealthy":
*   Check pod status: `kubectl get pods -n demo-namespace`.
*   Check service health endpoints locally: `kubectl port-forward svc/backend 8000:80 -n demo-namespace` then hit `localhost:8000/api/health`.
*   Verify Security Groups: Ensure EKS Node SGs allow traffic from the ALB SG on the target ports.

### 3. Rollback Approach
*   **CI/CD Rollback**: Revert the commit on the `main` branch to trigger a redeploy of the previous version.
*   **Kubernetes Rollback**: Run `kubectl rollout undo deployment/backend -n demo-namespace`.
*   **Terraform Rollback**: Revert infrastructure changes in code and run `terraform apply`.

---

## Cleanup (Destroy)
To tear down the entire environment and avoid AWS costs:
```bash
cd infra/terraform

# Run the automated cleanup script
# This script force-deletes hung K8s namespaces and cleans up orphaned ALBs
# before running terraform destroy to ensure a clean teardown.
bash cleanup.sh
```
