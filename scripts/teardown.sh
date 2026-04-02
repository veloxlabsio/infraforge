#!/bin/bash
set -euo pipefail

# InfraForge Teardown Script
# Removes only InfraForge-managed components — safe for shared clusters

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${RED}This will remove InfraForge components from the cluster.${NC}"
echo "Components: ArgoCD apps, Crossplane claims, Gatekeeper policies, Trivy, monitoring"
read -rp "Continue? (y/N) " confirm
[[ "$confirm" =~ ^[Yy]$ ]] || exit 0

echo -e "${YELLOW}Removing InfraForge ArgoCD applications...${NC}"
kubectl delete application fastapi-demo sample-app -n argocd 2>/dev/null || true

echo -e "${YELLOW}Removing Crossplane claims...${NC}"
kubectl delete microservices,databases --all -n apps 2>/dev/null || true
sleep 5

echo -e "${YELLOW}Removing Crossplane compositions and XRDs...${NC}"
kubectl delete compositions microservice-composition database-composition 2>/dev/null || true
kubectl delete compositeresourcedefinitions xmicroservices.platform.veloxlabs.dev xdatabases.platform.veloxlabs.dev 2>/dev/null || true

echo -e "${YELLOW}Removing Gatekeeper constraints and templates...${NC}"
kubectl delete -f "$(dirname "$0")/../k8s/gatekeeper/constraints/" 2>/dev/null || true
kubectl delete -f "$(dirname "$0")/../k8s/gatekeeper/templates/" 2>/dev/null || true

echo -e "${YELLOW}Uninstalling Helm releases...${NC}"
helm uninstall trivy-operator -n trivy-system 2>/dev/null || true
helm uninstall gatekeeper -n gatekeeper-system 2>/dev/null || true
helm uninstall crossplane -n crossplane-system 2>/dev/null || true
helm uninstall monitoring -n monitoring 2>/dev/null || true

echo -e "${YELLOW}Removing InfraForge namespaces...${NC}"
kubectl delete namespace argocd 2>/dev/null || true
kubectl delete namespace apps ml-serving monitoring crossplane-system gatekeeper-system trivy-system 2>/dev/null || true

echo -e "${GREEN}InfraForge removed.${NC}"
