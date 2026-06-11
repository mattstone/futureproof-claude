# Constituent: Customers (the homeowner & the journey)

Inherit: `../master.md`. The homeowner and the application journey — origination + identity. Runs **inside a resolved tenant**. The journey's UX is de-risked by the demo; its integration onto the real platform is built here.

---

## Domain model (tenant schema)
```
User        (TenantRecord)   role (customer|adviser|staff), email, auth, status
Applicant   (TenantRecord)   user_id, dob, contact, kyc_status (pending|passed|failed)
Property    (TenantRecord)   address, valuation, value_at_origination
Application (TenantRecord)   applicant_id, property_id, broker_id (nullable), state, quote_id
Quote       (TenantRecord)   product_version, term_years, ltv, income_pa, fees,
                             investment_plan jsonb, projection jsonb, risk jsonb,
                             issued_at        # IMMUTABLE once issued
Mortgage    (TenantRecord)   application_id, principal, term, start_on, end_on, state
ApplicationEvent (TenantRecord)  application_id, from_state, to_state, actor, at  # time-in-stage + audit
```

**Application state machine** (the canonical greenfield model — not the demo's enum):
```
enquiry -> quoted -> submitted -> in_assessment -> approved -> settled
                                       |              |
                                       +-> declined   +-> withdrawn
```
**Mortgage state machine:**
```
active -> investment_holiday -> active      (income pauses/resumes)
active -> run_off -> settled
```
There is **no** `arrears` / `repaying` / `prepaid` state on Mortgage. If one appears, it's a bug.

## The journey (self-service first; adviser-led is Phase 3)
land → **eligibility & quote** (calls the product brain; shows guaranteed income, plan, projection — plain language, never the language of debt) → **apply** (applicant, property, documents) → **verify** (KYC/AML) → **assess** (eligibility + valuation; Akane/Rie assist, human on exceptions) → **offer & accept** → **settle** (Funding books the mortgage; Investments opens the account; a `Mortgage` is created) → **live** (dashboard: income + Investment Health, never "balance owing").

## Interfaces (`Origination` facade)
```
Origination.start_enquiry(applicant_params)        -> Result(Application)
Origination.request_quote(application)             -> Result(Quote)        # delegates to ProductBrain
Origination.submit(application, details)           -> Result               # enquiry/quoted -> submitted
Origination.advance(application, to:, actor:)      -> Result               # guarded transition + ApplicationEvent
Origination.settle(application)                    -> Result(Mortgage)     # -> Funding.book + Investments.open
Origination.time_in_stage(application)             -> Duration
Origination.stalled(scope, threshold:)            -> [Application]         # the stuck-application signal
```
Quotes come **only** from `ProductBrain.quote(...)` (central, versioned). The journey never prices locally.

## Rules & invariants
- A `Quote` is **immutable** and records its `product_version` (reproducible). Re-quoting issues a new Quote.
- `advance` is a guarded transition: only legal transitions allowed; each writes an `ApplicationEvent` (this is what powers time-in-stage and stuck detection).
- `settle` is the integration point: it must create the `Mortgage`, book funding, and open the investment account atomically (or fail cleanly — no half-settled mortgage).
- Customer-facing copy: plain language, EPM-correct — never "loan", "repayment", "balance owing", "arrears".

## Business rules
Sources cited so a builder can verify. **Model parameters (income rates, etc.) live in the versioned product-model config — the product brain is the source of truth, not application code.**

**Eligibility** (checked at quote, re-checked on submit; per market — see `lenders.md` → Markets):
- LTV ≤ market ceiling (**80%** in every market today — `EpmModelConfig`, `regions.yml`).
- Applicant age ≥ market minimum — **AU 55 · US 62 · NZ 60 · UK 55**, no maximum (`EpmJurisdictionService`). This is a retirement product; the jurisdiction minimum governs, not the generic 18–85 form check.
- Property value within market bounds — **AU/US/NZ $500k–$10m · UK £300k–£10m** (`regions.yml`).
- Region consistency: application region must match the applicant's jurisdiction (submit validation).
- Ownership type ∈ {individual, joint, lender (company), super}; joint needs each borrower's name + age; company/super need the entity name.
- **KYC + AML required** in every market before approval; AML risk banded low/med/high (high: corporate, mortgage > $5m, etc.) (`EpmJurisdictionService`, `aml_check`).

**Product terms:**
- Term ∈ {10, 15, 20, 25, 30} years (`quote_service`); income payout term the same set.
- Mortgage type: interest-only (income out; principal + accrued cost settled at end) or P&I.
- **NNEG / 100% equity preserved** — the mortgage never exceeds property value; equity is guaranteed; not shared-appreciation (`EpmJurisdictionService`, `calculation_engine`).

**Quote:**
- Guaranteed income ≈ **1.5% of property value p.a.**, declining by term (annuity table ~1.50% @10yr → ~1.05% @30yr) — **take the figure from the product brain**, pinned to a `product_version`; the engine enforces the model constraints. Tom (lookup) and Pavel (Monte-Carlo) models both exist; don't hard-code a default here.
- A `Quote` is immutable and reproducible per `product_version`.

**Lifecycle:** legal transitions only (state machine above); a **decline requires a reason**; document completeness is enforced per stage (submit / process / accept).

**Jurisdiction notes affecting presentation** (information, never advice — the wall): AU Centrelink/Age-Pension asset-test impact; UK inheritance-tax impact; tax treatment differs (return-of-capital, not income) (`calculation_engine`).

**Confirm:** which property states (primary/investment/holiday) are eligible per market is **not enforced in code** — confirm. The Application state names here are the canonical greenfield set (enquiry→…→settled), not the demo's enum.

## Build slices
1. **Identity + applicant/property.** `User`, `Applicant`, `Property`; KYC stub. *Done when:* a customer can register and create an application within a tenant.
2. **Eligibility & quote.** `request_quote` → ProductBrain; quote screen. *Done when:* a customer gets a reproducible quote and the Quote is immutable. *(Walking-skeleton step.)*
3. **Application end-to-end.** State machine + `advance` + `ApplicationEvent`; submit → assess → approve. *Done when:* an application moves enquiry → approved with each transition logged.
4. **Settlement.** `settle` → create Mortgage + `Funding.book_mortgage` + `Funding.open_investment_account`, atomic. *Done when:* enquiry → settled produces a funded mortgage + investment account. *(Completes the walking skeleton.)*
5. **Live dashboard + stuck detection.** Servicing view (income + Investment Health); `stalled`. *Done when:* a customer sees their income/health and ops can list stalled applications.
6. **Adviser-led journey** (Phase 3, UK).

## File / module layout
```
app/domains/origination/
  models/    user.rb applicant.rb property.rb application.rb quote.rb mortgage.rb application_event.rb
  services/  origination.rb         # facade
  state/     application_state.rb mortgage_state.rb
```

## Edge cases & failure modes
- Quote requested with out-of-bounds inputs → ProductBrain rejects; surface a clear message, don't settle.
- `settle` partial failure (funding or account fails) → roll back the whole settlement; the Mortgage is not created.
- Stalled application (in_assessment beyond threshold) → surfaced for Akane/ops (step 3), not silently aged.
- Broker-attributed application → `broker_id` set; no broker portal yet (`brokers.md`).

## Dashboard & visualisations
See `master.md` → Dashboards. Understand journey conversion and surface stuck/dropping applications. Per-lender pipeline (tenant-scoped) + FP roll-up. Plain, EPM-correct language.
- **Application funnel (Sankey)** — enquiry → quoted → submitted → in_assessment → approved → settled (+ declined / dropped). *Surfaces:* conversion and **where applicants drop off**.
- **Pipeline aging / time-in-stage** (stacked bar) — applications by stage × age bucket. *Surfaces:* **stuck applications** — the signal Akane uses (`../agents/akane.md`, step 3).
- **Volume trend + calendar heatmap** — applications by month and by day. *Surfaces:* demand trend and seasonality.
- **Conversion trend** — submission → settled % by month. *Surfaces:* whether the journey is improving.
- **Acquisition overview** — apps this month, MoM %, conversion, split by channel (direct / broker) and region. *Surfaces:* where volume comes from.

## Tests
State-machine guards (illegal transitions rejected); quote immutability + reproducibility; `settle` atomicity (rollback on funding/account failure); time-in-stage + stalled; tenant isolation; no "loan/arrears" strings in customer-facing views.

## Audience (customer-facing agents — Akane, Misato)
Plain language, accessible (often older homeowners making a major decision), no jargon, never the language of debt. The advice wall is hard here. See `../agents/akane.md`, `../agents/misato.md`.

Cross-refs: `lenders.md` (runs in a tenant), product brain (quotes), `wholesale-funders.md` + `investments.md` (settlement), `PLATFORM_BUILD_BRIEF.md` §9, §4.2/4.3, §6.
