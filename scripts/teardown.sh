#!/bin/bash
set -euo pipefail

# InfraForge Teardown Script
# Removes all platform components from the cluster

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${RED}This will remove all InfraForge components from the cluster.${NC}"
read -rp "Continue? (y/N) " confirm
[[ "$confirm" =~ ^[Yy]$ ]] || exit 0

echo "Removing applications..."
kubectl delete applications --all -n argocd 2>/dev/null || true

echo "Removing Crossplane claims..."
kubectl delete microservices,databases --all -n apps 2>/dev/null || true
sleep 5

echo "Removing Trivy..."
helm uninstall trivy-operator -n trivy-system 2>/dev/null || true

echo "Removing Gatekeeper..."
kubectl delete constraints --all 2>/dev/null || true
kubectl delete constrainttemplates --all 2>/dev/null || true
helm uninstall gatekeeper -n gatekeeper-system 2>/dev/null || true

echo "Removing Crossplane..."
kubectl delete compositions --all 2>/dev/null || true
kubectl delete compositeresourcedefinitions --all 2>/dev/null || true
helm uninstall crossplane -n crossplane-system 2>/dev/null || true

echo "Removing monitoring..."
helm uninstall monitoring -n monitoring 2>/dev/null || true

echo "Removing ArgoCD..."
kubectl delete namespace argocd 2>/dev/null || true

echo "Removing namespaces..."
kubectl delete namespace apps ml-serving monitoring crossplane-system gatekeeper-system trivy-system 2>/dev/null || true

echo -e "${GREEN}InfraForge removed.${NC}"
