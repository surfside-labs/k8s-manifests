#!/usr/bin/env bash
# seal-secrets.sh — Generate SealedSecrets for dev and prod namespaces.
#
# Prerequisites:
#   - kubeseal installed locally (brew install kubeseal)
#   - kubectl configured with access to the cluster (KUBECONFIG set)
#   - Sealed Secrets controller running in sealed-secrets namespace
#
# Usage:
#   export KUBECONFIG=/path/to/kubeconfig
#   ./scripts/seal-secrets.sh
#
# Output files go into secrets/{dev,prod}/ — safe to commit to Git.

set -euo pipefail

CONTROLLER_NS=sealed-secrets
CONTROLLER_NAME=infra-sealed-secrets

seal() {
  local namespace="$1"
  local name="$2"
  local outfile="$3"
  shift 3
  # Remaining args are --from-literal key=value pairs
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

# ── GHCR pull secret ─────────────────────────────────────────────────────────
# Requires: GHCR_USER and GHCR_TOKEN env vars (a GitHub PAT with read:packages)
if [[ -z "${GHCR_USER:-}" || -z "${GHCR_TOKEN:-}" ]]; then
  echo "ERROR: Set GHCR_USER and GHCR_TOKEN before running this script."
  exit 1
fi

DOCKER_CONFIG=$(echo -n "{\"auths\":{\"ghcr.io\":{\"username\":\"${GHCR_USER}\",\"password\":\"${GHCR_TOKEN}\",\"auth\":\"$(echo -n "${GHCR_USER}:${GHCR_TOKEN}" | base64)\"}}}" | base64)

for ns in dev prod; do
  kubectl create secret docker-registry regcred \
    --namespace "$ns" \
    --docker-server=ghcr.io \
    --docker-username="${GHCR_USER}" \
    --docker-password="${GHCR_TOKEN}" \
    --dry-run=client \
    --output json \
    | kubeseal \
        --controller-namespace "$CONTROLLER_NS" \
        --controller-name "$CONTROLLER_NAME" \
        --format yaml \
    > "secrets/${ns}/regcred-sealed.yaml"
  echo "Written: secrets/${ns}/regcred-sealed.yaml"
done

# ── openclaw app secrets ──────────────────────────────────────────────────────
# Edit the --from-literal values below before running.
# Add all keys that openclaw reads from the openclaw-secrets Secret.
echo ""
echo "Sealing openclaw-secrets for dev..."
seal dev openclaw-secrets secrets/dev/openclaw-secrets-sealed.yaml \
  --from-literal=DATABASE_URL="postgres://openclaw:CHANGE_ME@postgres:5432/openclaw_dev" \
  --from-literal=SESSION_SECRET="CHANGE_ME_dev_session_secret"

echo "Sealing openclaw-secrets for prod..."
seal prod openclaw-secrets secrets/prod/openclaw-secrets-sealed.yaml \
  --from-literal=DATABASE_URL="postgres://openclaw:CHANGE_ME@postgres:5432/openclaw_prod" \
  --from-literal=SESSION_SECRET="CHANGE_ME_prod_session_secret"

echo ""
echo "Done. Commit the sealed files — they are safe for Git."
echo "  git add secrets/dev/ secrets/prod/"
echo "  git commit -m 'chore: add sealed secrets for dev and prod'"
