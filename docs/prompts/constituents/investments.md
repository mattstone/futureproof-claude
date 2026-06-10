# Constituent: Investments (the investment account)

Inherit: `../master.md`. The per-mortgage **investment account** that pays the homeowner's income and services the mortgage interest. Yumi's domain. Born **with** a mortgage — built alongside Customers/origination, not before. **Distinct from Wholesale Funders** (the capital source).

---

## Domain model (tenant schema)
```
InvestmentAccount   (TenantRecord)
  id, mortgage_ref, opened_at
  balance            decimal   # current account value
  target_allocation  jsonb     # { equity: 0.70, fixed_income: 0.30 }
  actual_allocation  jsonb     # current mix (drifts; rebalanced toward target)
  health_state       enum      # good_standing | watch | holiday
  health_score       decimal   # derived (see below)

IncomePayment       (TenantRecord)
  id, investment_account_id, amount, due_on, paid_on, status (scheduled|paid|paused)

AllocationEvent     (TenantRecord)   # rebalances + drift snapshots, for the trend view
  id, investment_account_id, equity_pct, fixed_income_pct, recorded_at, reason
```

**No `arrears` anywhere.** The customer never pays; "trouble" = the account underperforming, surfaced as an **investment holiday** and **Investment Health**.

## Derived metrics (define once, reuse on the dashboard and in Yumi)
- **Holiday %** = accounts in `health_state: holiday` ÷ active accounts.
- **Investment Health (portfolio)** = `100 − Holiday %` (and/or a weighted health score).
- **Health thresholds** (from `EpmModelConfig`): holiday-rate **warning 35%**, **critical 50%**; health **good 75 / fair 60**.
- **Allocation drift** = actual vs target (e.g. equity 78% vs 70% target → +8pp drift).

## Interfaces (`Funding` facade — account side)
```
Funding.open_investment_account(mortgage)   -> Result(InvestmentAccount)  # fund from the booking, set 70/30
Funding.record_income_payment(account)      -> Result(IncomePayment)
Funding.investment_health(account)          -> Health { state, score }
Funding.enter_holiday(account, reason)      -> Result   # income pauses
Funding.exit_holiday(account)               -> Result
Funding.propose_rebalance(account)          -> RebalancePlan  # toward target; Yumi proposes, human gates
Funding.portfolio_health(scope)             -> { holiday_pct, health, by_cohort }
```

## Rules & invariants (fixed product mechanics — see master §2)
- Funded at origination from the funder booking; target ~**70% equity ETFs / 30% fixed income**.
- Pays scheduled income; **services the mortgage interest from the account** — never bills the customer.
- **Run-off:** no exit until the mortgage cost is met from the account.
- **Investment holiday:** when health falls below threshold, income **pauses** (`enter_holiday`) — this is the EPM equivalent of payment trouble. Never "arrears", never "default".
- House price is fixed at origination; do not model ongoing house-price movement here.

## Business rules
**Model parameters are versioned (product brain / `EpmModelConfig`). The values below are the current v14a baseline in code; the model has since evolved (e.g. v14d Optimised) — confirm the canonical set with the product owner before relying on a specific number. The product brain is the source of truth.**

- **Target allocation:** ~**70% equity ETFs / 30% fixed income** (product intent). *Gap:* not enforced in current code (the model parameterises equity + cash + a hedging collar) — implement the 70/30 target + drift/rebalance explicitly.
- **Hedging collar:** caps annual return swings — **±20%** (v14a baseline) or **±35%** (optimised). Rebalance toward target within the collar.
- **Investment holiday (income pauses):** enter when the account value falls to **≤ 90% of the initial loan** (v14a; optimised 100%); exit when it recovers to **≥ ~146%** (v14a; optimised ~162%). Use **hysteresis** (entry ≠ exit) so accounts don't flap. Portfolio path-share thresholds for the dashboard: **warning 35% / critical 50%** on holiday (`EpmModelConfig`).
- **Run-off:** no exit or prepayment until the mortgage cost is met from the account.
- **Profit realisation:** every **5 years** FutureProof takes **~25%** of surplus above target (v14a); at **maturity** the remaining surplus splits **50/50 FutureProof / funder — never the borrower** (`EpmModelConfig`).
- **No customer payments, no arrears** — standing is Investment Health / Holiday % only.

## Build slices
1. **Open + fund account** on settlement; set target 70/30; record opening `AllocationEvent`. *Done when:* a settled mortgage has a funded account with target allocation.
2. **Income payments.** Schedule + `record_income_payment`. *Done when:* an account pays a scheduled income payment.
3. **Health + holiday.** Compute `investment_health`; `enter_holiday`/`exit_holiday` on threshold. *Done when:* an underperforming account enters holiday (income pauses) and Investment Health reflects it.
4. **Rebalance proposal** (Yumi). `propose_rebalance` toward target; human-gated execution. *Done when:* a drifted account yields a rebalance plan an approver can accept.
5. **Term settlement** (Phase 3). Contribute to settlement; surplus split is funding-side (`wholesale-funders.md`).

## File / module layout
```
app/domains/funding/
  models/    investment_account.rb  income_payment.rb  allocation_event.rb
  services/  funding.rb   # shared facade (account methods here; capital methods in wholesale-funders.md)
```

## Edge cases & failure modes
- Account can't be funded at settlement → block settlement, raise as an issue (don't create a half-built mortgage).
- Rapid health oscillation → hysteresis (enter/exit thresholds differ) so accounts don't flap in/out of holiday.
- Drift with no market data → `propose_rebalance` degrades gracefully (no proposal, flag for review).

## Dashboard & visualisations
See `master.md` → Dashboards. Track **Investment Health** and surface at-risk accounts/cohorts. Portfolio-level (FP) + per-lender. **Never arrears** — use Investment Health / Holiday %.
- **Investment Health gauge** (radial) — score = 100 − Holiday %; zones from the thresholds above. *Surfaces:* portfolio health at a glance.
- **Holiday % trend** — accounts / AUM on holiday over time. *Surfaces:* underperformance building.
- **Vintage cohort heatmap** — by origination quarter: holiday rate, P&L per contract, age, size. *Surfaces:* which vintages underperform.
- **Allocation drift vs target** — actual vs 70/30. *Surfaces:* accounts to rebalance — Yumi's trigger.
- **Holiday entry/exit flow** — entering vs leaving holiday over time. *Surfaces:* recovering or deteriorating.
- **Account cover** — balance (+ offset) vs obligations. *Surfaces:* accounts heading toward a holiday early.

## Tests
Open/fund; income payment; health calc + thresholds; holiday enter/exit with hysteresis; drift + rebalance proposal; tenant isolation. (Reuse `EpmModelConfig` thresholds — don't hard-code.)

## Audience (investment reporting agents)
Precise; health-and-income framing, never debt or arrears. See `../agents/yumi.md`.

Cross-refs: `customers.md` (mortgage settlement opens the account), `wholesale-funders.md` (funds it), `PLATFORM_BUILD_BRIEF.md` §4.4, §7.3.
