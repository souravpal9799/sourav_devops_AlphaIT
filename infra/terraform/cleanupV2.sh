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
CLUSTER_NAME=$(terraform output -raw eks_cluster_name 2>/dev/null || echo "demo-devops-cluster")
REGION=$(terraform output -raw aws_region 2>/dev/null || echo "ap-south-1")

echo "[INFO] Target Cluster: $CLUSTER_NAME"
echo "[INFO] Region: $REGION"

# 3. Update kubeconfig
echo "[INFO] Updating kubeconfig..."

aws eks update-kubeconfig 
--name "$CLUSTER_NAME" 
--region "$REGION" || true

# 4. Delete Kubernetes Workloads
echo "[INFO] Deleting Kubernetes workloads..."

kubectl delete ingress --all -A --timeout=30s 2>/dev/null || true
kubectl delete svc --all -A --timeout=30s 2>/dev/null || true
kubectl delete deploy --all -A --timeout=30s 2>/dev/null || true


# 5. Force Delete Stuck Pods
echo "[INFO] Force deleting pods..."

for ns in demo-namespace external-secrets; do
kubectl delete pod --all 
-n "$ns" 
--force 
--grace-period=0 
2>/dev/null || true
done

# 6. Remove Namespace Finalizers
echo "[INFO] Removing namespace finalizers..."

for ns in demo-namespace external-secrets; do
if kubectl get ns "$ns" >/dev/null 2>&1; then
kubectl get namespace "$ns" -o json 
| jq '.metadata.finalizers = []' 
> ns_patch.json

```
kubectl replace --raw "/api/v1/namespaces/$ns/finalize" \
  -f ns_patch.json 2>/dev/null || true

rm -f ns_patch.json
```

fi
done

# 7. Terraform Destroy
echo "[INFO] Running Terraform destroy..."

terraform destroy -auto-approve

# 8. Clean kubeconfig
echo "[INFO] Cleaning kubeconfig entry..."

kubectl config delete-context "$CLUSTER_NAME" 2>/dev/null || true

echo "========================================="
echo "[SUCCESS] Infrastructure Destroyed"
echo "========================================="