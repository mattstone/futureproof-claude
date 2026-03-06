//! Output helpers: JSON to stdout, optional CSV.

use std::io::Write;
use anyhow::Result;

use crate::metrics::{SimulationOutput, YearMetrics};

/// Write per-year detail to CSV.
pub fn write_csv(path: &str, yearly: &[YearMetrics]) -> Result<()> {
    let mut wtr = csv::Writer::from_path(path)?;
    for row in yearly {
        wtr.serialize(row)?;
    }
    wtr.flush()?;
    eprintln!("Wrote yearly CSV to {path}");
    Ok(())
}

fn fmt_dollar(v: f64) -> String {
    let abs = v.abs() as u64;
    let s = abs.to_string();
    let mut result = String::new();
    for (i, c) in s.chars().rev().enumerate() {
        if i > 0 && i % 3 == 0 { result.push(','); }
        result.push(c);
    }
    let formatted: String = result.chars().rev().collect();
    if v < 0.0 { format!("-${formatted}") } else { format!("${formatted}") }
}

/// Pretty-print a summary to stderr (human-readable) and JSON to stdout.
pub fn print_single(output: &SimulationOutput) -> Result<()> {
    let t = &output.terminal;
    eprintln!("═══ FutureProof EPM v2 – Single EPM Summary ═══");
    eprintln!("  Paths:              {}", t.nsim);
    eprintln!("  Tenure:             {} yr", t.tenure);
    eprintln!("  Mean surplus:       {:>14}", fmt_dollar(t.mean_surplus));
    eprintln!("  Median surplus:     {:>14}", fmt_dollar(t.median_surplus));
    eprintln!("  P01 surplus:        {:>14}", fmt_dollar(t.surplus_p01));
    eprintln!("  P10 surplus:        {:>14}", fmt_dollar(t.surplus_p10));
    eprintln!("  P90 surplus:        {:>14}", fmt_dollar(t.surplus_p90));
    eprintln!("  P99 surplus:        {:>14}", fmt_dollar(t.surplus_p99));
    eprintln!("  Deficit probability: {:.2}%", t.deficit_probability * 100.0);
    eprintln!("  E[loss|claim]:      {:>14}", fmt_dollar(t.expected_loss_given_claim));
    eprintln!("  Fair premium (PV):  {:>14}", fmt_dollar(t.fair_premium));
    eprintln!("  Fair premium SE:    {:>14}", fmt_dollar(t.fair_premium_se));
    eprintln!("  Loaded premium:     {:>14}", fmt_dollar(t.loaded_premium));
    eprintln!("  Reinsurance part:   {:>14}", fmt_dollar(t.reinsurance_partition));
    eprintln!("  Mean holiday qtrs:  {:.1}", t.mean_holiday_quarters);
    eprintln!("  Prepayment rate:    {:.1}%", t.prepayment_rate * 100.0);
    eprintln!("  Death rate:         {:.1}%", t.death_rate * 100.0);
    eprintln!("  Mean exit year:     {:.1}", t.mean_exit_year);
    eprintln!("  Mean final equity:  {:.4}", t.mean_final_equity);
    eprintln!("  Mean final house:   {:.4}", t.mean_final_house_index);
    eprintln!("  Mean final rate:    {:.4}", t.mean_final_rate);
    eprintln!("═══════════════════════════════════════════════");

    let json = serde_json::to_string_pretty(output)?;
    std::io::stdout().write_all(json.as_bytes())?;
    std::io::stdout().write_all(b"\n")?;
    Ok(())
}
