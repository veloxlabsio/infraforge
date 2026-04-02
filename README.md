# InfraForge

An open-source, AI-ready Internal Developer Platform built on Kubernetes.

## What is this?

InfraForge is a self-service platform where developers deploy applications and ML engineers serve models — on the same infrastructure, with unified observability and security.

## Architecture

```
Developer/ML Engineer
        │
        ▼
   Git Push (GitHub)
        │
        ▼
   ArgoCD (GitOps)
        │
        ▼
   Kubernetes Cluster
   ├── App Workloads (containers)
   ├── ML Workloads (KServe + vLLM)
   ├── Observability (Prometheus / Grafana / Loki)
   ├── Security (OPA Gatekeeper / Falco / Trivy)
   └── Infra Provisioning (Crossplane)
```

## Stack

| Layer | Tool | Status |
|---|---|---|
| Orchestration | K3s / K8s | Done |
| GitOps | ArgoCD | Done |
| Monitoring | Prometheus + Grafana | In Progress |
| ML Serving | KServe + MLflow | Planned |
| Developer Portal | Backstage | Planned |
| Infrastructure | Crossplane + Terraform | Planned |
| Security | OPA Gatekeeper + Falco + Trivy | Planned |
| Compliance | Audit Logging + PII Detection | Planned |

## Quick Start

### Prerequisites

- Docker
- kubectl
- k3d
- helm

### Local Setup

```bash
# Create cluster
./scripts/cluster-create.sh

# Deploy ArgoCD
./scripts/argocd-setup.sh

# Deploy monitoring stack
./scripts/monitoring-setup.sh

# Access ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8888:443
# Open https://localhost:8888
```

## Project Structure

```
infraforge/
├── k8s/
│   ├── argocd/          # ArgoCD application manifests
│   ├── monitoring/      # Prometheus + Grafana configs
│   ├── apps/            # Application deployments
│   │   └── sample-app/  # Example app deployed via GitOps
│   └── base/            # Shared K8s resources (namespaces, RBAC)
├── scripts/             # Setup and utility scripts
└── docs/                # Architecture docs
```

## License

MIT
