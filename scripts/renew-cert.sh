#!/bin/bash
export STEPPATH="$(dirname "$0")/../ca"
CERTS_DIR="$(dirname "$0")/../certs"

step ca renew \
  "$CERTS_DIR/svc.crt" \
  "$CERTS_DIR/svc.key" \
  --force \
  --expires-in 2m

echo "Renewed at $(date)"
step certificate inspect "$CERTS_DIR/svc.crt" --short
