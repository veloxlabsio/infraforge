.PHONY: help local-cluster bootstrap teardown status port-forward terraform-init terraform-plan terraform-apply

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# ─── Local Development ───────────────────────────────────────────

local-cluster: ## Create local k3d cluster
	@./scripts/cluster-create.sh

bootstrap: ## Install all platform components on current cluster
	@chmod +x ./scripts/bootstrap.sh && ./scripts/bootstrap.sh all

bootstrap-%: ## Install a specific component (argocd, monitoring, crossplane, gatekeeper, trivy, apps)
	@chmod +x ./scripts/bootstrap.sh && ./scripts/bootstrap.sh $*

teardown: ## Remove all platform components
	@chmod +x ./scripts/teardown.sh && ./scripts/teardown.sh

# ─── Status & Access ─────────────────────────────────────────────

status: ## Show platform status
	@echo "=== Pods by namespace ==="
	@kubectl get pods -A --no-headers | awk '{print $$1}' | sort | uniq -c | sort -rn
	@echo ""
	@echo "=== ArgoCD Applications ==="
	@kubectl get applications -n argocd 2>/dev/null || echo "ArgoCD not installed"
	@echo ""
	@echo "=== Crossplane Claims ==="
	@kubectl get microservices,databases -n apps 2>/dev/null || echo "Crossplane not installed"
	@echo ""
	@echo "=== Gatekeeper Constraints ==="
	@kubectl get constraints 2>/dev/null || echo "Gatekeeper not installed"
	@echo ""
	@echo "=== Vulnerability Reports ==="
	@kubectl get vulnerabilityreports -n apps -o wide 2>/dev/null || echo "Trivy not installed"

port-forward: ## Start port-forwarding for ArgoCD and Grafana
	@echo "Starting port-forwards..."
	@kubectl port-forward svc/argocd-server -n argocd 8888:443 &>/dev/null &
	@kubectl port-forward svc/monitoring-grafana -n monitoring 3333:80 &>/dev/null &
	@echo "ArgoCD:  https://localhost:8888"
	@echo "Grafana: http://localhost:3333"

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
