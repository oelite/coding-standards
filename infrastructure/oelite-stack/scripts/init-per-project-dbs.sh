#!/bin/bash
# OElite MongoDB per-project database setup (project-level onboarding).
# Creates or repairs a database user and verifies the emitted SCRAM connection.
set -euo pipefail

PROJECT_DB="${1:-}"
REPO_PATH="${2:-}"
STACK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ -z "$PROJECT_DB" ]; then
  echo "ERROR: project database name required" >&2
  echo "Usage: $0 <project-db-name> [gitlab-path]" >&2
  exit 1
fi

load_env_value() {
  local key="$1"
  if [ -n "${!key:-}" ]; then
    return
  fi
  if [ -f "$STACK_DIR/.env" ]; then
    while IFS='=' read -r env_key env_value; do
      if [ "$env_key" = "$key" ]; then
        printf -v "$key" '%s' "$env_value"
        export "$key"
        return
      fi
    done < "$STACK_DIR/.env"
  fi
}

load_env_value MONGO_ROOT_USER
load_env_value MONGO_ROOT_PASSWORD
MONGO_ROOT_USER="${MONGO_ROOT_USER:-admin}"
if [ -z "${MONGO_ROOT_PASSWORD:-}" ]; then
  echo "ERROR: MONGO_ROOT_PASSWORD is required; load the shared stack .env first." >&2
  exit 1
fi

MONGO_HOST="${OELITE_MONGO_HOST:-localhost}"
MONGO_PORT="${OELITE_MONGO_PORT:-27017}"
PROJECT_USER="oelite_${PROJECT_DB}"
PROJECT_PASS="${PROJECT_USER}_dev"

mongo_exec() {
  docker exec \
    -e "MONGO_ADMIN_USER=$MONGO_ROOT_USER" \
    -e "MONGO_ADMIN_PASS=$MONGO_ROOT_PASSWORD" \
    -e "MONGO_PROJECT_DB=$PROJECT_DB" \
    -e "MONGO_PROJECT_USER=$PROJECT_USER" \
    -e "MONGO_PROJECT_PASS=$PROJECT_PASS" \
    oelite-mongos mongosh --quiet --host "$MONGO_HOST" --port "$MONGO_PORT" "$@"
}

mongo_auth_exec() {
  mongo_exec -u "$MONGO_ROOT_USER" -p "$MONGO_ROOT_PASSWORD" --authenticationDatabase admin "$@"
}

echo "============================================================"
echo "  OElite MongoDB per-project database setup: $PROJECT_DB"
echo "============================================================"
echo ""

if ! mongo_exec --eval 'db.adminCommand({ ping: 1 }).ok' >/dev/null; then
  echo "ERROR: mongos is not reachable; run ./oelite-stack.sh up and ./oelite-stack.sh init first." >&2
  exit 1
fi

ensure_project_user() {
  local script
  script=$(cat <<'EOF'
var adminDb = db.getSiblingDB("admin");
var root = adminDb.getUser(process.env.MONGO_ADMIN_USER);
if (root) {
  adminDb.updateUser(process.env.MONGO_ADMIN_USER, { pwd: process.env.MONGO_ADMIN_PASS });
} else {
  adminDb.createUser({ user: process.env.MONGO_ADMIN_USER, pwd: process.env.MONGO_ADMIN_PASS, roles: ["root"] });
}
var projectDb = db.getSiblingDB(process.env.MONGO_PROJECT_DB);
try { projectDb.createCollection("_init_marker"); } catch (error) { if (!/already exists/i.test(error.message)) throw error; }
var projectUser = projectDb.getUser(process.env.MONGO_PROJECT_USER);
if (!projectUser) {
  projectDb.createUser({ user: process.env.MONGO_PROJECT_USER, pwd: process.env.MONGO_PROJECT_PASS, roles: [{ role: "readWrite", db: process.env.MONGO_PROJECT_DB }] });
} else {
  projectDb.updateUser(process.env.MONGO_PROJECT_USER, { pwd: process.env.MONGO_PROJECT_PASS, roles: [{ role: "readWrite", db: process.env.MONGO_PROJECT_DB }] });
}
EOF
)
  if ! mongo_auth_exec --eval "$script" >/dev/null 2>&1; then
    if ! mongo_exec --eval "$script" >/dev/null; then
      echo "ERROR: MongoDB onboarding failed; root credentials were rejected and trusted reconciliation was unavailable." >&2
      exit 1
    fi
    echo "Root password reconciled to the shared stack .env over the trusted local connection."
  fi
}

ensure_project_user

if ! docker exec \
  -e "MONGO_PROJECT_DB=$PROJECT_DB" \
  -e "MONGO_PROJECT_USER=$PROJECT_USER" \
  -e "MONGO_PROJECT_PASS=$PROJECT_PASS" \
  oelite-mongos mongosh --quiet --host "$MONGO_HOST" --port "$MONGO_PORT" \
  -u "$PROJECT_USER" -p "$PROJECT_PASS" --authenticationDatabase "$PROJECT_DB" \
  --eval 'var status = db.runCommand({ connectionStatus: 1 }); if (!status.authInfo.authenticatedUsers.some(function (user) { return user.user === process.env.MONGO_PROJECT_USER; })) { throw new Error("project user authentication failed"); } var projectDb = db.getSiblingDB(process.env.MONGO_PROJECT_DB); projectDb.getCollection("_init_marker").findOne();' >/dev/null 2>&1; then
  echo "ERROR: MongoDB project-user SCRAM verification failed; connection string was not emitted." >&2
  exit 1
fi

echo "Connection string for appsettings:"
echo "  $PROJECT_DB: mongodb://$PROJECT_USER:$PROJECT_PASS@localhost:27017/$PROJECT_DB?authSource=$PROJECT_DB"
echo ""
