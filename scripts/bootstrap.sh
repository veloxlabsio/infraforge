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

# Pinned versions — update these intentionally, not accidentally
ARGOCD_VERSION="v2.13.3"
PROMETHEUS_CHART_VERSION="67.11.0"
CROSSPLANE_CHART_VERSION="1.18.2"
GATEKEEPER_CHART_VERSION="3.18.2"
TRIVY_CHART_VERSION="0.25.0"

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

wait_for_deployment() {
    local name="$1" namespace="$2" timeout="${3:-300}"
    log "Waiting for $name in $namespace..."
    kubectl wait --for=condition=available "deployment/$name" -n "$namespace" --timeout="${timeout}s"
}

wait_for_crd() {
    local crd="$1" timeout="${2:-120}"
    local elapsed=0
    while ! kubectl get crd "$crd" &>/dev/null; do
        if [ "$elapsed" -ge "$timeout" ]; then
            err "Timed out waiting for CRD: $crd"
        fi
        sleep 5
        elapsed=$((elapsed + 5))
    done
}

# Apply base resources
setup_base() {
    log "Creating namespaces and network policies..."
    kubectl apply -f "$ROOT_DIR/k8s/base/namespaces.yaml"
    kubectl apply -f "$ROOT_DIR/k8s/base/network-policies.yaml"
    ok "Namespaces and network policies created"
}

# Install ArgoCD
setup_argocd() {
    log "Installing ArgoCD ${ARGOCD_VERSION}..."
    kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
    kubectl apply -n argocd \
        -f "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml" \
        --server-side --force-conflicts
    wait_for_deployment argocd-server argocd 300
    ok "ArgoCD installed"
    log "Retrieve credentials: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
}

# Install monitoring stack
setup_monitoring() {
    log "Installing Prometheus + Grafana (chart ${PROMETHEUS_CHART_VERSION})..."
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || true
    helm repo update prometheus-community
    helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
        --version "$PROMETHEUS_CHART_VERSION" \
        --namespace monitoring --create-namespace \
        --set grafana.service.type=ClusterIP \
        --set prometheus.prometheusSpec.retention=7d \
        --wait --timeout 300s
    ok "Monitoring stack installed"
    log "Retrieve Grafana password: kubectl -n monitoring get secret monitoring-grafana -o jsonpath='{.data.admin-password}' | base64 -d"
}

# Install Crossplane
setup_crossplane() {
    log "Installing Crossplane (chart ${CROSSPLANE_CHART_VERSION})..."
    helm repo add crossplane-stable https://charts.crossplane.io/stable 2>/dev/null || true
    helm repo update crossplane-stable
    helm upgrade --install crossplane crossplane-stable/crossplane \
        --version "$CROSSPLANE_CHART_VERSION" \
        --namespace crossplane-system --create-namespace \
        --wait --timeout 300s
    wait_for_deployment crossplane crossplane-system 120

    log "Installing Crossplane providers..."
    kubectl apply -f "$ROOT_DIR/k8s/crossplane/provider.yaml"
    kubectl apply -f "$ROOT_DIR/k8s/crossplane/function.yaml"

    log "Waiting for provider CRD..."
    wait_for_crd "providerconfigs.kubernetes.crossplane.io" 120
    kubectl apply -f "$ROOT_DIR/k8s/crossplane/provider-config.yaml"

    log "Applying namespace-scoped RBAC for provider..."
    kubectl apply -f "$ROOT_DIR/k8s/crossplane/rbac.yaml"
    SA=""
    local elapsed=0
    while [ -z "$SA" ]; do
        SA=$(kubectl get sa -n crossplane-system -o name 2>/dev/null | grep provider-kubernetes | head -1 | cut -d/ -f2) || true
        if [ "$elapsed" -ge 60 ]; then
            err "Timed out waiting for provider service account"
        fi
        sleep 5
        elapsed=$((elapsed + 5))
    done
    # ClusterRoleBinding for read-only namespace discovery
    kubectl create clusterrolebinding infraforge-provider-ns-reader \
        --clusterrole=infraforge-provider-ns-reader \
        --serviceaccount="crossplane-system:$SA" \
        --dry-run=client -o yaml | kubectl apply -f -
    # RoleBindings per namespace (provider can only touch apps and ml-serving)
    for ns in apps ml-serving; do
        kubectl create rolebinding "infraforge-provider" \
            --role=infraforge-provider \
            --serviceaccount="crossplane-system:$SA" \
            --namespace="$ns" \
            --dry-run=client -o yaml | kubectl apply -f -
    done

    log "Applying XRDs and Compositions..."
    kubectl apply -f "$ROOT_DIR/k8s/crossplane/xrd-microservice.yaml"
    kubectl apply -f "$ROOT_DIR/k8s/crossplane/xrd-database.yaml"
    wait_for_crd "microservices.platform.veloxlabs.dev" 60
    wait_for_crd "databases.platform.veloxlabs.dev" 60
    kubectl apply -f "$ROOT_DIR/k8s/crossplane/composition-microservice.yaml"
    kubectl apply -f "$ROOT_DIR/k8s/crossplane/composition-database.yaml"
    ok "Crossplane installed with Microservice + Database XRDs"
}

# Install OPA Gatekeeper
setup_gatekeeper() {
    log "Installing OPA Gatekeeper (chart ${GATEKEEPER_CHART_VERSION})..."
    helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts 2>/dev/null || true
    helm repo update gatekeeper
    helm upgrade --install gatekeeper gatekeeper/gatekeeper \
        --version "$GATEKEEPER_CHART_VERSION" \
        --namespace gatekeeper-system --create-namespace \
        --wait --timeout 300s
    wait_for_deployment gatekeeper-controller-manager gatekeeper-system 120
    log "Applying security policies..."
    kubectl apply -f "$ROOT_DIR/k8s/gatekeeper/templates/"
    wait_for_crd "k8snoprivileged.constraints.gatekeeper.sh" 30
    kubectl apply -f "$ROOT_DIR/k8s/gatekeeper/constraints/"
    ok "Gatekeeper installed with security policies"
}

# Install Trivy Operator
setup_trivy() {
    log "Installing Trivy Operator (chart ${TRIVY_CHART_VERSION})..."
    helm repo add aquasecurity https://aquasecurity.github.io/helm-charts/ 2>/dev/null || true
    helm repo update aquasecurity
    helm upgrade --install trivy-operator aquasecurity/trivy-operator \
        --version "$TRIVY_CHART_VERSION" \
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
    echo "Access UIs:  make port-forward"
    echo ""
    echo "Credentials:"
    echo "  ArgoCD:   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
    echo "  Grafana:  kubectl -n monitoring get secret monitoring-grafana -o jsonpath='{.data.admin-password}' | base64 -d"
    echo ""
    echo "Deploy a microservice:  kubectl apply -f k8s/apps/demo-api/claim.yaml"
    echo "Deploy a database:      kubectl apply -f k8s/apps/demo-db/claim.yaml"
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
