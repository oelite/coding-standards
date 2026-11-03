# Security-by-Design Skill

> **Status:** [x] active — see issue #22
> **Owner:** Maya
> **Tracked by:** https://code.phanes.ltd/oelite/coding-standards/-/issues/22
> **Related skill:** `architecture-design` (#19) — load together for security architecture reviews
> **Complements:** `agents/packs/security.md` — this SKILL.md deepens the pack with OWASP specifics, threat modeling, and pre-MR checklists

> **External References:**
> - OWASP Top 10 (2025): https://owasp.org/Top10/
> - NIST SSDF: https://csrc.nist.gov/Projects/ssdf
> - CWE Database: https://cwe.mitre.org/
> - OElite Prohibited Patterns: `coding-standards/5_git_workflow_standards/PROHIBITED-PATTERNS.md`

---

## 1. Mission & When to Load

**Mission:** Ensure all OElite implementations are secure-by-default. This skill provides AI agents with the knowledge to produce authentication, authorization, input validation, secrets management, and data protection patterns that meet OWASP standards without escalating to Maya for every implementation decision.

**Load this skill when ANY of these trigger phrases appear:**
- `auth`, `authentication`, `authorization`, `permission`, `RBAC`, `ABAC`, `session`
- `secret`, `API key`, `token`, `JWT`, `credential`, `password`
- `encrypt`, `decrypt`, `hash`, `HMAC`, `signature`, `TLS`, `certificate`
- `input validation`, `sanitize`, `injection`, `XSS`, `CSRF`, `SSRF`
- `PII`, `GDPR`, `data privacy`, `compliance`, `audit log`
- `vulnerability`, `CVE`, `OWASP`, `threat model`, `STRIDE`
- `rate limit`, `DDoS`, `throttle`
- `hard-code`, `.env`, `secrets manager`

**Default loaders:** Maya
**On-demand loaders:** Daniel, Sophia, Ethan, Grace, Marcus

---

## 2. OWASP Top 10 (2025)

For each category: vulnerability definition, common AI agent mistake, OElite-compliant correct implementation, and grep detection patterns.

---

### A01 — Broken Access Control

**Definition:** Access control enforces policy so that users cannot act outside their intended permissions. Failures typically lead to unauthorized information disclosure, modification, or destruction of data.

**Common AI Agent Mistake:** Implementing authorization checks only at the UI/API-controller layer and trusting the frontend to hide/disable unauthorized actions. Agents often write `if (user.IsAdmin)` in a controller and forget that any authenticated user can call the underlying service directly.

**Correct OElite Pattern:**
```csharp
// Every repository method MUST enforce access control at the data layer.
// Never trust caller context alone.
public class OrderRepository : DataRepository<PlatformDb>
{
    public async Task<Order?> GetByIdAsync(string orderId, string userId, string region)
    {
        // Server-enforced: always scope by owner, never trust client-provided userId
        var filter = Builders<Order>.Filter.And(
            Builders<Order>.Filter.Eq(o => o.Id, orderId),
            Builders<Order>.Filter.Eq(o => o.OwnerId, userId),  // resource-level check
            Builders<Order>.Filter.Eq(o => o.Region, region)   // data sovereignty
        );
        return await Collection.Find(filter).FirstOrDefaultAsync();
    }
}

// Controller: also checks, but this is defense-in-depth, not the primary enforcement
[Authorize(Roles = "User,Admin")]
public async Task<ActionResult<OrderDto>> GetOrder(string id)
{
    var order = await _orderRepo.GetByIdAsync(id, GetCurrentUserId(), GetCurrentRegion());
    if (order == null) return Forbid();
    return Ok(_mapper.Map<OrderDto>(order));
}
```

**Detection Grep:**
```bash
# BANNED: access control only at controller
rg -n "return Forbid\(\)" --type cs | rg -v "GetByIdAsync"

# BANNED: missing resource-level scoping in repository
rg -n "Find.*userId" --type cs | rg -v "Filter.And\|Builders.Filter"
```

---

### A02 — Cryptographic Failures

**Definition:** Failures related to cryptography which often lead to sensitive data exposure. Includes weak hash functions (MD5, SHA1 for passwords), improper key management, lack of encryption, and transmission over non-TLS channels.

**Common AI Agent Mistake:** Using MD5/SHA1 for passwords, storing secrets in plain text config, hard-coding encryption keys, using DES/3DES, and passing sensitive data in URLs (which get logged).

**Correct OElite Pattern:**
```csharp
// Passwords: Argon2id via OElite's PasswordHashingService
public class AuthService
{
    public async Task<bool> ValidatePasswordAsync(string plainText, string storedHash)
    {
        return await _hashService.VerifyAsync(plainText, storedHash);
    }

    public async Task<string> HashPasswordAsync(string plainText)
    {
        return await _hashService.HashAsync(plainText); // Argon2id, OWASP params
    }
}

// Encryption: AES-256-GCM via OElite's EncryptionService / DataProtectionService
public class PiiFieldService
{
    public string EncryptField(string plainText, DataClassification classification)
    {
        return _dataProtection.Protect(plainText, classification); // AES-256, purpose-keyed
    }
}

// NEVER: hard-coded keys, MD5, SHA1, DES, or plain-text secrets
// NEVER: sensitive data in URL query strings
```

**Detection Grep:**
```bash
# BANNED: weak algorithms
rg -n "MD5|SHA1|SHA1Managed|DesCryptoServiceProvider|3DES" --type cs

# BANNED: hard-coded secrets
rg -n '"sk-[a-zA-Z0-9]"|"Bearer |"api_key|"secret"' --type cs

# BANNED: secrets in URLs
rg -n "Request\.Uri\?\.Query\|new Uri.*\?" --type cs | rg -i "token\|key\|secret\|password"
```

---

### A03 — Injection (SQL/NoSQL/LDAP/Command)

**Definition:** Injection flaws occur when untrusted data is sent to an interpreter as part of a command or query. The attack's hostile data can trick the interpreter into executing unintended commands or accessing data.

**Common AI Agent Mistake:** String concatenation for MongoDB queries, especially when user input is used as field names or operators (NoSQL injection). Agents assume MongoDB is "safe" because it's NoSQL.

**Correct OElite Pattern:**
```csharp
// MongoDB: NEVER use string concatenation for field names or operators.
// User-controlled field names MUST be whitelisted.
public static class QueryFieldValidator
{
    private static readonly HashSet<string> AllowedSortFields = new(StringComparer.OrdinalIgnoreCase)
    {
        "createdAt", "updatedAt", "status", "name", "email"
    };

    private static readonly HashSet<string> AllowedFilterFields = new(StringComparer.OrdinalIgnoreCase)
    {
        "status", "region", "ownerId", "type", "priority"
    };

    public static string ValidateSortField(string field)
    {
        if (!AllowedSortFields.Contains(field))
            throw new SecurityException($"Invalid sort field: {field}");
        return field;
    }

    public static FilterDefinition<T> BuildSafeFilter<T>(string fieldName, string value)
    {
        if (!AllowedFilterFields.Contains(fieldName))
            throw new SecurityException($"Invalid filter field: {fieldName}");
        // Value is still parameterized — only the field name is whitelisted
        return Builders<T>.Filter.Eq(fieldName, value);
    }
}

// Usage:
var safeField = QueryFieldValidator.ValidateSortField(userProvidedSortField);
var filter = QueryFieldValidator.BuildSafeFilter<T>("status", userProvidedStatus);

// BANNED: Builders<T>.Filter.Eq(userInput, value) — field name from user is NoSQL injection
// BANNED: MongoDB.Driver.FilterDefinition created with string interpolation
```

**Detection Grep:**
```bash
# BANNED: MongoDB query with string interpolation on field names
rg -n 'Builders\..*\.Eq\(.*\+|\$|\.Format' --type cs

# BANNED: raw MongoDB queries
rg -n "BsonDocument|MongoDB\.Driver\.FilterDefinition" --type cs

# BANNED: LDAP/Command injection
rg -n 'Process\.Start|Runtime\.Exec|System\.DirectoryServices' --type cs | rg -v "whitelist\|validated"
```

---

### A04 — Insecure Design

**Definition:** Insecure design represents weaknesses in design patterns and architectures. It is different from insecure implementation — insecure design means the security controls were never created to defend against specific attacks.

**Common AI Agent Mistake:** Implementing features without thinking through the threat model. Agents implement the "happy path" without considering what an attacker could do with privilege escalation, race conditions, or business logic abuse.

**Correct Approach:** Always run a STRIDE analysis (see §10) before implementing new features. Pay particular attention to:
- Missing authorization at the data layer (A01 overlap)
- Race conditions in financial/permission-sensitive operations
- Business logic abuse (e.g., negative quantities, repeated coupon codes)
- Missing rate limiting on sensitive operations

---

### A05 — Security Misconfiguration

**Definition:** Security misconfiguration is the most commonly seen issue. This is commonly a result of insecure default configurations, incomplete configurations, open cloud storage, misconfigured HTTP headers, or verbose error messages.

**Common AI Agent Mistake:** Shipping apps with default credentials, debug endpoints, verbose error traces in production, overly permissive CORS, missing security headers, and debug mode enabled.

**Correct OElite Pattern:**
```csharp
// Security headers (add via middleware or k8s ingress annotations):
// - Content-Security-Policy: "default-src 'self'"
/*
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
X-XSS-Protection: 1; mode=block
Referrer-Policy: strict-origin-when-cross-origin
Permissions-Policy: geolocation=(), microphone=(), camera=()
*/

// Error handling: never expose stack traces in production
if (_env.IsDevelopment())
{
    app.UseDeveloperExceptionPage();
}
else
{
    app.UseExceptionHandler("/error"); // generic error page, no stack trace
    app.UseHsts();
}

// CORS: never use "*" for credentials-enabled requests
builder.Services.AddCors(options =>
{
    options.AddPolicy("Strict", policy =>
    {
        policy.WithOrigins("https://app.oelite.com")
              .AllowCredentials()
              .AllowOnly("GET", "POST", "PUT", "DELETE");
    });
});
```

**Detection Grep:**
```bash
# BANNED: debug mode in production configs
rg -n "Debug.*true|verbose.*error|stack.*trace.*true" --type json | rg -v "development\|localhost"

# BANNED: permissive CORS
rg -n 'AllowAnyOrigin|WithOrigins\("\*"\)' --type cs
```

---

### A06 — Vulnerable & Outdated Components

**Definition:** You are likely vulnerable if you do not know the versions of all components you use (client-side and server-side), if software is outdated or unsupported, or if you do not scan for vulnerabilities regularly.

**Common AI Agent Mistake:** Adding package dependencies without checking their CVE history, using `latest` version specifiers, and never running `npm audit` or `dotnet list package --vulnerable`.

**Correct Approach:**
```bash
# .NET
dotnet list package --vulnerable
dotnet add package <pkg> --version "[<version>]"  # pinned range

# Node.js
npm audit --audit-level=high
npm ls <package>  # check transitive deps
npx npm-check-updates --target minor  # controlled updates

# Docker/Container
trivy image <image>  # scan container image
```

**Policy:** Pin to exact versions for production. Use `npm-check-updates` or `dotnet-outdated` for controlled updates. For embargoed CVEs (critical severity with no patch), escalate to Maya immediately.

---

### A07 — Identification & Authentication Failures

**Definition:** Confirmation of the user's identity, authentication, and session management is critical to protect against authentication-related attacks. This includes weak passwords, credential stuffing, missing MFA, and improper JWT handling.

**Common AI Agent Mistake:** Implementing custom JWT validation, storing tokens in localStorage (XSS risk), not validating `exp`/`iat`/`jti` claims, using symmetric HS256 instead of RS256, and not implementing refresh token rotation.

**Correct OElite Pattern:** See §3 (Authentication & Authorization Patterns).

---

### A08 — Software & Data Integrity Failures

**Definition:** Software and data integrity failures relate to code and infrastructure that does not protect against integrity violations. Examples include relying on untrusted CDN without integrity checks, auto-updating without signature verification, or insecure deserialization.

**Common AI Agent Mistake:** Using `<script>` tags from public CDNs without `integrity` hashes, deserializing untrusted JSON without type constraints, and trusting unsigned configuration from external sources.

**Correct OElite Pattern:**
```html
<!-- Always use SRI hashes for external scripts -->
<script src="https://cdn.example.com/lib.js"
        integrity="sha384-oqVuAfXRKap..."
        crossorigin="anonymous"></script>
```

```csharp
// Safe deserialization: always use type constraints
var options = new JsonSerializerOptions
{
    PropertyNameCaseInsensitive = true,
    TypeNameHandling = TypeNameHandling.None  // NEVER Auto or Objects
};
```

---

### A09 — Security Logging & Monitoring Failures

**Definition:** Without logging and monitoring, breaches cannot be detected. Insufficient logging, detection, monitoring, and active response occurs in most incident responses and takes 200+ days to identify a breach.

**Common AI Agent Mistake:** Logging sensitive data (passwords, tokens, PII), not logging authentication events, using `Console.WriteLine` instead of structured logging, and not correlating logs with request IDs.

**Correct OElite Pattern:** See §8 (Logging & Monitoring for Security).

---

### A10 — Server-Side Request Forgery (SSRF)

**Definition:** SSRF flaws occur when a web app fetches a remote resource without validating the user-supplied URL. Attackers can force the application to send crafted requests to unexpected destinations.

**Common AI Agent Mistake:** Fetching URLs provided by users (e.g., webhook URLs, image URLs, oEmbed endpoints) without validating the hostname against a blocklist.

**Correct OElite Pattern:**
```csharp
public async Task<string> FetchExternalResourceAsync(string url)
{
    var parsed = new Uri(url, UriKind.Absolute);

    // Block private/reserved IP ranges
    if (IsPrivateOrReserved(parsed.Host))
        throw new SecurityException("External URL resolves to private network");

    // Allowlist scheme
    if (parsed.Scheme != "https")
        throw new SecurityException("Only HTTPS URLs allowed");

    using var response = await _httpClient.GetAsync(url);
    return await response.Content.ReadAsStringAsync();
}

private static bool IsPrivateOrReserved(string host)
{
    if (IPAddress.TryParse(host, out var ip))
        return IPAddress.IsLoopback(ip)
            || ip.IsPrivate()
            || IsReserved(ip);
    // Also check DNS resolution
    var addresses = Dns.GetHostAddresses(host);
    return addresses.Any(IsPrivateOrReserved);
}
```

**Detection Grep:**
```bash
# BANNED: HTTP client fetching user-provided URLs without validation
rg -n "HttpClient\.GetAsync\(.*url\|WebClient\.Download.*url\|fetch\(.*user" --type cs | rg -v "validated\|allowlist\|IsPrivateOrReserved"
```

---

## 3. Authentication & Authorization Patterns

### JWT (RS256 — OElite Standard)

```csharp
// TokenService.cs — reference: uranus/origin-auth/Origin.Services/Authentication/TokenService.cs
public class TokenService
{
    // MUST verify: signature, expiration, issuer, audience, jti (revocation)
    public async Task<ClaimsPrincipal?> ValidateTokenAsync(string token)
    {
        var handler = new JwtSecurityTokenHandler();
        handler.TokenReadQueue ??= new System.Threading.Concurrent.ConcurrentQueue<JwtSecurityToken>();

        var parameters = new TokenValidationParameters
        {
            ValidateIssuerSigningKey = true,
            IssuerSigningKey = await _keyService.GetCurrentPublicKeyAsync(), // RSA public key
            ValidateIssuer = true,
            ValidIssuer = _config.Issuer,
            ValidateAudience = true,
            ValidAudience = _config.Audience,
            ValidateLifetime = true,
            ClockSkew = TimeSpan.FromMinutes(5),
            TokenReplayCache = _redisBlacklist // check jti against revoked list
        };

        return await handler.ValidateTokenAsync(token, parameters, out _);
    }

    // Refresh token: MUST rotate on every use (one-time use)
    public async Task<RefreshTokenResult> RotateRefreshTokenAsync(string refreshToken)
    {
        // 1. Validate old token
        // 2. Check it's not in revocation list
        // 3. Invalidate old token (add to blacklist with original exp)
        await _redisBlacklist.AddAsync($"revoked:{GetJti(oldToken)}", oldExp);
        // 4. Issue new access + refresh tokens
        return new RefreshTokenResult(newAccessToken, newRefreshToken);
    }
}
```

**BANNED JWT Patterns:**
- HS256 (symmetric) — use RS256 only
- `ValidateIssuerSigningKey = false`
- `ValidateLifetime = false`
- Storing tokens in localStorage (use `httpOnly` cookies)
- Not checking `jti` for revocation
- Not rotating refresh tokens

### Authorization (RBAC + Resource-Level)

```csharp
// Controller level: role check (defense-in-depth, NOT primary enforcement)
[Authorize(Roles = "TenantAdmin,PlatformAdmin")]

// Service layer: explicit permission check
public class OrderService
{
    public async Task CancelOrderAsync(string orderId, ClaimsPrincipal user)
    {
        var order = await _orderRepo.GetByIdAsync(orderId,
            user.FindFirst(ClaimTypes.NameIdentifier)?.Value!,
            user.FindFirst("region")?.Value!);

        // PRIMARY enforcement: user must own the order
        if (order == null) throw new ForbiddenException();

        // Business rule: only owner or platform admin can cancel
        if (!user.IsInRole("PlatformAdmin") && order.OwnerId != user.UserId())
            throw new ForbiddenException();

        // Audit trail
        await _auditLog.LogAsync(new AuditEvent
        {
            Action = "Order.Cancel",
            UserId = user.UserId(),
            ResourceId = orderId,
            Result = "Success",
            IpAddress = user.FindFirst("x-forwarded-for")?.Value
        });
    }
}
```

**Key Rule:** Authorization MUST be enforced at the data repository layer, not just the service/controller. The repository is the last line of defense.

---

## 4. Input Validation Strategy

### Trust Boundary Model

Every piece of data that crosses a trust boundary MUST be validated:
1. **Entry point** (API controller): validate structure, type, format
2. **Parser layer**: validate schema, size limits, encoding
3. **Before persistence**: validate business rules, reference integrity

### API Schema Validation

```csharp
// .NET: FluentValidation (preferred OElite pattern)
public class CreateOrderCommandValidator : AbstractValidator<CreateOrderCommand>
{
    public CreateOrderCommandValidator()
    {
        RuleFor(x => x.CustomerId).NotEmpty().MaximumLength(50);
        RuleFor(x => x.Items).NotEmpty().Must(items => items.Count <= 100);
        RuleFor(x => x.ShippingAddress).SetValidator(new AddressValidator());
        // Explicitly reject unknown fields to prevent mass-assignment
        RuleFor(x => x).IgnoreUnknownProperties();
    }
}

// TypeScript: Zod (preferred OElite pattern for Next.js)
import { z } from 'zod';
const OrderSchema = z.object({
  customerId: z.string().min(1).max(50),
  items: z.array(ItemSchema).min(1).max(100),
  shippingAddress: AddressSchema,
}).strict(); // reject unknown keys
```

### MongoDB Query Injection Prevention

```csharp
// BANNED: string interpolation in field names
var filter = Builders<Order>.Filter.Eq("status" + userInput, value);

// REQUIRED: whitelist + parameterized values
var allowedFields = new HashSet<string> { "status", "priority", "createdAt" };
if (!allowedFields.Contains(sortField))
    throw new ValidationException("Invalid sort field");
var sortDef = Builders<Order>.Sort.Ascending(sortField);
```

### XSS Prevention

```tsx
// React: default to auto-escaping, never use dangerouslySetInnerHTML
// BANNED: dangerouslySetInnerHTML with user input
// ALLOWED: only for sanitized rich text via DOMPurify
import DOMPurify from 'dompurify';
const sanitized = DOMPurify.sanitize(userProvidedHtml);

// Angular: sanitize via DomSanitizer
constructor(private sanitizer: DomSanitizer) {}
this.safeHtml = this.sanitizer.bypassSecurityTrustHtml(userProvidedHtml);
```

---

## 5. Secrets Management

### BANNED Patterns (Zero Tolerance)

```bash
# NEVER hard-code secrets in source code
API_KEY="sk-live-xxxx"          # BANNED
const TOKEN = "bearer xxx";    # BANNED
connectionString="Server=...;Password=xxx"  # BANNED

# NEVER commit .env files
.env                              # BANNED from git
appsettings.json (with secrets)   # BANNED
```

### Required Pattern

```bash
# Secrets via environment variables or OElite config
OELITE_SECRET_<NAME>=sk-live-xxxx  # Kubernetes secret / CI variable

# In config class (appsettings.json is allowed for NON-secret config only)
public class AppConfig : BaseAppConfig
{
    public string ApiKey => GetSecret("API_KEY");  // reads K8s/CI secret
    public string ConnectionString => GetSecret("DB_CONN"); // reads K8s/CI secret
}
```

### Secret Rotation Policy

- Rotation window: 90 days for field-level encryption keys; immediate on suspected compromise
- Key versioning: support multiple active key versions during rotation
- **If a secret is accidentally committed:**
  1. Rotate it immediately (the committed secret is now compromised)
  2. Use `git-filter-repo` to rewrite history (never `git filter-branch`)
  3. Conduct a post-mortem
  4. Report to Maya for incident assessment

### OElitePathResolver

- `OElitePathResolver` is for **paths only**, never for secrets
- Secrets must use `GetSecret()` from `BaseAppConfig`

---

## 6. Rate Limiting & DDoS Mitigation

### Implementation Levels

| Level | Where | What |
|-------|-------|------|
| Gateway | API Gateway (Kortex) | Global rate limits per IP/key |
| Application | Service layer | Per-user, per-operation limits |
| Both | Combined | Defense-in-depth |

### OElite Pattern

```csharp
// Use OElite's rate limiting middleware (or implement via Redis sliding window)
public class RateLimitMiddleware
{
    public async Task InvokeAsync(HttpContext context)
    {
        var userId = context.User.FindFirst(ClaimTypes.NameIdentifier)?.Value
            ?? context.Connection.RemoteIpAddress?.ToString()
            ?? "anonymous";

        var key = $"ratelimit:{context.Request.Path}:{userId}";
        var count = await _redis.StringIncrementAsync(key);

        if (count == 1)
            await _redis.KeyExpireAsync(key, TimeSpan.FromSeconds(60));

        if (count > 100) // 100 requests per minute per user
        {
            context.Response.Headers.RetryAfter = "60";
            context.Response.StatusCode = 429;
            return;
        }
    }
}
```

### Fail-Open vs Fail-Closed

- **Fail-closed** (default for auth endpoints): if rate limiter fails, deny the request
- **Fail-open** (acceptable for read-only endpoints): if rate limiter fails, allow the request but log the failure

---

## 7. Secure Data Handling

### PII Classification

| Classification | Examples | Handling |
|---------------|----------|----------|
| **Credential** | Passwords, API keys, tokens | Argon2id hash / encrypted at rest |
| **PII** | Name, email, address, phone | Encrypted at rest, access logged |
| **PHI** | Health records, medical info | Encrypted at rest, GDPR+HIPAA compliant |
| **Financial** | Credit card, bank account | PCI-DSS compliance, never store raw |
| **Public** | Username, public profile | No special handling |

### GDPR Requirements

```csharp
// Right to erasure: implement hard delete or pseudonymization
public async Task EraseUserDataAsync(string userId)
{
    // Option 1: hard delete (if lawful basis allows)
    await _userRepo.HardDeleteAsync(userId);

    // Option 2: pseudonymize (if retention required)
    var pseudonym = await _crypto.GenerateRandomTokenAsync();
    await _userRepo.UpdateAsync(userId, new { Email = $"{pseudonym}@redacted.local" });
    // Anonymize related records...
}

// Region field on BaseEntity enforces data residency
// EU user data stays in EU region; US data stays in US region
public class User : BaseEntity
{
    // Region is inherited from BaseEntity: "EU", "US", etc.
}
```

### Encryption Requirements

- **In transit:** TLS 1.2 minimum, TLS 1.3 preferred; HSTS header
- **At rest (DB-level):** MongoDB TLS + disk encryption
- **At rest (field-level):** AES-256-GCM for PII/PHI/Financial/Credential fields
- **Rotation:** Field-level encryption keys rotate every 90 days

---

## 8. Logging & Monitoring for Security

### Log These Events (ALWAYS)

```csharp
await _securityLogger.LogAsync(new SecurityAuditEvent
{
    EventType = "Auth.Success",        // or "Auth.Failure"
    UserId = userId,
    IpAddress = GetClientIp(),
    UserAgent = Request.Headers.UserAgent.ToString(),
    RequestId = _httpContext.TraceIdentifier,
    Timestamp = DateTime.UtcNow,
    // NEVER log: passwords, tokens, full PII, credit card numbers
});

await _securityLogger.LogAsync(new SecurityAuditEvent
{
    EventType = "Authz.Denial",
    UserId = user.UserId(),
    Resource = $"{controller}.{action}",
    ResourceId = resourceId,
    DeniedPermission = requiredRole,
    RequestId = _httpContext.TraceIdentifier
});
```

### NEVER Log These

- Passwords, password hashes, or password change tokens
- Full JWT access tokens or refresh tokens
- Session IDs (unless hashed)
- Full credit card numbers or CVVs
- PII beyond what is necessary (log email prefix, not full email if not needed)
- Full request/response bodies in production (log size only)
- API keys in plain text

### Structured Logging Pattern

```csharp
Log.Information("Auth event: {EventType}, UserId: {UserId}, Ip: {IpAddress}, RequestId: {RequestId}",
    "Auth.Failure", userId.Substring(0,8) + "***", ip, requestId);
```

---

## 9. Dependency Security

### Required Scans

```bash
# Before adding ANY new dependency:
dotnet list package --vulnerable

# CI/CD: run these on every PR
npm audit --audit-level=high
trivy image <docker-image>
```

### Version Pinning Policy

| Environment | Policy |
|-------------|--------|
| Production | Exact versions (`1.2.3`, not `^1.2.3` or `*`) |
| Dev | Minor/patch range acceptable (`~1.2.3`) |
| Lock files | Commit `package-lock.json` and `obj/project.assets.json` |

### Supply Chain Risk

- **NEVER** add packages with < 1M downloads and no security audit history
- **NEVER** add packages whose source is not publicly auditable for production code
- For new packages, run `npm audit` and `syft <image>` to generate SBOM

---

## 10. Threat Modeling (STRIDE — Lightweight)

Agents **MUST** run a STRIDE analysis before implementing new features with security implications. Copy and fill in the template below.

### STRIDE Template

```
## STRIDE Analysis: <Feature Name>

### S — Spoofing
**Question:** Can an attacker impersonate a legitimate user?
- [ ] Is authentication required for this feature?
- [ ] Is the JWT validated (signature, expiration, issuer, audience)?
- [ ] Could an attacker replay a captured token?
**Mitigation:** [describe]

### T — Tampering
**Question:** Can an attacker modify data in transit or at rest?
- [ ] Is data encrypted in transit (TLS)?
- [ ] Is data integrity protected (HMAC or signed)?
- [ ] Can user input modify critical fields without authorization?
**Mitigation:** [describe]

### R — Repudiation
**Question:** Can a user deny an action they took?
- [ ] Are all security-relevant actions logged?
- [ ] Do logs include user ID, timestamp, IP, request ID?
- [ ] Are logs tamper-evident (write-once)?
**Mitigation:** [describe]

### I — Information Disclosure
**Question:** Can an attacker access data they shouldn't?
- [ ] Is PII encrypted at rest?
- [ ] Are authorization checks in place at the data layer?
- [ ] Could an IDOR vulnerability expose other users' data?
**Mitigation:** [describe]

### D — Denial of Service
**Question:** Can an attacker disrupt service for others?
- [ ] Is there rate limiting on this endpoint?
- [ ] Could expensive operations be abused (N+1 queries, unbounded loops)?
- [ ] Is there a circuit breaker for external dependencies?
**Mitigation:** [describe]

### E — Elevation of Privilege
**Question:** Can an attacker gain more permissions than intended?
- [ ] Is authorization checked at every trust boundary?
- [ ] Could input manipulation bypass role checks?
- [ ] Are admin endpoints protected by additional factors?
**Mitigation:** [describe]
```

**When to use:** New API endpoints, new data access patterns, new external integrations, new authentication flows, new file upload/download features.

---

## 11. Pre-MR Security Checklist

**MANDATORY** for any code touching authentication, authorization, PII, secrets, payments, or admin functions. Complete this checklist before requesting review.

### Authentication

- [ ] JWT tokens validated with RS256, not HS256
- [ ] Token expiration (`exp`) checked on every request
- [ ] Token issuer and audience validated against expected values
- [ ] `jti` claim checked against Redis revocation blacklist
- [ ] Refresh token rotated on every use (one-time use)
- [ ] MFA implemented for sensitive operations (if required by policy)
- [ ] No sensitive data stored in JWT payload beyond user ID and roles
- [ ] Tokens issued via `TokenService` from `origin-auth`, not custom implementation

### Authorization

- [ ] Authorization enforced at **data repository layer** (not just controller)
- [ ] `IOwnedEntity.Region` checked for all cross-region requests
- [ ] RBAC enforced via `Authorize(Roles=...)]` at controller AND service layer
- [ ] No client-side-only authorization (UI hiding is NOT security)
- [ ] Admin endpoints protected with additional verification

### Input Validation

- [ ] All inputs validated at trust boundaries (API entry point)
- [ ] Parameterized queries used (no string interpolation for MongoDB field names)
- [ ] Field names from user input whitelisted
- [ ] File uploads validated: type (magic bytes), size limit, content sniffing
- [ ] API schema validation: Zod (TS) or FluentValidation (.NET)
- [ ] Rich text sanitized via DOMPurify (React) or DomSanitizer (Angular)
- [ ] No `dangerouslySetInnerHTML` with user input

### Secrets

- [ ] No hard-coded secrets in source code
- [ ] Secrets via `GetSecret()` / environment variables / K8s secrets
- [ ] `.env` files in `.gitignore` and never committed
- [ ] `OElitePathResolver` not used for secrets
- [ ] No secrets in URL query strings (logged)
- [ ] Accidental secret committed → rotated immediately

### Cryptography

- [ ] TLS 1.2+ for all network communication
- [ ] HSTS header enabled
- [ ] Field-level encryption for PII/PHI/Financial/Credential fields
- [ ] Password hashing: Argon2id via OElite `PasswordHashingService`
- [ ] No weak algorithms: MD5, SHA1, DES, 3DES, RC4
- [ ] Encryption keys from secure key manager, not hard-coded
- [ ] Key rotation policy in place (90-day for field-level keys)

### Logging

- [ ] Authentication success/failure events logged
- [ ] Authorization denials logged with user ID, resource, action
- [ ] Admin actions logged
- [ ] Structured logging with `RequestId` correlation
- [ ] NO passwords, tokens, full PII, or credit card numbers in logs
- [ ] Log level appropriate (ERROR for security events, not INFO)

### Dependencies

- [ ] `dotnet list package --vulnerable` or `npm audit` run
- [ ] No known CVE packages in dependency tree
- [ ] Versions pinned for production
- [ ] Lock files committed (`package-lock.json`, `obj/project.assets.json`)

### Data Handling

- [ ] PII classified using classification table (§7)
- [ ] GDPR: right to erasure implemented
- [ ] Data retention policy defined and enforced
- [ ] `Region` field set on all entities (EU/US data residency)
- [ ] No sensitive data in error responses
- [ ] Data in transit: TLS, not clear text

### Rate Limiting

- [ ] Rate limiting on authentication endpoints
- [ ] Rate limiting on sensitive data operations
- [ ] Per-user AND per-IP limits enforced
- [ ] Redis-based for distributed environments
- [ ] Circuit breaker for external dependencies

### Error Handling

- [ ] No stack traces or internal details in production errors
- [ ] Generic error messages for clients; detailed errors for logging
- [ ] Custom error pages for HTTP errors (404, 403, 500)
- [ ] Unhandled exceptions logged with full context

### CSRF / CORS

- [ ] CSRF tokens on all state-changing requests (POST, PUT, DELETE)
- [ ] CORS policy not over-permissive (no `AllowAnyOrigin` with credentials)
- [ ] Origin header validated for API requests
- [ ] SameSite cookie attribute set appropriately

### Security Headers

- [ ] `Content-Security-Policy` defined and enforced
- [ ] `X-Content-Type-Options: nosniff`
- [ ] `X-Frame-Options: DENY` or `SAMEORIGIN` (if iframe required, restricted)
- [ ] `Referrer-Policy: strict-origin-when-cross-origin`
- [ ] `Permissions-Policy` set to restrict unnecessary capabilities

---

## 12. Before / After Examples

### Example A: Insecure Auth Endpoint → Secure

**BEFORE (insecure):**
```csharp
[HttpPost("login")]
public async Task<ActionResult> Login([FromBody] LoginRequest req)
{
    var user = _db.Users.FirstOrDefault(u => u.Email == req.Email);
    if (user == null) return BadRequest("Invalid email");
    if (user.PasswordHash != req.Password) return BadRequest("Invalid password"); // plain text compare!
    return Ok(new { token = Guid.NewGuid().ToString() }); // no JWT, random string
}
```

**AFTER (secure):**
```csharp
[HttpPost("login")]
public async Task<ActionResult<LoginResponse>> Login([FromBody] LoginRequest req)
{
    if (!ModelState.IsValid) return BadRequest(ModelState); // explicit validation

    var user = await _userRepo.FindByEmailAsync(req.Email);
    if (user == null)
    {
        await _auditLog.LogAsync(new SecurityAuditEvent { EventType = "Auth.Failure", EmailPrefix = "***" });
        return Ok(new LoginResponse { RequiresMfa = false }); // generic error
    }

    if (!await _hashService.VerifyAsync(req.Password, user.PasswordHash))
    {
        await _auditLog.LogAsync(new SecurityAuditEvent { EventType = "Auth.Failure", UserId = user.Id });
        return Ok(new LoginResponse { RequiresMfa = false });
    }

    var accessToken = await _tokenService.IssueAccessTokenAsync(user);
    var refreshToken = await _tokenService.IssueRefreshTokenAsync(user);

    await _auditLog.LogAsync(new SecurityAuditEvent { EventType = "Auth.Success", UserId = user.Id });

    return Ok(new LoginResponse
    {
        AccessToken = accessToken,
        RefreshToken = refreshToken.Token,
        ExpiresIn = 900 // 15 minutes
    });
}
```

### Example B: NoSQL Injection → Safe Query

**BEFORE (vulnerable):**
```csharp
[HttpGet("orders")]
public async Task<ActionResult> GetOrders([FromQuery] string sortBy)
{
    var filter = Builders<Order>.Filter.Eq("ownerId", GetCurrentUserId());
    var sort = Builders<Order>.Sort.Ascending(sortBy ?? "createdAt"); // user controls field name!
    return Ok(await _orderRepo.FindAsync(filter, sort));
}
```

**AFTER (secure):**
```csharp
[HttpGet("orders")]
public async Task<ActionResult> GetOrders([FromQuery] string sortBy)
{
    var safeSortField = QueryFieldValidator.ValidateSortField(sortBy ?? "createdAt");
    var filter = Builders<Order>.Filter.And(
        Builders<Order>.Filter.Eq("ownerId", GetCurrentUserId()),
        Builders<Order>.Filter.Eq("region", GetCurrentRegion())
    );
    var sort = Builders<Order>.Sort.Ascending(safeSortField);
    return Ok(await _orderRepo.FindAsync(filter, sort));
}
```

### Example C: Missing Authorization → Server-Enforced RBAC

**BEFORE (vulnerable — UI hides button, server trusts it):**
```csharp
[HttpDelete("orders/{id}")]
public async Task<ActionResult> DeleteOrder(string id)
{
    await _orderService.DeleteAsync(id); // no authorization check!
    return NoContent();
}
```

**AFTER (secure):**
```csharp
[Authorize(Roles = "User,Admin")] // controller check (defense-in-depth)
[HttpDelete("orders/{id}")]
public async Task<ActionResult> DeleteOrder(string id)
{
    await _orderService.DeleteAsync(id, GetCurrentUserId(), GetCurrentRegion());
    return NoContent();
}

// Service enforces at data layer
public async Task DeleteAsync(string orderId, string userId, string region)
{
    var order = await _orderRepo.GetByIdAsync(orderId, userId, region);
    if (order == null) throw new ForbiddenException();

    if (!GetCurrentUser().IsInRole("PlatformAdmin") && order.OwnerId != userId)
        throw new ForbiddenException();

    await _orderRepo.SoftDeleteAsync(orderId);
    await _auditLog.LogAsync(new AuditEvent { Action = "Order.Delete", ResourceId = orderId });
}
```

---

## 13. When to Escalate to Maya

### Self-Apply This Skill

Use this skill autonomously when:
- Implementing standard auth patterns (JWT validation, session management)
- Applying established authorization patterns (RBAC, resource-level checks)
- Validating input using whitelists and parameterized queries
- Managing secrets via environment variables / K8s secrets
- Running dependency scans and addressing findings
- Completing the pre-MR security checklist
- Writing audit logs with structured security events

### Escalate to Maya

Ask Maya directly when:
- Novel attack surface: new feature with security implications not covered by existing patterns
- Cryptographic algorithm choice: need to implement non-standard crypto or key sizes
- Supply chain decision: adding a new dependency with security concerns
- Incident response: suspected or confirmed security incident
- Security architecture review: new product, new data classification, new integration
- Compliance question: GDPR, SOC2, HIPAA, PCI-DSS specific requirements
- Token/key compromise: suspected or confirmed credential exposure
- Zero-day or embargoed CVE: critical vulnerability with no available patch
- Penetration test findings: triage and remediation planning

### How to Escalate

1. Open a GitLab issue with the `security` label
2. Assign to Maya
3. Include: attack description, affected components, impact assessment, and proposed mitigation
4. For incidents: include timeline, evidence (logs, traces), and affected users/data
