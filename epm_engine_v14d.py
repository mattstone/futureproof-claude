#!/usr/bin/env python3
"""
Faithful vectorised reimplementation of Pavel's v14d Optimised single-EPM Monte Carlo
(SingleProductCalc.bas: MonteCarlo_calc + SinglePath_calc).

Built to TIE OUT to the xlsm's verified outputs (base PoD 8.37%, mean surplus $1.14M,
reinsurance PoC 1.67%) — NOT the buggy Python engine (which amortised the loan and used a
leading mean-reversion trend, giving an optimistic 5.55%).

Key faithful details vs the old Python engine:
  - LoanFromFunder is FLAT at the $1.2M peak after the annuity period (NO amortisation).
  - Equity mean-reversion reverts to the LAGGED trend: SP500(t) uses LongTerm_mean(t-1).
  - Maturity year charges half interest / half NIM.
  - BalanceSurplus recorded BEFORE profit-share/collar deduction; windup at maturity.
"""
import numpy as np

def _norm_cdf(x):
    # Vectorised standard-normal CDF (Abramowitz-Stegun 26.2.17), ~1e-7 accuracy.
    t = 1.0/(1.0 + 0.2316419*np.abs(x))
    d = 0.3989422804014327*np.exp(-x*x/2.0)
    p = d*t*(0.319381530 + t*(-0.356563782 + t*(1.781477937 + t*(-1.821255978 + t*1.330274429))))
    return np.where(x >= 0, 1.0-p, p)

def _collar_price(cash, cap, floor, implvol):
    # BScall_put with r_eff=b_eff=cash, T implicit=1, S=1 (scale-invariant). Returns (Put-Call)/IA.
    v = implvol
    # call struck at cap
    d1c = (np.log(1.0/cap) + cash + 0.5*v*v)/v; d2c = d1c - v
    call = _norm_cdf(d1c) - cap*np.exp(-cash)*_norm_cdf(d2c)
    # put struck at floor
    d1p = (np.log(1.0/floor) + cash + 0.5*v*v)/v; d2p = d1p - v
    put = floor*np.exp(-cash)*(1.0-_norm_cdf(d2p)) - (1.0-_norm_cdf(d1p))
    return put - call

