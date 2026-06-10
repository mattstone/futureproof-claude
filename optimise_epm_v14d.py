#!/usr/bin/env python3
"""EPM v14d optimisation on the validated engine. Borrower income (annuity) wins ties.
Risk ceilings: reinsurance PoC <= 2/3/5%  <=>  PoD <= 10/15/25% (tail = worst 20% of deficits).
NOTE: engine is ~1-2.5pp conservative on PoD; winners must be spot-checked on Pavel's xlsm."""
import itertools
import numpy as np
import epm_engine_v14d as e

GROSS = 1_200_000   # 80% LVR x $1.5M; peak loan is always gross regardless of annuity
NP = 20_000

def cfg(annuity_total, term, floor=0.80, cap=1.40, fp=0.005, ps_pct=0.10, glide=None):
    return dict(initial_loan=GROSS-annuity_total, annuity_pa=annuity_total/term, annuity_term=term,
                hedge_floor=floor, hedge_cap=cap, fp_margin=fp, profit_taken_pct=ps_pct, glide=glide)

print("="*72)
print("1) GLIDE PATH SWEEP (de-risk equity -> cash near maturity), base product")
print("   w_end = equity weight at maturity (1.0 = no glide = current model)")
print("="*72)
for we in [1.0, 0.9, 0.7, 0.5, 0.3]:
    g = None if we == 1.0 else {'w_start':1.0,'w_end':we,'start_year':20}
    r = e.run({'glide':g}, n_paths=NP)
    tag = "no glide (current)" if we==1.0 else f"glide ->{we:.0%} equity"
    print(f"  {tag:24} PoD={r['pod']:5.2f}%  reinsPoC={r['reins_poc']:5.2f}%  mean=${r['mean_surplus']:>10,.0f}  FPrev=${r['fp_revenue']:>9,.0f}")

print()
print("="*72)
print("2) IN-MODEL SWEEP: annuity x payout-term x collar-floor (FP margin 0.50%, profit 10%/3yr)")
print("="*72)
rows = []
for annuity_total, term, floor in itertools.product(
        [250_000, 300_000, 350_000, 400_000], [10, 15, 20, 25], [0.80, 0.85, 0.90]):
    r = e.run(cfg(annuity_total, term, floor=floor), n_paths=NP)
    rows.append(dict(annuity=annuity_total, term=term, floor=floor,
                     pod=r['pod'], reins_poc=r['reins_poc'],
                     fp_rev=r['fp_revenue'], mean=r['mean_surplus'],
                     stakeholder=r['fp_revenue']+r['lender_nim']+r['funder_margin']))

def best_at(ceiling_pod, label):
    feas = [x for x in rows if x['pod'] <= ceiling_pod]
    if not feas:
        print(f"  {label}: no feasible config"); return
    # borrower income wins ties: max annuity, then max stakeholder revenue
    feas.sort(key=lambda x: (-x['annuity'], -x['stakeholder']))
    b = feas[0]
    print(f"  {label} (PoD<= {ceiling_pod}%): annuity=${b['annuity']:,} ({b['term']}yr)  floor={b['floor']:.2f}  "
          f"-> PoD={b['pod']:.2f}% reinsPoC={b['reins_poc']:.2f}%  FPrev=${b['fp_rev']:,.0f}  stakeholder=${b['stakeholder']:,.0f}")

print("\nBest config at each risk ceiling (borrower annuity maximised, then revenue):")
best_at(10.0, "reins PoC<=2%")
best_at(15.0, "reins PoC<=3%")
best_at(25.0, "reins PoC<=5%")

print("\nFrontier detail — max annuity achievable at each ceiling, by term:")
for term in [10,15,20,25]:
    line=f"  {term}yr term: "
    for ceil,lbl in [(10,'2%'),(15,'3%'),(25,'5%')]:
        feas=[x for x in rows if x['term']==term and x['pod']<=ceil]
        mx=max([x['annuity'] for x in feas]) if feas else 0
        line+=f"{lbl}->${mx//1000:.0f}K  "
    print(line)
