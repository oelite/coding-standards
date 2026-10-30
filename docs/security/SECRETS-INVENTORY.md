# Cluster Secret Provisioning & Rotation Runbook

**Scope**: `infrastructure/oelite-stack/clusters/<ENV>/` manifests (UAT, Production).
**Policy**: These directories are gitignored (`.gitignore` — operator-managed, may contain live credentials and kubeconfigs). **No live secret value is ever committed.** Secrets are provisioned **out-of-band**, directly in-cluster.

## Canonical pattern (cert-manager Cloudflare DNS-01 token, issue cs#86)

The Secret for cert-manager ACME DNS-01 (`cloudflare-api-token-secret`, namespace `cert-manager`) is provisioned **out-of-band**, never from a committed or applied manifest file:

```bash
# Run per cluster (UAT and Production kubecontexts), after rotating the token:
kubectl -n cert-manager create secret generic cloudflare-api-token-secret \
  --from-literal=api-token=<rotated-token>
```

## Rotation runbook — Cloudflare API token (issue cs#86, prefix `i001j73…`)

1. **Rotate (owner: ethan/ops — requires Cloudflare console access)**
   - Cloudflare dashboard → My Profile → API Tokens.
   - Roll the leaked token (prefix `i001j73…`): create the replacement first with **minimal scope** (Zone → DNS → Edit, scoped to the zones cert-manager serves), verify it works, then **delete/revoke the leaked token** so the committed/local plaintext value is dead.
2. **Recreate the in-cluster Secret (owner: ethan/ops)** — per cluster (UAT, Production):
   ```bash
   kubectl -n cert-manager create secret generic cloudflare-api-token-secret \
     --from-literal=api-token=<rotated-token>
   ```
   (Use `--dry-run=client -o yaml | kubectl apply -f -` to update in place if the Secret already exists.)
3. **Verify (owner: ethan/ops)**
   - Force a renewal / create a **test Certificate** using the DNS-01 solver and confirm it reaches `Ready`:
     ```bash
     kubectl -n cert-manager get certificate -w
     ```
   - Check cert-manager logs for a successful DNS-01 challenge with the new token; confirm no `403` from Cloudflare.
4. **Redact the operator-local manifest (owner: ethan/ops — only AFTER steps 1–3)**
   In both local files
   `infrastructure/oelite-stack/clusters/{UAT,Production}/cluster-config/cert-manager/acme-issuer-cloudflare-dns-token.yaml`
   replace the `stringData.api-token` value with the placeholder below and add the comment block above it:
   ```yaml
   # SECURITY (cs#86): Never commit real token values. This Secret is provisioned
   # OUT-OF-BAND directly in-cluster after rotation (see docs/security/SECRETS-INVENTORY.md):
   #   kubectl -n cert-manager create secret generic cloudflare-api-token-secret \
   #     --from-literal=api-token=<rotated-token>
   # Do NOT re-apply this manifest until the rotated token is provisioned in-cluster.
   stringData:
     api-token: REDACTED-ROTATE-OUT-OF-BAND-SEE-ISSUE-86
   ```
5. **Close the loop (owner: maya)**
   - Confirm the old token returns `401/403` from the Cloudflare API.
   - Record disposition on cs#86; file a follow-up to add gitleaks scanning for this repo (cloudflare api-token rule) so any future commit of this file class fails CI.

## Git-history disposition (recommendation)

**No history rewrite required.** Verified 2026-10-30: `infrastructure/oelite-stack/clusters/` was **never tracked** in any branch of `oelite/coding-standards` (`git log --all` empty for the path) — the plaintext copies exist only as operator-local, gitignored files. With the token rotated (step 1) and the manifests redacted (step 4), no live value remains anywhere; there is no git history to purge. History rewrites (filter-repo/force-push) are reserved for secrets that were actually pushed — not the case here.

## Follow-ups

- Add gitleaks scanning (`.gitleaks.toml` + CI job) to `oelite/coding-standards` covering Cloudflare/SendGrid/Twilio/generic token rules, so the `clusters/` file class can never silently land in git.
- Apply the same out-of-band pattern to any other cluster Secret manifests found under `clusters/<ENV>/` during the next ops review.
