# FutureProof EPM Income from Property Equity — Technical Architecture

> ## ⚠️ SUPERSEDED — 2026-06-04
> **This document is retired. Do not cite it.** It described systems in the present tense that were never built (Kafka, a full AWS estate, ISO 27001 / SOC 2 certification), lists Tailwind (which our own rules ban), uses a four-agent model that no longer matches us, and predates the joint-venture / platform direction entirely.
>
> **Current tech strategy:** `docs/pdfs/FutureProof_Platform_and_AI_Strategy_Jun2026.pdf` (generator: `generate_platform_ai_strategy.py`).
>
> Kept below for history only.

**Version 5.0** | Commercial in Confidence

---

## 1. EPM Overview

FutureProof transforms home equity into monthly income. We partner with homeowners, borrowers, and capital providers to build a simple system: invest equity, distribute returns, manage risk.

**The Four Players**

| Role | What They Do | Their Stake |
|------|------------|-----------|
| **Customer** | Partners their equity for monthly income | Receives monthly distributions |
| **Investment Partner** | Manages the invested capital | Generates ~10% p.a. returns over 30 years |
| **Lender** | Originates loans, manages customer relationships | Earns margin (0.75%–2%) on distributions |
| **Wholesale Funder** | Supplies capital to lenders | Earns wholesale margin (0.2%–3.6%) |

**How Monthly Income Works**

1. Investment Partner's fund earns returns.
2. System calculates monthly payout (based on equity %, fund performance, holiday status).
3. Customer gets their share.
4. Lender deducts margin. Wholesale Funder takes their cut. FutureProof takes 0.25%.

Simple. Repeatable. Auditable.

---

## 2. Customer Journey

### **PHASE 1: Origination (Weeks 1–4)**

Customer applies → Deal Agent verifies identity (KYC/AML), values property, assigns risk tier → e-signs documents → Lender & funder approve → Capital transferred → Account live.

### **PHASE 2: Ongoing (Months 1–30+)**

Every month:
- Distribution Agent calculates fund returns.
- Customer gets paid on fixed date.
- Investment Agent watches fund performance. If it drops 10%, interest holiday flag triggers automatically.
- Monthly statement shows distribution, margins, fund health, holiday status.
- Customer can request early exit anytime.

### **PHASE 3: Exit (Early or Maturity)**

Customer requests exit → Deal Agent calculates final amount (fund value minus fees) → Lender approves → Distribution Agent processes final payment → Loan closed → All records archived (7 years).

---

## 3. Stakeholder Views & Fraud Monitoring

**What each player sees + what we watch for:**

| Stakeholder | Dashboard Shows | Red Flags |
|-------------|-----------------|-----------|
| **Customer** | Monthly distributions, cumulative income, fund chart, holiday status | Multiple withdrawals same day, logins from new locations, rapid device switches |
| **Lender** | Distribution schedule, margin received, portfolio health, customer status | Holiday requests that look systematic, unusual pattern shifts, distributions delayed |
| **Investment Partner** | Fund performance, ETF data, rebalancing schedule, cost basis | Performance that doesn't match ETFs, holdings mismatches, rebalancing delays |
| **Wholesale Funder** | Portfolio yield, default rates, margin collections, lender tier performance | Yield compression, risk concentration, lender financial strain |

---

## 4. System Architecture

### **Core Platform**

**Rails 8.1 + Hotwire + Stimulus**

Single monolithic Rails app. Live dashboards update via Hotwire (Turbo). Lightweight JavaScript via Stimulus. No WebSocket complexity.

**PostgreSQL**

Source of truth: customers, transactions, audit trails. JSON columns for flexible fund metadata. Materialized views for performance aggregation. Database triggers enforce compliance rules automatically. Partitioned by customer ID for scale.

**Kafka Event Queue**

Agents publish events. Others subscribe. Deal created → Distribution Agent and Compliance Agent react. Distribution executed → Lender gets paid. Holiday triggered → Distribution Agent adjusts calculations. Exactly-once processing with dead-letter queues for failures.

**Redis Cache**

Sessions, rate limiting, staged calculations, fraud detection (Bloom filters), frequently accessed data.

**S3 Storage**

Documents, statements, audit logs. Encrypted at rest. Lifecycle: archive after 90 days, delete after 7 years (compliance).

