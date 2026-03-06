//! Aggregation and metrics over many simulation paths.

use serde::Serialize;

use crate::mortgage::{ExitReason, PathResult};
use crate::params::Cli;

// ── Helpers ─────────────────────────────────────────────────────────────────

fn percentile(sorted: &[f64], p: f64) -> f64 {
    if sorted.is_empty() { return 0.0; }
    let idx = p * (sorted.len() - 1) as f64;
    let lo = idx.floor() as usize;
    let hi = idx.ceil() as usize;
    let frac = idx - lo as f64;
    if lo >= sorted.len() - 1 { return sorted[sorted.len() - 1]; }
    sorted[lo] * (1.0 - frac) + sorted[hi] * frac
}

fn mean(v: &[f64]) -> f64 {
    if v.is_empty() { return 0.0; }
    v.iter().sum::<f64>() / v.len() as f64
}

fn std_err(v: &[f64]) -> f64 {
    let m = mean(v);
    let var = v.iter().map(|x| (x - m).powi(2)).sum::<f64>() / v.len() as f64;
    var.sqrt() / (v.len() as f64).sqrt()
}

// ── Per-year row ────────────────────────────────────────────────────────────

#[derive(Clone, Debug, Serialize)]
pub struct YearMetrics {
    pub year: usize,
    pub surplus_mean: f64,
    pub surplus_median: f64,
    pub surplus_p01: f64,
    pub surplus_p10: f64,
    pub surplus_p90: f64,
    pub surplus_p99: f64,
    pub deficit_prob: f64,
    pub holiday_mean: f64,
    pub holiday_median: f64,
    pub holiday_p90: f64,
    pub equity_mean: f64,
    pub house_mean: f64,
    pub rate_mean: f64,
    pub active_paths: usize, // paths still alive at this year
}

// ── Terminal summary ────────────────────────────────────────────────────────

#[derive(Clone, Debug, Serialize)]
pub struct TerminalMetrics {
    pub nsim: usize,
    pub tenure: usize,
    pub mean_surplus: f64,
    pub median_surplus: f64,
    pub surplus_p01: f64,
    pub surplus_p10: f64,
    pub surplus_p90: f64,
    pub surplus_p99: f64,
    pub deficit_probability: f64,
    pub expected_loss_given_claim: f64,
    pub fair_premium: f64,
    pub fair_premium_se: f64,
    pub loaded_premium: f64,
    pub reinsurance_partition: f64,
    pub mean_holiday_quarters: f64,
    pub prepayment_rate: f64,
    pub death_rate: f64,
    pub mean_exit_year: f64,
    pub mean_final_equity: f64,
    pub mean_final_house_index: f64,
    pub mean_final_rate: f64,
}

// ── Full output ─────────────────────────────────────────────────────────────

#[derive(Clone, Debug, Serialize)]
pub struct SimulationOutput {
    pub terminal: TerminalMetrics,
    pub yearly: Vec<YearMetrics>,
}

/// Compute all metrics from a set of path results.
pub fn aggregate(results: &[PathResult], cli: &Cli) -> SimulationOutput {
    let n = results.len() as f64;

    // ── Terminal ─────────────────────────────────────────────────────────
    let mut surpluses: Vec<f64> = results.iter().map(|r| r.surplus()).collect();
    surpluses.sort_by(|a, b| a.partial_cmp(b).unwrap());

    let deficit_count = surpluses.iter().filter(|&&s| s < 0.0).count();
    let deficit_probability = deficit_count as f64 / n;

    // Expected loss given claim (average deficit among deficits)
    let deficits: Vec<f64> = surpluses.iter().filter(|&&s| s < 0.0).map(|&s| -s).collect();
    let elgc = if deficits.is_empty() { 0.0 } else { mean(&deficits) };

    // Fair premium = E[max(0, deficit)] discounted at mean terminal rate
    let mean_rate = mean(&results.iter().map(|r| r.final_rate).collect::<Vec<_>>());
    let discount = (1.0 + mean_rate).powi(cli.tenure as i32);
    let pv_losses: Vec<f64> = results.iter()
        .map(|r| (-r.surplus()).max(0.0) / discount)
        .collect();
    let fair_premium = mean(&pv_losses);
    let fair_premium_se = std_err(&pv_losses);
    let loaded_premium = fair_premium * (1.0 + cli.lmi_upfront);
    let reinsurance_partition = fair_premium * cli.reinsurance_factor;

    let prepay_count = results.iter().filter(|r| r.exit_reason == ExitReason::Prepayment).count();
    let death_count = results.iter().filter(|r| r.exit_reason == ExitReason::Death).count();

    let terminal = TerminalMetrics {
        nsim: results.len(),
        tenure: cli.tenure,
        mean_surplus: mean(&surpluses),
        median_surplus: percentile(&surpluses, 0.5),
        surplus_p01: percentile(&surpluses, 0.01),
        surplus_p10: percentile(&surpluses, 0.10),
        surplus_p90: percentile(&surpluses, 0.90),
        surplus_p99: percentile(&surpluses, 0.99),
        deficit_probability,
        expected_loss_given_claim: elgc,
        fair_premium,
        fair_premium_se,
        loaded_premium,
        reinsurance_partition,
        mean_holiday_quarters: mean(&results.iter().map(|r| r.total_holiday_quarters as f64).collect::<Vec<_>>()),
        prepayment_rate: prepay_count as f64 / n,
        death_rate: death_count as f64 / n,
        mean_exit_year: mean(&results.iter().map(|r| r.exit_year as f64).collect::<Vec<_>>()),
        mean_final_equity: mean(&results.iter().map(|r| r.final_equity_index).collect::<Vec<_>>()),
        mean_final_house_index: mean(&results.iter().map(|r| r.final_house_index).collect::<Vec<_>>()),
        mean_final_rate: mean_rate,
    };

    // ── Per-year ────────────────────────────────────────────────────────
    let max_year = cli.tenure;
    let mut yearly = Vec::with_capacity(max_year);

    for yr in 1..=max_year {
        // Collect snapshots for this year from paths that are still alive
        let mut surp = Vec::new();
        let mut hol = Vec::new();
        let mut eq = Vec::new();
        let mut house = Vec::new();
        let mut rate_v = Vec::new();

        for r in results {
            if let Some(snap) = r.year_snapshots.iter().find(|s| s.year == yr) {
                surp.push(snap.balance_surplus);
                hol.push(snap.holiday_quarters as f64);
                eq.push(snap.equity_index);
                house.push(snap.house_index);
                rate_v.push(snap.cash_rate);
            }
        }

        surp.sort_by(|a, b| a.partial_cmp(b).unwrap());
        hol.sort_by(|a, b| a.partial_cmp(b).unwrap());

        let active = surp.len();
        let deficit_cnt = surp.iter().filter(|&&s| s < 0.0).count();

        yearly.push(YearMetrics {
            year: yr,
            surplus_mean: mean(&surp),
            surplus_median: percentile(&surp, 0.5),
            surplus_p01: percentile(&surp, 0.01),
            surplus_p10: percentile(&surp, 0.10),
            surplus_p90: percentile(&surp, 0.90),
            surplus_p99: percentile(&surp, 0.99),
            deficit_prob: if active > 0 { deficit_cnt as f64 / active as f64 } else { 0.0 },
            holiday_mean: mean(&hol),
            holiday_median: percentile(&hol, 0.5),
            holiday_p90: percentile(&hol, 0.9),
            equity_mean: mean(&eq),
            house_mean: mean(&house),
            rate_mean: mean(&rate_v),
            active_paths: active,
        });
    }

    SimulationOutput { terminal, yearly }
}
