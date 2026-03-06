# Security Framework — FutureProof EPM

**Version:** 1.0  
**Created:** 2026-03-06  
**Classification:** Internal — Confidential  
**Scope:** Application security, data protection, infrastructure hardening, and compliance across all four regions (US, AU, NZ, UK)

---

## Table of Contents

1. [Threat Model](#1-threat-model)
2. [Authentication & Access Control](#2-authentication--access-control)
3. [Data Classification & Protection](#3-data-classification--protection)
4. [Encryption](#4-encryption)
5. [API Security](#5-api-security)
6. [Infrastructure Security](#6-infrastructure-security)
7. [Input Validation & Output Encoding](#7-input-validation--output-encoding)
8. [Rate Limiting & Abuse Prevention](#8-rate-limiting--abuse-prevention)
9. [Audit Logging & Monitoring](#9-audit-logging--monitoring)
10. [Incident Response](#10-incident-response)
11. [Regulatory Compliance Matrix](#11-regulatory-compliance-matrix)
12. [Security Testing](#12-security-testing)
13. [Third-Party Dependencies](#13-third-party-dependencies)
14. [Implementation Status](#14-implementation-status)

---

## 1. Threat Model

### 1.1 Attack Surface

FutureProof is a fintech platform handling mortgage applications, property valuations, investment portfolio data, and PII across four jurisdictions. The attack surface includes:

| Surface | Risk | Priority |
|---------|------|----------|
| User authentication (Devise + SSO) | Account takeover, credential stuffing | Critical |
| Application forms (PII collection) | Data exfiltration, injection | Critical |
| Admin dashboard | Privilege escalation, insider threat | Critical |
| API endpoints (`/api/quotes`, `/api/chat`, `/api/calculations`) | Abuse, data scraping | High |
| File uploads (Active Storage) | Malware, path traversal | High |
| Email system (templates, workflows) | Phishing via platform | Medium |
| AI chat agents | Prompt injection, data leakage | Medium |
| Legal document generation | Template injection | Low |

### 1.2 Threat Actors

| Actor | Motivation | Capability |
|-------|-----------|------------|
| Opportunistic attacker | Financial data theft | Low — automated scanning |
| Organised crime | Mortgage fraud, identity theft | High — targeted attacks |
| Disgruntled insider | Data exfiltration, sabotage | High — authenticated access |
| Competitor | IP theft, service disruption | Medium |
| Regulator (adversarial audit) | Compliance testing | High — full disclosure expected |

### 1.3 Crown Jewels

Data assets ranked by sensitivity:

1. **Customer PII** — Names, addresses, DOBs, government IDs, income details
2. **Financial data** — Property valuations, mortgage terms, investment positions
3. **Authentication credentials** — Password hashes, SSO tokens, session data
4. **Business logic** — EPM calculation engine, Pavel/Tom financial models
5. **Lender/funder data** — Pool configurations, margin structures, wholesale rates

---

## 2. Authentication & Access Control

### 2.1 Current Implementation

```
Authentication: Devise (database_authenticatable, registerable, recoverable,
                        rememberable, timeoutable, omniauthable)
SSO:            OmniAuth (SAML, Google OAuth2, Entra ID)
CAPTCHA:        Google reCAPTCHA on registration
Sessions:       Devise timeoutable (auto-expire)
```

### 2.2 Role Hierarchy

```
Super Admin → Full platform access, all lenders
Lender Admin → Own lender's users, applications, contracts
User (Customer) → Own applications, documents, chat
Broker → Referral-scoped access (via lender relationship)
```

### 2.3 Required Enhancements

| Enhancement | Priority | Status |
|-------------|----------|--------|
| **Multi-factor authentication (MFA)** — TOTP for all admin roles | Critical | ❌ Not implemented |
| **Devise :lockable** — Lock accounts after 5 failed attempts | Critical | ❌ Not enabled |
| **Devise :confirmable** — Email verification before access | High | ❌ Not enabled |
| **Devise :trackable** — Login IP/timestamp logging | High | ❌ Not enabled |
| **Password complexity** — Require uppercase, number, special char, min 12 chars for admin | High | ⚠️ Min 6 only |
| **Session fixation protection** — Rotate session ID on login | Medium | ✅ Rails default |
| **IP allowlisting for admin** — Restrict `/admin` to known IPs | Medium | ❌ Not implemented |
| **API key rotation** — Automated key expiry for external integrations | Medium | ❌ Not implemented |

### 2.4 Recommended Devise Configuration

```ruby
# config/initializers/devise.rb — Security hardening
config.lock_strategy = :failed_attempts
config.unlock_strategy = :time
config.maximum_attempts = 5
config.unlock_in = 30.minutes
config.confirm_within = 3.days
config.reconfirmable = true
config.password_length = 12..128  # Admin: 12+, User: 10+
config.timeout_in = 30.minutes    # Admin: 15 minutes
config.stretches = Rails.env.test? ? 1 : 12
```

---

## 3. Data Classification & Protection

### 3.1 Classification Scheme

| Level | Label | Examples | Handling |
|-------|-------|----------|----------|
| **L4** | Restricted | Government IDs, TFNs/SSNs, bank account numbers | Encrypted at rest + in transit, field-level encryption, access logged, retention limits |
| **L3** | Confidential | Income, property valuations, mortgage terms, credit scores | Encrypted at rest, role-based access, audit trail |
| **L2** | Internal | User emails, phone numbers, addresses | Standard DB encryption, no public exposure |
| **L1** | Public | Marketing content, legal templates, region configs | No special handling |

### 3.2 PII Inventory

| Field | Classification | Model | Encrypted? | Retention |
|-------|---------------|-------|------------|-----------|
| `email` | L2 | User | DB-level | Account lifetime |
| `full_name` | L2 | User | DB-level | Account lifetime |
| `phone_number` | L2 | User | DB-level | Account lifetime |
| `date_of_birth` | L3 | Application | ❌ Plaintext | 7 years post-close |
| `government_id` | L4 | Application | ❌ **NEEDS ENCRYPTION** | 7 years post-close |
| `income_details` | L3 | Application | ❌ Plaintext | 7 years post-close |
| `property_address` | L2 | Application | DB-level | 7 years post-close |
| `property_value` | L3 | Application | DB-level | 7 years post-close |
| `credit_score` | L3 | Application | ❌ **NEEDS ENCRYPTION** | 7 years post-close |

### 3.3 Field-Level Encryption (Recommended)

For L4 data, implement application-level encryption using Rails 7+ encrypted attributes or `lockbox` gem:

```ruby
# app/models/application.rb
class Application < ApplicationRecord
  encrypts :government_id, deterministic: false
  encrypts :credit_score, deterministic: false
  encrypts :bank_account_number, deterministic: false
end
```

**Key management:** Use `Rails.application.credentials` with per-environment master keys. Rotate annually. Store master key in Fly.io secrets, never in source control.

### 3.4 Data Retention

| Region | Retention Period | Authority |
|--------|-----------------|-----------|
| AU | 7 years from contract close | NCCP Act s186, ATO requirements |
| US | 5 years from contract close | CFPB Regulation B, IRS |
| NZ | 7 years from contract close | CCCFA, IRD requirements |
| UK | 6 years from contract close | FCA SYSC 9, HMRC |

**Implementation:** Scheduled job (`DataRetentionJob`) runs monthly, anonymises records past retention window. Anonymisation replaces PII with hashed placeholders — never deletes records (audit trail integrity).

---

## 4. Encryption

### 4.1 In Transit

| Layer | Implementation | Status |
|-------|----------------|--------|
| HTTPS/TLS 1.3 | Fly.io edge TLS termination | ✅ Active |
| HSTS | `max-age=31536000; includeSubdomains; preload` | ✅ Active |
| Database connection | Neon.com enforces SSL | ✅ Active |
| Internal services | Fly.io private networking | ✅ Active |

### 4.2 At Rest

| Layer | Implementation | Status |
|-------|----------------|--------|
| Database (full disk) | Neon.com AES-256 at rest | ✅ Provider-managed |
| Active Storage files | Fly.io volume encryption | ✅ Provider-managed |
| Application-level (L4 fields) | Rails `encrypts` | ❌ **Not yet implemented** |
| Backups | Neon.com encrypted snapshots | ✅ Provider-managed |

### 4.3 Key Management

```
Master key:        Rails credentials (per-environment)
Storage:           Fly.io secrets (FLY_MASTER_KEY)
Rotation:          Annual (or on suspected compromise)
Access:            Deployment pipeline only — no human access in production
Backup:            Encrypted offline copy held by CTO
```

---

## 5. API Security

### 5.1 Current Endpoints

| Endpoint | Auth | Rate Limited | Input Validated |
|----------|------|--------------|-----------------|
| `POST /api/quotes/calculate` | None (public) | ✅ Rack::Attack | ✅ Service-level |
| `POST /api/chat` | Session (Devise) | ✅ Rack::Attack | ⚠️ Basic |
| `GET /api/calculations` | Session (Devise) | ✅ Rack::Attack | ✅ |

### 5.2 AI Chat Agent Security

The AI chat system (`AiAgentRouter`) routes user messages to specialised agents. Security concerns:

| Risk | Mitigation | Status |
|------|-----------|--------|
| Prompt injection | Sanitise user input before agent routing | ⚠️ Basic sanitisation only |
| Data leakage via chat | Agents should never return raw DB records | ⚠️ Mock responses only (safe for now) |
| Agent impersonation | Validate agent IDs server-side | ✅ Router validates |
| Conversation history exposure | Scope to authenticated user only | ✅ Devise session required |

**Recommendation:** When chat agents connect to live data, implement output filtering that strips L3/L4 data from responses unless the user owns that data.

### 5.3 CSRF Protection

```ruby
# application_controller.rb
protect_from_forgery with: :exception  # Rails default
```

API endpoints serving JSON should use `protect_from_forgery with: :null_session` and validate via session cookie or API token — never skip CSRF entirely.

---

## 6. Infrastructure Security

### 6.1 Fly.io Deployment

| Control | Implementation | Status |
|---------|----------------|--------|
| Container isolation | Fly.io Firecracker microVMs | ✅ |
| Secrets management | `fly secrets set` (encrypted at rest) | ✅ |
| Private networking | Internal DNS for service-to-service | ✅ |
| Auto-TLS | Fly.io managed certificates | ✅ |
| Health checks | Fly.io built-in + custom `/up` endpoint | ✅ |
| Deployment rollback | `fly releases` + instant rollback | ✅ |

### 6.2 Database (Neon.com)

| Control | Status |
|---------|--------|
| SSL-only connections | ✅ Enforced |
| IP allowlisting | ⚠️ Not configured (Neon uses connection pooling) |
| Automated backups | ✅ Continuous (point-in-time recovery) |
| Connection pooling | ✅ Neon serverless driver |
| Query logging | ⚠️ Application-level only |

### 6.3 DNS & CDN

| Control | Recommendation |
|---------|---------------|
| DNSSEC | Enable on domain registrar |
| CAA records | Restrict certificate issuance to Fly.io CA |
| DDoS protection | Fly.io Anycast + Rack::Attack application layer |

---

## 7. Input Validation & Output Encoding

### 7.1 Current Implementation

- **InputSanitization concern** — Strips null bytes, control characters, trims whitespace
  - ⚠️ Currently **disabled** on User model (`# include InputSanitization — Temporarily disabled for testing`)
- **Rails built-in** — ERB auto-escapes output by default
- **Strong parameters** — All controllers use `permit` whitelisting
- **CSP** — Strict Content Security Policy (no inline scripts/styles)

### 7.2 Required Actions

| Action | Priority | Details |
|--------|----------|---------|
| **Re-enable InputSanitization on User** | Critical | Disabled "temporarily" — must re-enable |
| **Add InputSanitization to Application model** | High | Financial data needs sanitisation |
| **Validate numeric inputs** | High | Property values, income — reject non-numeric |
| **Phone number validation** | Medium | `phony` gem is included but verify usage |
| **Email format validation** | ✅ | Already validates with `URI::MailTo::EMAIL_REGEXP` |

### 7.3 SQL Injection Prevention

Rails ActiveRecord parameterises queries by default. The `GoogleUpdateDetectorService` was refactored to use raw SQL (commit `99c22ce` on MarketingHub) — ensure any raw SQL in FutureProof uses parameterised queries:

```ruby
# ✅ Safe
ActiveRecord::Base.connection.execute(
  ActiveRecord::Base.sanitize_sql_array(["SELECT * FROM users WHERE id = ?", user_id])
)

# ❌ Dangerous
ActiveRecord::Base.connection.execute("SELECT * FROM users WHERE id = #{user_id}")
```

---

## 8. Rate Limiting & Abuse Prevention

### 8.1 Current Rack::Attack Configuration

```
Safelist:     localhost (127.0.0.1, ::1)
Blocklist:    .env, .git, config files, wp-admin, xmlrpc.php, malicious user agents
Throttle:     Sensitive POST endpoints — 3/minute per IP
              Login attempts — 5/10 minutes per IP
              Registration — rate limited
```

### 8.2 Recommended Enhancements

| Enhancement | Details |
|-------------|---------|
| **Quote calculator throttle** | 10 requests/minute per IP (prevent scraping financial models) |
| **Chat endpoint throttle** | 20 messages/minute per authenticated user |
| **Admin login separate throttle** | 3 attempts/30 minutes (stricter than user login) |
| **Progressive delays** | Exponential backoff on repeated failures |
| **Fail2ban integration** | Feed Rack::Attack blocks to system-level firewall (Fly.io doesn't support — log only) |

---

## 9. Audit Logging & Monitoring

### 9.1 Current Implementation

| System | Scope | Status |
|--------|-------|--------|
| **PaperTrail** | Model change tracking (versions table) | ✅ Active |
| **Exception Notification** | Production error emails | ✅ Active |
| **User model callbacks** | `log_creation`, `log_update` | ✅ Active |
| **Rack::Attack logging** | Blocked/throttled requests | ✅ Rails logger |

### 9.2 Required Audit Events

For financial services compliance, log these events to a tamper-resistant audit trail:

| Event | Data Captured | Retention |
|-------|--------------|-----------|
| User login (success/failure) | IP, user agent, timestamp, user ID | 2 years |
| Admin action | Admin ID, action, target record, before/after values | 7 years |
| Application state change | User ID, application ID, old state → new state | 7 years |
| Contract generation/signing | User ID, contract ID, document hash, timestamp | Permanent |
| Data export/download | User ID, data scope, timestamp | 2 years |
| PII access | User ID, field accessed, reason | 2 years |
| Quote calculation | IP, inputs (anonymised), result | 1 year |
| Failed authentication | IP, attempted email, failure reason | 1 year |

### 9.3 Centralised Logging (Recommendation)

```
Application logs → Fly.io log drain → external SIEM
                                     (Datadog / Papertrail / ELK)
Audit events   → Dedicated audit_events table (append-only, no DELETE permission)
                → Nightly export to cold storage (S3/GCS, encrypted)
```

---

## 10. Incident Response

### 10.1 Severity Classification

| Level | Description | Response Time | Example |
|-------|-------------|---------------|---------|
| **P1 — Critical** | Active data breach, system compromise | Immediate (< 1 hour) | Customer PII exfiltrated |
| **P2 — High** | Vulnerability exploited, service degraded | < 4 hours | Authentication bypass discovered |
| **P3 — Medium** | Vulnerability found (not exploited), near-miss | < 24 hours | Brakeman finds SQL injection |
| **P4 — Low** | Minor security improvement, hardening | Next sprint | Missing security header |

### 10.2 Breach Notification Requirements

| Region | Authority | Notification Window | Threshold |
|--------|-----------|--------------------|-----------| 
| AU | OAIC (Notifiable Data Breaches scheme) | 30 days (expedited: 72 hours for serious) | Likely to result in serious harm |
| US | State attorneys general (varies) | 30-90 days (varies by state) | PII of state residents |
| NZ | Office of Privacy Commissioner | 72 hours | Notifiable privacy breach |
| UK | ICO (GDPR/UK GDPR) | 72 hours | Risk to rights and freedoms |

### 10.3 Response Playbook

```
1. CONTAIN    — Isolate affected systems (fly scale count 0, rotate credentials)
2. ASSESS     — Determine scope (what data, how many users, which regions)
3. ERADICATE  — Patch vulnerability, revoke compromised credentials
4. NOTIFY     — Regulators (per above), affected users, legal counsel
5. RECOVER    — Restore from known-good backup, re-enable services
6. REVIEW     — Post-incident report within 5 business days
```

---

## 11. Regulatory Compliance Matrix

| Requirement | AU (ASIC/OAIC) | US (CFPB/FTC) | NZ (FMA/OPC) | UK (FCA/ICO) | Status |
|-------------|----------------|---------------|--------------|--------------|--------|
| Data encryption at rest | Required | Required | Required | Required (GDPR Art. 32) | ✅ DB-level |
| Field-level encryption (PII) | Recommended | Recommended | Recommended | Required (GDPR Art. 25) | ❌ |
| Breach notification | 72h (serious) | 30-90 days | 72h | 72h (GDPR Art. 33) | ⚠️ Process only |
| Right to erasure | APP 13 | Limited (CCPA) | IPP 9 | GDPR Art. 17 | ❌ Not built |
| Data portability | Not required | Not required | Not required | GDPR Art. 20 | ❌ Not built |
| Consent management | APP 3 | CFPB consent | IPP 3 | GDPR Art. 6-7 | ⚠️ Terms only |
| Audit trail | ACL condition | Reg B record-keeping | CCCFA records | FCA SYSC 9 | ✅ PaperTrail |
| Access controls (RBAC) | Required | Required | Required | Required | ✅ Basic |
| MFA for admin | Recommended | Recommended | Recommended | Required (FCA) | ❌ |
| Penetration testing | Annual (APRA if bank) | Annual (SOC 2) | Recommended | Annual (FCA) | ❌ |

---

## 12. Security Testing

### 12.1 Current Tools

```bash
bundle exec brakeman              # Static analysis (SAST)
bundle exec rubocop                # Code style + security rules
bundle exec rails test             # 382 tests, 2151 assertions
```

### 12.2 Testing Cadence

| Test | Frequency | Responsibility |
|------|-----------|---------------|
| **Brakeman scan** | Every commit (CI) | Automated |
| **Dependency audit** (`bundle audit`) | Weekly | Automated |
| **RuboCop security rules** | Every commit (CI) | Automated |
| **Manual security review** | Before each release | Developer |
| **Penetration test** | Annual (minimum) | External firm |
| **OWASP Top 10 review** | Quarterly | Internal |

### 12.3 Recommended Additions

```ruby
# Gemfile — Security testing
group :development, :test do
  gem "bundler-audit"        # Known vulnerability scanner
  gem "ruby_audit"           # Ruby CVE checker
end
```

Add to CI pipeline:
```bash
bundle exec bundle-audit check --update
bundle exec ruby-audit check
```

---

## 13. Third-Party Dependencies

### 13.1 Current Security-Relevant Gems

| Gem | Purpose | Risk | Notes |
|-----|---------|------|-------|
| `devise` | Authentication | Low | Well-maintained, widely audited |
| `omniauth` + providers | SSO | Medium | Ensure CSRF protection gem included (✅ `omniauth-rails_csrf_protection`) |
| `rack-attack` | Rate limiting | Low | Actively maintained |
| `secure_headers` | HTTP headers | Low | CSP handled separately |
| `paper_trail` | Audit trail | Low | Append-only versioning |
| `recaptcha` | Bot prevention | Low | Google dependency |
| `httparty` | HTTP client | Medium | Ensure no SSRF via user-controlled URLs |
| `tinymce-rails` | Rich text editor | Medium | XSS vector — ensure sanitisation of output |
| `image_processing` | Image transforms | Medium | ImageMagick CVE history — keep updated |

### 13.2 Supply Chain Security

- Run `bundle audit` weekly to check for known CVEs
- Pin gem versions in `Gemfile.lock` (already done by Bundler)
- Review changelogs before major gem updates
- Consider `gemfile_lock_diff` in CI to flag new/changed dependencies

---

## 14. Implementation Status

### Priority 1 — Critical (Before Production Launch)

- [ ] **Enable Devise :lockable** — Account lockout after failed attempts
- [ ] **Re-enable InputSanitization** on User model
- [ ] **Implement MFA** for all admin roles (TOTP via `devise-two-factor`)
- [ ] **Field-level encryption** for L4 data (government IDs, credit scores)
- [ ] **Strengthen password policy** — 12+ chars for admin, 10+ for users
- [ ] **Enable Devise :confirmable** — Email verification

### Priority 2 — High (Within 30 Days of Launch)

- [ ] **Enable Devise :trackable** — Login audit trail
- [ ] **Right to erasure** endpoint (data anonymisation)
- [ ] **Admin IP allowlisting** or VPN requirement
- [ ] **Penetration test** — Commission external firm
- [ ] **Add `bundler-audit` and `ruby_audit`** to CI
- [ ] **Quote calculator rate limiting** — Protect financial model from scraping

### Priority 3 — Medium (Within 90 Days)

- [ ] **Centralised logging** — SIEM integration via Fly.io log drain
- [ ] **Data retention automation** — Monthly anonymisation job
- [ ] **Data portability** — Export endpoint for UK GDPR compliance
- [ ] **Consent management** — Granular consent tracking beyond ToS
- [ ] **AI chat output filtering** — When agents connect to live data
- [ ] **API key management** — Rotation policy for external integrations

### Priority 4 — Ongoing

- [ ] Annual penetration testing
- [ ] Quarterly OWASP Top 10 review
- [ ] Weekly dependency audits
- [ ] Security awareness for team members with admin access

---

## Appendix A: Security Headers (Current)

```
Strict-Transport-Security: max-age=31536000; includeSubdomains; preload
X-Frame-Options: DENY
X-Content-Type-Options: nosniff
X-XSS-Protection: 1; mode=block
X-Permitted-Cross-Domain-Policies: none
Referrer-Policy: strict-origin-when-cross-origin
Content-Security-Policy: [strict — no inline, defined in content_security_policy.rb]
```

## Appendix B: Useful Commands

```bash
# Security scanning
bundle exec brakeman --no-pager           # Static analysis
bundle exec brakeman -f json -o report.json  # CI-friendly output
bundle exec bundle-audit check --update   # Known CVEs in gems

# Credential management
EDITOR=vim rails credentials:edit         # Edit credentials
fly secrets list                          # View Fly.io secrets (names only)
fly secrets set KEY=value                 # Set production secret

# Audit
rails runner "PaperTrail::Version.where(item_type: 'User').count"  # Version count
rails runner "User.where(locked_at: nil).where('failed_attempts > 0').count"  # Failed logins
```

---

*Document maintained by the FutureProof engineering team. Review quarterly or after any security incident.*
