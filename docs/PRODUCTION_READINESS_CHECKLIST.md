# FutureProof EPM — Production Readiness Checklist

**Date:** 2026-03-06  
**Target:** Go/No-Go decision for production deployment  
**Checklist Owner:** Platform Admin  
**Review Frequency:** Before every production release  

---

## 🚀 Pre-Deployment Verification

### Security & Compliance

- [ ] **SSL/TLS Certificate**
  - [ ] Valid certificate installed on Fly.io
  - [ ] Certificate expires >30 days from today
  - [ ] HTTPS enforced on all routes
  - [ ] HSTS header present (min-age=31536000)
  - Verify: `curl -I https://futureproof-epm-platform.fly.dev | grep Strict`

- [ ] **Authentication & Authorization**
  - [ ] Devise authentication working
  - [ ] Password minimum 10 characters enforced
  - [ ] Lockable strategy enabled (max 5 attempts, 30 min lockout)
  - [ ] Session timeout configured (<30 min idle)
  - [ ] Rate limiting enabled on login endpoints
  - [ ] 2FA optional for admin users (if implemented)
  - Verify: Try login with wrong password 6 times → should lock

- [ ] **Data Encryption**
  - [ ] Sensitive fields encrypted at rest (government_id, bank_account, credit_score)
  - [ ] Encryption keys in credentials (never in git)
  - [ ] Database backups encrypted
  - [ ] TLS in transit (all API calls)
  - Verify: Inspect database raw bytes → should see ciphertext

- [ ] **Input Sanitization**
  - [ ] HTML/script input sanitized on all forms
  - [ ] SQL injection protection active (parameterized queries)
  - [ ] File upload validation (type, size)
  - [ ] No inline scripts or styles (CSP compliant)
  - Verify: `bin/rails csp:report` → zero violations

- [ ] **Compliance Documentation**
  - [ ] Privacy Policy published for each region (AU/US/NZ/UK)
  - [ ] Terms of Service published
  - [ ] Data retention policy documented
  - [ ] GDPR compliance verified (if UK/EU customers)
  - [ ] Accessibility statement (WCAG 2.1 AA target)

---

### Functional Testing

- [ ] **Quote → Application Flow**
  - [ ] Calculator produces correct monthly income
  - [ ] Quote can be saved and retrieved
  - [ ] Customer registration from quote works
  - [ ] Application submission captures all required fields
  - [ ] Customer can view submitted application status
  - Verify: Run integration test: `bundle exec rails test test/integration/phase4_quote_to_approval_test.rb`

- [ ] **Lender Review & Approval**
  - [ ] Lender admin can view pending applications
  - [ ] Lender can approve application
  - [ ] Lender can reject application with reason
  - [ ] Approved applications generate contract
  - [ ] Customer receives email notification (approval/rejection)
  - Verify: Run integration test: `bundle exec rails test test/integration/phase4_lender_dashboard_test.rb`

- [ ] **Multi-Region Support**
  - [ ] AU site displays AU contracts + Centrelink disclosures
  - [ ] US site displays US contracts + TILA/RESPA disclosures
  - [ ] NZ site displays NZ contracts + CCCFA compliance
  - [ ] UK site displays UK contracts + FCA/MCOB compliance
  - [ ] Currency displays correctly in each region
  - [ ] All legal documents region-specific
  - Verify: Run integration test: `bundle exec rails test test/integration/phase4_multiregion_test.rb`

- [ ] **Admin & Funder Features**
  - [ ] Platform admin can view all applications
  - [ ] Funder can view portfolio and pool allocation
  - [ ] Email workflows trigger correctly
  - [ ] Reports generate without errors
  - [ ] Audit log records all admin actions
  - Verify: Run integration test: `bundle exec rails test test/integration/phase4_funder_admin_test.rb`

---

### Performance & Load

- [ ] **Page Load Times**
  - [ ] Homepage loads <2s (desktop, optimal connection)
  - [ ] Calculator loads <2s
  - [ ] Dashboard loads <3s
  - [ ] Quote generation <1s
  - Measure: `curl -w "@curl-format.txt" -o /dev/null -s https://futureproof-epm-platform.fly.dev/au`

