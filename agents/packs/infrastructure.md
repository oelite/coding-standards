# Task Pack: Infrastructure

## Who Loads This
Ethan (primary), Marcus (architecture review)

## Standards to Read (via tools)
- `coding-standards/1_dotNet_coding_standards/05,11`
- `coding-standards/5_git_workflow_standards/GIT-WORKFLOW-STANDARDS.md`
- Target repo `.gitlab-ci.yml`, `Dockerfile`, `docker-compose*.yml`, `k8s/`, `NuGet.config`

## Scope
- Docker / Docker Compose images
- GitLab CI pipelines (`.gitlab-ci.yml` per repo)
- K8s deployment validation
- Environment consistency
- Observability wiring
- Local development infrastructure (`docker-compose.dev.yml`)

## Docker Compose Standards
- Standardized versions (verified 2026-06-20):
  - MongoDB: `mongo:8.0`
  - Redis: `redis:8.8-alpine`
  - ClickHouse: `clickhouse/clickhouse-server:26.5`
  - Kafka: `confluentinc/cp-kafka:8.3.0` (NOT `apache/kafka`)
  - RabbitMQ: `rabbitmq:4.3-management-alpine`
  - OpenSearch: `opensearchproject/opensearch:3.7`
  - MinIO: `minio/minio:RELEASE.2025-09-07T16-13-09Z`
- **Never use `latest` tags**
- Minimal service principle: only include services actively consumed by app code (verified by `.csproj` references and actual source usage)
- **Version Update Process**: When a new major/minor version is released, Ethan verifies compatibility with OElite.Restme providers; update this section in AGENTS.md, then update all `docker-compose.dev.yml` files in the codebase; all repos MUST converge within the same release cycle.
- Port conflict handling: check before starting, remap if needed — NEVER kill existing containers

## CI/CD Pipeline Requirements
- Stage pattern: `version → build → test → pack/deploy → build_docker → deploy_k8s`
- Skip data-layer integration tests: `dotnet test --filter "Category!=Integration"`
- Skip E2E browser tests in CI
- Registries:
  - NuGet: `nuget.org` (main) / `packages.phanes.ltd` (develop/uat)
  - Docker: `registry.phanes.ltd/oelite`
- K8s namespaces: `oelite-{dev,uat,prod}`; prod is `when: manual`

## Verification Checklist
- [ ] `docker build -f <Dockerfile> .` succeeds
- [ ] `docker compose -f docker-compose.dev.yml up` starts all services; health checks pass
- [ ] No port conflicts (remapped if needed)
- [ ] Health endpoint responds 200
- [ ] K8s rollout status succeeds
- [ ] CI pipeline configured to skip integration/E2E tests

## Handoff Target
- Olivia (container health validation) + Maya (secrets review, if applicable) [parallel] → Isabella (docs + biz validation)
