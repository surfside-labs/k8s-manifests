# Traefik Infrastructure

This directory contains Traefik ingress controller configuration for K3s.

## Configuration

Traefik is deployed via K3s HelmChart CRD. The `values.yaml` file contains custom configuration for HTTPS on port 80 (bypassing Tailscale port 443 conflict).

## Key Settings

- **HTTPS on Port 80**: Traefik serves HTTPS traffic on port 80 instead of 443
- **NodePort 31001**: External access via Kubernetes NodePort
- **LoadBalancer IP**: 192.168.1.81 (assigned by MetalLB)
- **TLS Termination**: Traefik handles TLS, forwards HTTP to backends

## Applying Changes

K3s automatically applies HelmChart changes. To update:

```bash
kubectl patch helmchart traefik -n kube-system \
  --type=merge -p "{\"spec\":{\"valuesContent\":\"$(cat values.yaml)\"}}"
```

## Service Patch Required

After Helm chart updates, patch the service to map port 80 → websecure:

```bash
kubectl patch svc traefik -n kube-system --type=json \
  -p='[{"op": "replace", "path": "/spec/ports/0/targetPort", "value": "websecure"}]'
```
