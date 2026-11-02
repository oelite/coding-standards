# Deployment Observability Standard (TASK-95)

> **Owner**: Ethan (DevOps & Reliability)
> **Companion standards**: `GIT-WORKFLOW-STANDARDS.md` §2.1.2 (promotion gates), §2.1.3 (rollback standard), §8.7 (release issue lifecycle)
> **Companion runbook**: `infrastructure/oelite-stack/UAT-AVAILABILITY-RUNBOOK.md` (UAT peer availability SLAs)
> **Status**: §7 SLOs are **proposed and pending BUSINESS-RULEBOOK §5 ratification** — treat the values as targets, not commitments, until ratified.

This standard defines how deployments are **observed** after CI/CD ships them: how we watch rollouts, detect failure, page humans, verify health, and record evidence. It complements — does not replace — the promotion gates (§2.1.2) and rollback standard (§2.1.3) in `GIT-WORKFLOW-STANDARDS.md`.

---

## 1. GitLab Environments & Deploy Boards

### 1.1 Required `environment:` declarations

Every deploy job in every deployable repo's `.gitlab-ci.yml` MUST declare a GitLab `environment:` (per GIT-WORKFLOW-STANDARDS §2.1.2 rule 2):

```yaml
deploy_uat:
  environment:
    name: uat
    url: https://<service>.uat.phanes.ltd
    on_stop: stop_uat

deploy_prod:
  environment:
    name: production
    url: https://<service>.phanes.ltd
```

Without a declared environment the deploy does not appear on GitLab Environments or Deploy Boards, and rollout state becomes invisible — that is a workflow violation.

### 1.2 Deploy Board as single source of truth

- The GitLab **Deploy Board** (Environments → `uat` / `production`) is the canonical view of "what SHA is running where, and is the rollout healthy."
- During any rollout, Ethan (or the promoting agent) reads the board: pod states (ready vs. waiting vs. failed) and the deployed SHA. Screenshot or SHA reference is recorded on the release issue for production deploys.
- Do NOT treat pipeline job success as proof of a healthy rollout — a green `deploy_k8s` job only proves `kubectl apply` succeeded. Rollout completion is verified via the board / `kubectl rollout status` (§3).

### 1.3 Review cadence

| When | Who | What |
|------|-----|------|
| Immediately after each `deploy_uat` / `deploy_prod` | Ethan (or deploying agent) | Confirm rollout completes on the Deploy Board; check §3 health checks |
| Daily during a release week | Ethan | Review environment list for drift: stale review apps, orphaned environments, wrong-SHA deployments |
| Sprint review | Ethan + Emma | Audit environments per repo; remove dead entries; confirm `environment:` coverage in all deployable repos |

---

## 2. Rollout Failure Detection

### 2.1 Policy: no auto-rollback

OElite does **not** configure automated rollback on rollout failure. Rollbacks are a deliberate human decision executed per `GIT-WORKFLOW-STANDARDS.md` §2.1.3 (Ethan executes; human business owner authorizes Production rollbacks). Automated rollback on a partially-failed rollout can destroy a recovering state and masks the root cause.

### 2.2 Detection & paging per environment

| Signal | Environment | Detection | Response |
|--------|-------------|-----------|----------|
| Rollout stuck (pods not Ready > 10 min) | uat | Deploy Board / `kubectl rollout status` timeout | Ethan investigates; rollback at his discretion (§2.1.3) |
| Rollout stuck / failed | production | Deploy Board / `kubectl rollout status` timeout | Page Ethan immediately; incident recorded on the REL release issue; rollback only per §2.1.3 authority |
| Health endpoint failing post-deploy | uat | §3 checks fail | Ethan triages; if peer-related, follow UAT-AVAILABILITY-RUNBOOK SLAs (4 h ack / 1 business-day recovery) |
| Health endpoint failing post-deploy | production | §3 checks fail | Page Ethan + Emma; incident comms on the REL issue |

### 2.3 Incident comms

All production rollout incidents are logged **on the REL release issue** (§8.7 lifecycle) — what failed, observed symptoms, decision taken (fix-forward vs. rollback), and follow-up. This matches the §2.1.3 incident-comms rule: the release issue is the incident log of record.

---

## 3. Post-Deploy Health Checks

### 3.1 Checks

After each deployment completes (rollout status = complete), the deploying agent runs:

1. **Rollout completion**: `kubectl rollout status deployment/<name> -n oelite-{uat,prod}` — must reach "successfully rolled out".
2. **Service health endpoint**: `./oelite-stack.sh cluster UAT health` (UAT) or the service's own health endpoint (prod) — must return healthy/200.
3. **Peer consistency (UAT)**: `./infrastructure/oelite-stack/scripts/peers-health.sh --profile uat-peers` — confirms no peer was degraded by this deploy (BR-DEV-006: no silent degradation; peer-down handling stays fail-fast per the runbook — this check observes, it does not gate differently).

### 3.2 Soak-gate definition (explicit)

The **UAT soak gate** (GIT-WORKFLOW-STANDARDS §2.1.2 rule 3) is satisfied only when ALL of the following hold on the exact SHA being promoted:

