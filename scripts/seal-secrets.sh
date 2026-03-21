#!/usr/bin/env bash
# seal-secrets.sh — Generate SealedSecrets for dev and prod namespaces.
#
# Prerequisites:
#   - kubeseal installed (brew install kubeseal  OR  already on master0 at /usr/local/bin/kubeseal)
#   - kubectl configured with access to the cluster
#   - Sealed Secrets controller running in sealed-secrets namespace
#
# Usage (run from repo root):
#   export KUBECONFIG=/etc/rancher/k3s/k3s.yaml   # on master0
#   export GHCR_USER=trentamoore
#   export GHCR_TOKEN=ghp_your_new_pat            # read:packages scope
#   export OPENCODE_API_KEY=oc_...
#   export SIGNAL_PHONE_NUMBER=+1234567890
#   export SIGNAL_PASSWORD=your-signal-pin
#   export GATEWAY_TOKEN=$(openssl rand -base64 32)
#   ./scripts/seal-secrets.sh
#
# Output files go into envs/{dev,prod}/openclaw/ — safe to commit to Git.

set -euo pipefail

CONTROLLER_NS=sealed-secrets
CONTROLLER_NAME=infra-sealed-secrets

seal_generic() {
  local namespace="$1"
  local name="$2"
  local outfile="$3"
  shift 3
  kubectl create secret generic "$name" \
    --namespace "$namespace" \
    --dry-run=client \
    --output json \
    "$@" \
    | kubeseal \
        --controller-namespace "$CONTROLLER_NS" \
        --controller-name "$CONTROLLER_NAME" \
        --format yaml \
    > "$outfile"
  echo "Written: $outfile"
}

# ── Validate required env vars ────────────────────────────────────────────────
required_vars=(GHCR_USER GHCR_TOKEN OPENCODE_API_KEY SIGNAL_PHONE_NUMBER SIGNAL_PASSWORD GATEWAY_TOKEN)
for v in "${required_vars[@]}"; do
  if [[ -z "${!v:-}" ]]; then
    echo "ERROR: \$$v is not set. Export all required vars before running."
    echo "Required: ${required_vars[*]}"
    exit 1
  fi
done

# ── GHCR pull secret (regcred) ────────────────────────────────────────────────
echo "Sealing regcred for dev..."
kubectl create secret docker-registry regcred \
  --namespace dev \
  --docker-server=ghcr.io \
  --docker-username="${GHCR_USER}" \
  --docker-password="${GHCR_TOKEN}" \
  --dry-run=client --output json \
  | kubeseal \
      --controller-namespace "$CONTROLLER_NS" \
      --controller-name "$CONTROLLER_NAME" \
      --format yaml \
  > envs/dev/openclaw/regcred-sealed.yaml
echo "Written: envs/dev/openclaw/regcred-sealed.yaml"

echo "Sealing regcred for prod..."
kubectl create secret docker-registry regcred \
  --namespace prod \
  --docker-server=ghcr.io \
  --docker-username="${GHCR_USER}" \
  --docker-password="${GHCR_TOKEN}" \
  --dry-run=client --output json \
  | kubeseal \
      --controller-namespace "$CONTROLLER_NS" \
      --controller-name "$CONTROLLER_NAME" \
      --format yaml \
  > envs/prod/openclaw/regcred-sealed.yaml
echo "Written: envs/prod/openclaw/regcred-sealed.yaml"

# ── openclaw app secrets ──────────────────────────────────────────────────────
echo ""
echo "Sealing openclaw-secrets for dev..."
seal_generic dev openclaw-secrets envs/dev/openclaw/openclaw-secrets-sealed.yaml \
  --from-literal=OPENCODE_API_KEY="${OPENCODE_API_KEY}" \
  --from-literal=SIGNAL_PHONE_NUMBER="${SIGNAL_PHONE_NUMBER}" \
  --from-literal=SIGNAL_PASSWORD="${SIGNAL_PASSWORD}" \
  --from-literal=GATEWAY_TOKEN="${GATEWAY_TOKEN}"

echo "Sealing openclaw-secrets for prod..."
seal_generic prod openclaw-secrets envs/prod/openclaw/openclaw-secrets-sealed.yaml \
  --from-literal=OPENCODE_API_KEY="${OPENCODE_API_KEY}" \
  --from-literal=SIGNAL_PHONE_NUMBER="${SIGNAL_PHONE_NUMBER}" \
  --from-literal=SIGNAL_PASSWORD="${SIGNAL_PASSWORD}" \
  --from-literal=GATEWAY_TOKEN="${GATEWAY_TOKEN}"

echo ""
echo "Done. Commit all sealed files:"
echo "  git add envs/dev/openclaw/ envs/prod/openclaw/"
echo "  git commit -m 'chore: rotate sealed secrets'"
echo "  git push origin main"
