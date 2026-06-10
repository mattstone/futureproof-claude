# Constituent: Wholesale Funders (the capital source)

Inherit: `../master.md`. The shared funding stack a mortgage is booked into — central (control plane); every lender plugs in, no per-lender capital-markets desk. **Distinct from Investments** (the per-mortgage account that pays the homeowner) — see `investments.md`.

---

## Domain model
Funders/pools are control-plane reference data; allocations are per-tenant (a lender books its mortgages). Keep the funder/pool registry central; record allocations against the lender that drew them.

```
Funder            (central)
  id, name, type (wholesale|warehouse), country, capacity, terms, status

FunderPool        (central)
  id, funder_id, name, amount, allocated, benchmark_rate, margin_rate
  # available = amount - allocated ; total_rate = benchmark + margin
  has_many :lender_funder_pools   # which lenders may draw on this pool

FundingAllocation (tenant)
  id, mortgage_ref, pool_id, amount, booked_at, status (booked|settled|released)

# Deepen-later (Phase 3):
InsurancePolicy   (tenant)  mortgage_ref, insurer, coverage_pct (~0.90 LMI)
ReinsuranceLayer  (central) attaches_at, limit, reinsurer
HedgePosition     (central) instrument, notional, as_of   # portfolio S&P 500 hedge
```

## Interfaces (the `Funding` facade — funding side; see `investments.md` for the account side)
```
Funding.book_mortgage(mortgage)        -> Result(FundingAllocation)   # pick a pool by allocation rules
Funding.available(pool)                -> Money
Funding.release(allocation)            -> Result                      # on settlement/closure
# Phase 3:
Funding.attach_insurance(mortgage)     -> Result(InsurancePolicy)
Funding.portfolio_hedge_position()     -> HedgePosition
```

## Rules & invariants
- `book_mortgage` selects a pool the lender is permitted to draw (`lender_funder_pools`) with `available >= amount`; it increments `pool.allocated` atomically (no oversubscription).
- Booking is **idempotent per mortgage** (re-running doesn't double-allocate).
- Surplus at term splits **50/50 FutureProof / funder — never the borrower** (Phase 3 settlement).
- LMI covers ~90% of loss; the worst tail goes to reinsurance. Both are funding-side; they never appear to the customer.

## Business rules
(Values: `EpmModelConfig` v14a baseline — versioned; confirm the canonical set, the product brain owns it.)
- **Rate structure (annual drag):** wholesale funder margin **2.00%** + retail margin **0.70%** + FutureProof fee **0.25%** + hedge/rebalance **0.25%** (≈ **1.20%** customer-side drag). Pool rate = benchmark + margin.
- **Insurance:** LMI **1.6%** upfront (of the max loan at 80% LTV); reinsurance **0.1%** upfront. LMI covers the shortfall; the tail goes to reinsurance.
- **Pool allocation:** book a mortgage to a pool the lender may draw, with sufficient `available`; **no oversubscription** (`allocated ≤ amount`); deallocate on contract removal (`FunderPool`, `Contract`).
- **Approval constraints:** an application is approvable only with a valid lender, an active pool with sufficient capital, and a chosen mortgage configuration (`Application.approve!`).
- **Concentration limits (risk):** warn when a single **lender > 50%** of AUM, or a single **contract > 10%** of AUM (`EpmModelConfig` RISK_THRESHOLDS) — surface on the dashboard.
- **Surplus at maturity:** 50/50 FutureProof / funder (mechanics in `investments.md`).

## Build slices
1. **Funder/pool registry** (central) + `lender_funder_pools`. *Done when:* a pool with capacity exists and is assignable to a lender.
2. **Booking (the walking-skeleton stub).** `Funding.book_mortgage` → choose a pool → create a `FundingAllocation`, increment `allocated`. *Done when:* a settled mortgage is booked to a pool exactly once and `available` decreases by the amount; concurrent bookings can't oversubscribe.
3. **Release / lifecycle.** `release` on settlement/closure. *Done when:* releasing returns capacity to the pool.
4. **Insurance + reinsurance** (Phase 3). *Done when:* a booked mortgage carries an LMI policy and is assigned to a reinsurance layer.
5. **Portfolio hedge** (Phase 3). *Done when:* aggregate equity exposure is reflected in a hedge position.

## File / module layout
```
app/domains/funding/
  models/     funder.rb  funder_pool.rb  funding_allocation.rb
  services/   funding.rb        # facade (this file + investments.md account methods)
```

## Edge cases & failure modes
- No eligible pool with capacity → `Result.failure(:no_capacity)`, surfaced as an issue (runway alert), not a crash.
- Concurrent bookings on the same pool → row-lock / atomic increment; never oversubscribe.
- Re-booking an already-booked mortgage → no-op (idempotent).

## Dashboard & visualisations
See `master.md` → Dashboards. A **FutureProof control-plane** view across funders and lenders for **understanding capital trends and surfacing issues** (capital flows funder → pool → lender; a lender, if shown any, sees only its slice).
- **Capital KPI tiles** — Total Allocated / Committed / Available / Utilisation %. *Surfaces:* the capital position at a glance.
- **Utilisation bar + Runway** (per funder) — colour-coded utilisation bar + **runway in months** (available ÷ avg monthly deployment). *Surfaces:* capacity pressure and time-to-exhaustion — the headline early warning.
- **Allocation bars** (funder, pool) — deployed vs available. *Surfaces:* where capital is committed vs free.
- **Capital-flow Sankey** (D3) — funder → pool → lender → status; width = capital. *Surfaces:* where capital is stuck. Status nodes = EPM states (good standing / investment holiday / run-off / settled), **never "arrears"** (the demo's `in_arrears` is generic scaffolding — use Investment Health).
- **Concentration index (HHI)** across lenders. *Surfaces:* concentration risk.
- **Lender capacity table** — capacity / allocated / utilisation / weighted cost of capital / contract health. *Surfaces:* who's near capacity and what funding costs.

## Tests
Booking atomicity / no-oversubscription; idempotent re-book; available/runway calculations; isolation (a lender's allocations are tenant-scoped).

## Audience (funder-facing agents / reporting)
Precise, factual, reporting-oriented.

Cross-refs: `lenders.md` (pools assigned to lenders), `investments.md` (the account opened from a booking), `PLATFORM_BUILD_BRIEF.md` §7.
