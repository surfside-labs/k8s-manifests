# Surfside Labs Kubernetes Manifests

GitOps repository for Surfside Labs K3s cluster managed by ArgoCD.

## Repository Structure

```
k8s-manifests/
├── apps/                    # Application deployments
│   ├── argocd/             # ArgoCD ingress configuration
│   └── openclaw/           # OpenClaw API Gateway
├── infrastructure/          # Infrastructure components
│   ├── cert-manager/       # Certificate management
│   ├── metallb/            # Load balancer configuration
│   └── traefik/            # Ingress controller
└── argocd-apps/            # ArgoCD Application manifests
    ├── argocd-ingress.yaml
    ├── metallb.yaml
    └── openclaw.yaml
```

## Cluster Information

- **Cluster**: K3s v1.34.3+k3s1
- **Node**: master0.surfside-labs.com (Raspberry Pi 5)
- **Domain**: surfside-labs.com
- **Tailscale IP**: 100.125.173.53
- **LAN IP**: 192.168.1.80

## Applications

### OpenClaw
API Gateway for Surfside Labs infrastructure.

- **Namespace**: `openclaw`
- **Service Type**: LoadBalancer (192.168.1.80)
- **Ingress**: `https://openclaw.surfside-labs.com:31001`
- **Storage**: 2x PVCs (5Gi config, 10Gi workspace)

### ArgoCD
GitOps continuous delivery platform.

- **Namespace**: `argocd`
- **UI**: `https://argocd.surfside-labs.com:31001`
- **Username**: `admin`
- **Ingress**: Traefik IngressRoute with TLS

## Infrastructure

### Traefik
Ingress controller with custom configuration for HTTPS on port 80.

- **Namespace**: `kube-system`
- **Version**: 3.5.1
- **LoadBalancer IP**: 192.168.1.81
- **NodePort**: 31001 (websecure entrypoint)
- **Special Config**: HTTPS served on port 80 to bypass Tailscale port 443 conflict

### MetalLB
LoadBalancer implementation for bare-metal Kubernetes.

- **Namespace**: `metallb-system`
- **IP Pool**: 192.168.1.80 - 192.168.1.90
- **Mode**: Layer 2

### cert-manager
Certificate management (currently using self-signed certificates).

- **Namespace**: `cert-manager`
- **Version**: v1.16.2

## Getting Started

### Prerequisites

1. K3s cluster running
2. ArgoCD installed
3. kubectl configured
4. Access to this Git repository

### Initial Setup

1. **Clone this repository**:
   ```bash
   git clone https://github.com/surfside-labs/k8s-manifests.git
   cd k8s-manifests
   ```

2. **Deploy ArgoCD Applications**:
   ```bash
   # Apply all ArgoCD Application manifests
   kubectl apply -f argocd-apps/
   ```

3. **Verify synchronization**:
   ```bash
   # Check application status
   kubectl get applications -n argocd
   
   # Watch sync progress
   argocd app list
   ```

### ArgoCD Login

```bash
# Port-forward ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Get admin password
kubectl get secret argocd-initial-admin-secret -n argocd \
  -o jsonpath="{.data.password}" | base64 -d
```

## Making Changes

### GitOps Workflow

1. **Make changes** to manifests in this repository
2. **Commit and push** to the main branch
3. **ArgoCD automatically syncs** changes to cluster (if auto-sync enabled)
4. **Or manually sync** via ArgoCD UI or CLI

### Example: Update OpenClaw Image

```bash
# Edit deployment
vim apps/openclaw/deployment.yaml

# Update image tag
# image: ghcr.io/surfside-labs/openclaw:new-tag

# Commit and push
git add apps/openclaw/deployment.yaml
git commit -m "Update OpenClaw to new-tag"
git push origin main

# ArgoCD will automatically deploy the change
```

### Manual Sync

```bash
# Sync specific application
argocd app sync openclaw

# Sync all applications
argocd app sync --all
```

