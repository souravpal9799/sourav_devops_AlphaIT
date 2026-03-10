#!/bin/bash
# Cleanly destroy Kubernetes resources and Terraform infrastructure for EKS

set -euo pipefail

echo "========================================="
echo "[INFO] Starting Infrastructure Cleanup"
echo "========================================="

# 1. Validate Required Tools
for cmd in terraform kubectl aws jq; do
if ! command -v $cmd >/dev/null 2>&1; then
echo "[ERROR] Required command not found: $cmd"
exit 1
fi
done

# 2. Get Terraform Outputs
# Try to get outputs, but don't capture the warning messages into the variables
RAW_CLUSTER=$(terraform output -raw eks_cluster_name 2>/dev/null || echo "")
RAW_REGION=$(terraform output -raw aws_region 2>/dev/null || echo "")

CLUSTER_NAME=${RAW_CLUSTER:-"demo-devops-cluster"}
REGION=${RAW_REGION:-"ap-south-1"}

echo "[INFO] Target Cluster: $CLUSTER_NAME"
echo "[INFO] Region: $REGION"

# 3. Update kubeconfig
echo "[INFO] Updating kubeconfig..."

aws eks update-kubeconfig \
  --name "$CLUSTER_NAME" \
  --region "$REGION" || true


# 4. Delete Application Namespace Resources First
echo "[INFO] Deleting workloads in demo namespace..."

kubectl delete ingress --all -n demo-namespace --timeout=60s 2>/dev/null || true
kubectl delete svc --all -n demo-namespace --timeout=60s 2>/dev/null || true
kubectl delete deploy --all -n demo-namespace --timeout=60s 2>/dev/null || true

# 5. Delete Namespace Explicitly
echo "[INFO] Deleting namespaces..."

kubectl delete namespace demo-namespace --timeout=60s 2>/dev/null || true
kubectl delete namespace external-secrets --timeout=60s 2>/dev/null || true

echo "[INFO] Checking and removing namespace finalizers if stuck..."

# 6. Function to clean namespace
# echo "[INFO] Deleting namespaces..."

# kubectl delete namespace demo-namespace --timeout=60s 2>/dev/null || true
# kubectl delete namespace external-secrets --timeout=60s 2>/dev/null || true

# # 6. Remove Finalizers if Namespace Stuck
# echo "[INFO] Removing namespace finalizers to unstick namespaces..."

# kubectl get namespace demo-namespace -o json | jq '.spec.finalizers=[]' | kubectl replace --raw "/api/v1/namespaces/demo-namespace/finalize" -f -
# kubectl get namespace external-secrets -o json | jq '.spec.finalizers=[]' | kubectl replace --raw "/api/v1/namespaces/external-secrets/finalize" -f -

cleanup_namespace () {
    NS=$1

    if kubectl get namespace "$NS" >/dev/null 2>&1; then
        STATUS=$(kubectl get ns "$NS" -o jsonpath='{.status.phase}')

        if [ "$STATUS" == "Terminating" ]; then
            echo "[INFO] Namespace $NS is stuck in Terminating. Removing finalizers..."

            kubectl get namespace "$NS" -o json \
            | jq '.spec.finalizers=[]' \
            | kubectl replace --raw "/api/v1/namespaces/$NS/finalize" -f -

            echo "[INFO] Finalizers removed from $NS"
        else
            echo "[INFO] Namespace $NS exists but is not terminating."
        fi
    else
        echo "[INFO] Namespace $NS does not exist. Skipping."
    fi
}

# Run cleanup
cleanup_namespace demo-namespace
cleanup_namespace external-secrets

# 7. Terraform Destroy
echo "[INFO] Running Terraform destroy..."

terraform destroy -auto-approve

# 8. Clean kubeconfig
echo "[INFO] Cleaning kubeconfig entry..."

kubectl config delete-context "$CLUSTER_NAME" 2>/dev/null || true

echo "========================================="
echo "[SUCCESS] Infrastructure Destroyed"
echo "========================================="