# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability, please report it responsibly:

1. **Do NOT** open a public issue
2. Email: security@veloxlabs.dev
3. Include: description, steps to reproduce, potential impact

We will respond within 48 hours and work with you to resolve the issue.

## Security Practices

- All container images are scanned by Trivy in CI and at runtime
- OPA Gatekeeper enforces pod security policies
- No secrets are committed to the repository
- GitHub Actions are pinned by SHA
- Helm chart versions are pinned
- Containers run as non-root by default
- NetworkPolicies restrict pod-to-pod traffic

## Supported Versions

| Version | Supported |
|---------|-----------|
| main    | Yes       |

## Scope

This policy covers the InfraForge repository and its deployment artifacts. It does not cover third-party dependencies, though we monitor them via Trivy.
