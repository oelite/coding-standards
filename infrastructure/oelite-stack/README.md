# OElite Shared Local Infrastructure Stack

One-time machine setup. A **singleton** Docker Compose stack providing MongoDB (sharded replica set), Redis, ClickHouse, Kafka, RabbitMQ, and MinIO, shared across **all** OElite repos and worktrees on this machine.

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
| ClickHouse | `localhost:8123` (HTTP) / `localhost:9000` (native) | |
| Kafka | `localhost:9092` | KRaft mode (no ZK) |
| RabbitMQ | `localhost:5672` (AMQP), `15672` (UI) | User: `oelite`, Pass: `oelite123` |
| MinIO | `localhost:9000` (API), `9001` (Console) | User: `oelite`, Pass: `oelite123` |

### Per-Project MongoDB Connection

After running `./oelite-stack.sh init`, each project has a dedicated user + database:

```
mongodb://oelite_origin_auth:oelite_origin_auth_dev@localhost:27017/origin_auth?authSource=origin_auth
mongodb://oelite_apex:oelite_apex_dev@localhost:27017/apex?authSource=apex
mongodb://oelite_obelisk:oelite_obelisk_dev@localhost:27017/obelisk?authSource=obelisk
... (see init-per-project-dbs.sh for full list)
```

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
│  │ Kafka 8.3 (KRaft)       │    │  Native: 9000        │    │
│  │  localhost:9092         │    │  db per project      │    │
│  │  topic prefix per proj  │    └──────────────────────┘    │
│  └─────────────────────────┘                                 │
│                                 ┌──────────────────────┐    │
│  ┌─────────────────────────┐    │ RabbitMQ 4.3         │    │
│  │ MinIO (S3)              │    │  AMQP: 5672          │    │
│  │  API: 9000, Console:9001│    │  Mgmt UI: 15672      │    │
│  │  bucket per project     │    │  vhost per project   │    │
│  └─────────────────────────┘    └──────────────────────┘    │
└──────────────────────────────────────────────────────────────┘
```

## Resource Budget

| Service | Memory | CPU |
|---|---|---|
| mongo-configsvr×3 | 256 MB each | 0.5 each |
| mongo-shard-1 (primary) | 512 MB | 1.0 |
| mongo-shard-1 (secondary) | 256 MB | 0.5 |
| mongo-mongos | 256 MB | 0.5 |
| redis | 512 MB | 0.5 |
| clickhouse | 1024 MB | 1.0 |
| kafka | 1024 MB | 1.0 |
| rabbitmq | 512 MB | 0.5 |
| minio | 512 MB | 0.5 |
| **Total** | **~5 GB** | **~6 cores** |

Tested on: 23 GB RAM, 8+ core machines. On 8 GB machines, see [LITE-MODE.md](LITE-MODE.md) (TODO: future).

## Commands

```bash
./oelite-stack.sh up        # Start all services
./oelite-stack.sh init      # Initialize sharding + per-project DBs + buckets
./oelite-stack.sh down      # Stop all services
./oelite-stack.sh health    # Health check
./oelite-stack.sh status    # Show running containers
./oelite-stack.sh logs      # Tail logs (optional: oelite-mongos)
./oelite-stack.sh clean     # DELETE all data (irreversible!)
```

## Migration from Per-Repo `docker-compose.dev.yml`

If your repo currently has a per-repo `docker-compose.dev.yml`:

1. **Delete** the file (or move to `archive/` for reference).
2. **Update** your app's `appsettings.init.json` connection string to use the shared stack (see `init-per-project-dbs.sh` output for the exact string).
3. **Add** your project to `init-per-project-dbs.sh` (one line) so a dedicated DB is created on init.
4. **No code changes required** — connection string points to the same `localhost:27017` (now via mongos).

## CI/CD

CI/CD pipelines **must not** spin up these services. Use `Category!=Integration` filter on `dotnet test`. See `coding-standards/1_dotNet_coding_standards/14-TESTING-STANDARDS.md` for the full test categorization rules.

## Related

- Standard: `coding-standards/1_dotNet_coding_standards/16-SHARED-LOCAL-INFRASTRUCTURE.md`
- Issue: `oelite/coding-standards#23` (US-INFRA-001)
- Owner: **Ethan** (DevOps)