## Sync Policies

All applications are configured with:

- **Auto-sync**: Enabled (changes automatically deployed)
- **Self-heal**: Enabled (manual kubectl changes reverted)
- **Prune**: Enabled (removed manifests delete resources)

## Important Notes

### HTTPS on Port 80

Traefik is configured to serve HTTPS on port 80 instead of 443 due to Tailscale daemon occupying port 443 on the Tailscale IP.

**Access URLs**:
- ArgoCD: `https://argocd.surfside-labs.com:31001`
- OpenClaw: `https://openclaw.surfside-labs.com:31001`

### Storage Considerations

- **PVs use local-path provisioner** (hostPath-based)
- **Data stored in**: `/var/lib/rancher/k3s/storage/`
- **Node-specific**: PVs bound to specific nodes (not portable)
- **Backup important**: Backup `/var/lib/rancher/k3s/storage/` for disaster recovery

### ArgoCD Insecure Mode

ArgoCD runs with `server.insecure: "true"` to accept HTTP traffic from Traefik (which handles TLS termination). This is secure - TLS is enforced at Traefik layer.

## Troubleshooting

### Application Out of Sync

```bash
# Check application status
argocd app get openclaw

# View differences
argocd app diff openclaw

# Force sync
argocd app sync openclaw --force
```

### Check Pod Status

```bash
# List all pods
kubectl get pods -A

# Check specific application
kubectl get pods -n openclaw

# View logs
kubectl logs -n openclaw -l app=openclaw
```

### Ingress Not Working

```bash
# Check IngressRoute
kubectl get ingressroute -A

# Check Traefik service
kubectl get svc traefik -n kube-system

# Test from cluster
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl -k https://openclaw.argocd.svc.cluster.local
```

## Security

### Secrets Management

**Important**: Secrets are NOT stored in this repository. Current secrets:

- `openclaw-secrets` (namespace: openclaw)
- `argocd-initial-admin-secret` (namespace: argocd)
- `argocd-server-tls-prod` (namespace: argocd)
- `openclaw-server-tls-prod` (namespace: openclaw)
- `regcred` (namespace: openclaw) - GitHub Container Registry credentials

These must be manually created or managed via external secret management tools.

### Future: Sealed Secrets

Consider implementing Sealed Secrets or External Secrets Operator for GitOps-friendly secret management.

## Monitoring

### Application Health

```bash
# Check all applications
argocd app list

# Get detailed status
argocd app get openclaw

# View sync history
argocd app history openclaw
```

### Cluster Resources

```bash
# Resource usage
kubectl top nodes
kubectl top pods -A

# PVC status
kubectl get pvc -A

# Service endpoints
kubectl get svc -A
```

## Maintenance

### Update Application

1. Update manifest files in Git
2. Commit and push changes
3. ArgoCD auto-syncs (or manually sync)
4. Verify deployment

### Rollback

```bash
# View application history
argocd app history openclaw

# Rollback to specific revision
argocd app rollback openclaw <revision-id>
```

### Prune Resources

```bash
# Remove resources no longer in Git
argocd app sync openclaw --prune
```

## Contributing

1. Create a feature branch
2. Make changes
3. Test in staging environment (if available)
4. Create pull request
5. After merge, ArgoCD syncs to production

## Support

For issues or questions:
- Check ArgoCD UI for sync status
- Review pod logs: `kubectl logs -n <namespace> <pod-name>`
- Check application events: `kubectl describe app -n argocd <app-name>`

## References

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [K3s Documentation](https://docs.k3s.io/)
- [Traefik Documentation](https://doc.traefik.io/traefik/)
- [MetalLB Documentation](https://metallb.universe.tf/)
- [cert-manager Documentation](https://cert-manager.io/docs/)

---

**Last Updated**: February 2, 2026  
**Managed By**: Surfside Labs  
**Cluster**: master0.surfside-labs.com