### **Core Services**

**Distribution Engine** (Solid Queue job)

Runs 1st–5th of month via Rails native background job scheduler. Pulls fund returns, calculates per-customer distributions, stages in Redis, executes ACH/bank transfers via Stripe, publishes events. Retry logic with exponential backoff.

**Compliance Engine**

Real-time validation against 20+ regulatory rules. Writes immutable audit trail. Database triggers for Change Data Capture.

**Fraud Detection**

ML pipeline scores every transaction:
- Known patterns (Bloom filter)?
- Behavioral anomalies (isolation forest)?
- Rule violations (impossible geography, velocity)?

**Interest Holiday Logic**

Monthly job monitors fund performance vs. entry/exit thresholds. Triggers automatically at 90% drop. Releases automatically at 145.8% recovery.

**Notification Service**

Email (SendGrid), SMS (Twilio), in-app. Stores pending notifications, retries with backoff, confirms delivery.

**Document Engine**

Server-rendered templates (ERB) + Prawn gem. Generates loan docs, agreements, statements, disclosures. All digitally signed, archived to S3 with immutable version IDs.

---

## 5. Four-Agent Architecture

**Deal Agent**
- Processes applications
- Runs KYC/AML
- Generates documents
- Triggered by: New application

**Distribution Agent**
- Calculates monthly returns
- Deducts margins
- Executes payments
- Generates statements
- Triggered by: Monthly cutoff date

**Investment Agent**
- Monitors fund performance
- Calculates rolling metrics
- Decides holiday eligibility
- Triggers/releases holidays
- Triggered by: Monthly performance updates

**Compliance Agent**
- Real-time fraud detection
- Regulatory rule enforcement
- Generates audit reports
- Flags suspicious activity
- Triggered by: Transaction submission

### **Agent Communication**

All agents publish to Kafka. Others subscribe. Decoupled. Asynchronous. Scalable.

**Example flow:**
1. Deal Agent publishes `deal.created`.
2. Distribution Agent and Compliance Agent subscribe, wake up.
3. Distribution Agent publishes `distribution.monthly`.
4. Lender receives payment.
5. Investment Agent publishes `holiday.triggered`.
6. Distribution Agent adjusts calculations.
7. Compliance Agent publishes `fraud.detected`.
8. System escalates to lender for review.

---

## 6. Agent Technology: Claude & Kimi

### **Why Agents?**

Human agents would slow everything down. AI agents process in seconds. Four autonomous agents handle all workflows 24/7.

### **How We Do It: Claude & Kimi**

**Claude** handles Deal Agent workflows (KYC/AML logic, document generation decisions, eligibility assessment).

**Kimi** handles Distribution Agent workflows (complex calculation logic, margin deduction rules, payment reconciliation).

Both are integrated via OpenAI-compatible API endpoints that sit inside our private network. **Critical: No customer data ever leaves the system.** All processing happens on-premise. Customer names, account balances, fund performance data, transaction histories—all stay inside our infrastructure. Claude and Kimi receive anonymized, hashed transaction patterns and rule-based queries. They respond with recommendations that Distribution Agent executes, but they never touch raw customer data.

### **Implementation Details**

Rails service classes (e.g., `DealAgent::OnboardingService`). Each agent runs as Solid Queue background job (4 workers per pod). Horizontally scalable.

**Event Subscription (Kafka)**

Each agent subscribes to relevant Kafka topics using ruby-kafka gem. Consumer groups handle partitioning automatically. Dead-letter queues capture failures.

**Idempotency & Retry**

Agents implement idempotent handlers. Database unique constraints + transactional locks prevent double-processing. Failed tasks auto-retry (1s → 2s → 4s → 8s → 16s), then escalate.

**Distributed Tracing**

Every event gets a trace ID. As it flows through agents, each writes logs tagged with that ID. Search CloudWatch by trace ID, see the entire customer journey end-to-end.

**State Management**

- Deal workflow: `draft → submitted → kyc_pending → approved → funded → active`
- Holiday logic: `normal → holiday_pending → holiday_active → recovery_in_progress → normal`

**Call Center (Twilio Flex)**

