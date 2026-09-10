# 16. Shared Local Infrastructure

**Status**: Active (since 2026-09-07)
**Owner**: Ethan (DevOps), Marcus (architecture review)
**Related**: AGENTS.md §7 (Local Infrastructure), testing-standards §14

## Core Principle

A **single, shared** OElite infrastructure stack runs once per developer machine. All repos, all worktrees, and all agents connect to the same services. Per-project isolation is achieved via **namespaces** (databases, buckets, vhosts, topic prefixes) — **never** via separate container instances.

## The Problem This Solves

The pre-2026 model was per-repo `docker-compose.dev.yml`. With 9+ repos and 30+ active worktrees, this produced:

- **30+ duplicate MongoDB containers** on a developer's machine
- **Port conflicts** (multiple repos want `27017`)
- **Standalone MongoDB** in dev while production is sharded — sharding bugs only surfaced in production
- **Resource waste** — every worktree restart re-pulled images and reset volumes

## Mandatory Architecture

### Machine Topology (one per dev machine)

```
infrastructure/oelite-stack/  (in coding-standards repo)
  ├── docker-compose.shared.yml   ← the canonical stack
  ├── oelite-stack.sh             ← start/stop/init/health wrapper
  ├── scripts/                    ← init + health-check
  └── README.md
```

**All** OElite services that a local dev needs are here. **No per-repo compose file may redefine these services.**

### Per-Service Isolation

| Service | Isolation | Example |
|---|---|---|
| MongoDB | Database-per-project | `mongodb://localhost:27017/origin_auth` |
| Redis | Database number (0–15) or key prefix | `SELECT 5` for hermes |
| ClickHouse | Database-per-project | `CREATE DATABASE origin_auth` |
| Kafka | Topic prefix | `oelite.origin-auth.*` |
| RabbitMQ | Virtual host | `/oelite/origin-auth` |
| MinIO | Bucket-per-project | `oelite-origin-auth` |
| OpenSearch | Index-per-project | `oelite-origin-auth-*` |

### MongoDB Is a Sharded Replica Set — Always

The shared MongoDB is a **production-mimicking sharded replica set**:

- 3-node config server replica set (CSRS) on port 27019
- 1-node shard replica set (primary + non-electable secondary) on port 27018
- mongos router on port 27017 (app entry point)

**Why mandatory:**
- OElite.Restme uses change streams (denormalized cascade updates, event sync)
- Change streams **require** replica set mode
- Sharded collection operations (`sh.shardCollection()`) only work in sharded clusters
- All sharding-related bugs must be caught locally, not in UAT/prod

Apps connect via the **mongos** connection string:

```
mongodb://localhost:27017/?directConnection=true
```

(`directConnection=true` tells the driver to skip replica set discovery and go straight to mongos.)

## Rules

### ✅ REQUIRED

1. **All dev work uses the shared stack.** No new `docker-compose.dev.yml` in any repo may redefine MongoDB, Redis, ClickHouse, Kafka, RabbitMQ, MinIO, or OpenSearch.
2. **One-time machine setup.** Each developer runs `./oelite-stack.sh up && ./oelite-stack.sh init` once per fresh machine clone. Per-project databases/vhosts/buckets are created by running the project onboarding scripts (see `scripts/init-per-project-dbs.sh`, `init-rabbitmq.sh`, `init-minio.sh`).
3. **Connection strings use canonical ports** (27017, 6379, 9092, 5672, 9000, 8123).
4. **Per-project databases/buckets/vhosts** are created by running the project onboarding scripts during project setup. Credentials are stored in the project's own gitignored secrets. Never committed to coding-standards.
5. **Worktrees never spin up containers.** New worktrees connect to the existing singleton.
6. **CI/CD skips integration tests** with `Category!=Integration` filter. CI never touches this stack.

### ❌ PROHIBITED

1. **Per-repo MongoDB containers** in any `docker-compose*.yml`. The shared stack owns MongoDB.
2. **Per-repo Redis/ClickHouse/Kafka/RabbitMQ/MinIO/OpenSearch** instances. Use the shared stack.
3. **Port remapping** of the canonical ports (27017, 6379, 9092, etc.) per-repo. Conflict resolution is at the compose level, not the app level.
4. **Connecting directly to mongod** processes (configsvr, shard). All app code MUST go through mongos on 27017.
5. **Embedding infra credentials in repos.** Use the `.env.example` template; copy to `.env` (gitignored) for local overrides.

## Migration From Per-Repo Compose

Existing repos with `docker-compose.dev.yml` migrate in 4 steps:

1. **Delete** (or move to `archive/`) the existing `docker-compose.dev.yml`.
2. **Update** `appsettings.init.json` (or equivalent) with the shared connection string.
3. **Run the project onboarding scripts** to create your database, vhost, bucket:
   - MongoDB: `./scripts/init-per-project-dbs.sh <project>`
   - RabbitMQ: `./scripts/init-rabbitmq.sh <project>`
   - MinIO: `./scripts/init-minio.sh oelite-<project>`
4. **Verify** by running the integration test suite against the shared stack.

No application code changes are required — connection string is the only edit.

## What This Standard Does NOT Cover

- **Production infrastructure** (Kubernetes, CI/CD, cloud deployments) — see `agents/packs/infrastructure.md`
- **Application-level sharding decisions** (which collections to shard, which shard keys) — owned by each app
- **Cross-region replication** — not needed in local dev

## Verification

For every PR touching infra config, verify:

- [ ] `docker compose -f infrastructure/oelite-stack/docker-compose.shared.yml config` validates
- [ ] `./oelite-stack.sh up` starts all services
- [ ] `./oelite-stack.sh health` returns OK for all services
- [ ] `mongosh --host localhost:27017 --eval "sh.status()"` shows 1 shard registered
- [ ] `redis-cli ping` returns PONG
- [ ] `curl http://localhost:9200/_cluster/health` shows OpenSearch healthy
- [ ] No new `docker-compose.dev.yml` was added to any repo (grep across monorepo)

## Handoff

After implementation, the **shared infrastructure** is owned by **Ethan** (DevOps) for ongoing maintenance. Code review of infra changes goes to **Marcus** (architecture) for the isolation model and to **Grace** (backend review) for the script quality.

## Change History

| Date | Author | Change |
|---|---|---|
| 2026-09-07 | Ethan (Sisyphus) | Initial creation — replaces per-repo compose model. Issue #23. |
| 2026-09-10 | Ethan (Sisyphus) | Add OpenSearch 3.7.0 + Dashboards UI to shared stack. Issue #25. |
| 2026-09-10 | Ethan (Sisyphus) | Refactor init scripts to project-level; remove per-project hardcodings from shared infrastructure. |
