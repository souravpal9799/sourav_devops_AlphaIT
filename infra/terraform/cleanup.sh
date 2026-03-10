#!/bin/bash
# cleanup.sh - Robustly destroys the EKS infrastructure while protecting the backend state

set -e

echo "[INFO] Starting Full Infrastructure Cleanup (AlphaIT)..."

# 1. Update KubeConfig
CLUSTER_NAME=$(terraform output -raw eks_cluster_name 2>/dev/null || echo "demo-devops-cluster")
REGION=$(terraform output -raw aws_region 2>/dev/null || echo "ap-south-1")

echo "[INFO] Target Cluster: $CLUSTER_NAME ($REGION)"

# 2. Force delete Ingress and Namespaces (The main cause of hangs)
echo "[INFO] Cleaning up Kubernetes resources..."
aws eks update-kubeconfig --name $CLUSTER_NAME --region $REGION || true

# Force delete ingress
kubectl delete ingress demo-ingress -n demo-namespace --timeout=30s || true

# Force clear finalizers for hung namespaces
for ns in demo-namespace external-secrets; do
  echo "Force clearing finalizers for namespace: $ns"
  kubectl get namespace $ns -o json | jq '.spec.finalizers = []' > ns_patch.json 2>/dev/null || true
  if [ -f ns_patch.json ]; then
    kubectl replace --raw "/api/v1/namespaces/$ns/finalize" -f ns_patch.json || true
    rm ns_patch.json
  fi
done

# 3. Use Terraform to destroy the EKS cluster and VPC
echo "[INFO] Running Terraform Destroy (Infrastructure)..."
# We target everything EXCEPT the tf_state module to preserve S3/DynamoDB
terraform destroy -auto-approve \
  -target=module.alb_controller \
  -target=module.rds \
  -target=module.security_group \
  -target=module.irsa \
  -target=module.cloudwatch \
  -target=module.ecr \
  -target=module.eks \
  -target=module.vpc \
  -target=kubernetes_namespace.app_namespace \
  -target=kubernetes_service_account.backend_sa \
  -target=aws_eks_addon.cloudwatch_observability \
  -lock=false

echo "[OK] Destruction complete! Backend state resources remain preserved."
