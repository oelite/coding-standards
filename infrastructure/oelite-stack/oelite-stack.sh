#!/bin/bash
# OElite Shared Local Infrastructure Manager
# Single entrypoint for managing the shared stack on this machine.
# Usage: ./oelite-stack.sh {up|down|init|health|status|logs|clean}
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

cmd="${1:-help}"

# Generate the keyfile for MongoDB if not present
ensure_keyfile() {
  if [ ! -f .mongo.key ]; then
    echo "[keyfile] Generating MongoDB cluster keyfile..."
    openssl rand -base64 756 > .mongo.key
    chmod 400 .mongo.key
  fi
}

# Ensure .env exists with random credentials (first run only)
ensure_secrets() {
  if [ ! -f .env ] || [ ! -s .env ]; then
    echo "[secrets] Generating .env with random credentials..."
    ./scripts/generate-secrets.sh
  fi
}

case "$cmd" in
  up)
    ensure_keyfile
    ensure_secrets
    echo "Starting OElite shared infrastructure..."
    docker compose -f docker-compose.shared.yml up -d
    echo ""
    echo "Waiting for health checks..."
    sleep 30
    ./scripts/health-check.sh || true
    echo ""
    echo "Run './oelite-stack.sh init' to initialize MongoDB sharding and per-project DBs."
    ;;

  init)
    ensure_keyfile
    ensure_secrets
    echo "Running one-time init (MongoDB CSRS → shard → add-shard → per-project DBs, RabbitMQ vhosts, MinIO buckets)..."
    docker compose -f docker-compose.shared.yml --profile init up --abort-on-container-exit
    # Remove exited init containers after they complete their one-shot work
    docker compose -f docker-compose.shared.yml --profile init down --rmi local 2>/dev/null || true
    echo ""
    echo "Init complete. Run './oelite-stack.sh health' to verify."
    ;;

  down)
    echo "Stopping OElite shared infrastructure (preserves volumes)..."
    docker compose -f docker-compose.shared.yml down
    ;;

  clean)
    echo "WARNING: This will DELETE all OElite data volumes."
    echo "Your .env and .mongo.key credentials are preserved (gitignored)."
    read -p "Type 'yes' to continue: " confirm
    if [ "$confirm" = "yes" ]; then
      docker compose -f docker-compose.shared.yml down -v
      echo "Cleaned."
    else
      echo "Aborted."
    fi
    ;;

  health)
    ./scripts/health-check.sh
    ;;

  secrets)
    ./scripts/generate-secrets.sh --rotate
    echo ""
    echo "Secrets rotated. Credentials are stored in .env and seeded into"
    echo "data volumes (e.g. the MongoDB root user). A simple restart is NOT"
    echo "enough — use clean+re-up to pick up new credentials:"
    echo "  ./oelite-stack.sh clean && ./oelite-stack.sh up && ./oelite-stack.sh init"
    ;;

  status)
    docker compose -f docker-compose.shared.yml ps
    ;;

  logs)
    docker compose -f docker-compose.shared.yml logs -f "${2:-}"
    ;;

  help|*)
    cat <<EOF
OElite Shared Local Infrastructure Manager

Usage:
  ./oelite-stack.sh up        Start all services (generates .env if missing)
  ./oelite-stack.sh init      Initialize DBs, users, vhosts, buckets (read-only-safe)
  ./oelite-stack.sh down      Stop all services (preserves volumes)
  ./oelite-stack.sh health    Run health checks against all services
  ./oelite-stack.sh status    Show running containers
  ./oelite-stack.sh logs      Tail logs (optionally: ./oelite-stack.sh logs oelite-mongos)
   ./oelite-stack.sh secrets   Rotate all credentials (regenerates .env)
   ./oelite-stack.sh clean     DELETE all data volumes (.env/.mongo.key preserved)

First-time setup:
  ./oelite-stack.sh up
  ./oelite-stack.sh init

Secrets management:
  ./oelite-stack.sh secrets         Regenerate all random credentials
  ./scripts/generate-secrets.sh --print  View current credentials (SENSITIVE)
EOF
    ;;
esac
