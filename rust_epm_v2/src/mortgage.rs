//! Single-EPM mortgage simulation.
//!
//! Simulates one EPM over its tenure with quarterly timesteps, stochastic
//! equity/rate/house-price paths, holiday logic, profit-sharing, prepayment
//! and mortality.

use rand::rngs::StdRng;
use rand::Rng;
use rand::SeedableRng;

use crate::params::Cli;
use crate::stochastic::{self, StochasticParams};

/// Per-year snapshot for a single path.
#[derive(Clone, Debug, Default)]
pub struct YearSnapshot {
    pub year: usize,
    pub balance_surplus: f64,   // holdings − loan − deferred
    pub equity_index: f64,      // normalised equity level
    pub house_index: f64,       // normalised house level
    pub cash_rate: f64,
    pub holiday_quarters: usize,
    pub on_holiday: bool,
    pub deferred_interest: f64,
    pub holdings_value: f64,
    pub loan_size: f64,
}

/// Terminal result for one path.
#[derive(Clone, Debug)]
pub struct PathResult {
    pub final_holdings: f64,
    pub final_loan: f64,
    pub deferred_interest: f64,
    pub total_holiday_quarters: usize,
    pub exit_year: usize,        // < tenure means early exit
    pub exit_reason: ExitReason,
    pub final_equity_index: f64,
    pub final_house_index: f64,
    pub final_rate: f64,
    pub home_value: f64,         // stochastic terminal home value
    pub year_snapshots: Vec<YearSnapshot>,
}

#[derive(Clone, Debug, PartialEq)]
pub enum ExitReason {
    Maturity,
    Prepayment,
    Death,
}

impl PathResult {
    /// Net surplus (positive = funded, negative = deficit / insurance claim).
    pub fn surplus(&self) -> f64 {
        self.final_holdings - self.final_loan - self.deferred_interest
    }
}

