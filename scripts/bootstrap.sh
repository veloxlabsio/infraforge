#!/bin/bash
set -euo pipefail

# InfraForge Bootstrap Script
# Sets up the entire platform on a Kubernetes cluster (local k3d or cloud)

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log()  { echo -e "${BLUE}[infraforge]${NC} $1"; }
ok()   { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err()  { echo -e "${RED}[✗]${NC} $1"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# Check prerequisites
check_deps() {
    log "Checking prerequisites..."
    local missing=()
    for cmd in kubectl helm; do
        command -v "$cmd" &>/dev/null || missing+=("$cmd")
    done
    if [ ${#missing[@]} -gt 0 ]; then
        err "Missing tools: ${missing[*]}. Install them first."
    fi
    kubectl cluster-info &>/dev/null || err "No Kubernetes cluster found. Connect to a cluster first."
    ok "All prerequisites met"
}

# Apply base resources
setup_base() {
    log "Creating namespaces..."
    kubectl apply -f "$ROOT_DIR/k8s/base/namespaces.yaml"
    ok "Namespaces created"
}

# Install ArgoCD
setup_argocd() {
    log "Installing ArgoCD..."
    kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml --server-side --force-conflicts
    log "Waiting for ArgoCD to be ready..."
    kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=300s
    ok "ArgoCD installed"
}

# Install monitoring stack
setup_monitoring() {
    log "Installing Prometheus + Grafana..."
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || true
    helm repo update prometheus-community
    helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
        --namespace monitoring --create-namespace \
        --set grafana.adminPassword=infraforge \
        --set grafana.service.type=ClusterIP \
        --set prometheus.prometheusSpec.retention=7d \
        --wait --timeout 300s
    ok "Monitoring stack installed"
}

# Install Crossplane
setup_crossplane() {
    log "Installing Crossplane..."
    helm repo add crossplane-stable https://charts.crossplane.io/stable 2>/dev/null || true
    helm repo update crossplane-stable
    helm upgrade --install crossplane crossplane-stable/crossplane \
        --namespace crossplane-system --create-namespace \
        --wait --timeout 300s
    log "Waiting for Crossplane to be ready..."
    kubectl wait --for=condition=available deployment/crossplane -n crossplane-system --timeout=120s

    log "Installing Crossplane providers..."
    kubectl apply -f "$ROOT_DIR/k8s/crossplane/provider.yaml"
    kubectl apply -f "$ROOT_DIR/k8s/crossplane/function.yaml"
    sleep 30
    kubectl apply -f "$ROOT_DIR/k8s/crossplane/provider-config.yaml"

    log "Granting provider permissions..."
    SA=$(kubectl get sa -n crossplane-system -o name | grep provider-kubernetes | head -1 | cut -d/ -f2)
    if [ -n "$SA" ]; then
        kubectl create clusterrolebinding provider-kubernetes-admin \
            --clusterrole=cluster-admin \
            --serviceaccount="crossplane-system:$SA" \
            --dry-run=client -o yaml | kubectl apply -f -
    fi

    log "Applying XRDs and Compositions..."
    kubectl apply -f "$ROOT_DIR/k8s/crossplane/xrd-microservice.yaml"
    kubectl apply -f "$ROOT_DIR/k8s/crossplane/xrd-database.yaml"
    sleep 10
    kubectl apply -f "$ROOT_DIR/k8s/crossplane/composition-microservice.yaml"
    kubectl apply -f "$ROOT_DIR/k8s/crossplane/composition-database.yaml"
    ok "Crossplane installed with Microservice + Database XRDs"
}

# Install OPA Gatekeeper
setup_gatekeeper() {
    log "Installing OPA Gatekeeper..."
    helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts 2>/dev/null || true
    helm repo update gatekeeper
    helm upgrade --install gatekeeper gatekeeper/gatekeeper \
        --namespace gatekeeper-system --create-namespace \
        --set replicas=1 --set audit.replicas=1 \
        --wait --timeout 300s
    log "Applying security policies..."
    kubectl apply -f "$ROOT_DIR/k8s/gatekeeper/templates/"
    sleep 5
    kubectl apply -f "$ROOT_DIR/k8s/gatekeeper/constraints/"
    ok "Gatekeeper installed with security policies"
}

# Install Trivy Operator
setup_trivy() {
    log "Installing Trivy Operator..."
    helm repo add aquasecurity https://aquasecurity.github.io/helm-charts/ 2>/dev/null || true
    helm repo update aquasecurity
    helm upgrade --install trivy-operator aquasecurity/trivy-operator \
        --namespace trivy-system --create-namespace \
        --set trivy.ignoreUnfixed=true \
        --wait --timeout 300s
    ok "Trivy Operator installed"
}

# Deploy sample apps via ArgoCD
deploy_apps() {
    log "Deploying applications via ArgoCD..."
    kubectl apply -f "$ROOT_DIR/k8s/argocd/sample-app.yaml"
    kubectl apply -f "$ROOT_DIR/k8s/argocd/fastapi-demo.yaml"
    ok "Applications deployed"
}

# Print access info
print_access() {
    echo ""
    echo "============================================"
    echo "  InfraForge Platform Ready"
    echo "============================================"
    echo ""
    ARGOCD_PASS=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d)
    echo "ArgoCD:     kubectl port-forward svc/argocd-server -n argocd 8888:443"
    echo "            https://localhost:8888  (admin / $ARGOCD_PASS)"
    echo ""
    echo "Grafana:    kubectl port-forward svc/monitoring-grafana -n monitoring 3333:80"
    echo "            http://localhost:3333   (admin / infraforge)"
    echo ""
    echo "Deploy a microservice:"
    echo "  kubectl apply -f k8s/apps/demo-api/claim.yaml"
    echo ""
    echo "Deploy a database:"
    echo "  kubectl apply -f k8s/apps/demo-db/claim.yaml"
    echo ""
}

# Main
main() {
    echo ""
    echo "  ╦┌┐┌┌─┐┬─┐┌─┐╔═╗┌─┐┬─┐┌─┐┌─┐"
    echo "  ║│││├┤ ├┬┘├─┤╠╣ │ │├┬┘│ ┬├┤ "
    echo "  ╩┘└┘└  ┴└─┴ ┴╚  └─┘┴└─└─┘└─┘"
    echo "  Internal Developer Platform"
    echo ""

    check_deps

    COMPONENTS="${1:-all}"

    case "$COMPONENTS" in
        all)
            setup_base
            setup_argocd
            setup_monitoring
            setup_crossplane
            setup_gatekeeper
            setup_trivy
            deploy_apps
            ;;
        argocd)     setup_base && setup_argocd ;;
        monitoring) setup_monitoring ;;
        crossplane) setup_crossplane ;;
        gatekeeper) setup_gatekeeper ;;
        trivy)      setup_trivy ;;
        apps)       deploy_apps ;;
        *)          err "Unknown component: $COMPONENTS. Use: all|argocd|monitoring|crossplane|gatekeeper|trivy|apps" ;;
    esac

    print_access
}

main "$@"
