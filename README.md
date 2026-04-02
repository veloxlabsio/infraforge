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
| Monitoring | Prometheus + Grafana | Done |
| Infrastructure | Crossplane | Done |
| Security | OPA Gatekeeper + Trivy | In Progress |
| ML Serving | KServe + MLflow | Planned |
| Developer Portal | Backstage | Planned |
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

## Self-Service: Deploy a Microservice

Developers deploy apps with a simple claim — no Kubernetes knowledge needed:

```yaml
apiVersion: platform.veloxlabs.dev/v1alpha1
kind: Microservice
metadata:
  name: my-api
  namespace: apps
spec:
  image: my-image:v1
  replicas: 3
  port: 8000
  resources:
    cpu: "100m"
    memory: "128Mi"
```

Crossplane handles the rest — creates Deployment, Service, health checks, resource limits.

## Project Structure

```
infraforge/
├── k8s/
│   ├── argocd/          # ArgoCD application manifests
│   ├── monitoring/      # Prometheus + Grafana configs
│   ├── crossplane/      # XRDs, Compositions, Provider configs
│   ├── apps/            # Application deployments
│   │   ├── sample-app/  # Nginx app deployed via GitOps
│   │   ├── fastapi-demo/# FastAPI app deployed via ArgoCD
│   │   └── demo-api/    # Microservice deployed via Crossplane claim
│   └── base/            # Shared K8s resources (namespaces, RBAC)
├── apps/                # Application source code
│   └── fastapi-demo/    # FastAPI app with Dockerfile
├── scripts/             # Setup and utility scripts
└── docs/                # Architecture docs
```

## License

MIT