def run(params=None, n_paths=50_000, seed=42):
    p = dict(
        home_value=1_500_000, lvr=0.80, initial_loan=900_000,
        annuity_pa=30_000, annuity_term=10, tenure=30, loan_type='PI',
        wholesale_margin=0.02, retail_margin=0.007, fp_margin=0.005,
        hedging_fee=0.0025, lmi_upfront=0.0125, reins_upfront=0.001,
        eq_expret=0.092, eq_vol=0.166, eq_meanrev=0.163,
        hedge_cap=1.40, hedge_floor=0.80,
        cash_init=0.0421, cash_theta=0.0213, cash_kappa=0.24, cash_vol=0.0122,
        corr=0.30, holiday_entry=0.75, holiday_exit=1.458,
        profit_share_years=3, profit_taken_pct=0.10,
        implvol=0.175,          # StochReturnVol (E31) — used for BS collar pricing
        collar_fixed=None,      # if set (e.g. 0.003), use fixed collar ("Given" mode); else BS-priced
        # --- glide path (NOT in Pavel's xlsm — prototype extension) ---
        # None = 100% collared-equity throughout (matches xlsm). Else dict:
        #   {'w_start':1.0,'w_end':0.3,'start_year':20} -> equity weight glides linearly
        #   from w_start (held until start_year) down to w_end at maturity; rest in cash.
        glide=None,
        # State-dependent ratchet (NOT in xlsm — prototype). If set (e.g. 0.10), each year keep
        # loan*(1+ratchet) in the collared-equity sleeve and lock the surplus above it into cash.
        ratchet=None,
        # Methodology toggle:
        #   amortise=False -> FLAT principal (Pavel's xlsm; lump repayment at maturity)
        #   amortise=True  -> principal pays down straight-line to 0 over the post-annuity years,
        #                     funded from the investment account (the "P&I" reading)
        amortise=False,
    )
    if params: p.update(params)
    T = p['tenure']; N = n_paths
    rng = np.random.default_rng(seed)

    # ---- loan from funder: rises with annuity, then FLAT or AMORTISING ----
    peak = p['initial_loan'] + p['annuity_pa']*p['annuity_term']
    amort_step = peak/(T - p['annuity_term']) if (p['amortise'] and T > p['annuity_term']) else 0.0
    loan = np.zeros(T+1); loan[0] = p['initial_loan']
    for t in range(1, T+1):
        if t <= p['annuity_term']:
            loan[t] = loan[t-1] + p['annuity_pa']
        elif p['amortise']:
            loan[t] = max(loan[t-1] - amort_step, 0.0)
        else:
            loan[t] = loan[t-1]
    cust_loan = np.zeros(T+1)
    for t in range(1, T+1):
        cust_loan[t] = cust_loan[t-1] + (p['annuity_pa'] if t <= p['annuity_term'] else 0)
    max_loan = loan.max()

    # ---- shocks: cash, and equity correlated to cash ----
    zc = rng.standard_normal((N, T+1))
    ze_ind = rng.standard_normal((N, T+1))
    ze = p['corr']*zc + np.sqrt(1-p['corr']**2)*ze_ind

    # ---- cash rate (OU exact discretisation) ----
    cash = np.zeros((N, T+1)); cash[:, 0] = p['cash_init']
    w = np.exp(-p['cash_kappa'])
    for t in range(1, T+1):
        cash[:, t] = np.maximum(cash[:, t-1]*w + p['cash_theta']*(1-w) + p['cash_vol']*zc[:, t], 0)

    # ---- equity (GBM + mean reversion to LAGGED trend), start 100 ----
    sp = np.full(N, 100.0); ltm = np.full(N, 100.0)
    inv_ret_hedged = np.zeros((N, T+1))
    er, ev, ek = p['eq_expret'], p['eq_vol'], p['eq_meanrev']
    floor_r, cap_r = p['hedge_floor']-1, p['hedge_cap']-1
    for t in range(1, T+1):
        sp_new = sp*(1+er+ev*ze[:, t]) + ek*(ltm - sp)
        ltm = ltm*(1+er)
        raw = sp_new/sp - 1
        sp = sp_new
        inv_ret_hedged[:, t] = np.clip(raw, floor_r, cap_r)

    # ---- equity-weight schedule: glide (calendar) precomputed; ratchet (state-dependent) in-loop ----
    wq = np.ones(T+1)
    if p['glide'] is not None:
        g = p['glide']; ws, we, sy = g['w_start'], g['w_end'], g['start_year']
        for t in range(T+1):
            wq[t] = ws if t <= sy else ws + (we-ws)*(t-sy)/(T-sy)

    # ---- base collar price per path/period (BS each year, or fixed "Given" mode) ----
    if p['collar_fixed'] is not None:
        base_collar = np.full((N, T+1), float(p['collar_fixed']))
    else:
        base_collar = _collar_price(cash, p['hedge_cap'], p['hedge_floor'], p['implvol'])

    # ---- waterfall ----
    upfront = max_loan*(p['lmi_upfront'] + p['reins_upfront'])
    IA = np.full(N, loan[0] - upfront)
    IA *= (1 - base_collar[:, 0])   # init: fully in equity sleeve
    entry_thr = p['initial_loan']*p['holiday_entry']
    exit_thr = p['initial_loan']*p['holiday_exit']

    holiday_flag = np.zeros(N, dtype=int)
    holiday_count = np.zeros(N, dtype=int)
    repay_step = np.zeros(N, dtype=int)
    holiday_acct = np.zeros(N)
    funder_int_tot = np.zeros(N)
    int_charged_tot = np.zeros(N)
    surplus_by_year = np.zeros((N, T+1))
    surplus_by_year[:, 0] = IA - loan[0]   # InterestDeficit(0)=0
    fp_margin_rev = np.zeros(N)
    profit_share_fp = np.zeros(N)
    holiday_years = np.zeros(N)
    holiday_by_year = np.zeros(T+1)

    for t in range(1, T+1):
        funding_cost = p['wholesale_margin'] + cash[:, t]
        avg_loan = (loan[t-1] + loan[t]) / 2
        funder_int = -funding_cost*avg_loan
        funder_int_tot = funder_int_tot + funder_int

        prev_flag = holiday_flag.copy()
        prev_count = holiday_count.copy()
        entering = (prev_flag == 0) & (IA < entry_thr)
        staying = (prev_flag == 1) & ~(IA > exit_thr)
        holiday_flag = (entering | staying).astype(int)
        holiday_count = np.where(holiday_flag == 1, holiday_count + 1, 0)
        holiday_years = holiday_years + holiday_flag
        holiday_by_year[t] = float(holiday_flag.mean())

        repay_flag = (prev_flag == 1) & (holiday_flag == 0)
        repay_periods = np.where(repay_flag, prev_count, 0)
        repay_step = np.where((repay_periods > 0) & (repay_step == 0), repay_periods, repay_step - 1)
        repay_step = np.maximum(repay_step, 0)

        holiday_open = holiday_acct.copy()
        interest_holiday = np.where(holiday_flag == 1, -funder_int, 0.0)
        repay_holiday = np.where(repay_step > 0, -holiday_open/np.maximum(repay_step, 1), 0.0)
        holiday_acct = holiday_open + interest_holiday + repay_holiday

        int_charged = funder_int + interest_holiday + repay_holiday
        nim = -p['retail_margin']*avg_loan
        if t == T:
            nim = -p['retail_margin']*loan[t-1]/2
            int_charged = -funding_cost*loan[t-1]/2   # maturity half interest, no holiday offset
        int_charged_tot = int_charged_tot + int_charged
        int_deficit = funder_int_tot - int_charged_tot

        # equity weight this year: ratchet (state-dependent) > glide (calendar) > 100%
        if p['ratchet'] is not None:
            target_eq = np.minimum(IA, loan[t]*(1.0+p['ratchet']))   # keep ~obligation in equity, lock the rest
            eqw = np.where(IA > 1e-9, np.clip(target_eq/IA, 0.0, 1.0), 1.0)
        elif p['glide'] is not None:
            eqw = np.full(N, wq[t])
        else:
            eqw = np.ones(N)
        year_ret = eqw*inv_ret_hedged[:, t] + (1.0-eqw)*cash[:, t]
        fp_margin_pay = -p['fp_margin']*IA
        fp_margin_rev = fp_margin_rev + p['fp_margin']*IA   # FP collects this
        inv_ret_pay = IA*year_ret
        hedge_fee_pay = -p['hedging_fee']*IA

        IA = IA + inv_ret_pay + int_charged + nim + fp_margin_pay + hedge_fee_pay
        if p['amortise'] and t > p['annuity_term']:
            IA = IA - (loan[t-1] - loan[t])   # investment account funds the principal repayment

        if p['loan_type'] == 'IO':
            surplus = IA - loan[t] + cust_loan[t] + int_deficit
        else:
            surplus = IA - loan[t] + int_deficit
        surplus_by_year[:, t] = surplus

        if t < T:
            if t % p['profit_share_years'] == 0:
                ps = np.where(surplus > 0, surplus*p['profit_taken_pct'], 0.0)
                IA = IA - ps
                profit_share_fp = profit_share_fp + ps*0.5   # profit share splits 50/50 FP/funder
            IA = IA*(1 - base_collar[:, t]*eqw)   # collar only on the equity sleeve
        else:
            IA = IA - np.maximum(surplus, 0)   # windup

    final = surplus_by_year[:, T]
    pod = float(np.mean(final < 0)*100)
    se = float(np.sqrt(pod/100*(1-pod/100)/N)*100)
    windup_fp = np.maximum(final, 0)*0.5
    fp_rev = float(np.mean(fp_margin_rev + profit_share_fp + windup_fp))
    # deterministic stakeholder margins (proportional to loan; path-independent)
    avg_loans = np.array([(loan[t-1]+loan[t])/2 for t in range(1, T+1)])
    avg_loans[-1] = loan[T-1]/2   # maturity half
    lender_nim = float(p['retail_margin']*avg_loans.sum())
    funder_margin = float(p['wholesale_margin']*avg_loans.sum())
    annuity_total = p['annuity_pa']*p['annuity_term']

    # ---- SEVERITY-AWARE insurance metrics (two-layer: LMI first-loss, reinsurance tail) ----
    disc = float(np.exp(-p['cash_theta']*T))
    defmask = final < 0
    n_def = int(defmask.sum())
    top_cover = float(np.percentile(final[defmask], 20)) if n_def > 0 else 0.0   # 20th pct of deficits (negative)
    deficit = np.maximum(-final, 0.0)
    lmi_claim = np.minimum(deficit, -top_cover)                  # LMI: deficit capped at the boundary
    reins_mask = final < top_cover
    reins_claim = np.where(reins_mask, top_cover - final, 0.0)   # reins: excess deficit below the boundary
    lmi_prem = disc*float(lmi_claim.mean())                      # discounted expected LMI loss (fair premium)
    reins_prem = disc*float(reins_claim.mean())                 # discounted expected reins loss (fair premium)
    reins_es = float(reins_claim[reins_mask].mean()) if reins_mask.sum() > 0 else 0.0  # severity given claim
    out = dict(
        pod=round(pod, 2), se=round(se, 3),
        reins_poc=round(0.20*pod, 3),               # frequency only (worst 20% of deficits)
        reins_prem=round(reins_prem, 0),            # SEVERITY-AWARE: discounted expected reins loss
        reins_es=round(reins_es, 0),                # expected shortfall (mean reins loss | claim)
        lmi_prem=round(lmi_prem, 0),
        top_cover_limit=round(top_cover, 0),
        mean_surplus=round(float(final.mean()), 0),
        median_surplus=round(float(np.median(final)), 0),
        annuity_total=annuity_total,
        fp_revenue=round(fp_rev, 0),
        lender_nim=round(lender_nim, 0),
        funder_margin=round(funder_margin, 0),
        deficit_by_year=[round(float(np.mean(surplus_by_year[:, y] < 0)*100), 2) for y in range(1, T+1)],
        pct_surplus_maturity=round(100.0 - pod, 2),
        mean_holiday_years=round(float(holiday_years.mean()), 2),
        median_holiday_years=float(np.median(holiday_years)),
        pct_zero_holidays=round(float(np.mean(holiday_years == 0)*100), 1),
        holiday_by_year=[round(float(holiday_by_year[y]*100), 1) for y in range(1, T+1)],
        median_surplus_by_year=[round(float(np.median(surplus_by_year[:, y])), 0) for y in range(1, T+1)],
        p10=round(float(np.percentile(final, 10)), 0),
        p25=round(float(np.percentile(final, 25)), 0),
        final=final,
    )
    return out

if __name__ == '__main__':
    base = run()
    print(f"BASE: PoD={base['pod']}% (SE {base['se']}%)  mean=${base['mean_surplus']:,.0f}  median=${base['median_surplus']:,.0f}")
    print(f"      target (xlsm): PoD 8.37%, mean $1,137,899, median $993,211")
    print(f"  deficit yr1={base['deficit_by_year'][0]}%  yr30={base['deficit_by_year'][-1]}%  (xlsm yr1 58.3%, yr30 8.37%)")
    # scenarios
    central = run({'eq_expret':0.085,'eq_meanrev':0.13,'cash_theta':0.027,'collar_fixed':0.003,'wholesale_margin':0.022})
    adverse = run({'eq_expret':0.080,'eq_meanrev':0.10,'cash_theta':0.030,'collar_fixed':0.004,'wholesale_margin':0.025})
    print(f"CENTRAL: PoD={central['pod']}%  (xlsm target 40%)")
    print(f"ADVERSE: PoD={adverse['pod']}%  (xlsm target 69%)")
