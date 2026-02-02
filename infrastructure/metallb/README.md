# MetalLB Load Balancer

MetalLB provides LoadBalancer services for bare-metal Kubernetes clusters.

## Configuration

- **IP Pool**: 192.168.1.80 - 192.168.1.90
- **Mode**: Layer 2 (L2Advertisement)
- **Auto-assign**: Enabled

## Current Assignments

- `192.168.1.80`: OpenClaw service
- `192.168.1.81`: Traefik LoadBalancer

## Installation

MetalLB is installed via manifests. Apply with:

```bash
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.9/config/manifests/metallb-native.yaml
kubectl apply -f config.yaml
```

## Notes

- Uses native Kubernetes CRDs (IPAddressPool, L2Advertisement)
- Layer 2 mode requires nodes on same LAN segment
- IP range must not overlap with DHCP assignments