- [ ] **Database Performance**
  - [ ] Key queries have indexes (applications, users, contracts)
  - [ ] No N+1 query issues in critical paths
  - [ ] Database backups running on schedule
  - [ ] Connection pool sized appropriately (max connections)
  - Verify: Check Fly.io logs for slow query warnings

- [ ] **Static Assets**
  - [ ] CSS/JS minified and gzipped
  - [ ] Images optimized (WebP format preferred)
  - [ ] CDN/cache headers set correctly
  - [ ] Asset fingerprinting enabled (cache busting)
  - Verify: `curl -I https://futureproof.../app.css | grep Cache-Control`

- [ ] **API Response Times**
  - [ ] Quote API <500ms
  - [ ] Application submission <1s
  - [ ] Dashboard data loads <2s
  - [ ] No hanging requests (timeout <30s)
  - Verify: Network tab in browser DevTools

---

### Monitoring & Logging

- [ ] **Error Tracking**
  - [ ] Error monitoring configured (Sentry, Rollbar, or equivalent)
  - [ ] Critical errors alert to team immediately
  - [ ] 404/500 errors logged with context (user, path, timestamp)
  - [ ] Error threshold set (e.g., 5 errors in 5 min = alert)
  - Verify: Trigger a test error → check alert system

- [ ] **Application Monitoring**
  - [ ] Uptime monitoring configured (85% minimum required: 99% target)
  - [ ] CPU/memory usage monitored
  - [ ] Database connection pool monitored
  - [ ] Alert on resource exhaustion (>80% CPU, >90% memory)

- [ ] **Access Logging**
  - [ ] All login attempts logged (success + failure)
  - [ ] Admin actions logged with timestamps
  - [ ] Data exports logged with user/timestamp
  - [ ] Audit trail searchable by date/user/action

---

### Data Integrity & Backup

- [ ] **Database Backups**
  - [ ] Automated backups running daily
  - [ ] Backups stored in secure location (encrypted)
  - [ ] Backup restore tested (at least monthly)
  - [ ] Retention: minimum 30 days, target 90 days
  - Verify: Check Fly.io managed backup status

- [ ] **Data Validation**
  - [ ] All money fields validated as numeric
  - [ ] Dates validated for reasonable ranges (age 55-95)
  - [ ] Required fields enforced at database level (NOT NULL)
  - [ ] Uniqueness constraints on critical fields (email, licence numbers)

- [ ] **Secrets Management**
  - [ ] API keys/secrets in Rails credentials (not .env)
  - [ ] Credentials encrypted with MASTER_KEY
  - [ ] No secrets in git history
  - [ ] Secrets rotated quarterly (or on key employee departure)
  - Verify: `git log -p --all | grep -i "password\|api_key\|secret"` → should be zero results

---

### Deployment Safety

- [ ] **Pre-Deploy Checks**
  - [ ] All tests passing (>80% coverage target, 0 critical failures)
  - [ ] No pending migrations
  - [ ] No deprecated gems
  - [ ] Code review completed (2+ reviewers for production)
  - [ ] Change log updated
  - Verify: `bin/rails db:migrate:status`, `bundle outdated`

- [ ] **Deployment Procedure**
  - [ ] Documented deployment checklist (see DEPLOYMENT_CHECKLIST.md)
  - [ ] Deployment window scheduled (low-traffic time preferred)
  - [ ] Rollback plan documented
  - [ ] Team on standby during deployment
  - [ ] Monitoring actively watched during + 1 hour after deploy

- [ ] **Post-Deploy Verification**
  - [ ] Application starts without errors
  - [ ] Key pages load successfully
  - [ ] Database migrations completed successfully
  - [ ] No error spikes in monitoring
  - [ ] Customer-facing flows working (quote → application → approval)

---

### Legal & Regulatory

