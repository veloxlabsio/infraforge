#!/bin/bash
set -euo pipefail

CLUSTER_NAME="infraforge"
HTTP_PORT="${HTTP_PORT:-9080}"
HTTPS_PORT="${HTTPS_PORT:-9443}"

echo "Creating K3s cluster: $CLUSTER_NAME"

# Check if cluster already exists
if k3d cluster list | grep -q "$CLUSTER_NAME"; then
    echo "Cluster '$CLUSTER_NAME' already exists."
    echo "To delete and recreate: k3d cluster delete $CLUSTER_NAME"
    exit 0
fi

k3d cluster create "$CLUSTER_NAME" \
    --servers 1 \
    --agents 2 \
    --port "${HTTP_PORT}:80@loadbalancer" \
    --port "${HTTPS_PORT}:443@loadbalancer" \
    --k3s-arg "--disable=traefik@server:0" \
    --wait

echo ""
echo "Cluster '$CLUSTER_NAME' created successfully."
kubectl get nodes
