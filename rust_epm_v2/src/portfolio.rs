//! Portfolio-level simulation: multiple cohorts of EPMs.

use rayon::prelude::*;
use serde::Serialize;

use crate::metrics;
use crate::mortgage;
use crate::params::Cli;
use crate::stochastic::StochasticParams;

#[derive(Clone, Debug, Serialize)]
pub struct CohortSummary {
    pub cohort_year: usize,
    pub tenure: usize,
    pub count: usize,
    pub mean_surplus: f64,
    pub deficit_probability: f64,
    pub fair_premium: f64,
    pub prepayment_rate: f64,
    pub death_rate: f64,
}

#[derive(Clone, Debug, Serialize)]
pub struct PortfolioOutput {
    pub cohorts: Vec<CohortSummary>,
    pub total_epms: usize,
    pub aggregate_mean_surplus: f64,
    pub aggregate_deficit_prob: f64,
    pub aggregate_fair_premium: f64,
}

/// Run the portfolio simulation.
///
/// For each cohort year, spawn `cohort_size` EPMs split evenly across
/// 15/20/25/30-year tenures, each with `portfolio_nsim` MC paths.
pub fn run_portfolio(cli: &Cli, sp: &StochasticParams) -> PortfolioOutput {
    let tenures = [15_usize, 20, 25, 30];
    let per_tenure = cli.cohort_size / tenures.len();

    // Build all (cohort_year, tenure) pairs upfront
    let pairs: Vec<(usize, usize)> = (0..cli.cohort_years)
        .flat_map(|cy| tenures.iter().map(move |&t| (cy, t)))
        .collect();

    let cohorts: Vec<CohortSummary> = pairs
        .into_par_iter()
        .map(|(cy, tenure)| {
            let mut c = cli.clone();
            c.tenure = tenure;
            c.nsim = cli.portfolio_nsim;
            // Offset seed per cohort so paths differ
            c.seed = cli.seed.wrapping_add((cy * 1_000_000 + tenure * 10_000) as u64);

            let results: Vec<_> = (0..c.nsim as u64)
                .into_par_iter()
                .map(|pid| mortgage::simulate_path(&c, sp, pid))
                .collect();

            let out = metrics::aggregate(&results, &c);

            CohortSummary {
                cohort_year: cy + 1,
                tenure,
                count: per_tenure,
                mean_surplus: out.terminal.mean_surplus,
                deficit_probability: out.terminal.deficit_probability,
                fair_premium: out.terminal.fair_premium,
                prepayment_rate: out.terminal.prepayment_rate,
                death_rate: out.terminal.death_rate,
            }
        })
        .collect();

    let total_epms: usize = cohorts.iter().map(|c| c.count).sum();
    let total_weighted: f64 = cohorts.iter().map(|c| c.count as f64).sum();
    let agg_surplus = cohorts.iter().map(|c| c.mean_surplus * c.count as f64).sum::<f64>() / total_weighted;
    let agg_deficit = cohorts.iter().map(|c| c.deficit_probability * c.count as f64).sum::<f64>() / total_weighted;
    let agg_fp = cohorts.iter().map(|c| c.fair_premium * c.count as f64).sum::<f64>() / total_weighted;

    PortfolioOutput {
        cohorts,
        total_epms,
        aggregate_mean_surplus: agg_surplus,
        aggregate_deficit_prob: agg_deficit,
        aggregate_fair_premium: agg_fp,
    }
}
