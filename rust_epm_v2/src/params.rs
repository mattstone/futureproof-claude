//! CLI parameters and default constants for the EPM model.
//!
//! Every magic number from the Excel v10 model is surfaced here as either a
//! CLI flag (via `clap`) or a named constant.

use clap::Parser;

// ── Excel v10 defaults ──────────────────────────────────────────────────────

pub const HOME_VALUE: f64 = 2_000_000.0;
pub const LVR: f64 = 0.80;
pub const MAX_LOAN: f64 = 1_600_000.0;
pub const INITIAL_LOAN: f64 = 1_250_000.0;
pub const TENURE_YEARS: usize = 30;
pub const ANNUITY_PAYMENT_PA: f64 = 35_000.0;
pub const ANNUITY_TERM_YEARS: usize = 10;
pub const HOLIDAY_ENTRY: f64 = 0.9;
pub const HOLIDAY_EXIT: f64 = 1.458;
pub const PROFIT_SHARE_INTERVAL: usize = 5;
pub const PROFIT_SHARE_FRACTION: f64 = 0.20;
pub const CAP: f64 = 1.4;
pub const FLOOR: f64 = 0.8;
pub const NSIM: usize = 50_000;

// Stochastic – equity (S&P 500)
pub const EQUITY_MEAN: f64 = 0.10;
pub const EQUITY_VOL: f64 = 0.10;
pub const EQUITY_S0: f64 = 1.0; // normalised

// Stochastic – cash rate (Vasicek)
pub const RATE_INITIAL: f64 = 0.044;
pub const RATE_MEAN_REV_LEVEL: f64 = 0.044;
pub const RATE_MEAN_REV_SPEED: f64 = 0.8;
pub const RATE_VOL: f64 = 0.015;

// Stochastic – house prices (GBM)
pub const HOUSE_MEAN: f64 = 0.03;
pub const HOUSE_VOL: f64 = 0.12;

// Correlations
pub const CORR_EQUITY_RATE: f64 = 0.2;
pub const CORR_EQUITY_HOUSE: f64 = 0.3;
pub const CORR_RATE_HOUSE: f64 = -0.2;

// Cost stack
pub const WHOLESALE_MARGIN: f64 = 0.02;
pub const RETAIL_MARGIN: f64 = 0.0075;
pub const HEDGING_COST: f64 = 0.0036;
pub const FP_MARGIN: f64 = 0.0025;
pub const LMI_UPFRONT: f64 = 0.0125;
pub const REINSURANCE_FACTOR: f64 = 0.2;

// Prepayment / mortality
pub const PREPAYMENT_RATE_PA: f64 = 0.03;
pub const BORROWER_START_AGE: f64 = 65.0;
pub const GOMPERTZ_ALPHA: f64 = 0.00005;
pub const GOMPERTZ_BETA: f64 = 0.087;

// ── CLI ─────────────────────────────────────────────────────────────────────

#[derive(Parser, Debug, Clone)]
#[command(name = "epm", about = "FutureProof EPM Monte Carlo Engine v2")]
pub struct Cli {
    /// Number of simulation paths
    #[arg(long, default_value_t = NSIM)]
    pub nsim: usize,

    /// Loan tenure in years
    #[arg(long, default_value_t = TENURE_YEARS)]
    pub tenure: usize,

    /// Initial loan amount
    #[arg(long, default_value_t = INITIAL_LOAN)]
    pub loan: f64,

    /// Home value
    #[arg(long, default_value_t = HOME_VALUE)]
    pub home_value: f64,

    /// Annuity payment per year
    #[arg(long, default_value_t = ANNUITY_PAYMENT_PA)]
    pub annuity_pa: f64,

    /// Annuity term in years
    #[arg(long, default_value_t = ANNUITY_TERM_YEARS)]
    pub annuity_term: usize,

    /// Holiday entry threshold (fraction of initial investment)
    #[arg(long, default_value_t = HOLIDAY_ENTRY)]
    pub holiday_entry: f64,

    /// Holiday exit threshold (fraction of initial investment)
    #[arg(long, default_value_t = HOLIDAY_EXIT)]
    pub holiday_exit: f64,

