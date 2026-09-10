#!/bin/bash
# OElite MongoDB per-project database setup (project-level onboarding).
# Creates a database, dedicated user, and grants for a single project.
#
# This is NOT run by `oelite-stack.sh init`. Each project invokes it during its
# own onboarding, passing its project slug:
#   ./scripts/init-per-project-dbs.sh origin_auth
#
# The shared stack exposes only the root user on admin DB. Per-project users are
# created by this script using the provided project slug.
set -euo pipefail

PROJECT_DB="${1:-}"
REPO_PATH="${2:-}"

if [ -z "$PROJECT_DB" ]; then
  echo "ERROR: project database name required"
  echo "Usage: $0 <project-db-name> [gitlab-path]"
  echo "  e.g. $0 origin_auth oelite/uranus/origin-auth"
  exit 1
fi

MONGO_HOST="${OELITE_MONGO_HOST:-localhost}"
MONGO_PORT="${OELITE_MONGO_PORT:-27017}"
ADMIN_USER="${MONGO_ROOT_USER:-admin}"
ADMIN_PASS="${MONGO_ROOT_PASSWORD:-}"

# Use admin DB to create the root user (via localhost exception on first run)
echo "============================================================"
echo "  OElite MongoDB per-project database setup: $PROJECT_DB"
echo "============================================================"
echo ""

# Switch to the project DB and create a collection marker
echo "[$PROJECT_DB] Creating database and user..."
MONGO_PROJECT_DB="$PROJECT_DB" MONGO_PROJECT_USER="oelite_${PROJECT_DB}" MONGO_PROJECT_PASS="oelite_${PROJECT_DB}_dev" \
  mongosh -u "$ADMIN_USER" -p "$ADMIN_PASS" --quiet --host "$MONGO_HOST" --port "$MONGO_PORT" --authenticationDatabase admin --eval '
var db = db.getSiblingDB(process.env.MONGO_PROJECT_DB);
try { db.createCollection("_init_marker"); } catch (e) { if (!/already exists/i.test(e.message)) throw e; }
db.createUser({
  user: process.env.MONGO_PROJECT_USER,
  pwd: process.env.MONGO_PROJECT_PASS,
  roles: [{ role: "readWrite", db: process.env.MONGO_PROJECT_DB }]
});
' 2>/dev/null || echo "  (user may already exist - safe to ignore)"

echo ""
echo "Connection string for appsettings:"
echo "  $PROJECT_DB: mongodb://oelite_${PROJECT_DB}:oelite_${PROJECT_DB}_dev@localhost:27017/$PROJECT_DB?authSource=$PROJECT_DB"
echo ""