When manual escalation needed, ops team gets a ticket in Twilio Flex. Agent clicks customer, Flex dials via Twilio, logs call recording. If customer calls in, IVR routes to available agent. Agent sees customer profile, recent interactions, account balance.

**Sync vs. Async**

Async by default (publish event, job queued). Sync only for:
- Stripe payment (5-sec timeout)
- IDology KYC (10-sec timeout)
- Property valuation (15-sec timeout)

All wrapped in circuit breaker pattern.

---

## 7. Interest Holiday Mechanism

**Why holidays exist:** Market downturns shouldn't force customers to pay lenders. We pause interest accrual automatically.

**How it works:**

| Threshold | What Happens |
|-----------|-------------|
| **90% drop** | Holiday automatically triggers. Customer still gets monthly distributions. Lender gets alert. Statements show holiday status. |
| **145.8% recovery** | Holiday automatically lifts. Everything returns to normal. |

**Example timeline:**

- **Months 1–10:** Normal operations. Fund does well. Customer gets paid.
- **Month 11:** Market drop. Fund hits 88% (below 90% threshold). Holiday flag activates.
- **Months 12–18:** Holiday active. Customer still paid. Statements note holiday.
- **Month 19:** Fund recovers to 145.8%. Holiday automatically released.

---

## 8. Compliance & Fraud Detection

**What we check. How we catch bad actors.**

### **Compliance Rules**

| Rule | What We Verify | What Happens If It Fails |
|------|---|---|
| **KYC/AML** | Customer identity confirmed before onboarding | Application rejected |
| **Responsible Lending** | Fund amount appropriate for risk tier | Margin increased; tier adjusted |
| **Distribution Accuracy** | Monthly calcs match fund returns | Distribution held pending audit |
| **Fund Performance** | Daily returns reconcile with actual | Discrepancy flagged |
| **Holiday Logic** | Thresholds applied correctly | Manually reviewed |
| **Data Privacy** | PII access logged; encrypted | Unauthorized access alert |

### **Real-Time Fraud Monitoring**

**Account anomalies:**
- Logins from unusual locations
- Rapid device changes
- After-hours patterns

**Transaction anomalies:**
- Multiple withdrawals same day
- Requests after distribution
- Systematic holiday manipulation

**Data inconsistencies:**
- Reported vs. actual fund value mismatch
- Distribution calculation errors

**Regulatory violations:**
- KYC/AML failures
- Undisclosed conflicts
- Unauthorized transfers

### **Audit & Reporting**

**Audit Trail:** Every transaction, margin payment, holiday trigger recorded with timestamp, user ID, changes. Retained 7 years minimum.

**Monthly Reporting:** Lenders and wholesale funders get automated reports on portfolio health, margin collections, default scenarios.

**Annual Certification:** External auditor reviews all regulatory requirements (Australia, UK, US).

---

## 9. Multi-Jurisdiction Financial Regulation

FutureProof operates across four jurisdictions. Each has national financial regulation, state/territory-level requirements, and distinct licensing obligations. The platform enforces jurisdiction-specific rules automatically via the Compliance Agent and region configuration.

### **Australia**

**National Regulators & Legislation**

| Regulator / Act | Scope | FutureProof Obligation |
|-----------------|-------|----------------------|
| **ASIC** (Australian Securities & Investments Commission) | Consumer credit, financial services, market conduct | Australian Financial Services Licence (AFSL); Australian Credit Licence (ACL); responsible lending obligations |
| **APRA** (Australian Prudential Regulation Authority) | Prudential oversight of lenders and funders | Capital adequacy reporting for wholesale funders; liquidity coverage ratios |
| **National Consumer Credit Protection Act 2009** (NCCP) | All consumer credit products | Responsible lending assessments; hardship obligations; mandatory disclosure; credit guides |
| **AML/CTF Act 2006** | Anti-money laundering, counter-terrorism financing | Customer identification (KYC); ongoing due diligence; suspicious matter reports (SMRs) to AUSTRAC; transaction monitoring |
| **Corporations Act 2001** | Financial product disclosure, managed investment schemes | Product Disclosure Statements (PDS) if EPM classified as financial product; ongoing disclosure obligations |
| **Design and Distribution Obligations (DDO)** | Product governance | Target Market Determination (TMD) for EPM product; distribution conditions; review triggers |

