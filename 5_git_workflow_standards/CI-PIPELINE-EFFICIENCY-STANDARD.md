# CI Pipeline Efficiency Standard

> **Repository**: coding-standards
> **Scope**: ALL OElite sub-repositories (normative for every `.gitlab-ci.yml`)
> **Maintained by**: Ethan (DevOps & Reliability)
> **Status**: Active
> **Version**: 1.1.0
> **Issues**: TASK-102 (#102), TASK-104 (#104) — v1.1.0 amends per owner decision: nightly E2E schedules DROPPED

---

## Overview

This standard defines **when pipelines run**, **which test tiers run at each trigger**, and **how failing suites terminate** across every OElite repository. It exists because full pipelines on every branch push — including multi-hour E2E suites that continue collecting failures after the first failure — were draining GitLab runner capacity and delaying MRs.

**Decisions recorded by the business owner (2026-11-03):**

1. Pipelines trigger on **MR events and protected branches only** — no push pipelines on `feature/*` or `fix/*` branches.
2. **No E2E suites in MR pipelines.** Developers run the full E2E suite **locally** (against the shared `oelite-stack` infrastructure) and record evidence in the MR before requesting review. CI runs E2E only as part of the promotion chain (§2.3) per `GIT-WORKFLOW-STANDARDS.md` §2.1.2. **No nightly/scheduled E2E pipelines** (owner decision, TASK-104).

---

## 1. Pipeline Trigger Tiers (Mandatory)

Every `.gitlab-ci.yml` MUST declare this `workflow:` block (adjust protected-branch list to the repo's actual branches):

```yaml
workflow:
  rules:
    # MR pipelines — the merge gate (build + unit + lint; NO E2E)
    - if: '$CI_PIPELINE_SOURCE == "merge_request_event"'
    # Protected branches — full pipeline including integration/E2E tiers
    - if: '$CI_COMMIT_BRANCH == "develop"'
    - if: '$CI_COMMIT_BRANCH == "uat"'
    - if: '$CI_COMMIT_BRANCH == "main" || $CI_COMMIT_BRANCH == "master"'
    # Release tags
    - if: '$CI_COMMIT_TAG'
    # Manual / API triggers only — NO scheduled E2E pipelines (TASK-104)
    - if: '$CI_PIPELINE_SOURCE == "web" || $CI_PIPELINE_SOURCE == "api"'
```

| Tier | Trigger | Jobs allowed | Rationale |
|------|---------|--------------|-----------|
| **MR pipeline** | `merge_request_event` | Build, lint, unit tests, static analysis | The merge-eligibility gate. Fast feedback; no E2E. |
| **Protected-branch pipeline** | push to `develop` / `uat` / `main`/`master` | Full pipeline: build, unit, integration (ephemeral `services:` where available), E2E tiers per §2 | Validates the integration point; feeds deployment gates. |
| **Promotion MR** | MR `uat` ← `develop`, `main` ← `uat` | Per §2.1.2 promotion gates | UAT soak + production gates unchanged. |
| **Feature/fix branch push** | plain push, no MR | **No pipeline** | Intermediate commits prove nothing; the MR pipeline validates the final state. |

**Enforcement rules:**

- A repo MUST NOT have per-job `rules:` that re-enable push pipelines on unprotected branches.
- Per-job rules may further restrict (e.g., path-based `changes:`), never broaden the workflow block.
- Existing per-job `rules:` in repos remain valid only where they are subsets of the workflow block above.

---

## 2. E2E Execution Policy (Mandatory)

### 2.1 MR pipelines — E2E is PROHIBITED

E2E browser suites (Playwright or equivalent) MUST NOT run in MR pipelines. Long-running E2E in MR pipelines was the primary cause of runner exhaustion and MR queueing.

### 2.2 Developer contract — local E2E before MR is Ready

For every user-facing change, the implementing developer (human or agent) MUST, **before transitioning the MR to `Ready to Merge`**:

1. Start the shared local stack: `./oelite-stack.sh up` (+ `init` if needed).
2. Run the full E2E suite locally against the running dev server (e.g., `npx playwright test`).
3. Record evidence in the MR description: command executed, pass/fail counts, and screenshot/trace paths per the E2E Quality Gates (`principles.md` §Testing Policy; verification via `scripts/e2e-quality-check.sh`).

Reviewers MUST reject an MR for a user-facing change whose description lacks local E2E evidence. "Unit tests pass" is NOT sufficient (see `ISSUE-MR-TEMPLATES.md` MR template checklist).

### 2.3 CI E2E — promotion gates only

| Branch / gate | E2E execution | Blocking? |
|---------------|---------------|-----------|
| `develop` | No automatic E2E on ordinary pushes; developer local E2E evidence remains the MR gate (§2.2). | N/A |
| `uat` | Full E2E as part of the develop → uat promotion soak | Blocking per §2.1.2 |
| `main`/`master` | Full E2E post-deploy verification (or as part of uat → main promotion MR evidence) | Per §2.1.2 + `DEPLOYMENT-OBSERVABILITY-STANDARD.md` |

No nightly/scheduled E2E pipelines are configured. Ethan preserves the existing promotion-gate sequence and verifies E2E evidence per release issue.

### 2.4 Data-layer integration tests

Unchanged from existing policy (`agents/roles/ethan.md`, standard 16): unit tests always run in CI; data-layer integration tests run only via ephemeral CI `services:` where the runner provides them, otherwise filtered out (`Category!=Integration`) and run locally against the shared stack.

---

## 3. Fail-Fast & Resource Hygiene (Mandatory)

### 3.1 Fail-fast for test suites

A failing test suite MUST stop early instead of collecting hours of secondary failures:

- **Playwright**: set `maxFailures: 5` in `playwright.config.ts` (or `--max-failures=5` on the CLI).
- **.NET**: `dotnet test -- --stop-on-failure` (xUnit v3 / VSTest `--StopOnFail` where supported).
- **Jest/Vitest**: `--bail=5`.

Secondary-failure logs are still available from the partial run; the goal is to stop hours-long zombie runs, not to hide diagnostics.

### 3.2 Job timeouts

Every job MUST declare an explicit `timeout:` bounded to its tier (GitLab default is 1h+ and lets hung jobs eat runners):

| Job class | Max timeout |
|-----------|-------------|
| Build / lint / unit | 15m |
| Integration (ephemeral services) | 30m |
| E2E smoke / post-deploy checks | 30m |
| Full E2E (promotion) | 90m |

### 3.3 Interruptible jobs

All MR-pipeline jobs MUST set `interruptible: true` so newer commits on the same MR auto-cancel stale runs.

### 3.4 Auto-cancel redundant pipelines

Ethan MUST enable **Settings → CI/CD → General pipelines → "Auto-cancel redundant pipelines"** on every project (and in group settings as the default for new projects). Combined with §3.3 this ensures only the newest pipeline for an MR/branch survives.

### 3.5 Merge gate

Projects MUST keep **Settings → Merge requests → "Pipelines must succeed"** enabled so the MR pipeline (build + unit) remains the merge gate even though E2E is absent from it.

---

## 4. Caching & Runner Efficiency (Recommended)

- Cache NuGet (`~/.nuget/packages`) and npm/pnpm stores via `cache:` keyed on lockfile hashes.
- Prefer the shared `uranus/ci-builder` build image to avoid per-job image pulls.
- Use `needs:`/DAG to parallelize independent stages instead of sequential waits.

---

## 5. Rollout Plan (Ethan-owned)

1. Update `coding-standards/.gitlab-ci.yml` as the reference implementation (this repo).
2. Roll the `workflow:` block + timeouts + `interruptible` + validated fail-fast config into all active repos' `.gitlab-ci.yml` (22+ repos; `mercury/runners` CI remains disabled with `SKIP_BUILD=true` until separately reinstated). Use per-repo issues/worktrees as required by the Git workflow; no pilot/wave sequencing is mandated.
3. Enable "Auto-cancel redundant pipelines" group-wide; verify per project via settings audit.
4. Announce the developer local-E2E contract via Emma (team communication) and update onboarding docs (Isabella).

---

## 6. Compliance Checklist (per repo, verified by Ethan)

- [ ] `workflow:` block present; no push pipelines on unprotected branches
- [ ] MR pipeline jobs: `interruptible: true`, explicit `timeout:`, no E2E jobs
- [ ] Promotion-gate E2E evidence present per §2.3; no nightly E2E schedule configured
- [ ] Fail-fast configured in test runner config (`maxFailures` / runner-specific bail or stop-on-failure)
- [ ] "Auto-cancel redundant pipelines" + "Pipelines must succeed" enabled
- [ ] Caching configured for package managers
- [ ] `deploy_uat` / `deploy_prod` branch-gated rules unchanged (§2.1.2 still holds)
