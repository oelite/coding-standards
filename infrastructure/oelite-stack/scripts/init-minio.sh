#!/bin/sh
# OElite MinIO bucket setup for a SINGLE project (project-level onboarding).
# Creates one bucket for the project on the shared MinIO instance. Idempotent.
#
# This is NOT run by `oelite-stack.sh init`. Each project invokes it during its
# own onboarding, passing its bucket name:
#   ./scripts/init-minio.sh oelite-origin-auth
#
# The shared stack exposes only the superuser (MINIO_ROOT_USER/PASSWORD).
# Per-project buckets/keys are the project's responsibility.
set -eu

BUCKET="${1:-}"
if [ -z "$BUCKET" ]; then
  echo "ERROR: bucket name required"
  echo "Usage: $0 <bucket-name>   e.g. $0 oelite-origin-auth"
  exit 1
fi

MINIO_HOST="${MINIO_HOST:-oelite-minio}"
MINIO_PORT="${MINIO_PORT:-9000}"
MC_ALIAS="oelite"
MC_USER="${MINIO_ROOT_USER:-oelite}"
MC_PASS="${MINIO_ROOT_PASSWORD:-oelite123}"

echo "============================================================"
echo "  OElite MinIO bucket setup for: $BUCKET"
echo "============================================================"

# Wait for MinIO to be ready
for i in $(seq 1 30); do
  mc alias set $MC_ALIAS "http://$MINIO_HOST:$MINIO_PORT" "$MC_USER" "$MC_PASS" 2>/dev/null && break
  echo "Waiting for MinIO..."
  sleep 2
done

result=$(mc ls "$MC_ALIAS/$BUCKET" 2>&1)
ret=$?
if [ $ret -eq 0 ]; then
  echo "  exists:  $BUCKET"
elif echo "$result" | grep -q "does not exist"; then
  err=$(mc mb "$MC_ALIAS/$BUCKET" 2>&1)
  if [ $? -eq 0 ]; then
    echo "  created: $BUCKET"
  else
    echo "  ERROR: $BUCKET — mc mb failed: $err" >&2
    exit 1
  fi
else
  echo "  ERROR: $BUCKET — mc ls failed: $result" >&2
  exit 1
fi

echo ""
echo "============================================================"
echo "  Done. Console: http://localhost:9001"
echo "  Bucket: $BUCKET"
echo "============================================================"