**State & Territory Requirements**

| State/Territory | Additional Requirement |
|----------------|----------------------|
| **NSW** | Fair Trading Act 1987; Property and Stock Agents Act 2002 (if property valuation involved) |
| **VIC** | Australian Consumer Law and Fair Trading Act 2012; Estate Agents Act 1980 |
| **QLD** | Fair Trading Act 1989; Property Occupations Act 2014 |
| **WA** | Fair Trading Act 2010; Real Estate and Business Agents Act 1978 |
| **SA** | Fair Trading Act 1987; Land Agents Act 1994 |
| **TAS** | Australian Consumer Law (Tasmania) Act 2010 |
| **ACT** | Fair Trading (Australian Consumer Law) Act 1992 |
| **NT** | Consumer Affairs and Fair Trading Act 1990 |

### **United Kingdom**

**National Regulators & Legislation**

| Regulator / Act | Scope | FutureProof Obligation |
|-----------------|-------|----------------------|
| **FCA** (Financial Conduct Authority) | Consumer protection, market integrity, competition | FCA authorisation; compliance with Consumer Duty (2023); fair value assessments; vulnerability policies |
| **PRA** (Prudential Regulation Authority) | Prudential soundness of financial firms | Capital requirements for lenders; stress testing; recovery and resolution plans |
| **Consumer Credit Act 1974** | Regulated credit agreements | Pre-contractual information; right of withdrawal (14 days); unfair relationship provisions |
| **Financial Services and Markets Act 2000** (FSMA) | Overarching financial regulation | Permissions for regulated activities; approved persons regime; financial promotions |
| **Money Laundering Regulations 2017** (MLR) | AML/KYC | Customer due diligence; enhanced due diligence for high-risk; suspicious activity reports (SARs) to NCA |
| **Senior Managers & Certification Regime (SM&CR)** | Individual accountability | Senior management functions defined; annual certification; conduct rules for all staff |
| **Mortgage Credit Directive Order 2015** | EU-derived mortgage regulation (retained) | Affordability assessments; ESIS (European Standardised Information Sheet); binding offers |

**Regional Considerations**

| Region | Additional Requirement |
|--------|----------------------|
| **England & Wales** | Law of Property Act 1925; Land Registration Act 2002 |
| **Scotland** | Separate property law (feudal heritage); Registration of Title (Scotland) Act; separate Land Register |
| **Northern Ireland** | Property (NI) Order 1978; Land Registration Act (NI) 1970; separate registry |

### **United States**

**Federal Regulators & Legislation**

| Regulator / Act | Scope | FutureProof Obligation |
|-----------------|-------|----------------------|
| **SEC** (Securities and Exchange Commission) | Securities regulation | Registration if EPM constitutes a security; Regulation D exemptions for private placements to wholesale funders |
| **CFPB** (Consumer Financial Protection Bureau) | Consumer financial products | TILA disclosures (APR, finance charges); RESPA settlement procedures; ability-to-repay rules |
| **FinCEN** (Financial Crimes Enforcement Network) | AML/BSA compliance | Currency Transaction Reports (CTRs); Suspicious Activity Reports (SARs); Customer Due Diligence (CDD) Rule |
| **OCC** (Office of the Comptroller of the Currency) | National bank oversight | Applicable if lender is nationally chartered; CRA compliance |
| **Truth in Lending Act (TILA)** | Disclosure of credit terms | Loan Estimate within 3 business days; Closing Disclosure 3 days before settlement |
| **Real Estate Settlement Procedures Act (RESPA)** | Settlement services | Good faith estimates; prohibition on kickbacks; escrow account requirements |
| **Equal Credit Opportunity Act (ECOA)** | Anti-discrimination | Adverse action notices; prohibited basis protections; fair lending monitoring |
| **Dodd-Frank Wall Street Reform Act** | Systemic risk, consumer protection | Qualified Mortgage (QM) rules; ability-to-repay; risk retention for securitised products |
| **Bank Secrecy Act (BSA)** | AML compliance | AML program requirement; independent testing; designated compliance officer |

**State-Level Requirements (Key States)**

