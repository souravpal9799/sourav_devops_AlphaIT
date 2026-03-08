# DevOps EKS Solution

A production-ready DevOps MVP project on AWS. This repository provisions infrastructure via Terraform and deploys a full-stack application to Amazon EKS using a modern CI/CD pipeline.

---

## 📝 Submission Note

*   **Frontend URL (ALB endpoint):** [http://k8s-demoname-demoingr-05ef6cf45a-798694407.ap-south-1.elb.amazonaws.com](http://k8s-demoname-demoingr-05ef6cf45a-798694407.ap-south-1.elb.amazonaws.com)
*   **Backend health URL (/health):** [http://k8s-demoname-demoingr-05ef6cf45a-798694407.ap-south-1.elb.amazonaws.com/api/health](http://k8s-demoname-demoingr-05ef6cf45a-798694407.ap-south-1.elb.amazonaws.com/api/health)
*   **CI/CD used:** GitHub Actions (Automated: Triggers on every push/commit to the `main` branch).
*   **How backend connects to RDS:** The FastAPI application uses **IAM Roles for Service Accounts (IRSA)** to securely retrieve database credentials from **AWS Secrets Manager** at runtime.
*   **CloudWatch dashboard:** `demo-devops-dashboard` (Provides metrics for EKS Node CPU/Memory and RDS Performance).
*   **Assumptions:**
    *   Deployment is performed in the `ap-south-1` (Mumbai) region.
    *   The AWS Load Balancer Controller is installed via Helm to manage the ALB Ingress.
    *   Pods are deployed in private subnets and exposed via an internet-facing ALB in public subnets.
    *   Database schema is automatically initialized by the backend on its first successful connection to RDS.

---

## 🚀 Deploying in a new AWS account (Alpha)

Follow these steps to replicate this infrastructure and application in a clean AWS environment.

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
# Generate remote backend configuration (S3 + DynamoDB)
bash setup-backend.sh 
terraform init -backend-config=backend-config.hcl
terraform plan
terraform apply --auto-approve
```

#### B. Kubernetes Configuration & Deployment
After Terraform finishes, update your local kubeconfig:
```bash
# Update cluster name if you changed it in tfvars
aws eks update-kubeconfig --name demo-devops-cluster --region ap-south-1
```

# 1. Apply static manifests
kubectl apply -f infra/kubernetes/namespace.yaml
kubectl apply -f infra/kubernetes/service.yaml
kubectl apply -f infra/kubernetes/ingress.yaml

# 2. Inject image names and deploy applications
export BACKEND_IMAGE="your-account-id.dkr.ecr.ap-south-1.amazonaws.com/backend-app:latest"
export FRONTEND_IMAGE="your-account-id.dkr.ecr.ap-south-1.amazonaws.com/frontend-app:latest"

envsubst < infra/kubernetes/backend-deployment.yaml | kubectl apply -f -
envsubst < infra/kubernetes/frontend-deployment.yaml | kubectl apply -f -
```

#### C. Cleanup (Destroy)
To tear down the entire environment and avoid AWS costs:
```bash
# 1. Remove Kubernetes resources first to clean up the ALB
kubectl delete -f infra/kubernetes/

# 2. Destroy infrastructure
cd infra/terraform
terraform destroy --auto-approve
```

---

## System Architecture Highlights

*   **Networking:** Custom VPC with 2 Public (ALB) and 2 Private (EKS/RDS) subnets.
*   **Security:** IRSA for pod-level IAM permissions; RDS credentials moved from ENV files to AWS Secrets Manager.
*   **Routing:** Unified ALB Ingress handles both Frontend (Root) and Backend (via `/api`) traffic.
*   **Observability:** CloudWatch Dashboard for real-time cluster and database monitoring.
