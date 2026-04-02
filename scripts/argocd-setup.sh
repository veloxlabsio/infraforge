#!/bin/bash
set -euo pipefail

echo "Deploying ArgoCD..."

kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -n argocd \
    -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml \
    --server-side --force-conflicts

echo "Waiting for ArgoCD pods to be ready..."
kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s

ARGO_PWD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

echo ""
echo "ArgoCD deployed successfully."
echo ""
echo "Access the UI:"
echo "  kubectl port-forward svc/argocd-server -n argocd 8888:443"
echo "  URL:      https://localhost:8888"
echo "  Username: admin"
echo "  Password: $ARGO_PWD"
