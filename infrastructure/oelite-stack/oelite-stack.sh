#!/bin/bash
# OElite Shared Local Infrastructure Manager
# Single entrypoint for managing the shared stack on this machine.
# Usage: ./oelite-stack.sh {up|down|init|health|status|logs|clean}
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

cmd="${1:-help}"

# Parse global flags (must come before subcommands)
WITH_UI=1
shift_extra_args() {
  shift
}
for arg in "$@"; do
  case "$arg" in
    --no-ui)  WITH_UI=0 ;;
  esac
done

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

# Build compose profile args (UIs are opt-in via --profile ui)
compose_profile_args() {
  if [ "$WITH_UI" -eq 1 ]; then
    echo "--profile ui"
  fi
}

case "$cmd" in
  up)
    ensure_keyfile
    ensure_secrets
    echo "Starting OElite shared infrastructure..."
    docker compose -f docker-compose.shared.yml $(compose_profile_args) up -d
    echo ""
    echo "Waiting for health checks..."
    sleep 30
    ./scripts/health-check.sh || true
    echo ""
    if [ "$WITH_UI" -eq 1 ]; then
      echo "Run './oelite-stack.sh up --no-ui' to skip debug UIs (saves ~1 GB RAM)."
    else
      echo "Run './oelite-stack.sh up' to include debug UIs."
    fi
    echo "Run './oelite-stack.sh init' to initialize MongoDB sharding and per-project DBs."
    ;;

  init)
    ensure_keyfile
    ensure_secrets
    echo "Running one-time init (MongoDB CSRS → shard → add-shard)..."
    docker compose -f docker-compose.shared.yml --profile init up
    echo ""
    ./scripts/init-clickhouse-users.sh
    echo ""
    echo "Init complete. Run './oelite-stack.sh health' to verify."
    echo ""
    echo "Per-project databases/vhosts/buckets are created by each project during onboarding."
    echo "See scripts/init-per-project-dbs.sh, init-rabbitmq.sh, and init-minio.sh."
    echo "If a project's RabbitMQ auth fails (ACCESS_REFUSED), repair it with:"
    echo "  ./oelite-stack.sh repair-rabbitmq <project-slug>"
    ;;

  repair-rabbitmq)
    if [ ! -f .env ] || [ ! -s .env ]; then
      echo "ERROR: stack .env not found in $(pwd). Run './oelite-stack.sh up' first —" >&2
      echo "the broker's superuser is seeded from it and the repair needs those credentials." >&2
      exit 1
    fi
    shift
    if [ -z "${1:-}" ]; then
      echo "Usage: ./oelite-stack.sh repair-rabbitmq <project-slug>   e.g. ./oelite-stack.sh repair-rabbitmq hermes" >&2
      exit 1
    fi
    echo "Repairing RabbitMQ vhost/user/permissions for project: $1"
    echo "(Idempotent — recreates the vhost, re-syncs the per-project user password"
    echo " to the canonical onboarding value, and re-grants vhost permissions.)"
    echo ""
    set -a
    . ./.env
    set +a
    RABBIT_HOST="${RABBIT_HOST:-localhost}" ./scripts/init-rabbitmq.sh "$1"
    echo "Repair complete. Re-authentication as oelite_$1 should now succeed."
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

  cluster)
    ENV_NAME="${2:-}"
    ACTION="${3:-}"
    if [ -z "$ENV_NAME" ]; then
      echo "Usage: ./oelite-stack.sh cluster <ENV> [kubectl|health|audit|kubeconfig-path] [args...]"
      echo ""
      echo "Available environments:"
      for d in clusters/*/; do
        env_name="$(basename "$d")"
        echo "  - $env_name"
      done
      exit 1
    fi
    KC_DIR="clusters/$ENV_NAME/kubeconfig"
    if [ ! -d "$KC_DIR" ]; then
      echo "[ERR] No kubeconfig dir for env '$ENV_NAME' (expected $KC_DIR/). Available: "
      ls -1 clusters/ 2>/dev/null | sed 's/^/  - /'
      exit 1
    fi
    # Resolve the single kubeconfig file (any name) inside the kubeconfig/ dir.
    KC_FILE=""
    count=0
    for f in "$KC_DIR"/*; do
      # Skip dotfiles and .DS_Store
      [ -e "$f" ] || continue
      base="$(basename "$f")"
      case "$base" in .*) continue ;; esac
      [ -f "$f" ] || continue
      KC_FILE="$f"
      count=$((count+1))
    done
    if [ "$count" -eq 0 ]; then
      echo "[ERR] No kubeconfig found in $KC_DIR/"
      exit 1
    fi
    if [ "$count" -gt 1 ]; then
      echo "[WARN] Multiple kubeconfig files in $KC_DIR/; using first ($KC_FILE)."
      echo "       Standard: exactly ONE kubeconfig per environment."
      ls -1 "$KC_DIR" | grep -v '^\.'
    fi
    export KUBECONFIG="$(pwd)/$KC_FILE"

    case "$ACTION" in
      kubectl|run|"")
        # Either 'kubectl' subcommand or run the action itself as kubectl args
        if [ "$ACTION" = "kubectl" ] || [ -z "$ACTION" ]; then
          kubectl "${@:4}" 2>/dev/null || exec kubectl "${@:4}"
        else
          # Treat ACTION as first kubectl arg: e.g. `cluster UAT get pods`
          kubectl "$ACTION" "${@:4}" 2>/dev/null || exec kubectl "$ACTION" "${@:4}"
        fi
        ;;
      health)
        echo "=== Cluster: $ENV_NAME ($KUBECONFIG) ==="
        echo "--- Nodes ---"
        kubectl get nodes -o wide
        echo "--- All Pods (non-Completed) ---"
        kubectl get pods -A -o custom-columns='NS:.metadata.namespace,NAME:.metadata.name,READY:.status.containerStatuses[*].ready,STATUS:.status.phase,RESTARTS:.status.containerStatuses[*].restarts,AGE:.metadata.creationTimestamp' 2>/dev/null | head -60
        echo "--- OElite infra Pods (statefulset: mongo/clickhouse/opensearch/rabbitmq/kafka/redis) ---"
        kubectl get pods -A -o wide | grep -Ei 'mongo|clickhouse|kafka|opensearch|rabbit|redis|zookeeper' || echo "(none found)"
        echo "--- Non-Ready / Error Pods ---"
        kubectl get pods -A --no-headers 2>/dev/null | awk '$4!="Running" && $4!="Completed" && $4!="" {print}' | head -20 || true
        ;;
      audit)
        echo "=== Resource audit: $ENV_NAME ==="
        echo "--- Node Allocatable / Requests ---"
        kubectl top nodes 2>/dev/null || kubectl describe nodes | grep -A 8 "Allocated resources"
        echo "--- Top Pods (default ns infra) ---"
        kubectl top pods -n default 2>/dev/null | head -30 || echo "(metrics-server unavailable or no metrics)"
        echo "--- Per-namespace CPU/Mem requests ---"
        for ns in default cert-manager ingress-nginx metallb-system; do
          kubectl get pods -n "$ns" -o json 2>/dev/null \
            | jq -r '.items[] | select(.spec.containers) | .metadata.name as $n | .spec.containers[] | [.name, (.resources.requests.cpu // "-"), (.resources.requests.memory // "-"), (.resources.limits.memory // "-")] | @tsv' 2>/dev/null \
            | awk -v ns="$ns" 'BEGIN{cpu=0;mem=0} {cpu+=$2; mem+=$3} END{if(NR>0) print ns": "NR" pods"}'
        done
        ;;
      kubeconfig-path)
        echo "$KUBECONFIG"
        ;;
      *)
        echo "Unknown cluster action '$ACTION'. Use: kubectl|health|audit|kubeconfig-path"
        exit 1
        ;;
    esac
    ;;

  help|*)
    cat <<EOF
OElite Shared Local Infrastructure Manager

Usage:
  ./oelite-stack.sh up        Start all services (generates .env if missing)
  ./oelite-stack.sh init      Initialize DBs, users, vhosts, buckets (read-only-safe)
  ./oelite-stack.sh repair-rabbitmq <project-slug>
                              Idempotently repair a project's RabbitMQ vhost, user,
                              and permissions (fixes ACCESS_REFUSED after drift)
  ./oelite-stack.sh down      Stop all services (preserves volumes)
  ./oelite-stack.sh health    Run health checks against all services
  ./oelite-stack.sh status    Show running containers
  ./oelite-stack.sh logs      Tail logs (optionally: ./oelite-stack.sh logs oelite-mongos)
   ./oelite-stack.sh secrets   Rotate all credentials (regenerates .env)
   ./oelite-stack.sh clean     DELETE all data volumes (.env/.mongo.key preserved)

Remote K8s cluster helpers (per-environment, gitignored under clusters/):
  ./oelite-stack.sh cluster list                 List available environments
  ./oelite-stack.sh cluster UAT kubectl get pods  Connect to UAT and run arbitrary kubectl
  ./oelite-stack.sh cluster UAT health            Summary health of UAT oelite infrastructure
  ./oelite-stack.sh cluster UAT audit             Resource audit of UAT nodes + infra pods
  ./oelite-stack.sh cluster UAT kubeconfig-path   Print resolved KUBECONFIG for UAT

  (env names: UAT, Production, ... — see clusters/<ENV>/kubeconfig/)

First-time setup:
  ./oelite-stack.sh up
  ./oelite-stack.sh init

Secrets management:
  ./oelite-stack.sh secrets         Regenerate all random credentials
  ./scripts/generate-secrets.sh --print  View current credentials (SENSITIVE)
EOF
    ;;
esac
