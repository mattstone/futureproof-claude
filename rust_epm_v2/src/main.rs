//! FutureProof EPM Monte Carlo Engine v2
//!
//! Standalone binary that simulates the Equity Preservation Mortgage product
//! with correlated stochastic equity, interest-rate and house-price paths,
//! prepayment, mortality, holiday logic, and profit-sharing.

mod metrics;
mod mortgage;
mod output;
mod params;
mod portfolio;
mod stochastic;

use anyhow::Result;
use clap::Parser;
use rayon::prelude::*;

use params::Cli;
use stochastic::StochasticParams;

fn main() -> Result<()> {
    let cli = Cli::parse();

    let dt = 0.25; // quarterly timestep

    let sp = StochasticParams::new(
        cli.equity_mean, cli.equity_vol,
        cli.rate_kappa, cli.rate_theta, cli.rate_vol, cli.rate_initial,
        cli.house_mean, cli.house_vol,
        cli.corr_eq_rate, cli.corr_eq_house, cli.corr_rate_house,
        dt,
    );

    if cli.portfolio {
        eprintln!("Running portfolio simulation ({} cohort years × {} EPMs × {} paths)…",
            cli.cohort_years, cli.cohort_size, cli.portfolio_nsim);
        let port = portfolio::run_portfolio(&cli, &sp);
        let json = serde_json::to_string_pretty(&port)?;
        print!("{json}");
        eprintln!("\nPortfolio simulation complete.");
        return Ok(());
    }

    eprintln!("Running {} paths, tenure {} yr…", cli.nsim, cli.tenure);
    let start = std::time::Instant::now();

    let results: Vec<_> = (0..cli.nsim as u64)
        .into_par_iter()
        .map(|pid| mortgage::simulate_path(&cli, &sp, pid))
        .collect();

    let elapsed = start.elapsed();
    eprintln!("Simulation done in {:.2}s ({:.0} paths/s)",
        elapsed.as_secs_f64(),
        cli.nsim as f64 / elapsed.as_secs_f64());

    let out = metrics::aggregate(&results, &cli);

    if let Some(ref csv_path) = cli.csv_out {
        output::write_csv(csv_path, &out.yearly)?;
    }

    output::print_single(&out)?;

    Ok(())
}
