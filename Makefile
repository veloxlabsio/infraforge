.PHONY: help doctor local-cluster build-demo load-demo bootstrap teardown status verify port-forward stop-port-forward terraform-init terraform-plan terraform-apply terraform-destroy terraform-kubeconfig

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-22s\033[0m %s\n", $$1, $$2}'

# ─── Preflight ────────────────────────────────────────────────────

doctor: ## Check all prerequisites are installed
	@echo "Checking prerequisites..."
	@command -v docker >/dev/null 2>&1 && echo "  docker: $$(docker --version)" || echo "  docker: MISSING"
	@command -v kubectl >/dev/null 2>&1 && echo "  kubectl: $$(kubectl version --client --short 2>/dev/null || kubectl version --client)" || echo "  kubectl: MISSING"
	@command -v helm >/dev/null 2>&1 && echo "  helm: $$(helm version --short)" || echo "  helm: MISSING"
	@command -v k3d >/dev/null 2>&1 && echo "  k3d: $$(k3d version -o json 2>/dev/null | head -1 || k3d version)" || echo "  k3d: MISSING (needed for local dev)"
	@echo ""
	@kubectl cluster-info >/dev/null 2>&1 && echo "Cluster: connected" || echo "Cluster: NOT connected"

# ─── Local Development ───────────────────────────────────────────

local-cluster: ## Create local k3d cluster
	@./scripts/cluster-create.sh

load-demo: ## Build demo image and load into local k3d cluster
	@docker build -t fastapi-demo:local apps/fastapi-demo/
	@k3d image import fastapi-demo:local -c infraforge
	@sed -i 's|image: .*fastapi-demo.*|image: fastapi-demo:local|' k8s/apps/fastapi-demo/deployment.yaml
	@echo "Image loaded. Deployment manifest updated to fastapi-demo:local"
	@echo "NOTE: Do not commit this change — CI manages the image tag in production."

bootstrap: ## Install all platform components on current cluster
	@chmod +x ./scripts/bootstrap.sh && ./scripts/bootstrap.sh all

bootstrap-%: ## Install a specific component (argocd, monitoring, crossplane, gatekeeper, trivy, apps)
	@chmod +x ./scripts/bootstrap.sh && ./scripts/bootstrap.sh $*

teardown: ## Remove all platform components (scoped to infraforge resources)
	@chmod +x ./scripts/teardown.sh && ./scripts/teardown.sh

# ─── Status & Verification ───────────────────────────────────────

status: ## Show platform status
	@echo "=== Pods by namespace ==="
	@kubectl get pods -A --no-headers | awk '{print $$1}' | sort | uniq -c | sort -rn
	@echo ""
	@echo "=== ArgoCD Applications ==="
	@kubectl get applications -n argocd 2>/dev/null || echo "  ArgoCD not installed"
	@echo ""
	@echo "=== Crossplane Claims ==="
	@kubectl get microservices,databases -n apps 2>/dev/null || echo "  Crossplane not installed"
	@echo ""
	@echo "=== Gatekeeper Constraints ==="
	@kubectl get constraints 2>/dev/null || echo "  Gatekeeper not installed"
	@echo ""
	@echo "=== Vulnerability Reports ==="
	@kubectl get vulnerabilityreports -n apps -o wide 2>/dev/null || echo "  Trivy not installed"

verify: ## Verify all platform components are healthy
	@echo "Verifying platform health..."
	@echo ""
	@echo "--- ArgoCD ---"
	@kubectl get applications -n argocd -o jsonpath='{range .items[*]}{.metadata.name}: sync={.status.sync.status} health={.status.health.status}{"\n"}{end}' 2>/dev/null || echo "  NOT INSTALLED"
	@echo ""
	@echo "--- Crossplane ---"
	@kubectl get microservices,databases -n apps -o jsonpath='{range .items[*]}{.kind}/{.metadata.name}: synced={.status.conditions[?(@.type=="Synced")].status} ready={.status.conditions[?(@.type=="Ready")].status}{"\n"}{end}' 2>/dev/null || echo "  NOT INSTALLED"
	@echo ""
	@echo "--- Gatekeeper ---"
	@kubectl get constraints -o jsonpath='{range .items[*]}{.kind}/{.metadata.name}: enforcement={.spec.enforcementAction} violations={.status.totalViolations}{"\n"}{end}' 2>/dev/null || echo "  NOT INSTALLED"
	@echo ""
	@echo "--- Pods not ready ---"
	@kubectl get pods -n apps --field-selector=status.phase!=Running 2>/dev/null || echo "  All pods running"

# ─── Access ──────────────────────────────────────────────────────

port-forward: ## Start port-forwarding for ArgoCD and Grafana
	@echo "Starting port-forwards..."
	@kubectl port-forward svc/argocd-server -n argocd 8888:443 &>/dev/null &
	@kubectl port-forward svc/monitoring-grafana -n monitoring 3333:80 &>/dev/null &
	@echo "ArgoCD:  https://localhost:8888"
	@echo "Grafana: http://localhost:3333"
	@echo ""
	@echo "Credentials:"
	@echo "  ArgoCD:  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
	@echo "  Grafana: kubectl -n monitoring get secret monitoring-grafana -o jsonpath='{.data.admin-password}' | base64 -d"

stop-port-forward: ## Stop InfraForge port-forward processes
	@pkill -f "kubectl port-forward svc/argocd-server" 2>/dev/null || true
	@pkill -f "kubectl port-forward svc/monitoring-grafana" 2>/dev/null || true
	@echo "InfraForge port-forwards stopped"

# ─── Cloud Deployment ────────────────────────────────────────────

terraform-init: ## Initialize Terraform
	@cd terraform && terraform init

terraform-plan: ## Plan cloud infrastructure
	@cd terraform && terraform plan

terraform-apply: ## Apply cloud infrastructure
	@cd terraform && terraform apply

terraform-destroy: ## Destroy cloud infrastructure
	@cd terraform && terraform destroy

terraform-kubeconfig: ## Get kubeconfig from cloud cluster
	@cd terraform && terraform output -raw kubeconfig > ../kubeconfig
	@echo "Kubeconfig saved to ./kubeconfig"
	@echo "Run: export KUBECONFIG=./kubeconfig"
