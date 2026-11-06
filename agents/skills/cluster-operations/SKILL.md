# Cluster Operations Skill (UAT / Production K8s)

> **Status:** [x] active — see issue #117
> **Owner:** Ethan (DevOps & Reliability)
> **Tracked by:** https://code.phanes.ltd/oelite/coding-standards/-/issues/117
> **Complements:** `agents/packs/infrastructure.md`, `infrastructure/oelite-stack/README.md` § "Remote K8s Clusters"

---

## 1. Mission & When to Load

**Mission:** Give Ethan everything needed to operate the UAT and Production
Kubernetes clusters autonomously — where the per-environment kubeconfigs and
cluster setup data live, and the sanctioned commands to use them — so cluster
work never escalates to "human intervention required".

**⛔ Access rule:** ONLY Ethan may load this skill and operate on remote
clusters. Other roles and agents have no cluster permissions and must NOT read
`clusters/` contents; they escalate via GitLab issue to Ethan.

**Load this skill when ANY of these trigger phrases appear:**
- `UAT cluster`, `Production cluster`, `prod cluster`, `kubectl`, `KUBECONFIG`
- `kubeconfig`, `cluster health`, `pod status`, `resource audit`, `node capacity`
- `assess quote/resource setup`, `quota`, `resource quota`, `requests/limits`
- `nginx-ingress`, `cert-manager`, `metallb`, `storage class`, `private registry`
- `firewall allowlist`, `tcp-allowlist`, `allowlist.ips`, `public IP`
- `cluster bootstrap`, `app install on cluster` (mongodb/redis/kafka/clickhouse/rabbitmq/opensearch/minio on K8s)
- `deploy to UAT/prod`, `rollout status`, `oelite-uat namespace`, `oelite-prod namespace`

**Default loaders:** Ethan
**On-demand loaders:** none — no other role has cluster access.

---

## 2. Where the Cluster Data Lives (gitignored — never committed)

```
coding-standards/infrastructure/oelite-stack/
└── clusters/                        ← GITIGNORED (.gitignore line: infrastructure/oelite-stack/clusters/)
    ├── UAT/
    │   ├── kubeconfig/              ← exactly ONE kubeconfig file (any filename)
    │   ├── cluster-config/          ← bootstrap scripts + app manifests (metallb, cert-manager,
    │   │                               ingress, storage, apps/<service>/ incl. secrets)
    │   ├── firewall-allowlist.conf  ← operator-local firewall config
    │   └── allowlist.ips            ← operator-local IP allowlist
    └── Production/
        ├── kubeconfig/
        └── cluster-config/          (+ firewall-allowlist.conf / allowlist.ips when present)
```

If `clusters/<ENV>/kubeconfig/` is missing on this machine, the kubeconfigs are
operator-distributed and not present — say so explicitly and stop; do NOT ask
the human to "provide credentials" in chat. Only the human operator can place
these files locally.

---

## 3. How to Operate — ALWAYS via the helper, never raw kubeconfig access

`./oelite-stack.sh cluster` resolves the single kubeconfig in
`clusters/<ENV>/kubeconfig/`, exports `KUBECONFIG` for the child process only,
and never echoes credentials:

```bash
cd coding-standards/infrastructure/oelite-stack

./oelite-stack.sh cluster list                          # list environments present locally
./oelite-stack.sh cluster UAT kubectl get pods -A       # arbitrary kubectl against UAT
./oelite-stack.sh cluster UAT health                    # health summary of UAT infra
./oelite-stack.sh cluster UAT audit                     # resource audit: nodes + top pods
./oelite-stack.sh cluster Production kubectl get nodes
./oelite-stack.sh cluster UAT kubeconfig-path           # resolved KUBECONFIG path (path only)
```

### Resource / quota assessment (typical "can we fit X?" task)

```bash
./oelite-stack.sh cluster UAT kubectl get nodes -o wide
./oelite-stack.sh cluster UAT kubectl describe node <node>     # Allocatable / Allocated resources
./oelite-stack.sh cluster UAT kubectl top nodes
./oelite-stack.sh cluster UAT kubectl top pods -A --sort-by=memory
./oelite-stack.sh cluster UAT kubectl get resourcequota,limitrange -A
./oelite-stack.sh cluster UAT kubectl get requests,limits -A   # per-pod requests/limits summary
./oelite-stack.sh cluster Production kubectl top pods -n oelite-prod
```

### Firewall allowlist (public TCP ports)

```bash
./scripts/tcp-allowlist.sh UAT add-my-ip    # add operator's current public IP
./scripts/tcp-allowlist.sh UAT dry-run
./scripts/tcp-allowlist.sh UAT apply        # keep an SSH session open while applying!
./scripts/tcp-allowlist.sh UAT status
```

Config is operator-local: `clusters/<ENV>/firewall-allowlist.conf` +
`allowlist.ips` (template: `scripts/tcp-allowlist.conf.example`).

---

## 4. Security Rules (NON-NEGOTIABLE — LLM context hygiene)

1. **Never read, `cat`, `grep`, or paste the contents of any file under
   `clusters/` into the conversation, tool output, issue/MR text, or any LLM
   context.** This includes kubeconfigs, `*-secret.yaml`, `*users.yaml`,
   JAAS configmaps, and firewall allowlists. File *names* and *structure* are
   fine; *contents* are forbidden.
2. **Never print secret values from kubectl** — do not run
   `kubectl get secret <name> -o yaml` / `-o json` / `jsonpath={.data...}`.
   Use `kubectl get secret <name> -o jsonpath='{.metadata.name}'` style
   metadata-only queries, or `kubectl describe` (which redacts data).
3. **Use the `./oelite-stack.sh cluster` helper** — it scopes KUBECONFIG to the
   child process. Never `export KUBECONFIG=...` globally, never copy a
   kubeconfig elsewhere, never base64-decode secret data.
4. **If an operation appears to require a credential value** (e.g., rotate a
   password, mint a token), escalate to the human operator via GitLab issue —
   describe *which* file/secret and *what* is needed, never the value.
5. **CI deploys use GitLab CI/CD file-type variables** (`$OElite_K8S` prod,
   `$PHANES_K8S` uat) — never local kubeconfig files in pipelines.
6. If you accidentally captured secret material in output, stop, flag it in the
   session, and rotate the exposed credential via a GitLab issue assigned to
   the human operator.

---

## 5. Verification

- `./oelite-stack.sh cluster list` shows the expected environments (UAT,
  Production) without printing credential material.
- `./oelite-stack.sh cluster <ENV> health` returns a health summary.
- No command in the session transcript printed kubeconfig or secret contents.
- Cluster changes are traceable: GitLab issue referenced, `.oe-scope` updated.