    /// Profit share fraction (e.g. 0.20 = 20%)
    #[arg(long, default_value_t = PROFIT_SHARE_FRACTION)]
    pub profit_share: f64,

    /// Profit share interval in years
    #[arg(long, default_value_t = PROFIT_SHARE_INTERVAL)]
    pub profit_share_interval: usize,

    /// Cap on equity index performance
    #[arg(long, default_value_t = CAP)]
    pub cap: f64,

    /// Floor on equity index performance
    #[arg(long, default_value_t = FLOOR)]
    pub floor: f64,

    // ── Equity ──
    #[arg(long, default_value_t = EQUITY_MEAN)]
    pub equity_mean: f64,
    #[arg(long, default_value_t = EQUITY_VOL)]
    pub equity_vol: f64,

    // ── Rate ──
    #[arg(long, default_value_t = RATE_INITIAL)]
    pub rate_initial: f64,
    #[arg(long, default_value_t = RATE_MEAN_REV_LEVEL)]
    pub rate_theta: f64,
    #[arg(long, default_value_t = RATE_MEAN_REV_SPEED)]
    pub rate_kappa: f64,
    #[arg(long, default_value_t = RATE_VOL)]
    pub rate_vol: f64,

    // ── House ──
    #[arg(long, default_value_t = HOUSE_MEAN)]
    pub house_mean: f64,
    #[arg(long, default_value_t = HOUSE_VOL)]
    pub house_vol: f64,

    // ── Correlations ──
    #[arg(long, default_value_t = CORR_EQUITY_RATE)]
    pub corr_eq_rate: f64,
    #[arg(long, default_value_t = CORR_EQUITY_HOUSE)]
    pub corr_eq_house: f64,
    #[arg(long, default_value_t = CORR_RATE_HOUSE)]
    pub corr_rate_house: f64,

    // ── Cost stack ──
    #[arg(long, default_value_t = WHOLESALE_MARGIN)]
    pub wholesale_margin: f64,
    #[arg(long, default_value_t = RETAIL_MARGIN)]
    pub retail_margin: f64,
    #[arg(long, default_value_t = HEDGING_COST)]
    pub hedging_cost: f64,
    #[arg(long, default_value_t = FP_MARGIN)]
    pub fp_margin: f64,
    #[arg(long, default_value_t = LMI_UPFRONT)]
    pub lmi_upfront: f64,
    #[arg(long, default_value_t = REINSURANCE_FACTOR)]
    pub reinsurance_factor: f64,

    // ── Prepayment / mortality ──
    #[arg(long, default_value_t = PREPAYMENT_RATE_PA)]
    pub prepayment_rate: f64,
    #[arg(long, default_value_t = BORROWER_START_AGE)]
    pub start_age: f64,
    #[arg(long, default_value_t = GOMPERTZ_ALPHA)]
    pub gompertz_alpha: f64,
    #[arg(long, default_value_t = GOMPERTZ_BETA)]
    pub gompertz_beta: f64,

    /// Disable prepayment modelling
    #[arg(long, default_value_t = false)]
    pub no_prepayment: bool,

    /// Disable mortality modelling
    #[arg(long, default_value_t = false)]
    pub no_mortality: bool,

    /// Write per-year CSV detail to this path
    #[arg(long)]
    pub csv_out: Option<String>,

    /// Run portfolio simulation instead of single EPM
    #[arg(long, default_value_t = false)]
    pub portfolio: bool,

    /// Portfolio: EPMs per cohort year
    #[arg(long, default_value_t = 1000)]
    pub cohort_size: usize,

    /// Portfolio: number of cohort years
    #[arg(long, default_value_t = 10)]
    pub cohort_years: usize,

    /// Portfolio: paths per EPM (lower for speed)
    #[arg(long, default_value_t = 1000)]
    pub portfolio_nsim: usize,

    /// Use principal & interest repayment (default: interest only)
    #[arg(long, default_value_t = false)]
    pub principal_and_interest: bool,

    /// Random seed (0 = random)
    #[arg(long, default_value_t = 42)]
    pub seed: u64,
}

impl Cli {
    /// Total variable cost margin p.a.
    pub fn variable_cost_margin(&self) -> f64 {
        self.wholesale_margin + self.retail_margin + self.hedging_cost + self.fp_margin
    }
}
