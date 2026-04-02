# Contributing to InfraForge

## Getting Started

1. Fork the repository
2. Clone your fork
3. Create a feature branch: `git checkout -b feature/your-feature`
4. Make your changes
5. Test locally: `make local-cluster && make bootstrap`
6. Commit and push
7. Open a pull request

## Development Setup

```bash
# Prerequisites
# - Docker
# - kubectl
# - k3d
# - helm

make local-cluster
make bootstrap
make status
```

## Guidelines

- All K8s manifests must pass `kubeconform -strict`
- Containers must run as non-root with `capabilities.drop: ["ALL"]`
- No hardcoded secrets or credentials in source
- Shell scripts must pass `shellcheck`
- Dockerfiles must pass `hadolint`

## What We Need Help With

- Additional Crossplane compositions (Redis, RabbitMQ)
- Backstage integration
- Multi-cloud Terraform modules (AWS, GCP)
- Better documentation and tutorials
- Security hardening

## Reporting Issues

Use GitHub Issues. Include:
- What you expected
- What happened
- Steps to reproduce
- Environment (OS, K8s version, tool versions)
