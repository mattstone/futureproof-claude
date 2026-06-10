# EpmModelConfig — Single Source of Truth for EPM Financial Parameters
#
# ALL financial model parameters live here. Every calculator, service,
# dashboard, and API references this config. No hardcoded parameters elsewhere.
#
# Current production model: v14d Optimised
#   Source:    data/FutureProofCalculator_Pavel_v14d (Optimised Paramters).xlsm
#   Validated: 50,000-path Monte Carlo, xlsm-verified 2026-05-24
#              (monte_carlo_v14d_optimised_results.json; Python engine: epm_engine_v14d.py)
#
# Usage:
#   EpmModelConfig.params                    # current production parameters (v14d Optimised)
#   EpmModelConfig.params[:equity_mean]      # individual parameter
#   EpmModelConfig.annuity_rate(term: 10)    # annuity rate for a given term
#   EpmModelConfig.total_variable_cost       # sum of all annual cost drags
#   EpmModelConfig.risk_metrics              # MC-validated risk metrics
#   EpmModelConfig.model_version             # version string recorded on quotes
#
class EpmModelConfig
  # Version string recorded on every persisted quote for reproducibility.
  # Bump whenever any parameter below changes.
  MODEL_VERSION = "v14d-optimised".freeze

  # ============================================================
  # v14d OPTIMISED PARAMETERS (current production)
  # Source: FutureProofCalculator_Pavel_v14d (Optimised Paramters).xlsm
  # Validated: 50,000-path Monte Carlo, PoD 8.37% (SE 0.12%)
  # ============================================================
  V14D_OPTIMISED_PARAMS = {
    # ── Mortgage Structure ──────────────────────────────────
    max_ltv: 0.80,
    base_property_value: 1_500_000,
    initial_loan: 900_000,
    tenure_years: 30,
    annuity_pa: 30_000,           # 2.0% of base property value
    annuity_term_years: 10,

    # ── Investment Return Model ─────────────────────────────
    # GBM with Stochastic Drift + Mean Reversion
    equity_mean: 0.092,
    equity_vol: 0.166,
    equity_mean_reversion: 0.163,

    # ── Hedging Collar (asymmetric) ─────────────────────────
    buffer_cap: 1.40,        # +40% cap on annual return
    buffer_floor: 0.80,      # -20% floor on annual return
    collar_price: 0.00046,   # net cost p.a. (BS-priced)

    # ── Cash Rate Model (Ornstein-Uhlenbeck) ────────────────
    cash_rate_initial: 0.0421,
    cash_rate_theta: 0.0213,   # long-run mean
    cash_rate_kappa: 0.24,     # mean reversion speed
    cash_rate_sigma: 0.0122,   # volatility
    cash_rate_equity_corr: 0.30,

    # ── Cost Structure ──────────────────────────────────────
    wholesale_margin: 0.02,    # 2.00% — funder cost of funds spread
    retail_margin: 0.007,      # 0.70% — NIM charged to borrower
    fp_margin: 0.005,          # 0.50% — FP annual management fee
    hedging_fee: 0.0025,       # 0.25% — hedging/rebalancing cost

    # ── Insurance ───────────────────────────────────────────
    lmi_upfront_pct: 0.0125,        # 1.25% of max loan
    reinsurance_upfront_pct: 0.001, # 0.1% of max loan

    # ── Holiday Mechanism ───────────────────────────────────
    holiday_entry_level: 0.75,   # investment < 75% of initial loan → holiday
    holiday_exit_level: 1.458,   # investment > 145.8% of initial loan → exit

    # ── Profit Share ────────────────────────────────────────
    profit_share_pct: 0.10,      # 10% of surplus drawn at each reset
    profit_share_interval: 3,    # 3-year resets
    surplus_split: 0.50         # 50/50 split at maturity (FP / Funder)
  }.freeze

  # ============================================================
  # ANNUITY RATES (% of home value, annual)
  # 10yr anchor is the validated v14d Optimised point ($30K p.a. on $1.5M).
  # PROVISIONAL: 15-30yr points scale the v14a term shape to the v14d anchor
  # and have NOT been Monte Carlo validated — pending Pavel's v14d term
  # structure runs. Do not quote 15-30yr terms externally as validated.
  # ============================================================
  ANNUITY_RATES = {
    10 => 0.02,     # 2.00% — VALIDATED (v14d Optimised base case)
    15 => 0.0183,   # 1.83% — provisional
    20 => 0.0167,   # 1.67% — provisional
    25 => 0.0153,   # 1.53% — provisional
    30 => 0.014    # 1.40% — provisional
  }.freeze

  # Terms with Monte Carlo validation under the current model version
  VALIDATED_TERMS = [ 10 ].freeze

  # ============================================================
  # MC-VALIDATED RISK METRICS
  # 50,000 paths, v14d Optimised, per-mortgage layer, xlsm-verified 2026-05-24
  # ============================================================
  RISK_METRICS = {
    pod_yr30: 8.37,            # per-mortgage Probability of Deficit at maturity
    pod_yr15: 44.84,           # per-mortgage PoD mid-term (snapshot, not a claim metric)
    pod_se: 0.12,
    mean_surplus_yr30: 1_137_899,
    median_surplus_yr30: 993_211,
    p1_surplus_yr30: -559_318,
    p5_surplus_yr30: -35_524,
    p10_surplus_yr30: 60_439,
    cond_expected_deficit: -143_274,
    lmi_fair_premium: 10_168,        # PV, per mortgage
    lmi_loaded_premium: 15_253,
    reinsurance_poc: 1.67,           # tail-risk layer Probability of Claim
    reinsurance_fair_premium: 1_827, # PV, per mortgage
    reinsurance_loaded_premium: 2_740,
    # Portfolio-after-waterfall PoC, 50,000-path portfolio run (2026-05-21,
    # Pavel's xlsm). Materially close to per-mortgage PoD — do NOT present
    # the portfolio waterfall as eliminating claim risk.
    portfolio_poc_steady_state: 5.5,
    mean_total_holiday_years: 3.46,
    pct_zero_holidays: 55.2
  }.freeze

  # ============================================================
  # RISK DASHBOARD THRESHOLDS (calibrated to MC results)
  # ============================================================
  RISK_THRESHOLDS = {
    holiday_rate_warning: 0.35,   # v14d MC peaks at ~26% of paths on holiday (years 6-8)
    holiday_rate_critical: 0.50,  # 50% would indicate severe underperformance
    at_risk_rate_warning: 0.02,   # 2% of AUM in investment-at-risk contracts
    at_risk_rate_critical: 0.05,  # 5% of AUM
    concentration_warning: 0.50,  # single lender > 50%
    single_exposure_warning: 0.10, # single contract > 10% of AUM
    high_ltv_threshold: 0.75,     # equity > 75%
    health_excellent: 90,
    health_good: 75,
    health_fair: 60
  }.freeze

  # Legacy demo heuristic: the original demo webapp derived P&I income as
  # ~77% of the interest-only quote. Used only by the legacy :original API model.
  PI_INCOME_FACTOR = 0.77

  class << self
    # ── Primary Accessors ─────────────────────────────────
    def params
      V14D_OPTIMISED_PARAMS
    end

    def model_version
      MODEL_VERSION
    end

    def risk_metrics
      RISK_METRICS
    end

    def risk_thresholds
      RISK_THRESHOLDS
    end

    # ── Computed Values ───────────────────────────────────
    def annuity_rate(term:)
      ANNUITY_RATES[term] || raise(ArgumentError, "Unsupported term: #{term}. Use: #{ANNUITY_RATES.keys.join(', ')}")
    end

    def annuity_rates
      ANNUITY_RATES
    end

    def validated_term?(term)
      VALIDATED_TERMS.include?(term)
    end

    def total_variable_cost
      p = V14D_OPTIMISED_PARAMS
      p[:retail_margin] + p[:fp_margin] + p[:hedging_fee]
    end

    def total_spread
      p = V14D_OPTIMISED_PARAMS
      p[:wholesale_margin] + p[:retail_margin] + p[:fp_margin] + p[:hedging_fee]
    end

    # Indicative all-in borrower rate: initial cash rate + full spread stack.
    # Display/estimation only — actual funding cost floats with the cash rate.
    def indicative_borrower_rate
      V14D_OPTIMISED_PARAMS[:cash_rate_initial] + total_spread
    end

    # As a percentage number for display, e.g. 7.66
    def indicative_borrower_rate_pct
      (indicative_borrower_rate * 100).round(2)
    end

    # Revenue model: FP earns from FP margin (annual) + profit share (3-yr resets)
    def fp_annual_margin_rate
      V14D_OPTIMISED_PARAMS[:fp_margin]
    end

    def max_loan(home_value:)
      (home_value * V14D_OPTIMISED_PARAMS[:max_ltv]).round(0)
    end

    # ── Monte Carlo Defaults ──────────────────────────────
    # Returns params formatted for the Ruby/Python MC services
    def mc_defaults
      p = V14D_OPTIMISED_PARAMS
      {
        equity_return: p[:equity_mean],
        volatility: p[:equity_vol],
        cash_rate: p[:cash_rate_initial],
        wholesale_lending_margin: p[:wholesale_margin],
        additional_loan_margins: p[:retail_margin] + p[:fp_margin] + p[:hedging_fee],
        holiday_enter_fraction: p[:holiday_entry_level],
        holiday_exit_fraction: p[:holiday_exit_level],
        hedging_cap: p[:buffer_cap] - 1.0,   # convert to % gain cap
        hedging_max_loss: 1.0 - p[:buffer_floor], # convert to % loss floor
        hedging_cost_pa: p[:hedging_fee],
        loan_to_value: p[:max_ltv]
      }
    end

    # ── Model Info (for API/display) ──────────────────────
    def model_info
      {
        name: "Pavel's Model v14d Optimised",
        version: MODEL_VERSION,
        source: "FutureProofCalculator_Pavel_v14d (Optimised Paramters).xlsm",
        validation: "50,000-path Monte Carlo (xlsm-verified)",
        description: "P&I + index-linked ETF with asymmetric hedging collar (+40%/-20%), interest holidays, and 3-year profit share resets.",
        last_updated: "2026-05",
        parameters: V14D_OPTIMISED_PARAMS,
        risk_metrics: RISK_METRICS,
        annuity_rates: ANNUITY_RATES.transform_values { |v| "#{(v * 100).round(2)}%" }
                                    .transform_keys { |k| "#{k}yr" },
        validated_terms: VALIDATED_TERMS
      }
    end
  end
end
