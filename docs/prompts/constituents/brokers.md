# Constituent: Brokers (distribution channel)

Inherit: `../master.md`. A first-class actor: brokers introduce customers to lenders. In Australia brokers originate the majority of mortgages, so if AU is first this is close to the centre of go-to-market — but **stage it**: model attribution now, build the channel when distribution needs it.

---

## Domain model
```
# Phase 1 (now — thin):
Application.broker_id   (TenantRecord, nullable)   # attribution only

# Phase 3 (when the channel is live):
Broker             (central or tenant — decide by whether a broker serves multiple lenders)
  id, firm_name, individual_name, accreditation_ref, status (pending|active|suspended), country
BrokerReferral     (tenant)   broker_id, application_id, referred_at, source
BrokerCommission   (tenant)   broker_id, mortgage_ref, basis, amount, status (accrued|paid)
```
**Scoping decision to make when building:** a broker who works across several lenders argues for a central `Broker` registry with per-tenant `BrokerReferral`/`Commission`; a broker tied to one lender can be fully tenant-scoped. Default to central registry + tenant referrals (matches the real market) unless told otherwise.

## Interfaces (`Brokers` facade — Phase 3)
```
Brokers.attribute(application, broker)      -> Result          # Phase 1: just set broker_id
Brokers.start_on_behalf(broker, client)     -> Result(Application)   # broker portal
Brokers.accredit(broker, ref)               -> Result
Brokers.performance(broker, window:)        -> Stats { referrals, approval_rate, commission }
```

## Rules & invariants
- A broker is an **intermediary, not the end customer** — but the **advice wall still protects the end customer**: a broker-driven application doesn't let an agent cross into personal advice to the customer.
- Commission never affects pricing or the customer's terms (priced solely by the product brain).
- Broker actions are still tenant-scoped (a broker acting for lender A can't see lender B).

## Business rules
- **Accreditation:** a broker must be **active** and in a **valid jurisdiction** (AU/US/NZ/UK) to operate (`Broker`). No automated licence check today — manual admin; confirm whether to add verification.
- **Commission:** `loan_amount × commission_percentage`, configured **per broker + lender** (`BrokerCommissionRate`, `BrokerCommissionCalculator`).
- **Payment trigger** (configurable): `on_approval` | `on_funding` | `on_first_payment`.
- **Status workflow:** pending → earned → paid; **one commission per application** (unique) (`BrokerCommission`).
- Commission **never** affects the customer's pricing or terms — priced solely by the product brain.
- **Clawback** on a mortgage that later runs off / settles early: not defined in code — confirm with finance (Phase 3).

## Build slices
1. **Attribution (now).** Add `Application.broker_id`; capture it on enquiry. *Done when:* an application can be attributed to a broker; nothing else required for the walking skeleton.
2. **Broker registry + accreditation** (Phase 3). *Done when:* a broker can be onboarded and accredited.
3. **Broker portal** (Phase 3) — apply on a client's behalf (an adviser-led-style flow). *Done when:* a broker can start and track an application for a client.
4. **Commissions + reporting** (Phase 3). *Done when:* commission accrues per settled mortgage and a broker can see performance.

## File / module layout
```
app/domains/brokers/   (Phase 3)
  models/    broker.rb broker_referral.rb broker_commission.rb
  services/  brokers.rb
# Phase 1: just the broker_id column on Application (origination package).
```

## Edge cases & failure modes
- Broker suspended mid-pipeline → existing applications continue; no new referrals.
- Commission on a mortgage that later goes to run-off/holiday → clawback/adjustment rules (Phase 3, define with finance).
- Duplicate referral (same client, two brokers) → attribution policy needed (Phase 3).

## Dashboard & visualisations
See `master.md` → Dashboards. A proven **broker scorecard** exists in the demo — rebuild it with the channel (not in the first slice).
- **Broker scorecard bubble chart** — X = applications (rolling 365d), Y = approval / conversion rate %, bubble size = commission earned; medians marked. *Surfaces:* broker volume vs quality, and the commission/quality relationship — spotting high-volume-low-quality vs genuinely strong brokers.
- **Broker performance** — conversion by broker, rolling 30 / 90 / 365d. *Surfaces:* which brokers convert, and the trend.

## Tests
Phase 1: attribution sets `broker_id` and flows through the funnel. Phase 3: portal isolation (broker can't cross lenders), commission accrual, performance windows.

## Audience (broker-facing agents — likely the first new agent beyond the five)
Efficient, professional, channel-specific. The advice wall still protects the end customer.

Cross-refs: `customers.md` (broker_id on Application; adviser-led-style flow), `lenders.md` (brokers operate within a lender), `PLATFORM_BUILD_BRIEF.md` §5.4.
