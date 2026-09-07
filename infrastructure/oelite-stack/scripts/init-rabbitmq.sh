#!/bin/sh
# OElite RabbitMQ per-project vhost setup
# Creates one vhost + dedicated user per OElite project on the shared RabbitMQ.
# Idempotent: safe to re-run.
set -eu

RABBIT_HOST="${RABBIT_HOST:-oelite-rabbitmq}"
RABBIT_PORT="${RABBIT_PORT:-15672}"
RABBIT_USER="${RABBITMQ_DEFAULT_USER:-oelite}"
RABBIT_PASS="${RABBITMQ_DEFAULT_PASS:-oelite123}"

PROJECTS="
origin_auth
apex
obelisk
synapse
stela
hermes
orion
kortex
oesterling
helios_core
sip
stela_runtime
"

echo "============================================================"
echo "  OElite RabbitMQ per-project vhost setup"
echo "============================================================"

# Wait for RabbitMQ management API
for i in $(seq 1 30); do
  if curl -sf -u "$RABBIT_USER:$RABBIT_PASS" "http://$RABBIT_HOST:$RABBIT_PORT/api/overview" >/dev/null 2>&1; then
    break
  fi
  echo "Waiting for RabbitMQ..."
  sleep 2
done

# Verify reachable
if ! curl -sf -u "$RABBIT_USER:$RABBIT_PASS" "http://$RABBIT_HOST:$RABBIT_PORT/api/overview" >/dev/null 2>&1; then
  echo "ERROR: RabbitMQ management API not reachable after 60s"
  exit 1
fi

AUTH="-u $RABBIT_USER:$RABBIT_PASS"
BASE="http://$RABBIT_HOST:$RABBIT_PORT/api"

for proj in $PROJECTS; do
  vhost="/oelite/$proj"
  user="oelite_$proj"
  pass="oelite_${proj}_dev"

  # Create vhost (PUT is idempotent)
  if curl -sf $AUTH -X PUT -H 'content-type:application/json' -d '{}' "$BASE/vhosts/$(printf '%s' "$vhost" | sed 's|/|%2F|g')" >/dev/null 2>&1; then
    echo "  vhost: $vhost"
  else
    echo "  vhost exists or error: $vhost"
  fi

  # Create user (PUT is idempotent)
  if curl -sf $AUTH -X PUT -H 'content-type:application/json' \
    -d "{\"password\":\"$pass\",\"tags\":\"\"}" \
    "$BASE/users/$user" >/dev/null 2>&1; then
    echo "    user: $user"
  else
    echo "    user exists or error: $user"
  fi

  # Grant permissions (configure/write/read) on the vhost
  curl -sf $AUTH -X PUT -H 'content-type:application/json' \
    -d '{"configure":".*","write":".*","read":".*"}' \
    "$BASE/permissions/$(printf '%s' "$vhost" | sed 's|/|%2F|g')/$user" >/dev/null 2>&1
done

echo ""
echo "Per-project RabbitMQ connection strings:"
for proj in $PROJECTS; do
  echo "  $proj: amqp://oelite_$proj:oelite_${proj}_dev@localhost:5672/oelite/$proj"
done
echo ""
