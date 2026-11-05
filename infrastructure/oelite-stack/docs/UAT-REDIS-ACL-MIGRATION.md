# UAT Redis ACL Migration (Staged)

**Issue**: `oelite/coding-standards#108`  
**Umbrella**: `oelite/uranus/orion#150` (API crash: `#143`)  
**Owner**: Ethan  
**Scope**: UAT shared Redis only. Production is out of scope.

## Goal

Keep the existing shared UAT Redis (`redis-prod` in `default`). Introduce per-project ACL users and Kubernetes Secrets. Retain the legacy `default` user until every consumer is migrated and validated. Then revoke the legacy credential (Phase 3) under Maya’s security sign-off.

## Connection string format (mandatory)

StackExchange.Redis does **not** accept `redis://` URIs for Orion’s Restme path. Use:

```text
host:port,user=<project>,password=<secret>,defaultDatabase=0,abortConnect=false
```

Do **not** use base64 passwords that contain `=` inside a `redis://` URI — the `=` is parsed as an option separator and crashes startup (`Keyword 'redis=...' is not supported`).

## Phases

| Phase | Action | Gate |
|-------|--------|------|
| 0 | Mount ACL file (`redis-prod-acl` Secret) **while keeping `--requirepass`** (dual-mode). Project users come from aclfile; legacy clients keep requirepass auth. Wait for AOF load (PING) before verify; auto-rollback on failure. Drop requirepass only in Phase 3. | `redis-prod` ready; legacy clients still PING |
| 1 | Create `orion` ACL user + `orion-redis` Secret in `oelite-uat`; rewire `orion-api` | Orion Ready; `https://api.uat.orion.oelite.cloud/health` → 200 |
| 2 | Migrate remaining consumers (`nexus`, `evitale`, `hermes`, `kortex`, `origin`, `obelisk`; confirm Harbor) | Each owner validates |
| 3 | Revoke legacy `default` credential | All consumers migrated + Maya sign-off (`#145`) |

## Operator script

```bash
cd coding-standards/.worktrees/ethan-108/infrastructure/oelite-stack
./scripts/uat-redis-acl-phase0-1-orion.sh --dry-run
./scripts/uat-redis-acl-phase0-1-orion.sh
```

Credentials are generated into a shredded temp directory. Never paste them into issues, MRs, shell history, logs, or assistant prompts. Use `./oelite-stack.sh cluster UAT kubectl ...` for cluster access.

## Planned project users

`orion`, `nexus`, `evitale`, `hermes`, `kortex`, `origin`, `obelisk`  
Harbor appears to run its own Redis (`harbor/harbor-redis-0`) — confirm before adding a shared-ACL user.

## ACL policy (initial)

- Broad key/channel match (`~* &*`) pending key-pattern tightening in Phase 2
- Allow read/write/connection/pubsub/transaction/scripting + `ping`/`info`
- Deny `@dangerous`

## Evidence rules

Record only sanitized status in GitLab (pod Ready, HTTP 200, rollout success). Never include credentials, hashes, or full connection strings.
