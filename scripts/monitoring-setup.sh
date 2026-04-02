#!/bin/bash
set -euo pipefail

echo "Deploying Prometheus + Grafana monitoring stack..."

# Add helm repos
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Create monitoring namespace
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

# Install kube-prometheus-stack (Prometheus + Grafana + Alertmanager + node-exporter)
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
    --namespace monitoring \
    --set grafana.adminPassword=infraforge \
    --set grafana.service.type=ClusterIP \
    --set prometheus.prometheusSpec.retention=7d \
    --set prometheus.prometheusSpec.resources.requests.memory=256Mi \
    --set prometheus.prometheusSpec.resources.requests.cpu=100m \
    --wait --timeout 300s

echo ""
echo "Monitoring stack deployed."
echo ""
echo "Access Grafana:"
echo "  kubectl port-forward svc/monitoring-grafana -n monitoring 3000:80"
echo "  URL:      http://localhost:3000"
echo "  Username: admin"
echo "  Password: infraforge"
echo ""
echo "Access Prometheus:"
echo "  kubectl port-forward svc/monitoring-kube-prometheus-prometheus -n monitoring 9090:9090"
echo "  URL:      http://localhost:9090"