/// Run a single path simulation. `path_id` is used to seed the RNG.
pub fn simulate_path(
    cli: &Cli,
    sp: &StochasticParams,
    path_id: u64,
) -> PathResult {
    let seed = if cli.seed == 0 { path_id } else { cli.seed.wrapping_add(path_id) };
    let mut rng = StdRng::seed_from_u64(seed);

    let total_quarters = cli.tenure * 4;
    let annuity_quarters = cli.annuity_term * 4;
    let quarterly_annuity = cli.annuity_pa / 4.0;
    let variable_margin = cli.variable_cost_margin();

    // Initial investment: the loan goes into the equity index (normalised at 1.0)
    let initial_investment = cli.loan;
    let mut units = initial_investment; // since S0 = 1.0, units = investment / S0
    let mut loan_size = cli.loan + quarterly_annuity; // Excel: loan starts + first annuity
    let mut deferred_interest = 0.0_f64;
    let mut rate = sp.rate_init;
    let mut equity_index = 1.0_f64;
    let mut house_index = 1.0_f64;

    let holiday_enter_val = initial_investment * cli.holiday_entry;
    let holiday_exit_val = initial_investment * cli.holiday_exit;
    let mut on_holiday = cli.holiday_entry > 1.0;
    let mut total_holiday_quarters = 0_usize;
    let mut current_year_holiday = 0_usize;
    let mut exit_reason = ExitReason::Maturity;
    let mut exit_year = cli.tenure;

    let mut year_snapshots: Vec<YearSnapshot> = Vec::with_capacity(cli.tenure);

    // Gompertz mortality pre-calc
    let use_mortality = !cli.no_mortality;
    let use_prepayment = !cli.no_prepayment;
    let quarterly_prepayment_prob = 1.0 - (1.0 - cli.prepayment_rate).powf(0.25);

    // Last profit-share equity index level
    let mut last_profit_share_index = 1.0_f64;

    for q in 1..=total_quarters {
        // ── Stochastic step ─────────────────────────────────────────────
        let (eq_factor, new_rate, house_factor) = stochastic::step(sp, rate, &mut rng);
        rate = new_rate;
        equity_index *= eq_factor;
        house_index *= house_factor;

        let holdings_value = units * equity_index;

        // ── Interest ────────────────────────────────────────────────────
        let quarterly_rate = rate / 4.0 + variable_margin / 4.0;
        let interest_due = loan_size * quarterly_rate;
        let interest_per_unit = interest_due / equity_index;

        // ── Holiday logic ───────────────────────────────────────────────
        if on_holiday {
            if holdings_value > holiday_exit_val {
                on_holiday = false;
                units -= interest_per_unit;
                current_year_holiday = 0;
            } else {
                current_year_holiday += 1;
                total_holiday_quarters += 1;
                deferred_interest += interest_due;
            }
        } else if holdings_value < holiday_enter_val {
            on_holiday = true;
            current_year_holiday += 1;
            total_holiday_quarters += 1;
            deferred_interest += interest_due;
        } else {
            current_year_holiday = 0;
            units -= interest_per_unit;

            // Super-pay: if above exit threshold and deferred > 0, pay extra
            if holdings_value > holiday_exit_val && deferred_interest > 0.0 {
                let extra = interest_due.min(deferred_interest);
                units -= extra / equity_index;
                deferred_interest -= extra;
            }
        }

        // ── Principal repayment (if P&I mode) ────────────────────────────
        if cli.principal_and_interest && !on_holiday {
            let quarterly_principal = cli.loan / (total_quarters as f64);
            let principal_units = quarterly_principal / equity_index;
            units -= principal_units;
            loan_size -= quarterly_principal;
        }

        // ── Annuity (loan grows) ────────────────────────────────────────
        if q < annuity_quarters {
            if cli.principal_and_interest {
                // In P&I mode, sell units to fund the annuity payment
                let annuity_units = quarterly_annuity / equity_index;
                units -= annuity_units;
            } else {
                // Interest-only: annuity just adds to the loan
                loan_size += quarterly_annuity;
            }
        }

        // ── Profit share (every N years) ────────────────────────────────
        if q % (cli.profit_share_interval * 4) == 0 {
            let period_return = equity_index / last_profit_share_index;
            let capped = period_return.min(cli.cap).max(cli.floor);
            if capped > 1.0 {
                let surplus_units = units * (1.0 - 1.0 / capped) * cli.profit_share;
                units -= surplus_units;
            }
            last_profit_share_index = equity_index;
        }

        // ── Year-end snapshot ───────────────────────────────────────────
        if q % 4 == 0 {
            let year = q / 4;
            year_snapshots.push(YearSnapshot {
                year,
                balance_surplus: units * equity_index - loan_size - deferred_interest,
                equity_index,
                house_index,
                cash_rate: rate,
                holiday_quarters: current_year_holiday,
                on_holiday,
                deferred_interest,
                holdings_value: units * equity_index,
                loan_size,
            });
            current_year_holiday = 0;
        }

        // ── Prepayment check (quarterly) ────────────────────────────────
        if use_prepayment && rng.gen::<f64>() < quarterly_prepayment_prob {
            exit_reason = ExitReason::Prepayment;
            exit_year = (q + 3) / 4;
            return PathResult {
                final_holdings: units * equity_index,
                final_loan: loan_size,
                deferred_interest,
                total_holiday_quarters,
                exit_year,
                exit_reason,
                final_equity_index: equity_index,
                final_house_index: house_index,
                final_rate: rate,
                home_value: cli.home_value * house_index,
                year_snapshots,
            };
        }

        // ── Mortality check (quarterly, Gompertz) ───────────────────────
        if use_mortality {
            let age = cli.start_age + (q as f64) / 4.0;
            // Gompertz hazard rate: μ(x) = α exp(β x), integrate over quarter
            let hazard = cli.gompertz_alpha * (cli.gompertz_beta * age).exp();
            let quarterly_death_prob = 1.0 - (-hazard * 0.25).exp();
            if rng.gen::<f64>() < quarterly_death_prob {
                exit_reason = ExitReason::Death;
                exit_year = (q + 3) / 4;
                return PathResult {
                    final_holdings: units * equity_index,
                    final_loan: loan_size,
                    deferred_interest,
                    total_holiday_quarters,
                    exit_year,
                    exit_reason,
                    final_equity_index: equity_index,
                    final_house_index: house_index,
                    final_rate: rate,
                    home_value: cli.home_value * house_index,
                    year_snapshots,
                };
            }
        }
    }

    PathResult {
        final_holdings: units * equity_index,
        final_loan: loan_size,
        deferred_interest,
        total_holiday_quarters,
        exit_year,
        exit_reason,
        final_equity_index: equity_index,
        final_house_index: house_index,
        final_rate: rate,
        home_value: cli.home_value * house_index,
        year_snapshots,
    }
}
