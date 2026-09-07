#!/bin/bash
# Health check for OElite shared infrastructure
# Verifies all services are reachable and responding via docker exec.
# Credentials are sourced from .env (gitignored) for services that
# require authentication (Redis, ClickHouse, MongoDB root).
set -eu

STACK_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$STACK_DIR/.env"
if [ -f "$ENV_FILE" ]; then
  set -a
  . "$ENV_FILE"
  set +a
fi

GREEN='\033[0;32m'; RED='\033[0;31m'; YEL='\033[1;33m'; NC='\033[0m'
ok()   { printf "  ${GREEN}[OK]${NC}  %s\n" "$1"; }
fail() { printf "  ${RED}[FAIL]${NC} %s\n" "$1"; }
warn() { printf "  ${YEL}[WARN]${NC} %s\n" "$1"; }

check() {
  local name="$1"; local cmd="$2"
  if eval "$cmd" >/dev/null 2>&1; then ok "$name"; else fail "$name"; return 1; fi
}

echo "============================================================"
echo "  OElite shared infrastructure health check"
echo "============================================================"

# MongoDB — uses localhost exception (no auth needed for ping)
check "MongoDB configsvr-1 (27019)" "docker exec oelite-mongo-configsvr-1 mongosh --quiet --port 27019 --eval 'db.adminCommand({ping:1})' >/dev/null 2>&1"
check "MongoDB configsvr-2 (27019)" "docker exec oelite-mongo-configsvr-2 mongosh --quiet --port 27019 --eval 'db.adminCommand({ping:1})' >/dev/null 2>&1"
check "MongoDB configsvr-3 (27019)" "docker exec oelite-mongo-configsvr-3 mongosh --quiet --port 27019 --eval 'db.adminCommand({ping:1})' >/dev/null 2>&1"
check "MongoDB shard1-primary (27018)" "docker exec oelite-mongo-shard1-primary mongosh --quiet --port 27018 --eval 'db.adminCommand({ping:1})' >/dev/null 2>&1"
check "MongoDB shard1-secondary (27018)" "docker exec oelite-mongo-shard1-secondary mongosh --quiet --port 27018 --eval 'db.adminCommand({ping:1})' >/dev/null 2>&1"
check "MongoDB mongos (27017)" "docker exec oelite-mongos mongosh --quiet --port 27017 --eval 'db.adminCommand({ping:1})' >/dev/null 2>&1"

# Redis — requires password (requirepass)
REDIS_P="${REDIS_PASSWORD:-}"
check "Redis" "docker exec oelite-redis redis-cli --raw -a '$REDIS_P' ping | grep -q PONG"

# ClickHouse — HTTP ping (no auth on /ping endpoint)
check "ClickHouse HTTP (8123)" "curl -sf http://localhost:8123/ping >/dev/null 2>&1"

# Kafka — list topics (no auth)
check "Kafka (9092)" "docker exec oelite-kafka kafka-topics --bootstrap-server localhost:9092 --list >/dev/null 2>&1"

# RabbitMQ — AMQP ping (no auth on internal diagnostics)
check "RabbitMQ AMQP (5672)" "docker exec oelite-rabbitmq rabbitmq-diagnostics -q ping >/dev/null 2>&1"

# MinIO — health endpoint (no auth)
check "MinIO API (9000)" "curl -sf http://localhost:9000/minio/health/live >/dev/null 2>&1"

# Check MongoDB sharding status
echo ""
echo "MongoDB cluster status:"
docker exec oelite-mongos mongosh --quiet --port 27017 --eval 'JSON.stringify({version: db.version(), shards: db.adminCommand({listShards:1}).shards.map(s=>s._id)}, null, 2)' 2>/dev/null || warn "Could not query sharding status"

echo ""
echo "============================================================"
echo "  Done."
echo "============================================================"