| State | Licensing & Key Requirements |
|-------|----------------------------|
| **California** | Department of Financial Protection and Innovation (DFPI) licence; California Financing Law (CFL); California Residential Mortgage Lending Act |
| **New York** | NYDFS mortgage banker licence; NY Banking Law Article 12-D; NYDFS cybersecurity regulation (23 NYCRR 500) |
| **Texas** | Department of Savings and Mortgage Lending licence; Texas Finance Code Chapter 156 |
| **Florida** | Office of Financial Regulation mortgage lender licence; Florida Fair Lending Act |
| **Illinois** | IDFPR Residential Mortgage License; Illinois Residential Mortgage License Act |
| **All 50 states** | NMLS (Nationwide Multistate Licensing System) registration; state-specific usury caps; varying foreclosure procedures (judicial vs. non-judicial) |

### **New Zealand**

**National Regulators & Legislation**

| Regulator / Act | Scope | FutureProof Obligation |
|-----------------|-------|----------------------|
| **FMA** (Financial Markets Authority) | Financial markets, services, conduct | Financial service provider registration; fair dealing obligations; licensed market conduct |
| **RBNZ** (Reserve Bank of New Zealand) | Prudential oversight | Prudential requirements for non-bank deposit takers; macro-prudential policy (LVR restrictions) |
| **Credit Contracts and Consumer Finance Act 2003 (CCCFA)** | Consumer credit | Lender responsibility principles; affordability assessments; fee reasonableness; hardship provisions |
| **CCCFA Amendments 2021** | Strengthened responsible lending | Detailed income/expense verification; suitability assessments; borrower-centric affordability |
| **Financial Markets Conduct Act 2013 (FMCA)** | Financial products, fair dealing | Fair dealing (misleading conduct); licensing for financial advice; disclosure obligations |
| **AML/CFT Act 2009** | Anti-money laundering | Customer due diligence; suspicious transaction reports (STRs) to NZ Police FIU; annual AML/CFT risk assessment |
| **Financial Service Providers (Registration and Dispute Resolution) Act 2008** | Provider registration | FSP registration; membership of approved dispute resolution scheme |

**Regional Notes**

New Zealand operates as a unitary state — no state/territory-level financial regulation. All financial regulation is national. However, local government consents may apply to property valuations under the Resource Management Act 1991.

---

## 10. IT Security & Privacy Regulation

Each jurisdiction imposes distinct data protection, privacy, and cybersecurity requirements. FutureProof maintains a unified security architecture that satisfies the strictest standard across all four markets.

### **Cross-Jurisdiction Security Standards**

| Standard | Scope | FutureProof Implementation |
|----------|-------|---------------------------|
| **ISO 27001:2022** | Information security management system | Certified ISMS covering all EPM data processing; annual surveillance audits; Statement of Applicability maintained |
| **SOC 2 Type II** | Trust service criteria (security, availability, confidentiality) | Annual audit by independent CPA firm; continuous control monitoring; report provided to wholesale funders |
| **PCI DSS v4.0** | Payment card data (if applicable) | Stripe handles PCI scope; SAQ-A compliance for redirect-based payments; no card data touches FutureProof servers |
| **OWASP Top 10** | Web application security | Brakeman (static analysis) in CI; annual penetration testing; WAF rules aligned to OWASP categories |

### **Australia — Privacy & Cybersecurity**

| Regulation | Key Requirements | FutureProof Compliance |
|-----------|-----------------|----------------------|
| **Privacy Act 1988 + Australian Privacy Principles (APPs)** | Collection limitation; use/disclosure restrictions; data quality; security safeguards; cross-border disclosure rules | APP-compliant privacy policy; consent management; data minimisation; APP 8 cross-border transfer assessments for any offshore processing |
| **Notifiable Data Breaches (NDB) Scheme** | Mandatory notification to OAIC and affected individuals for eligible data breaches | Incident response plan with 30-day assessment window; automated breach detection; notification templates pre-approved by legal |
| **Consumer Data Right (CDR)** | Open banking data sharing (if banking data accessed) | CDR-compliant APIs if accessing banking data; accreditation as data recipient if required |
| **APRA CPS 234** | Information security for APRA-regulated entities | Applicable to wholesale funders — FutureProof provides CPS 234 compliance evidence as data processor; security capability assessments; third-party assurance |
| **Critical Infrastructure Act 2018 (SOCI)** | Critical infrastructure protection | Risk management program if designated as critical financial infrastructure; mandatory incident reporting within 12 hours for critical incidents |
| **State breach notification** | NSW, VIC, QLD have supplementary notification requirements for government-related data | Monitored; currently N/A but implemented as configurable rules |

