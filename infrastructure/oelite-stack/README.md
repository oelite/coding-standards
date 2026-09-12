# OElite Shared Local Infrastructure Stack

One-time machine setup. A **singleton** Docker Compose stack providing MongoDB (sharded replica set), Redis, ClickHouse, Kafka, RabbitMQ, MinIO, and OpenSearch, shared across **all** OElite repos and worktrees on this machine.

Per-project isolation is achieved via **namespaces** (databases, buckets, vhosts), **not** separate container instances.

## Why Singleton?

| Problem | Solution |
|---|---|
| Every worktree spawns its own MongoDB → 9+ duplicates | One machine-wide MongoDB |
| Per-repo `docker-compose.dev.yml` port conflicts | Fixed canonical ports (27017, 6379, 9092, ...) |
| OElite.Restme change streams require replica set | Real sharded RS (configsvr×3 + shard1 + mongos) |
| Production-only bugs (sharding, chunk migration) | Local dev matches production topology |

## Quick Start

```bash
cd infrastructure/oelite-stack

# 1. Start all services
./oelite-stack.sh up

# 2. Initialize sharding + per-project DBs + buckets (once)
./oelite-stack.sh init

# 3. Verify
./oelite-stack.sh health
```

## Connection Strings

All app code connects to these **fixed canonical endpoints**:

| Service | Endpoint | Notes |
|---|---|---|
| MongoDB | `mongodb://localhost:27017/?directConnection=true` | via mongos (sharded) |
| Redis | `localhost:6379` | SELECT db number per project |
| ClickHouse | `localhost:8123` (HTTP) | Native TCP 9000 internal-only |
| Kafka | `localhost:9092` | KRaft mode (no ZK) |
| RabbitMQ | `localhost:5672` (AMQP), `15672` (UI) | User + pass in `.env` |
| MinIO | `localhost:9000` (API), `9001` (Console) | User + pass in `.env` |
| OpenSearch | `localhost:9200` | Single-node, no auth in dev |

### Per-Project Onboarding

The shared stack exposes only superuser credentials (in `.env`). Each project
creates its own database, vhost, bucket, and per-project credentials during
onboarding. Run the project-level init scripts from the project's own
`.gitlab-ci.yml` or a project-local setup script:

```bash
# MongoDB — project DB + dedicated user (scoped to that DB only)
./scripts/init-per-project-dbs.sh origin_auth

# RabbitMQ — vhost + dedicated user
./scripts/init-rabbitmq.sh origin_auth

# MinIO — project bucket + service-account key
./scripts/init-minio.sh oelite-origin-auth
```

The scripts are idempotent and accept the project slug as the only argument.
Project credentials are stored in the project's own gitignored secrets
(`appsettings.init.json`, `.env`, etc.) — **never** in the shared
`infrastructure/oelite-stack/.env`.

## Debug / Monitoring UIs

The shared stack includes web-based UIs for inspecting and monitoring all services. UIs start
**by default** (via `--profile ui`). Disable them on resource-constrained machines:

```bash
# Start without UI containers (saves ~1 GB RAM)
./oelite-stack.sh up --no-ui
```

| Service | URL | Tool | Description |
|---|---|---|---|
| Redis | http://localhost:5540 | RedisInsight | Key browser, CLI, slowlog, memory analyzer |
| Kafka | http://localhost:8080 | Kafka UI | Topics, consumer groups, lag, message browser |
| ClickHouse | http://localhost:3000 | chmonitor | Queries, merges, replication, cluster health |
| MongoDB | http://localhost:3141 | MongoStudio | Schema, collections, aggregation builder |
| RabbitMQ | http://localhost:15672 | *(built-in management UI)* | Queues, exchanges, vhosts, message inspector |
| MinIO | http://localhost:9001 | *(built-in console)* | Bucket browser, object inspector |
| OpenSearch | http://localhost:5601 | OpenSearch Dashboards | Index browser, Dev Tools console, visualizations |

### Connecting UIs to Services

- **RedisInsight**: Auto-discovers the Redis instance. If prompted, connect to `oelite-redis:6379` with password from `.env` (`REDIS_PASSWORD`).
- **Kafka UI**: Cluster `oelite` is auto-configured in `docker-compose.shared.yml`.
- **chmonitor**: Configured via environment variables to point at `oelite-clickhouse:8123`.
- **MongoStudio**: Connects to `oelite-mongos:27017` using root credentials from `.env`.
  Set `MONGODB_ADMIN_ACCESS_KEY` in `.env` for admin access (generated on first `oelite-stack.sh up`).

## Secrets Management

**No credentials are committed to the repo.** Each developer generates random
credentials on first `up` and stores them in a per-machine, gitignored file.

| File | Committed? | Purpose |
|---|---|---|
| `.env.example` | yes | Schema + key names only (no values) |
| `.env` | **no** (gitignored) | Real random credentials for THIS machine |
| `.mongo.key` | **no** (gitignored) | MongoDB cluster auth key (binary, 756 bytes) |

### How it works

1. **First run** (`./oelite-stack.sh up` on a fresh clone):
   - `./scripts/generate-secrets.sh` creates `.env` with random passwords
     for: MongoDB root, ClickHouse admin, Redis, RabbitMQ, MinIO, OpenSearch.
   - `chmod 600` is applied (owner read/write only).
2. **Subsequent runs** — existing `.env` is preserved; credentials are NOT
   regenerated unless you ask. This means your password stays the same across
   restarts.
3. **Per-service consumption** — every service container mounts `.env`
   via `env_file: .env` in `docker-compose.shared.yml`.

### Common operations

