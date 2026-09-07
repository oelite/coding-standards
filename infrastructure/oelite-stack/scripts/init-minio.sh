#!/bin/sh
# OElite MinIO per-project bucket setup
# Creates one bucket per OElite project on the shared MinIO instance.
# Runs once on `docker compose --profile init up`.

MINIO_HOST="${MINIO_HOST:-oelite-minio}"
MINIO_PORT="${MINIO_PORT:-9000}"
MC_ALIAS="oelite"
MC_USER="${MINIO_ROOT_USER:-oelite}"
MC_PASS="${MINIO_ROOT_PASSWORD:-oelite123}"

BUCKETS="
oelite-origin-auth
oelite-apex
oelite-obelisk
oelite-synapse
oelite-stela
oelite-hermes
oelite-orion
oelite-kortex
oelite-oesterling
oelite-helios-core
oelite-sip
oelite-stela-runtime
"

echo "============================================================"
echo "  OElite MinIO bucket setup"
echo "============================================================"

# Wait for MinIO to be ready
for i in $(seq 1 30); do
  mc alias set $MC_ALIAS http://$MINIO_HOST:$MINIO_PORT $MC_USER $MC_PASS 2>/dev/null && break
  echo "Waiting for MinIO..."
  sleep 2
done

for bucket in $BUCKETS; do
  result=$(mc ls $MC_ALIAS/$bucket 2>&1)
  ret=$?
  if [ $ret -eq 0 ]; then
    echo "  exists:   $bucket"
  elif echo "$result" | grep -q "does not exist"; then
    err=$(mc mb $MC_ALIAS/$bucket 2>&1)
    if [ $? -eq 0 ]; then
      echo "  created:   $bucket"
    else
      echo "  ERROR: $bucket — mc mb failed: $err" >&2
    fi
  else
    echo "  ERROR: $bucket — mc ls failed: $result" >&2
  fi
done

echo ""
echo "============================================================"
echo "  Done. Console: http://localhost:9001"
echo "  User: $MC_USER  Pass: $MC_PASS"
echo "============================================================"