### **United Kingdom — Privacy & Cybersecurity**

| Regulation | Key Requirements | FutureProof Compliance |
|-----------|-----------------|----------------------|
| **UK GDPR + Data Protection Act 2018** | Lawful basis for processing; data subject rights (access, erasure, portability); DPO requirement; DPIA for high-risk processing; 72-hour breach notification to ICO | Lawful basis: contract + legitimate interest; automated DSAR (Data Subject Access Request) portal; DPO appointed; DPIA completed for EPM product; breach notification workflow tested quarterly |
| **FCA data requirements** | SYSC 13 (operational risk); FG 16/5 (data security in financial services) | Operational resilience self-assessment; important business services identified; impact tolerances set and tested |
| **NIS Regulations 2018** | Network and information systems security for essential services | Applicable if designated as essential financial service; CAF (Cyber Assessment Framework) self-assessment; incident reporting to lead authority |
| **UK Cyber Essentials Plus** | Baseline cybersecurity certification | Certified annually; vulnerability scans; verified by external assessor |
| **PSD2 / Open Banking** | Strong Customer Authentication (SCA); secure API access | SCA for customer-facing transactions; OAuth 2.0 + FAPI-compliant API security |

### **United States — Privacy & Cybersecurity**

| Regulation | Key Requirements | FutureProof Compliance |
|-----------|-----------------|----------------------|
| **Gramm-Leach-Bliley Act (GLBA)** | Financial privacy; Safeguards Rule; pretexting protection | Privacy notices at onboarding and annually; written information security plan (WISP); vendor management programme |
| **GLBA Safeguards Rule (2023 amendments)** | Designated qualified individual; risk assessment; encryption; MFA; continuous monitoring | Qualified individual designated; annual risk assessment; encryption at rest (AES-256) and in transit (TLS 1.3); MFA enforced for all access; SIEM-based continuous monitoring |
| **NYDFS Cybersecurity Regulation (23 NYCRR 500)** | Comprehensive cybersecurity for financial services in New York | Cybersecurity programme; CISO appointed; 72-hour incident notification to NYDFS; annual penetration testing; 500.17 certification filed annually |
| **CCPA / CPRA (California)** | Consumer privacy rights; right to delete; right to opt-out of sale; data minimisation | California-specific privacy notices; opt-out mechanisms; data inventory maintained; annual CPRA risk assessments |
| **State privacy laws** | Virginia (VCDPA), Colorado (CPA), Connecticut (CTDPA), Utah (UCPA), Texas (TDPSA), Oregon, Montana, etc. | Unified privacy framework that satisfies strictest state standard; configurable consent flows per state; vendor DPA library |
| **SEC Cybersecurity Disclosure Rules (2023)** | Material cybersecurity incident disclosure within 4 business days (8-K); annual risk management disclosure (10-K) | Applicable if SEC-registered; incident materiality assessment process; board-level cybersecurity governance documented |
| **FTC Safeguards Rule** | Information security programme for non-bank financial institutions | Overlaps with GLBA Safeguards; unified compliance programme covers both |

**State Breach Notification**

All 50 US states have breach notification laws with varying requirements:

| Requirement | Range Across States |
|-------------|-------------------|
| **Notification timeline** | 30 days (Florida, Colorado) to 90 days (Connecticut) to "most expedient time" (majority) |
| **Attorney General notification** | Required in ~35 states above certain thresholds (typically 500+ individuals) |
| **Credit monitoring** | Required in some states (e.g., California for SSN; Massachusetts) |
| **Definition of personal information** | Varies — some include biometrics, geolocation, health data, online credentials |

FutureProof implements the strictest standard: 30-day notification, AG notification for all breaches >250 individuals, free credit monitoring offered for any breach involving financial data.

### **New Zealand — Privacy & Cybersecurity**