```bash
# View current credentials (SENSITIVE — do not share or commit)
./scripts/generate-secrets.sh --print

# Rotate ALL secrets (regenerates random passwords, requires service restart)
./oelite-stack.sh secrets

# Rotate just one secret manually
./scripts/generate-secrets.sh --rotate

# Full reset (removes volumes AND credentials)
./oelite-stack.sh clean && ./oelite-stack.sh up && ./oelite-stack.sh init
```

### Adding a new service to the secrets flow

If you add a service that needs a credential, edit `scripts/generate-secrets.sh`:
add the key name to the `SECRETS=(...)` array at the bottom. Then add the
key to `.env.example` (committed) with an empty value.

## Topology

```
┌──────────────────────────────────────────────────────────────┐
│  OElite Shared Stack (docker-compose.shared.yml)             │
│                                                              │
│  ┌─────────────────────────┐    ┌──────────────────────┐    │
│  │ MongoDB Sharded RS      │    │ Redis 8.8            │    │
│  │  configsvr×3 (27019)    │    │  localhost:6379      │    │
│  │  shard1 (27018)         │    │  db 0..15 per proj   │    │
│  │  mongos (27017)         │    └──────────────────────┘    │
│  │  ↓ apps connect here    │                                 │
│  └─────────────────────────┘    ┌──────────────────────┐    │
│                                 │ ClickHouse 26.5      │    │
│  ┌─────────────────────────┐    │  HTTP: 8123          │    │
│  │ Kafka 8.3 (KRaft)       │    │  Native: internal    │    │
│  │  localhost:9092         │    │  db per project      │    │
│  │  topic prefix per proj  │    └──────────────────────┘    │
│  └─────────────────────────┘                                 │
│  ┌─────────────────────────┐    ┌──────────────────────────────┐    ┌─────────────────────┐    │
│  │ MinIO (S3)              │    │ RabbitMQ 4.3               │    │ OpenSearch 2.x        │    │
│  │  API: 9000, Console:9001│    │  AMQP: 5672                │    │  API: 9200           │    │
│  │  bucket per project     │    │  Mgmt UI: 15672            │    └─────────────────────┘    │
│  └─────────────────────────┘    │  vhost per project        │                        │
│                                 └──────────────────────────────┘                        │
└──────────────────────────────────────────────────────────────┘

## Resource Budget

| Service | Memory | CPU |
|---|---|---|
| mongo-configsvr×3 | 512 MB each | 0.5 each |
| mongo-shard-1 (primary) | 512 MB | 1.0 |
| mongo-shard-1 (secondary/arb) | 512 MB | 0.5 |
| mongo-mongos | 512 MB | 0.5 |
| redis | 512 MB | 0.5 |
| clickhouse | 2048 MB | 1.5 |
| kafka | 1024 MB | 1.0 |
| rabbitmq | 512 MB | 0.5 |
| minio | 512 MB | 0.5 |
| opensearch | 1024 MB | 1.0 |
| **UI Services** | | |
| redisinsight | 256 MB | 0.25 |
| kafka-ui | 512 MB | 0.25 |
| chmonitor | 256 MB | 0.25 |
| mongostudio | 512 MB | 0.25 |
| opensearch-dashboards | 512 MB | 0.25 |
| **Total (all)** | **~9 GB** | **~9 cores** |
| **Total (--no-ui)** | **~7 GB** | **~7.5 cores** |

> **ClickHouse sizing** (INFRA-1279): ClickHouse is pinned at a 2 GiB container limit
> with an explicit `max_server_memory_usage` (1.5 GiB) drop-in at
> `config/clickhouse/config.d/99-oelite-memory.xml`, plus a per-query bound at
> `config/clickhouse/users.d/99-oelite-limits.xml`. This is deliberate — the default
> 0.9× auto-derived cap OOMed (Code 241) on the old 1 GiB limit once merges + multiple
> project databases exceeded baseline RSS. The health check now runs `SELECT 1`, so a
> memory-starved ClickHouse fails `./oelite-stack.sh health` instead of reporting green.

Tested on: 23 GB RAM, 8+ core machines. On 8 GB machines: use `--no-ui` flag to skip debug UIs.

## Commands

```bash
./oelite-stack.sh up        # Start all services
./oelite-stack.sh init      # Initialize MongoDB sharding (CSRS → shard → add-shard)
./oelite-stack.sh down      # Stop all services
./oelite-stack.sh health    # Health check
./oelite-stack.sh status    # Show running containers
./oelite-stack.sh logs      # Tail logs (optional: oelite-mongos)
./oelite-stack.sh clean     # DELETE all data (irreversible!)
```

## Migration from Per-Repo `docker-compose.dev.yml`

If your repo currently has a per-repo `docker-compose.dev.yml`:

1. **Delete** the file (or move to `archive/` for reference).
2. **Update** your app's `appsettings.init.json` connection string to use the shared stack.
3. **Run the project onboarding scripts** to create your database, vhost, bucket:
   - MongoDB: `./scripts/init-per-project-dbs.sh your-project`
   - RabbitMQ: `./scripts/init-rabbitmq.sh your-project`
   - MinIO: `./scripts/init-minio.sh oelite-your-project`
4. **No code changes required** — connection string points to the same `localhost:27017` (now via mongos).

## CI/CD

CI/CD pipelines **must not** spin up these services. Use `Category!=Integration` filter on `dotnet test`. See `coding-standards/1_dotNet_coding_standards/14-TESTING-STANDARDS.md` for the full test categorization rules.

## Related

- Standard: `coding-standards/1_dotNet_coding_standards/16-SHARED-LOCAL-INFRASTRUCTURE.md`
- Issue: `oelite/coding-standards#25` ([INFRA-002] Add OpenSearch)
- Owner: **Ethan** (DevOps)