- [ ] **Region-Specific Compliance**
  - [ ] **Australia (AU)**
    - [ ] Privacy Act notice displayed
    - [ ] ASIC/ASFL compliance documented
    - [ ] Centrelink asset test disclaimer shown
    - [ ] NNEG clause in all AU contracts
    - Verify: Check `/au` site for Privacy Act mention

  - [ ] **United States (US)**
    - [ ] TILA/RESPA disclosures present
    - [ ] State-specific disclaimers (CA, FL, AZ, NY)
    - [ ] No recourse clause clearly stated
    - [ ] Loan proceeds not taxable disclosure
    - Verify: Check `/us` site for TILA mention

  - [ ] **New Zealand (NZ)**
    - [ ] CCCFA compliance documented
    - [ ] Relationship Property Act notice shown
    - [ ] Privacy Act 2020 notice
    - Verify: Check `/nz` site for CCCFA mention

  - [ ] **United Kingdom (UK)**
    - [ ] FCA authorization verified
    - [ ] MCOB compliance
    - [ ] GDPR/ICO compliance (Data Protection Act 2018)
    - [ ] Inheritance Tax (IHT) impact disclosed
    - Verify: Check `/uk` site for FCA mention

---

### Operational Readiness

- [ ] **Team Training**
  - [ ] Lender admins trained on application review
  - [ ] Funder admins trained on portfolio monitoring
  - [ ] Platform admins trained on escalations/troubleshooting
  - [ ] Customer support has documentation
  - [ ] Runbook exists for common issues

- [ ] **Documentation**
  - [ ] User guides (customer, lender, funder)
  - [ ] API documentation published
  - [ ] Architecture documentation (for developers)
  - [ ] Runbooks for common issues
  - [ ] Troubleshooting guide (for support team)

- [ ] **Support Infrastructure**
  - [ ] Support email monitored (SLA: response <4h)
  - [ ] Support phone line tested (if applicable)
  - [ ] Chat support ready (if applicable)
  - [ ] Escalation path documented
  - [ ] On-call rotation established

---

### Browser & Device Compatibility

- [ ] **Desktop Browsers**
  - [ ] Chrome (latest 2 versions)
  - [ ] Firefox (latest 2 versions)
  - [ ] Safari (latest 2 versions)
  - [ ] Edge (latest 2 versions)
  - Verify: BrowserStack testing

- [ ] **Mobile Devices**
  - [ ] iPhone (iOS 14+, Safari)
  - [ ] Android (Android 11+, Chrome)
  - [ ] Responsive design <375px width
  - [ ] Touch targets ≥48px
  - Verify: iPhone 12, Pixel 5 testing

- [ ] **Accessibility**
  - [ ] WCAG 2.1 AA compliance (target)
  - [ ] Color contrast 4.5:1 (text), 3:1 (UI)
  - [ ] Keyboard navigation working
  - [ ] Screen reader compatible
  - [ ] Focus indicators visible
  - Verify: axe DevTools audit <10 violations

---

## 🎯 Sign-Off

### Final Approval Gate

| Role | Name | Date | Status |
|------|------|------|--------|
| Platform Admin | `__________` | ________ | ☐ Approve ☐ Reject |
| Security Lead | `__________` | ________ | ☐ Approve ☐ Reject |
| Technical Lead | `__________` | ________ | ☐ Approve ☐ Reject |
| Product Owner | `__________` | ________ | ☐ Approve ☐ Reject |

**All items must be ☑️ before proceeding to production.**

### Known Issues / Waivers (if any)

```
[Document any accepted risks or deferred items]
```

### Deployment Timestamp

```
Approved for deployment: _________________ (UTC)
Deployed by: _________________ (name + email)
Verified by: _________________ (name + email)
```

---

## Post-Deployment Monitoring (24-48 hours)

- [ ] Error rate normal (<0.1% of requests)
- [ ] Page load times unchanged
- [ ] No customer complaints
- [ ] Database performance stable
- [ ] No security alerts
- [ ] Mobile/desktop rendering correct

**Sign-off:** `__________` (Date: `__________`)

---

## Appendix: Quick Checks

```bash
# Test suite
bin/rails test

# CSP violations
bin/rails csp:report

# Database
bin/rails db:migrate:status

# Gems
bundle audit

# Code quality
rubocop

# Security
brakeman -z

# Load test (if applicable)
# Load generator tool here
```
