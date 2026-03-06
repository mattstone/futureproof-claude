# Incident Response Plan — FutureProof EPM

**Version:** 1.0  
**Created:** 2026-03-06  
**Scope:** Security incidents, data breaches, platform outages, financial calculation errors, and regulatory incidents across AU, US, NZ, and UK  
**Classification:** Internal — Confidential

---

## Table of Contents

1. [Incident Categories](#1-incident-categories)
2. [Severity Levels](#2-severity-levels)
3. [Response Team](#3-response-team)
4. [Detection & Reporting](#4-detection--reporting)
5. [Response Procedures](#5-response-procedures)
6. [Data Breach Response](#6-data-breach-response)
7. [Financial Calculation Error Response](#7-financial-calculation-error-response)
8. [Platform Outage Response](#8-platform-outage-response)
9. [Regulatory Incident Response](#9-regulatory-incident-response)
10. [Communication Templates](#10-communication-templates)
11. [Post-Incident Review](#11-post-incident-review)
12. [Testing & Drills](#12-testing--drills)
13. [Implementation Checklist](#13-implementation-checklist)

---

## 1. Incident Categories

| Category | Description | Examples |
|----------|-------------|---------|
| **Security** | Unauthorised access, data breach, malware, credential compromise | SQL injection, admin account takeover, ransomware |
| **Data breach** | PII or financial data exposed to unauthorised parties | Database dump leaked, email to wrong recipient, third-party breach |
| **Financial** | Calculation errors affecting consumer payments or quotes | Income miscalculated, NNEG incorrectly applied, portfolio allocation error |
| **Platform** | Service disruption affecting consumers or internal operations | Application down, database unreachable, payment processing failure |
| **Regulatory** | Compliance failure, regulator inquiry, licence condition breach | Unlicensed activity, missed reporting deadline, consumer complaint escalation |
| **Third-party** | Incident at a vendor or partner affecting FutureProof | Neon.com outage, Fly.io compromise, lender partner breach |

---

## 2. Severity Levels

| Level | Name | Description | Response Time | Escalation |
|-------|------|-------------|---------------|------------|
| **P1** | Critical | Active data breach, system compromise, financial loss to consumers, regulator enforcement action | **< 1 hour** | CEO + CTO + Legal + affected regulator |
| **P2** | High | Vulnerability exploited (no confirmed data loss), significant platform degradation, calculation error affecting live consumers | **< 4 hours** | CTO + Engineering Lead + Compliance |
| **P3** | Medium | Vulnerability discovered (not exploited), minor platform issue, near-miss incident | **< 24 hours** | Engineering Lead + Compliance |
| **P4** | Low | Security hardening opportunity, minor process gap, documentation update | **Next sprint** | Engineering team |

### Severity Decision Tree

```
Is consumer data exposed or at risk?
├── YES → Is it confirmed exfiltrated?
│   ├── YES → P1 CRITICAL
│   └── NO  → P2 HIGH
└── NO  → Are consumers financially impacted?
    ├── YES → P2 HIGH (P1 if material loss)
    └── NO  → Is the platform unavailable?
        ├── YES (>30 min) → P2 HIGH
        ├── YES (<30 min) → P3 MEDIUM
        └── NO  → P3 MEDIUM or P4 LOW
```

---

## 3. Response Team

### 3.1 Incident Response Team (IRT)

| Role | Responsibility | On-Call |
|------|---------------|---------|
| **Incident Commander (IC)** | Owns the incident end-to-end. Makes decisions, coordinates response, communicates status. | CTO (primary), CEO (backup) |
| **Technical Lead** | Investigates root cause, implements containment and fix | Senior Engineer |
| **Compliance Officer** | Assesses regulatory notification obligations, drafts regulator communications | Compliance / Legal |
| **Communications Lead** | Drafts consumer notifications, manages external comms | Head of Operations / Marketing |
| **Scribe** | Documents timeline, actions, decisions in real-time | Assigned per incident |

### 3.2 External Contacts

| Contact | When to Engage | Details |
|---------|---------------|---------|
| **Legal counsel (AU)** | Any P1/P2 involving AU data or AU regulator | [Firm TBD] |
| **Legal counsel (US)** | Any P1/P2 involving US data or state/federal regulator | [Firm TBD] |
| **Legal counsel (NZ)** | Any P1/P2 involving NZ data or FMA/OPC | [Firm TBD] |
| **Legal counsel (UK)** | Any P1/P2 involving UK data or FCA/ICO | [Firm TBD] |
| **Forensic investigator** | Confirmed data breach (P1) | [Firm TBD — pre-engage on retainer] |
| **Cyber insurer** | Any P1 or P2 involving potential claim | [Insurer TBD] |
| **Fly.io support** | Infrastructure incidents | support@fly.io / status.flyio.net |
| **Neon.com support** | Database incidents | Neon support portal |

---

## 4. Detection & Reporting

### 4.1 Detection Sources

| Source | What It Detects | Alert Method |
|--------|----------------|-------------|
| **Rack::Attack logs** | Brute force, scanning, blocked requests | Rails logger → log drain → alert |
| **Exception monitoring** | Application errors, unhandled exceptions | Exception Notification gem → email |
| **Brakeman (CI)** | New code vulnerabilities | CI pipeline failure |
| **Bundle audit (CI)** | Known gem CVEs | CI pipeline failure |
| **Fly.io monitoring** | Container health, resource exhaustion | Fly.io dashboard + alerts |
| **Neon.com monitoring** | Database health, connection issues | Neon dashboard |
| **PaperTrail audit** | Unexpected data changes | Custom alerting on sensitive model changes |
| **Consumer reports** | Account compromise, incorrect payments | Support channel |
| **Regulator notification** | Complaints, investigations | Official correspondence |

### 4.2 Internal Reporting

Any team member who suspects a security incident must report immediately:

```
INCIDENT REPORT (Internal)

Channel:    #incidents (Slack/Teams) or direct to CTO
Required:   
  - What was observed?
  - When was it observed?
  - What systems/data are affected?
  - Is it ongoing?
  - Severity estimate (P1-P4)

DO NOT:
  - Attempt to fix without reporting first
  - Discuss on public channels
  - Contact affected consumers without IC approval
  - Share incident details outside the IRT
```

---

## 5. Response Procedures

### 5.1 P1 Critical — Immediate Response

```
MINUTE 0-15: TRIAGE
├── IC declared (CTO or delegate)
├── IRT assembled (virtual war room)
├── Initial assessment: scope, affected systems, data at risk
├── Scribe begins incident log
└── Cyber insurer notified (if potential claim)

MINUTE 15-60: CONTAIN
├── Isolate affected systems:
│   ├── fly scale count 0 (take app offline if necessary)
│   ├── Rotate compromised credentials immediately
│   ├── Block attacker IPs (Rack::Attack or Fly.io firewall)
│   └── Revoke affected API keys/tokens
├── Preserve evidence:
│   ├── Snapshot database (Neon point-in-time)
│   ├── Capture application logs
│   ├── Do NOT modify or delete any logs
│   └── Image affected containers if possible
└── Legal counsel engaged

HOUR 1-4: ASSESS
├── Determine scope:
│   ├── What data was accessed/exfiltrated?
│   ├── How many consumers affected?
│   ├── Which regions affected?
│   └── Is the attack ongoing or contained?
├── Regulatory notification assessment (see Section 6)
├── Consumer notification drafted (see Section 10)
└── Fix identified (or workaround)

HOUR 4-24: ERADICATE & RECOVER
├── Vulnerability patched
├── Compromised systems rebuilt (not just patched)
├── Credentials rotated (all affected + precautionary)
├── Service restored (staged rollout with monitoring)
├── Consumer notifications sent (if required)
└── Regulator notifications filed (if required)

HOUR 24-72: STABILISE
├── Enhanced monitoring on affected systems
├── Verify no further compromise
├── Consumer support team briefed
├── FAQ prepared for consumer inquiries
└── Post-incident review scheduled (within 5 business days)
```

### 5.2 P2 High — Urgent Response

```
HOUR 0-1: TRIAGE
├── IC notified and confirmed
├── Technical Lead begins investigation
├── Compliance Officer assesses regulatory implications
└── Scope determined

HOUR 1-4: CONTAIN & FIX
├── Vulnerability patched or workaround applied
├── Affected consumers identified
├── Monitoring enhanced
└── Communications drafted if needed

HOUR 4-24: RESOLVE
├── Permanent fix deployed
├── Consumer notifications (if applicable)
├── Compliance reporting (if applicable)
└── Post-incident review within 10 business days
```

### 5.3 P3/P4 — Standard Response

```
P3: Logged, investigated within 24 hours, fixed in current sprint,
    reviewed in next team retrospective.

P4: Logged, prioritised in backlog, fixed when scheduled,
    no formal post-incident review required.
```

---

## 6. Data Breach Response

### 6.1 Notification Obligations by Region

| Region | Authority | Mandatory? | Threshold | Notification Window | Consumer Notification |
|--------|-----------|-----------|-----------|--------------------|-----------------------|
| **AU** | OAIC (Office of Australian Information Commissioner) | ✅ Yes (NDB scheme) | Likely to result in serious harm | **30 days** (expedited: as soon as practicable for serious breaches) | Required if serious harm likely |
| **US** | State attorneys general | ✅ Yes (varies by state) | PII of state residents compromised | **30-90 days** (varies: CA=72hrs for health data, NY=expeditious, FL=30 days) | Required in all states with breach laws (all 50) |
| **NZ** | Office of Privacy Commissioner (OPC) | ✅ Yes (since Dec 2020) | Notifiable privacy breach (serious harm likely) | **As soon as practicable** (no fixed deadline, but 72 hours expected) | Required if serious harm likely |
| **UK** | ICO (Information Commissioner's Office) | ✅ Yes (UK GDPR Art. 33) | Risk to rights and freedoms of individuals | **72 hours** from awareness | Required if high risk (Art. 34) |

### 6.2 Breach Assessment Checklist

```
□ What personal data was involved?
  □ L4 (Restricted): Government IDs, TFNs/SSNs, bank accounts
  □ L3 (Confidential): Income, valuations, credit scores
  □ L2 (Internal): Email, phone, address
  □ L1 (Public): No notification required

□ How many individuals affected?
  □ 1-10
  □ 11-100
  □ 101-1,000
  □ 1,000+

□ Which regions are affected?
  □ AU → OAIC notification
  □ US → State AG notifications (each affected state)
  □ NZ → OPC notification
  □ UK → ICO notification (72-hour clock starts NOW)

□ Was data actually exfiltrated or just accessed?
  □ Confirmed exfiltration → P1, all notifications mandatory
  □ Access only (no evidence of exfiltration) → Assess on case-by-case
  □ Encryption was in place → May reduce "serious harm" assessment

□ Can affected individuals be identified?
  □ Yes → Direct notification
  □ No → Public notification (website, media)
```

### 6.3 Multi-Region Breach Coordination

If a breach affects consumers in multiple regions, the **shortest notification window governs**:

```
UK: 72 hours (ICO)     ← THIS IS THE DEADLINE
NZ: ~72 hours (OPC)
AU: 30 days (OAIC) but "as soon as practicable" for serious
US: Varies (CA can be 72 hours for medical data)

RULE: Start ALL notifications within 72 hours.
File UK/NZ first (shortest deadline).
File AU/US in parallel.
Consumer notifications: simultaneous across all regions.
```

### 6.4 Breach Register

Maintain a formal breach register (mandatory under UK GDPR Art. 33(5)):

| Field | Description |
|-------|-------------|
| Incident ID | Unique reference |
| Date detected | When the breach was discovered |
| Date occurred | When the breach actually happened (if different) |
| Description | What happened |
| Data categories | Types of personal data involved |
| Individuals affected | Count and regions |
| Likely consequences | Assessment of harm |
| Measures taken | Containment, notification, remediation |
| Notified regulators | Which regulators, when, reference numbers |
| Notified consumers | When, how, content of notification |

---

## 7. Financial Calculation Error Response

### 7.1 Why This Matters

EPM calculation errors are uniquely dangerous — an incorrect income figure, NNEG miscalculation, or portfolio allocation error directly affects consumer finances. A calculation error may constitute:

- **Misleading conduct** (AU: ASIC Act s12DA, NZ: FTA s9, UK: FCA PRIN 7, US: CFPB UDAAP)
- **Breach of contract** (if consumer received incorrect income amount)
- **Regulatory breach** (incorrect disclosures)

### 7.2 Detection

| Source | What It Catches |
|--------|----------------|
| Automated reconciliation | Portfolio value vs expected value (daily check) |
| Income payment audit | Actual payment vs calculated payment (monthly) |
| Consumer complaint | "My income changed unexpectedly" |
| Quarterly model review | Back-test calculation engine against Pavel spreadsheet |
| Annual audit | External auditor verifies calculation accuracy |

### 7.3 Response Procedure

```
STEP 1: IDENTIFY SCOPE
├── Which calculation is wrong? (income, NNEG, portfolio allocation, quote)
├── How many consumers affected?
├── How long has the error existed?
├── Direction of error: overpaid or underpaid?
└── Financial impact per consumer and total

STEP 2: STOP THE BLEEDING
├── If ongoing: Correct the calculation engine immediately
├── If affecting payments: Hold next payment cycle pending review
├── Deploy fix to production
└── Verify fix with test cases

STEP 3: CONSUMER IMPACT ASSESSMENT
├── Overpaid consumers: DO NOT claw back without legal advice
│   └── Lender may absorb loss if amount is small
│   └── If material: legal counsel on recovery options
├── Underpaid consumers: Issue catch-up payment immediately
│   └── Include interest/compensation for inconvenience
└── Document every affected consumer and amount

STEP 4: NOTIFICATION
├── All affected consumers notified in writing
├── Apology + explanation + what was done to fix
├── If underpaid: payment enclosed
├── If overpaid: "No action required from you" (pending legal review)
├── Regulator notification if material (>$10K total or >50 consumers)
└── Compliance team assesses reportable breach

STEP 5: ROOT CAUSE & PREVENTION
├── How did the error enter the system?
├── Why wasn't it caught by tests?
├── Add specific test case for this scenario
├── Add reconciliation check to prevent recurrence
└── Post-incident review within 5 business days
```

### 7.4 Materiality Thresholds

| Impact | Classification | Response |
|--------|---------------|----------|
| <$100 per consumer, <10 consumers | Minor | Fix, notify, no regulator report |
| $100-$1,000 per consumer, 10-50 consumers | Moderate | Fix, notify, compliance review, consider regulator report |
| >$1,000 per consumer OR >50 consumers | Material | Fix, notify, regulator report mandatory, external audit |
| Any amount if systemic (affects calculation engine logic) | Material | Full response regardless of per-consumer amount |

---

## 8. Platform Outage Response

### 8.1 Severity by Duration

| Duration | Severity | Response |
|----------|----------|----------|
| < 5 minutes | P4 | Log and monitor. No notification. |
| 5-30 minutes | P3 | Investigate. Status page updated. |
| 30 min - 4 hours | P2 | IRT engaged. Consumer notification if affecting payments/applications. |
| > 4 hours | P1 | Full incident response. Regulator notification if affecting regulated activities. |

### 8.2 Platform Components & Impact

| Component | Consumer Impact | Business Impact |
|-----------|----------------|----------------|
| **Web application (Fly.io)** | Cannot access portal, apply, or view statements | Applications stalled |
| **Database (Neon.com)** | Complete service failure | All operations halted |
| **Payment processing** | Income payments delayed | Consumer hardship risk |
| **Email system** | Notifications delayed | Application workflow delayed |
| **Chat agents** | AI assistance unavailable | Increased support load |
| **Document generation** | Contracts/statements unavailable | Application processing delayed |

### 8.3 Payment Delay Protocol

If a platform outage delays consumer income payments:

```
1. Identify all affected consumers and payment amounts
2. Process payments manually via backup channel (bank transfer)
3. Notify consumers: "Your payment may be delayed by [X] days"
4. Ensure payments arrive within 3 business days of scheduled date
5. If delay >3 days: Add compensation ($50 or equivalent)
6. If delay >7 days: Regulator notification + formal complaint process available
```

---

## 9. Regulatory Incident Response

### 9.1 Types of Regulatory Incidents

| Incident | Trigger | Response |
|----------|---------|----------|
| **Regulator inquiry** | Letter/email from ASIC/CFPB/FMA/FCA | Acknowledge within 24 hours. Legal counsel immediately. |
| **Consumer complaint (escalated)** | Complaint to AFCA/FOS/FDRS/CFPB | Respond within EDR scheme timeframes |
| **Licence condition breach** | Internal discovery or regulator finding | Self-report to regulator. Remediate immediately. |
| **Reportable situation (AU)** | Significant breach of ACL/AFSL conditions | Report to ASIC within 30 days (s912D Corporations Act) |
| **Section 166 review (UK)** | FCA orders independent review | Appoint skilled person, cooperate fully |

### 9.2 Regulator Communication Rules

```
DO:
✅ Respond promptly (within stated timeframes)
✅ Be honest and transparent
✅ Cooperate fully with information requests
✅ Engage legal counsel before responding to enforcement
✅ Keep detailed records of all regulator correspondence
✅ Self-report breaches (it's better they hear from you)

DO NOT:
❌ Ignore or delay regulator correspondence
❌ Provide incomplete or misleading information
❌ Destroy or alter documents after a regulator inquiry
❌ Contact affected consumers without coordinating with regulator
❌ Make public statements about an investigation without legal advice
```

---

## 10. Communication Templates

### 10.1 Consumer Data Breach Notification

```
Subject: Important Security Notice — FutureProof

Dear [Consumer Name],

We are writing to inform you of a data security incident that may 
have affected your personal information.

WHAT HAPPENED
On [date], we identified [brief, plain-language description of what 
occurred]. We immediately took steps to contain the incident and 
engaged cybersecurity experts to investigate.

WHAT INFORMATION WAS INVOLVED
Based on our investigation, the following information may have been 
affected: [list specific data types — be precise, not vague].

WHAT WE ARE DOING
• We have contained the incident and secured our systems
• We have notified the relevant authorities ([OAIC/ICO/OPC/State AG])
• We are offering [credit monitoring / identity protection] at no cost
• We have [specific security improvements made]

WHAT YOU CAN DO
• Monitor your financial accounts for unusual activity
• [Region-specific: Contact IDCARE (AU/NZ) / Action Fraud (UK) / FTC (US)]
• Change your FutureProof password at [link]
• Contact us with any concerns: [dedicated incident support line]

We sincerely apologise for this incident. The security of your 
information is our highest priority.

[Name]
[Title]
FutureProof
[Dedicated incident phone number]
[Dedicated incident email]
```

### 10.2 Financial Calculation Error Notification

```
Subject: Correction to Your FutureProof Income Payment

Dear [Consumer Name],

We have identified an error in the calculation of your EPM income 
payment for [period].

WHAT HAPPENED
Due to [brief explanation], your income was [underpaid/overpaid] 
by [amount] for [number] payment(s).

WHAT WE ARE DOING

[If underpaid:]
We have corrected the error and a catch-up payment of [amount] 
has been processed to your nominated account. You should receive 
this within 3 business days. Your future payments have been 
corrected to [new amount] per month.

[If overpaid:]
We have corrected the calculation for future payments. You do not 
need to take any action regarding the overpayment at this time.

We apologise for this error and have implemented additional checks 
to prevent it from recurring.

If you have any questions, please contact us at [phone/email].

[Name]
[Title]
```

### 10.3 Platform Outage Notification

```
Subject: FutureProof Service Update

Dear [Consumer Name],

We are experiencing a temporary service disruption that may affect 
your ability to access the FutureProof portal.

Your EPM income payments are not affected and will continue as 
scheduled.

[If payments ARE affected:]
Your scheduled income payment for [date] may be delayed by up to 
[X] business days. We are working to process all payments as 
quickly as possible and will notify you when your payment has 
been sent.

We apologise for the inconvenience and expect to restore full 
service by [estimated time].

For urgent matters, please contact us at [phone].
```

---

## 11. Post-Incident Review

### 11.1 Timeline

| Incident Severity | Review Deadline | Participants |
|-------------------|----------------|-------------|
| P1 | Within 5 business days | Full IRT + CEO |
| P2 | Within 10 business days | IRT |
| P3 | Next team retrospective | Engineering team |
| P4 | Backlog item | Assigned engineer |

### 11.2 Review Template

```
INCIDENT POST-MORTEM

Incident ID:        [INC-YYYY-NNN]
Date:               [date]
Duration:           [start to resolution]
Severity:           [P1/P2/P3/P4]
Incident Commander: [name]

SUMMARY
One paragraph: what happened, who was affected, what was the impact.

TIMELINE
[HH:MM] Event
[HH:MM] Event
...

ROOT CAUSE
What was the underlying cause? (Not "the server crashed" but 
"unpatched CVE in dependency X allowed...")

CONTRIBUTING FACTORS
What made it worse or delayed resolution?

WHAT WENT WELL
What worked in our response?

WHAT COULD BE IMPROVED
What would we do differently?

ACTION ITEMS
| # | Action | Owner | Deadline | Status |
|---|--------|-------|----------|--------|
| 1 |        |       |          |        |

LESSONS LEARNED
Key takeaways for the team.
```

### 11.3 Action Item Tracking

All post-incident action items tracked in the project management system with:
- Clear owner
- Deadline (P1 actions: within 2 weeks; P2: within 1 month)
- Verification that the fix actually prevents recurrence
- Review in next incident drill

---

## 12. Testing & Drills

### 12.1 Drill Schedule

| Drill | Frequency | Scope |
|-------|-----------|-------|
| **Tabletop exercise** | Quarterly | Walk through a scenario verbally — test decision-making |
| **Technical drill** | Semi-annually | Simulate an incident (e.g., rotate credentials, test failover) |
| **Full simulation** | Annually | End-to-end drill including regulator notification (mock) |
| **Backup restoration** | Quarterly | Verify Neon.com point-in-time recovery works |
| **Communication test** | Semi-annually | Test notification delivery (email, SMS) to sample consumers |

### 12.2 Tabletop Scenarios

| # | Scenario | Focus Area |
|---|----------|-----------|
| 1 | Admin account compromised via credential stuffing | Authentication, containment, data scoping |
| 2 | Ransomware on Fly.io container | Infrastructure, backup restoration, comms |
| 3 | Calculation engine produces incorrect income for 200 consumers for 3 months | Financial remediation, regulator notification, consumer trust |
| 4 | Neon.com suffers data breach exposing FutureProof database | Third-party breach response, multi-region notification |
| 5 | FCA sends Section 166 notice requesting independent review | Regulatory response, legal coordination, board notification |
| 6 | Consumer dies, beneficiaries allege EPM was mis-sold | Complaints handling, legal, ERC/AFCA process |

---

## 13. Implementation Checklist

### Immediate (Before Launch)

- [ ] Incident Response Plan reviewed and approved by board
- [ ] IRT roles assigned with named individuals and contact details
- [ ] External contacts established (legal counsel in each region, forensic firm, cyber insurer)
- [ ] Incident reporting channel created (#incidents or equivalent)
- [ ] Breach register template created (spreadsheet or dedicated tool)
- [ ] Communication templates finalised and pre-approved by legal
- [ ] Backup restoration verified (Neon.com PITR test)
- [ ] Monitoring and alerting configured (Rack::Attack, exceptions, PaperTrail)

### Within 90 Days of Launch

- [ ] First tabletop exercise conducted
- [ ] All team members trained on incident reporting process
- [ ] Regulator notification templates pre-completed (just add specifics)
- [ ] Cyber insurance in place with incident response coverage
- [ ] Consumer notification delivery tested (email deliverability verified)
- [ ] Payment delay backup process tested (manual bank transfer)

### Ongoing

- [ ] Quarterly tabletop exercises
- [ ] Semi-annual technical drills
- [ ] Annual full simulation
- [ ] Quarterly backup restoration tests
- [ ] Annual plan review and update
- [ ] Post-incident reviews completed within deadlines
- [ ] Action items tracked and closed

---

*This plan must be tested before it's needed. An untested incident response plan is just documentation. Schedule the first tabletop exercise within 30 days of finalising this document.*
