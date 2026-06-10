# Quarantined buggy Monte Carlo engines — DO NOT USE

**Quarantined 2026-06-01.**

## What is in here

`monte_carlo_v14d_optimised.py` — the v14d "Optimised" per-mortgage Monte Carlo engine that
*used to* feed the v14d papers (Reinsurance, Model Review, Model Assumptions, Actuarial Review).

## Why it is quarantined

It has a **confirmed equity mean-reversion trend-lag bug**. In the simulation loop it advances the
long-term equity trend by `(1 + mu)` **before** applying the mean-reversion term:

```python
equity_trend *= (1 + eq_mu)                       # <-- advances the trend FIRST
...
mean_rev_component = eq_kappa * (equity_trend - equity_index)   # reverts toward the inflated trend
```

So prices revert toward a target inflated by ~9% each step → the engine is **optimistically biased**.
On the base case it reports **PoD ≈ 5.55%**, whereas Pavel's authoritative workbook
(`data/FutureProofCalculator_Pavel_v14d (Optimised Paramters).xlsm`, `MainSingleEPM!AL6`) reports
**8.37%** on identical inputs. It also reports tail/reinsurance PoC 1.11% vs the workbook's 1.67%.

The correct treatment (used by the validated engine) reverts to the **lagged** trend, then advances it:

```python
sp_new = sp*(1 + er + ev*z) + ek*(ltm - sp)   # revert to LAGGED trend ltm(t-1)
ltm    = ltm*(1 + er)                          # THEN advance the trend
```

## The danger (why it is guarded, not just moved)

Running it writes `monte_carlo_v14d_optimised_results.json` in the working directory — the **exact
file the live paper generators read**. That JSON was overwritten on 2026-05-24 with xlsm-verified
values (8.37% / 1.67%). Re-running this engine would silently re-corrupt it with the buggy 5.55%,
and every headline across the papers would regress on the next regeneration. The file therefore has
a hard `sys.exit()` guard at the top and refuses to run.

## Use this instead

`epm_engine_v14d.py` (repo root) — the **validated** vectorised reimplementation of Pavel's VBA. It
ties out to the workbook's three known points (base 8.37%, central ~40%, adverse ~69%; reads ~0.85pp
conservative on PoD) and is what the Optimisation Analysis paper is built on. Spot-check winners on
the xlsm.

## Siblings that share the same bug (still at repo root — NOT yet quarantined)

These v14c-era engines have the identical trend-lag pattern. They feed only **deprecated** v14c
papers, so the live risk is lower, but treat their output with the same suspicion:

- `monte_carlo_v14c_optimised.py`
- `monte_carlo_v14c_003.py`
- `monte_carlo_v14c_003_comprehensive.py`
