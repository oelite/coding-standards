# UAT Availability Runbook — Peer Services (TASK-97, issue #97)

> **Owner**: Ethan (DevOps & Reliability) · **Registry**: `infrastructure/oelite-stack/config/peer-registry.yml`
> **Companion standard**: `1_dotNet_coding_standards/17-LOCAL-DEV-PEER-INTEGRATION.md`
> **Business rules**: BR-DEV-001..006 (BUSINESS-RULEBOOK § 8)

This runbook defines how the shared **UAT peer environment** is kept available
and version-consistent for local development integration (`uat-peers` profile),
and what happens when a peer is down.

---

## 1. UAT Deploy Cadence

| Aspect | Policy |
|--------|--------|
| UAT namespace | `oelite-uat` (K8s) |
| Regular deploys | Automatic on merge to `uat` branch, per repo CI (`deploy_k8s` stage) |
| Expected cadence | 1–3 peer updates per week, staggered across repos |
| Freeze windows | During release cut weeks: only hotfix deploys to UAT |
| Version drift budget | A peer must not fall below the registry `minVersion` — see § 2 |

UAT is a **shared, best-effort environment**. It may be briefly unavailable
during deploys; `peers-health` is the tool that tells you whether it is
currently usable. App-deploy rollout/health checks are defined separately in
`5_git_workflow_standards/DEPLOYMENT-OBSERVABILITY-STANDARD.md` — this runbook
covers peer availability, not app deployment observability.

## 2. Version-Pinning Policy (`minVersion` enforcement)

- The registry pins, per peer: `contractVersion` (the contract consumers code
  against), `minVersion` (the oldest UAT deployment consumers may integrate
  against), and `channel: stable` (v1 consumes the stable channel only).
- **`peers-health --verbose`** reports each peer's live version (via
  `versionEndpoint`) and flags `versionDrift: true` when
  `live < minVersion`.
- When a peer reports drift:
  1. Ethan notifies the owning repo's team (see escalation table) to deploy or
     roll back UAT.
  2. If the drift is intentional (breaking change), the owner raises an MR to
     bump `contractVersion`/`minVersion` in the registry **before** consumers
     are broken — registry changes require Marcus architecture review.
  3. Consumers integrating against a drifted peer will fail fast on next
     `peers-health --strict` run (BR-DEV-006: no silent degradation).

## 3. Escalation Path — Peer Down

`peers-health` exit codes: `0` healthy · `1` critical peer down (or `--strict`
any down) · `2` config error. When you get `1`:

| Step | Action | SLA |
|------|--------|-----|
| 1 | Run `peers-health --profile uat-peers --verbose` and capture which peers are down | immediate |
| 2 | Check Orion UAT dashboards/alerts for the peer (`orion` repo, monitoring stack) | immediate |
| 3 | If a deploy is in flight, wait and re-run `peers-health` | ≤ 30 min |
| 4 | Otherwise, raise a GitLab issue on the peer's owning repo (table below), tagged `Priority::High`, and link it on issue #97 | — |
| 5 | Owning team **acknowledges** | **4 h ack** |
| 6 | Owning team restores the peer | **1 business-day recovery** |

### Peer ownership & escalation contacts

| Peer | Owning repo | Escalation owner |
|------|-------------|------------------|
| origin-auth | `oelite/uranus/origin-auth` | Daniel |
| kortex | `oelite/helios/kortex` | Sophia |
| nexus | `oelite/helios/nexus` | Daniel |
| oesterling | `oelite/helios/oesterling` | Daniel |
| apex | `oelite/jupiter/apex` | Daniel |
| synapse | `oelite/mercury/synapse` | Daniel |
| obelisk | `oelite/venus/obelisk` | Daniel |
| hermes | `oelite/uranus/hermes` | Daniel |
| orion | `oelite/uranus/orion` | Ethan |

`critical: true` peers (currently **origin-auth**) block all peer-integration
work when down — escalate immediately per the table; do not attempt a mock
fallback (BR-DEV-006 forbids silent degradation; fail fast with the peer named
in the error).

## 4. Reset Policy Execution

Each registry entry declares `testTenantId` (the reserved UAT tenant for dev
writes, BR-DEV-005) and `resetPolicy`:

| resetPolicy | Peers | Execution |
|-------------|-------|-----------|
| `weekly` | origin-auth, kortex, nexus, oesterling, synapse, obelisk | Ethan (or peer owner) purges records carrying the `dev-<username>-` prefix from `testTenantId` **every Monday**; scripted purge preferred over manual SQL |
| `monthly` | apex | First business day of the month, same `dev-*` purge scope (billing test data is kept longer for statement verification) |
| `manual` | hermes, orion | Read-only peers — reset only on request via GitLab issue |