| Regulation | Key Requirements | FutureProof Compliance |
|-----------|-----------------|----------------------|
| **Privacy Act 2020** | 13 Information Privacy Principles (IPPs); mandatory breach notification; cross-border disclosure rules; compliance notices | IPP-compliant data handling; Privacy Officer appointed; breach notification to OPC within 72 hours for notifiable breaches; cross-border transfer assessments |
| **Notifiable Privacy Breaches** | Mandatory notification to OPC and affected individuals for breaches causing serious harm | Automated breach assessment workflow; pre-approved notification templates; harm assessment matrix aligned to OPC guidance |
| **RBNZ Guidelines on Cybersecurity** | Cyber resilience expectations for financial institutions | Annual cyber resilience self-assessment; incident response tested; third-party risk management |
| **CERT NZ reporting** | Voluntary but expected incident reporting | Integrated into incident response process; CERT NZ contacted for significant incidents |
| **NZ Information Security Manual (NZISM)** | Government security standard (applicable if processing government-adjacent data) | Aligned to NZISM controls where applicable; used as security baseline |

### **Data Residency & Cross-Border Transfers**

| Jurisdiction | Data Residency Rule | FutureProof Approach |
|-------------|--------------------|--------------------|
| **Australia** | APP 8 requires reasonable steps before cross-border disclosure; no hard residency mandate but APRA CPS 234 expects control | Primary data in AU region (ap-southeast-2); cross-border transfers only with APP 8 assessment and contractual safeguards |
| **UK** | UK GDPR adequacy decisions or appropriate safeguards (UK IDTA / UK SCCs) | Primary data in UK region (eu-west-2); transfers to adequate countries only; UK International Data Transfer Agreement for others |
| **US** | No federal data residency law; GLBA requires safeguards regardless of location; some state laws restrict government data | Primary data in US region (us-east-1); state-specific restrictions enforced; GLBA safeguards applied globally |
| **NZ** | Privacy Act 2020 IPP 12 — disclosure to foreign entity only if comparable protections exist | Primary data in AU region (ap-southeast-2) with NZ-specific encryption keys; cross-border assessment completed for AU hosting |

### **Platform Security Architecture**

The following security controls apply across all jurisdictions:

1. **Encryption at rest:** AES-256 for all databases, S3 buckets, and backups.
2. **Encryption in transit:** TLS 1.3 minimum for all connections; certificate pinning for inter-service communication.
3. **Authentication:** MFA enforced for all internal access; OAuth 2.0 + PKCE for customer-facing; hardware security keys for admin.
4. **Authorisation:** Role-based access control (RBAC) with principle of least privilege; attribute-based access control (ABAC) for cross-jurisdiction data.
5. **Key management:** AWS KMS with per-jurisdiction CMKs; automatic key rotation every 365 days; HSM-backed for signing operations.
6. **Logging & audit:** All access logged with user ID, IP, timestamp, action; logs immutable (append-only); retained per jurisdiction requirements (7 years AU/UK/NZ, varies by state in US).
7. **Penetration testing:** Annual external pen test; quarterly vulnerability scans; bug bounty programme.
8. **Incident response:** Documented IR plan; tested quarterly; jurisdiction-specific notification timelines enforced; war room procedures for critical incidents.
9. **Vendor management:** All third-party vendors assessed against SOC 2 or ISO 27001; DPAs in place; annual reassessment.
10. **Business continuity:** RPO < 1 hour; RTO < 4 hours; multi-AZ deployment; tested failover twice annually.

---

## 11. Technology Stack

**Backend**
- Rails 8.1 (Ruby 3.4.8)
- Solid Queue (native Rails background jobs, 4 workers)
- ruby-kafka (event streaming)
- Puma (web server, 3 threads, auto-scaling)

**Data**
- PostgreSQL 16 (primary + read replica)
- Redis 7 (cache + session store)
- Kafka 3.6 (event log, 3 replicas)
- PgBouncer (connection pooling)

**Agents & Workflow**
- Solid Queue (async execution)
- Kafka (pub/sub, 4 topic streams)
- OpenTelemetry (distributed tracing)
- Dead-letter queues (failure handling)
- State machines (holiday logic, deal workflow)

**Communication**
- SendGrid (email)
- Twilio (SMS + voice)
- Twilio Flex (call center)
- WebRTC (video calls)
- DocuSign (e-signature)

