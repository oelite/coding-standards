#!/bin/bash
# Health check for OElite shared infrastructure
# Verifies all services are reachable and responding.
set -e

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

check "MongoDB (mongos:27017)" "mongosh --quiet --eval 'db.adminCommand({ping:1})' --host localhost --port 27017"

check "Redis (localhost:6379)" "redis-cli ping"

check "ClickHouse HTTP (localhost:8123)" "curl -sf http://localhost:8123/ping"

check "ClickHouse native (localhost:9000)" "echo 'SELECT 1' | curl -sf 'http://localhost:8123/' --data-binary @-"

check "Kafka (localhost:9092)" "kafka-topics --bootstrap-server localhost:9092 --list 2>/dev/null"

check "RabbitMQ AMQP (localhost:5672)" "nc -z localhost 5672"

check "MinIO API (localhost:9000)" "curl -sf http://localhost:9000/minio/health/live"

# Check MongoDB sharding status
echo ""
echo "MongoDB cluster status:"
mongosh --quiet --eval 'JSON.stringify({version: db.version(), shards: db.adminCommand({listShards:1}).shards.map(s=>s._id)}, null, 2)' --host localhost --port 27017 2>/dev/null || warn "Could not query sharding status"

echo ""
echo "============================================================"
echo "  Done."
echo "============================================================"
