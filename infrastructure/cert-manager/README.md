# cert-manager

cert-manager is a Kubernetes addon to automate certificate management.

## Installation

cert-manager is installed via official manifests:

```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.16.2/cert-manager.yaml
```

## Current Usage

- **Self-signed certificates**: ArgoCD and OpenClaw use self-signed certs
- **TLS secrets**: Stored in respective namespaces

## Future: Let's Encrypt Integration

To enable automated Let's Encrypt certificates:

1. Create ClusterIssuer for Let's Encrypt
2. Update IngressRoute TLS sections to use cert-manager annotations
3. Configure DNS-01 or HTTP-01 challenge method

Example ClusterIssuer (not yet implemented):

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@surfside-labs.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - dns01:
        # Configure DNS provider here
```
