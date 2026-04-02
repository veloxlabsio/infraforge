# InfraForge

A Kubernetes platform starter kit with GitOps, monitoring, security policies, vulnerability scanning, and self-service infrastructure — pre-wired and working in one command.

> **Note:** InfraForge is a learning and reference platform, not a production-hardened product. Use it to bootstrap a development environment or as a starting point for your own IDP.

## Why InfraForge?

Wiring ArgoCD with Crossplane, configuring Gatekeeper policies, connecting Trivy scanning, and adding Prometheus takes time. InfraForge gives you a working baseline with all of these integrated, so you can learn, experiment, and build on top of it.

## Architecture

```
                    Developer
                       │
                 git push (code)
                       │
              ┌────────▼────────┐
              │  GitHub Actions  │──── Build image, push to GHCR
              │    CI/CD        │──── Security scan (Trivy)
              │                 │──── Manifest validation
              └────────┬────────┘
                       │
                       │ updates K8s manifests
                       │
              ┌────────▼────────┐
              │    ArgoCD       │──── Watches git repo
              │    (GitOps)     │──── Auto-syncs to cluster
              └────────┬────────┘
                       │
         ┌─────────────┼─────────────┐
         │             │             │
    ┌────▼────┐  ┌─────▼─────┐  ┌───▼────┐
    │Crossplane│  │ Gatekeeper │  │ Trivy  │
    │  (infra) │  │ (policies) │  │ (CVEs) │
    └────┬────┘  └─────┬─────┘  └───┬────┘
         │             │             │
         └─────────────┼─────────────┘
                       │
              ┌────────▼────────┐
              │   Kubernetes    │
              │    Cluster      │
              │                 │
              │  ┌───────────┐  │
              │  │    Apps   │  │
              │  │  Services │  │
              │  │ Databases │  │
              │  └───────────┘  │
              │                 │
              │  ┌───────────┐  │
              │  │Prometheus │  │
              │  │ + Grafana │  │
              │  └───────────┘  │
              └─────────────────┘
```

## Stack

| Layer | Tool | What it does |
|---|---|---|
| Orchestration | K3s / DigitalOcean K8s | Runs the cluster |
| GitOps | ArgoCD | Deploys from git automatically |
| CI/CD | GitHub Actions | Builds images, runs security scans |
| Monitoring | Prometheus + Grafana | Metrics, dashboards, alerts |
| Self-Service | Crossplane | Developers provision infra via YAML claims |
| Policy | OPA Gatekeeper | Blocks insecure deployments |
| Security | Trivy Operator | Scans every container image for CVEs |
| IaC | Terraform | Provisions cloud infrastructure |

## Quick Start

### Prerequisites

- Docker, kubectl, helm
- [k3d](https://k3d.io) (for local) or DigitalOcean account (for cloud)

### Local (k3d)

```bash
git clone https://github.com/veloxlabsio/infraforge.git
cd infraforge

# Create local cluster
make local-cluster

# Install everything
make bootstrap
```

### Cloud (DigitalOcean)

```bash
# Copy and edit terraform variables
cp terraform/terraform.tfvars.example terraform/terraform.tfvars

# Provision cluster
make terraform-init
make terraform-apply
make terraform-kubeconfig
export KUBECONFIG=./kubeconfig

# Install platform
make bootstrap
```

### Access UIs

```bash
make port-forward

# ArgoCD:  https://localhost:8888
# Grafana: http://localhost:3333
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
  image: my-app:v1
  replicas: 3
  port: 8000
  resources:
    cpu: "100m"
    memory: "128Mi"
```

Crossplane creates the Deployment, Service, health checks, and resource limits automatically.

### Deploy a Database

```yaml
apiVersion: platform.veloxlabs.dev/v1alpha1
kind: Database
metadata:
  name: my-db
  namespace: apps
spec:
  engine: postgres
  storageSize: "5Gi"
```

Gets you a PostgreSQL StatefulSet with PVC, credentials secret, and a ClusterIP service.

## Security

InfraForge layers security controls at build time and runtime:

- **GitHub Actions** — Lint and Trivy scan run as gates before image push; image scan runs before manifest update
- **OPA Gatekeeper** — 7 policies: blocks privileged containers, host namespaces, hostPath volumes; enforces non-root, resource limits, required labels, capability drop
- **Trivy Operator** — Continuously scans all running container images for CVEs
- **Pod Security** — All workloads use `runAsNonRoot`, `seccompProfile: RuntimeDefault`, and `capabilities.drop: ["ALL"]`
- **NetworkPolicies** — Default-deny ingress in apps namespace, allow only same-namespace and monitoring scrape

Example: trying to deploy a privileged container gets denied:

```
Error from server (Forbidden): admission webhook "validation.gatekeeper.sh" denied the request:
[no-privileged-containers] Privileged container 'app' is not allowed
```

## Project Structure

```
infraforge/
├── .github/workflows/   # CI/CD pipeline
├── apps/                # Application source code
│   └── fastapi-demo/    #   Demo app with Dockerfile
├── k8s/
│   ├── argocd/          # ArgoCD application manifests
│   ├── crossplane/      # XRDs, Compositions, Providers
│   ├── gatekeeper/      # OPA policy templates + constraints
│   ├── apps/            # Application K8s manifests
│   └── base/            # Namespaces, NetworkPolicies
├── terraform/           # DigitalOcean infrastructure
├── scripts/
│   ├── bootstrap.sh     # One-command platform setup (pinned versions)
│   ├── teardown.sh      # Scoped removal of infraforge resources
│   └── cluster-create.sh
├── LICENSE
├── CONTRIBUTING.md
├── SECURITY.md
└── Makefile             # All operations
```

## Make Targets

```
make doctor            # Check prerequisites
make local-cluster     # Create local k3d cluster
make build-demo        # Build demo FastAPI image
make load-demo         # Build + load image into k3d
make bootstrap         # Install all platform components
make bootstrap-argocd  # Install only ArgoCD
make status            # Show platform status
make verify            # Verify all components are healthy
make port-forward      # Access ArgoCD + Grafana UIs
make teardown          # Remove infraforge resources
make terraform-plan    # Plan cloud infrastructure
make terraform-apply   # Provision cloud cluster
```

## Known Limitations

- Crossplane provisions in-cluster resources only (no managed cloud databases yet)
- Single-replica PostgreSQL — not suitable for production data
- No secret management integration (Vault, External Secrets) yet
- No ingress controller or TLS termination
- No log aggregation (Loki/ELK)
- Backstage developer portal planned but not yet included

## License

MIT — see [LICENSE](LICENSE)
