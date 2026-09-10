#!/bin/sh
# OElite RabbitMQ vhost setup for a SINGLE project (project-level onboarding).
# Creates one vhost + dedicated user on the shared RabbitMQ. Idempotent.
#
# This is NOT run by `oelite-stack.sh init`. Each project invokes it during its
# own onboarding, passing its project slug:
#   ./scripts/init-rabbitmq.sh origin_auth
#
# The shared stack exposes only the superuser (RABBITMQ_DEFAULT_USER/PASS).
# Per-project credentials/namespaces are the project's responsibility.
set -eu

PROJECT_NAME="${1:-}"
if [ -z "$PROJECT_NAME" ]; then
  echo "ERROR: project slug required"
  echo "Usage: $0 <project-slug>   e.g. $0 origin_auth"
  exit 1
fi

RABBIT_HOST="${RABBIT_HOST:-oelite-rabbitmq}"
RABBIT_PORT="${RABBIT_PORT:-15672}"
RABBIT_USER="${RABBITMQ_DEFAULT_USER:-oelite}"
RABBIT_PASS="${RABBITMQ_DEFAULT_PASS:-oelite123}"

echo "============================================================"
echo "  OElite RabbitMQ vhost setup for: $PROJECT_NAME"
echo "============================================================"

# Wait for RabbitMQ management API
for i in $(seq 1 30); do
  if curl -sf -u "$RABBIT_USER:$RABBIT_PASS" "http://$RABBIT_HOST:$RABBIT_PORT/api/overview" >/dev/null 2>&1; then
    break
  fi
  echo "Waiting for RabbitMQ..."
  sleep 2
done

if ! curl -sf -u "$RABBIT_USER:$RABBIT_PASS" "http://$RABBIT_HOST:$RABBIT_PORT/api/overview" >/dev/null 2>&1; then
  echo "ERROR: RabbitMQ management API not reachable after 60s"
  exit 1
fi

AUTH="-u $RABBIT_USER:$RABBIT_PASS"
BASE="http://$RABBIT_HOST:$RABBIT_PORT/api"
VHOST="/oelite/$PROJECT_NAME"
USER="oelite_$PROJECT_NAME"
PASS="${RABBITMQ_PROJECT_PASSWORD:-oelite_${PROJECT_NAME}_dev}"
VHOST_ENC="$(printf '%s' "$VHOST" | sed 's|/|%2F|g')"

# Create vhost (PUT is idempotent)
if curl -sf $AUTH -X PUT -H 'content-type:application/json' -d '{}' "$BASE/vhosts/$VHOST_ENC" >/dev/null 2>&1; then
  echo "  vhost: $VHOST"
else
  echo "  vhost exists or error: $VHOST"
fi

# Create user (PUT is idempotent)
if curl -sf $AUTH -X PUT -H 'content-type:application/json' \
  -d "{\"password\":\"$PASS\",\"tags\":\"\"}" \
  "$BASE/users/$USER" >/dev/null 2>&1; then
  echo "    user: $USER"
else
  echo "    user exists or error: $USER"
fi

# Grant permissions (configure/write/read) on the vhost
curl -sf $AUTH -X PUT -H 'content-type:application/json' \
  -d '{"configure":".*","write":".*","read":".*"}' \
  "$BASE/permissions/$VHOST_ENC/$USER" >/dev/null 2>&1

echo ""
echo "Project RabbitMQ connection string (store in the project's own secrets):"
echo "  amqp://$USER:$PASS@localhost:5672/oelite/$PROJECT_NAME"
echo ""