| # | Gate condition | Evidence location |
|---|----------------|-------------------|
| 1 | `deploy_uat` pipeline green on that SHA | Pipeline URL on the release issue |
| 2 | Rollout completed on UAT (§3.1 item 1) | `kubectl rollout status` output / Deploy Board |
| 3 | UAT health check passed (§3.1 item 2) | Health-check output on the release issue |
| 4 | Olivia + Isabella validation sign-offs recorded **on the release issue** | Issue comments (§8.7) |

**Soak duration**: minimum one business day of UAT residency between the UAT deploy and the `uat → main` release MR, unless compressed per §2.1.2 rule 6a (recorded human authorization).

### 3.3 Gating matrix

| Check | uat deploys | uat → main promotion | prod deploys |
|-------|-------------|----------------------|--------------|
| Rollout completion (§3.1.1) | Blocking | Blocking (on promoted SHA) | Blocking |
| Health endpoint (§3.1.2) | Blocking | Blocking | Blocking |
| `peers-health` (§3.1.3) | Non-blocking warning in CI; blocking in manual pre-promotion check | Blocking (manual run) | n/a |
| Olivia/Isabella sign-off | n/a | Blocking (on release issue) | n/a |

---

## 4. Alerting Paths

### 4.1 Channels

| Severity | Environment | Channel | Acknowledgment SLA |
|----------|-------------|---------|--------------------|
| Rollout failure / health fail | production | Page Ethan (direct) + comment on REL issue | immediate (business hours) / 1 h (release window) |
| Rollout failure / health fail | uat | Ethan via GitLab issue on the affected repo | 4 h |
| Peer down in UAT | uat peers | Per UAT-AVAILABILITY-RUNBOOK §3 steps (issue to owning team) | 4 h ack / 1 business-day recovery (runbook SLAs) |
| Environment drift / stale envs | any | Sprint-review audit (§1.3) | next sprint review |

### 4.2 Auto-filed incident issue template

When a rollout or health check fails and no REL issue exists (e.g., non-release deploy), Ethan files an issue on the affected repo:

```markdown
## Title
[DEPLOY-ALERT] <service> rollout/health failure — <env>

## Details
- Service: <name>
- Environment: uat | production
- Deployed SHA: <sha>
- Pipeline: <url>
- Failure signal: rollout timeout | health endpoint <status> | peers-health critical

## Response
- [ ] Ethan acknowledged
- [ ] Root cause identified
- [ ] Resolution: fix-forward | rollback (per GIT-WORKFLOW-STANDARDS.md §2.1.3)
- [ ] Follow-up issue created (if needed)
```

If a REL issue exists, the incident is recorded there instead (§2.3) — do not fork the log of record.

---

## 5. Orion Boundary: Deploy vs. Runtime Observability

Orion owns **runtime** observability (metrics, dashboards, alerts on running services). This standard covers **deployment** observability only. The boundary:

| Concern | Owner | Standard |
|---------|-------|----------|
| Was the rollout healthy? Did the new SHA go live? | Deployment observability (this standard, Ethan) | GitLab Deploy Boards, `kubectl rollout status`, §3 checks |
| Is the service healthy/performing after rollout? | Runtime observability (Orion monitoring stack) | Orion dashboards & alerts |
| Peer availability in UAT | UAT-AVAILABILITY-RUNBOOK (Ethan) | `peers-health` + runbook SLAs |

**What apps MUST emit** so deployment observability works:
- A **health endpoint** (`/health` or equivalent) returning 200 only when the app can serve — used by §3 checks.
- **Startup and readiness signals** compatible with k8s probes (readiness gate traffic until the app is actually ready).
- **Version/SHA exposure** in the health payload or logs, so the running SHA can be reconciled against the Deploy Board.
- Runtime metrics/logs to Orion's monitoring stack (runtime concern — defined in the Orion repo, not here).

---

## 6. Release-Issue Integration

Deployment observability evidence is a **required closure input** for the REL release issue (§8.7). After the production deploy, Ethan (or Emma) posts a **post-deploy health comment** on the release issue containing:

1. Deployed SHA + environment(s)
2. Rollout completion evidence (`kubectl rollout status` result / Deploy Board state)
3. Health-check result (§3.1 item 2)
4. Any incidents during rollout (or "none")

A release issue MUST NOT be closed (`issue-status closed`) without this comment recorded. It is the deploy-side counterpart to the Olivia/Isabella sign-offs.

---

## 7. Service-Level Objectives (SLOs) — PROPOSED, PENDING RATIFICATION

> ⚠️ **These SLOs are proposals pending BUSINESS-RULEBOOK §5 ratification.** They are targets for planning, not commitments. Do not reference them as contractual until ratified.

| SLO | Proposed target | Scope |
|-----|-----------------|-------|
| Rollout completion detection | ≤ 10 min from deploy job end | all environments |
| Production rollout failure acknowledgment | ≤ 1 h during release window | production |
| UAT deploy failure acknowledgment | ≤ 4 h | uat |
| Post-deploy health evidence recorded | same session as deploy | all environments |
| UAT soak residency | ≥ 1 business day (unless §2.1.2 rule 6a compression) | uat → main |

---

## Version History

| Date | Change |
|------|--------|
| Nov 02 2026 | Initial standard (TASK-95, issue #95): environments/deploy boards, rollout failure detection (no auto-rollback), post-deploy health checks + explicit soak-gate definition, alerting paths, Orion boundary, release-issue integration, proposed SLOs. |