Conventions (Emma stakeholder decision 3, #97 note 58415):
- All dev-written UAT records carry a `dev-<username>-` identifier prefix so
  peer owners can identify and purge local-dev-created data.
- Origin Auth additionally uses a dedicated per-machine IAM client named
  `dev-<username>-local` (registered in the UAT realm, registry-declared
  scopes only). Never share the UAT acceptance client.
- Writes outside these two patterns to UAT are prohibited (BR-DEV-005).

## 5. `peers-health` Integration in CI

Where the checks live in `coding-standards/.gitlab-ci.yml`:

| Job | Stage | What it does | Blocking? |
|-----|-------|--------------|-----------|
| `validate-peer-registry` | `test` | YAML syntax + JSON Schema validation of `peer-registry.yml` (fail-closed on schema drift) | **Blocking** |
| `peers-health-check` | `test` | Runs the tool against UAT peers | **Non-blocking warning** (`allow_failure: true`) — surfaces UAT outages in MR pipelines without blocking merges |

Notes:
- `peers-health-check` deliberately does **not** use `--auth`: CI runners hold
  no dev-machine Keychain, and AC-003/AC-004 forbid hermetic CI from requiring
  UAT credentials. Reachability + version checks only.
- The job may be pinned to a schedule (nightly) in addition to MR pipelines
  once Orion alerting covers it; the non-blocking posture stays until then.
- Exit `2` (config error) in CI is **always** blocking — a broken registry
  must not merge, which is why `validate-peer-registry` runs first.

## 6. CI Token Minting (V2, TASK-99 — BUSINESS-RULEBOOK § 8.2)

Hermetic CI jobs never mint UAT tokens (AC-004). When a job must hit UAT peers,
the ONLY sanctioned pattern is the documented `.uat-integration-auth` template
in `.gitlab-ci.yml`:

1. **Variables provisioning** (Ethan-owned, per consuming repo):
   - Register ONE per-project IAM client per consuming repo in the UAT realm
     (client id: `uat-ci-<project-slug>`), scoped to exactly the peer
     `credentials.scopes` the job needs. Request via GitLab issue on
     `oelite/coding-standards`.
   - Store the client id/secret as **PROTECTED + MASKED** CI/CD variables:
     `OELITE_UAT_IAM_CLIENT_ID` / `OELITE_UAT_IAM_CLIENT_SECRET`.
     Optionally `OELITE_UAT_TOKEN_ENDPOINT` (defaults to origin-auth UAT).
2. **Per-run mint**: the job mints a token at the start of its script using
   the client-credentials flow (RFC 6749 §4.4). The token is held ONLY in the
   job-scoped environment (`$OELITE_UAT_TOKEN`) and dies with the job.
3. **Never write to disk, artifacts, or cache** — the token must never persist
   across jobs or be exposed in logs. GitLab protects protected-variable
   values from logs by default; do not disable masking.
4. **Audit expectations**: every mint carries the per-project client identity
   in the UAT audit log. Ethan monitors issuance rate/anomaly via Orion; Maya
   owns anomaly investigation (BR-DEV-004).

This pattern ensures zero long-lived secrets in CI, per-job attribution, and
≤15-minute blast radius for any leaked token.

## 7. Local Developer Quick Reference

```bash
# Is UAT usable right now?
./infrastructure/oelite-stack/scripts/peers-health.sh --profile uat-peers

# Pre-flight before starting integration work (fail fast, name the blocker)
./infrastructure/oelite-stack/scripts/peers-health.sh --profile uat-peers --strict --verbose

# Machine-readable output (scripts / tooling)
./infrastructure/oelite-stack/scripts/peers-health.sh --profile uat-peers --json

# Verify my machine's UAT credentials are provisioned
#   static peers: Keychain lookup
#   dynamic peers (V2): full client-credentials mint vs UAT token endpoint,
#   reporting TTL remaining. Bootstrap IAM client secret is stored in the OS
#   credential store under `oelite/iam/dev-<username>-local`; CI uses
#   pipeline-scoped variables; local dev uses Keychain.
./infrastructure/oelite-stack/scripts/peers-health.sh --profile uat-peers --auth

# Only the peer I actually depend on
./infrastructure/oelite-stack/scripts/peers-health.sh --profile uat-peers --peer origin-auth
```

Reminder: credentials live in **per-machine Keychain** (`oelite-uat-<peer>`
services, account `oelite`) — never committed, rotated per
`SECURITY-PATTERNS.md` (90-day rotation SLA).
