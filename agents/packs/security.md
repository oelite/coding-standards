# Task Pack: Security

## Who Loads This
Maya (primary), Daniel (implementation reference), Grace (code review reference)

## Standards to Read (via tools)
- `uranus/origin-auth/.ai/standards/security-standards.md`
- `coding-standards/2_general_web_coding_standards` (security sections)
- Target repo `.ai/standards/security-standards.md` (if exists)

## Mandatory Review Triggers
Review REQUIRED when ANY apply:
- Any change to authentication-related code or flows
- Any new/changed API endpoint touching security, authentication, or permissions
- Any change to create/update/delete (CRUD) record operations
- Password hashing, token signing/validation, key generation/rotation, encryption-service changes
- Dependency additions/updates with potential CVEs
- Any secrets-handling change

## Security Requirements

### Authentication (Origin Auth)
- JWT: RS256 issuance, validation, introspection (RFC 7662), revocation (RFC 7009)
- Redis blacklist for revoked tokens
- JWK Set endpoint
- `TokenService.cs` — reference implementation

### Authorization / Tenancy
- Server-side access control on every data operation
- Tenant isolation via `Region` + `IOwnedEntity`
- `IsPlatformAdmin()` / `IsTenantAdmin()` checks in controllers
- Frontend guards: `PlatformGuard`, `TenantAdminGuard`
- JWT `role` claims determine tier

### Cryptography
- Password hashing: **Argon2id** (OWASP params), constant-time compare
- Field encryption: AES-256 with 90-day rotation
- Key material at rest: AES-GCM
- RSA keys: 2048/4096, rotation support
- Secrets: K8s secrets / CI variables only — **never committed, never logged**

### Gateway (Kortex)
- `[Authorize(Roles=…)]`
- Versioned routes
- Unified proxy & security gateway

## Verification Checklist
- [ ] Tenant isolation cannot be bypassed
- [ ] Tokens validate/expire/revoke correctly
- [ ] No secrets committed or logged
- [ ] Crypto parameters meet standard
- [ ] Container scan passes (Trivy in origin-auth)
- [ ] All auth/security code reviewed by Maya

## Handoff Target
- Grace (code review) → Olivia (testing) → Ethan (deploy + scan) → Isabella (docs + biz validation)
