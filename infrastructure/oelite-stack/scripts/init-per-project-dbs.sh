#!/bin/bash
# OElite per-project database setup
#
# Creates a database, dedicated user, and grants for each OElite project on
# the shared MongoDB. Runs ONCE per machine (after shared stack is up).
# Idempotent: re-running has no effect if databases already exist.
#
# Connection: Uses the local mongos at localhost:27017.
# Auth:       Localhost exception is enabled in docker-compose for the
#             admin user. In production, this would use SCRAM auth.

set -euo pipefail

MONGO_HOST="${OELITE_MONGO_HOST:-localhost}"
MONGO_PORT="${OELITE_MONGO_PORT:-27017}"
ADMIN_USER="${OELITE_MONGO_ADMIN_USER:-admin}"
ADMIN_PASS="${OELITE_MONGO_ADMIN_PASS:-oelite123}"

# OElite projects that need their own MongoDB database
# (Add new projects here as they onboard to the shared stack.)
PROJECTS=(
  "origin_auth:uranus/origin-auth"
  "apex:jupiter/apex"
  "obelisk:venus/obelisk"
  "synapse:mercury/synapse"
  "stela:uranus/stela"
  "hermes:uranus/hermes"
  "orion:uranus/orion"
  "kortex:helios/kortex"
  "oesterling:helios/oesterling"
  "helios_core:helios/core"
  "sip:venus/sip"
  "stela_runtime:venus/stela-runtime"
)

# Use admin DB to create users for each project
mongosh_cmd="mongosh --host $MONGO_HOST --port $MONGO_PORT --quiet"

echo "============================================================"
echo "  OElite per-project MongoDB setup"
echo "============================================================"
echo ""

for entry in "${PROJECTS[@]}"; do
  db="${entry%%:*}"
  repo="${entry#*:}"
  user="oelite_${db}"
  pass="oelite_${db}_dev"

  echo "[$db] ($repo)"

  # Switch to the project DB and create a collection marker (ensures DB exists)
  $mongosh_cmd --eval "
    db = db.getSiblingDB('$db');
    db.createCollection('_init_marker', { strict: false });
  " >/dev/null 2>&1

  # Create the per-project user (scoped to the project DB only)
  $mongosh_cmd --eval "
    db = db.getSiblingDB('$db');
    try {
      db.createUser({
        user: '$user',
        pwd: '$pass',
        roles: [{ role: 'readWrite', db: '$db' }]
      });
      print('  user created: $user');
    } catch (e) {
      if (e.code === 51024 || /already exists/i.test(e.message)) {
        print('  user exists: $user');
      } else {
        throw e;
      }
    }
  " 2>/dev/null

  echo "  -> mongodb://$user:$pass@$MONGO_HOST:$MONGO_PORT/$db?authSource=$db"
  echo ""
done

echo "============================================================"
echo "  Per-project databases ready."
echo "============================================================"
echo ""
echo "Use these connection strings in your app's appsettings.init.json:"
echo ""
for entry in "${PROJECTS[@]}"; do
  db="${entry%%:*}"
  user="oelite_${db}"
  pass="oelite_${db}_dev"
  echo "  $db: mongodb://$user:$pass@localhost:27017/$db?authSource=$db"
done
echo ""
