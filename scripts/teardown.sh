#!/bin/bash
set -euo pipefail

# InfraForge Teardown Script
# Removes InfraForge-managed resources. Does NOT delete namespaces that
# may contain other workloads on a shared cluster.

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

echo -e "${RED}This will remove InfraForge-managed resources from the cluster.${NC}"
echo "It will NOT delete namespaces (safe for shared clusters)."
read -rp "Continue? (y/N) " confirm
[[ "$confirm" =~ ^[Yy]$ ]] || exit 0

echo -e "${YELLOW}[1/8] Removing ArgoCD applications...${NC}"
kubectl delete application fastapi-demo sample-app -n argocd --ignore-not-found 2>/dev/null || true

echo -e "${YELLOW}[2/8] Removing Crossplane claims...${NC}"
kubectl delete microservices,databases --all -n apps --ignore-not-found 2>/dev/null || true
sleep 5

echo -e "${YELLOW}[3/8] Removing Crossplane compositions, XRDs, providers...${NC}"
kubectl delete compositions microservice-composition database-composition --ignore-not-found 2>/dev/null || true
kubectl delete compositeresourcedefinitions \
    xmicroservices.platform.veloxlabs.dev \
    xdatabases.platform.veloxlabs.dev \
    --ignore-not-found 2>/dev/null || true
kubectl delete -f "$ROOT_DIR/k8s/crossplane/provider-config.yaml" --ignore-not-found 2>/dev/null || true
kubectl delete -f "$ROOT_DIR/k8s/crossplane/function.yaml" --ignore-not-found 2>/dev/null || true
kubectl delete -f "$ROOT_DIR/k8s/crossplane/provider.yaml" --ignore-not-found 2>/dev/null || true

echo -e "${YELLOW}[4/8] Removing Gatekeeper constraints and templates...${NC}"
kubectl delete -f "$ROOT_DIR/k8s/gatekeeper/constraints/" --ignore-not-found 2>/dev/null || true
kubectl delete -f "$ROOT_DIR/k8s/gatekeeper/templates/" --ignore-not-found 2>/dev/null || true

echo -e "${YELLOW}[5/8] Removing NetworkPolicies...${NC}"
kubectl delete -f "$ROOT_DIR/k8s/base/network-policies.yaml" --ignore-not-found 2>/dev/null || true

echo -e "${YELLOW}[6/8] Uninstalling Helm releases...${NC}"
helm uninstall trivy-operator -n trivy-system 2>/dev/null || true
helm uninstall gatekeeper -n gatekeeper-system 2>/dev/null || true
helm uninstall crossplane -n crossplane-system 2>/dev/null || true
helm uninstall monitoring -n monitoring 2>/dev/null || true

echo -e "${YELLOW}[7/8] Removing cluster-scoped RBAC artifacts...${NC}"
kubectl delete clusterrolebinding infraforge-provider-ns-reader --ignore-not-found 2>/dev/null || true
kubectl delete clusterrole infraforge-provider-ns-reader --ignore-not-found 2>/dev/null || true
# Clean up RoleBindings in managed namespaces
for ns in apps ml-serving; do
    kubectl delete rolebinding infraforge-provider -n "$ns" --ignore-not-found 2>/dev/null || true
    kubectl delete role infraforge-provider -n "$ns" --ignore-not-found 2>/dev/null || true
done

echo -e "${YELLOW}[8/8] Removing InfraForge app deployments...${NC}"
kubectl delete -f "$ROOT_DIR/k8s/apps/sample-app/deployment.yaml" --ignore-not-found 2>/dev/null || true
kubectl delete -f "$ROOT_DIR/k8s/apps/fastapi-demo/deployment.yaml" --ignore-not-found 2>/dev/null || true

echo ""
echo -e "${GREEN}InfraForge resources removed.${NC}"
echo "Namespaces were NOT deleted. To remove them manually:"
echo "  kubectl delete namespace argocd monitoring crossplane-system gatekeeper-system trivy-system"
