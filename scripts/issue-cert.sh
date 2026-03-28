#!/bin/bash
export STEPPATH="$(dirname "$0")/../ca"
CERTS_DIR="$(dirname "$0")/../certs"

step ca certificate localhost \
  "$CERTS_DIR/svc.crt" \
  "$CERTS_DIR/svc.key" \
  --ca-url https://localhost:9000 \
  --not-after=5m \
  --force

echo "Issued at $(date)"
step certificate inspect "$CERTS_DIR/svc.crt" --short