**Frontend**
- Hotwire (Turbo Streams + Drive)
- Stimulus JS (lightweight controllers)
- Tailwind CSS (styling)
- ERB templates (server-rendered)
- Chart.js (performance charts)

**Infrastructure**
- AWS S3 (documents, versioned)
- AWS CloudFront (CDN)
- S3 Glacier (archive)
- Fly.io (deployment)
- GitHub Actions (CI/CD)
- Docker (containers)
- Terraform (IaC)

**Monitoring**
- Sentry (error tracking)
- CloudWatch (logs)
- Grafana (dashboards)
- PagerDuty (escalation)
- HTTPS/TLS, WAF, CSP headers

---

## 12. Database Schema

**Core tables:**

| Table | Purpose | Key Fields |
|-------|---------|-----------|
| `customers` | Homeowners | id, email, phone, kyc_status, aml_status, risk_tier |
| `properties` | Residential with equity | id, customer_id, address, property_value, equity_percentage, loan_amount |
| `accounts` | Customer investment accounts | id, customer_id, property_id, starting_balance, current_balance, holiday_flagged |
| `fund_performance` | Monthly metrics (materialized view) | account_id, month, starting_value, ending_value, return_pct, rolling_12m_return |
| `distributions` | Monthly payouts (immutable) | id, account_id, fund_return_amount, lender_margin, customer_payout, executed_at |
| `payments` | ACH/bank transfers (immutable) | id, distribution_id, amount, bank_account_id, status, stripe_charge_id |
| `audit_log` | Append-only event log | id, entity_type, action, changes_json, user_id, timestamp, trace_id |
| `fraud_alerts` | Detected patterns | id, customer_id, alert_type, fraud_score, status, reviewed_by |
| `lenders` | Loan originators | id, name, tier, max_funding_line, current_balance, margin_rate |
| `wholesale_funders` | Capital providers | id, name, funding_capacity, current_deployed, margin_rate |

**Design patterns:**

- **Immutable logs:** `distributions`, `payments`, `audit_log` have no UPDATE/DELETE. All changes are INSERT-only with timestamps.
- **Soft deletes:** `customers`, `accounts` include `deleted_at`. Preserves history; queries filter `WHERE deleted_at IS NULL`.
- **JSON columns:** `audit_log.changes_json` stores before/after. `fraud_alerts.details_json` stores model output. `accounts.metadata_json` stores region-specific terms.
- **Materialized views:** `fund_performance` refreshed nightly. Improves dashboard load times.
- **Partitioning:** `distributions`, `payments` partitioned by `created_at` (monthly partitions). Old partitions move to cold storage.

---

## 13. Deployment & Quality Assurance

**Testing**

- **Unit tests:** Core logic (distributions, holiday logic, fraud rules).
- **Integration tests:** Agent workflows, end-to-end customer journeys, payments.
- **Performance tests:** Batch processing at scale (1000s of customers), query optimization.
- **Security tests:** Auth, authorization, data access, PII encryption.
- **Manual tests:** Customer portal UX, lender reporting, admin workflows.

**Continuous Deployment**

GitHub Actions runs tests on every PR. RSpec (200+ specs), Rubocop (linting), Brakeman (security), database migrations validated. Tests + code review approval required before merge.

Staging environment deployed automatically from main branch using Fly.io (same infra as production). Runs against production-replica DB (encrypted, daily sanitized PII). Manual smoke tests.

Production: Blue-green deployment on Fly.io. Traffic shifted 10% → 50% → 100% over 10 minutes (canary rollout). Health checks verify Rails boot, database, Kafka, latency. Automatic rollback if health checks fail within 5 minutes.

**Monitoring & Alerting**

- **Sentry:** Real-time errors. Critical errors trigger PagerDuty within 2 minutes.
- **CloudWatch:** Structured JSON logging (trace_id, user_id, duration_ms, queries, API calls). 90 days hot, then S3 archive.
- **Grafana:** System health (CPU, memory, disk), app metrics (requests/sec, error rate, p95 latency), business metrics (distributions, revenue), agent health (lag, dead-letter size), database health (pool, replication lag).
- **Alerts:** error rate >1%, distribution latency >60s, Kafka lag >1000 messages.

---

**Commercial in Confidence**

© 2026 FutureProof Financial Group Limited. All rights reserved.
