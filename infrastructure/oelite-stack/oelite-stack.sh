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

case "$cmd" in
  up)
    ensure_keyfile
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
    echo "Running one-time init (MongoDB CSRS → shard → add-shard → per-project DBs, RabbitMQ vhosts, MinIO buckets)..."
    docker compose -f docker-compose.shared.yml --profile init up
    echo ""
    echo "Init complete. Run './oelite-stack.sh health' to verify."
    ;;

  down)
    echo "Stopping OElite shared infrastructure (preserves volumes)..."
    docker compose -f docker-compose.shared.yml down
    ;;

  clean)
    echo "WARNING: This will DELETE all OElite data volumes."
    read -p "Type 'yes' to continue: " confirm
    if [ "$confirm" = "yes" ]; then
      docker compose -f docker-compose.shared.yml down -v
      rm -f .mongo.key
      echo "Cleaned."
    else
      echo "Aborted."
    fi
    ;;

  health)
    ./scripts/health-check.sh
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
  ./oelite-stack.sh up        Start all services
  ./oelite-stack.sh init      Initialize MongoDB sharding + per-project DBs + MinIO buckets
  ./oelite-stack.sh down      Stop all services (preserves volumes)
  ./oelite-stack.sh health    Run health checks against all services
  ./oelite-stack.sh status    Show running containers
  ./oelite-stack.sh logs      Tail logs (optionally: ./oelite-stack.sh logs oelite-mongos)
  ./oelite-stack.sh clean     DELETE all data volumes (irreversible)

First-time setup:
  ./oelite-stack.sh up
  ./oelite-stack.sh init
EOF
    ;;
esac
