use pyo3::prelude::*;
use rand::SeedableRng;
use rand_distr::{Distribution, Normal};
use rayon::prelude::*;

/// Generate Monte Carlo price paths using Geometric Brownian Motion
/// Returns a 2D vector where each inner vector is a price path
#[pyfunction]
fn gen_monte_carlo_paths(
    loan_duration_years: usize,
    equity_return: f64,
    volatility: f64,
    num_paths: usize,
    s0: f64,
) -> PyResult<Vec<Vec<f64>>> {
    let dt = 1.0 / 120.0; // dt = 1/120 (120 steps per year)
    let n_steps = ((loan_duration_years as f64) / dt).round() as usize; // Total timesteps

    // Generate paths in parallel using rayon
    let paths: Vec<Vec<f64>> = (0..num_paths)
        .into_par_iter()
        .map(|seed| {
            let mut rng = rand::rngs::StdRng::seed_from_u64(seed as u64);
            let normal = Normal::new(0.0, 1.0).unwrap();

            let mut path = Vec::with_capacity(n_steps);
            let mut price = s0;
            path.push(price);

            // Geometric Brownian Motion: dS = μ*S*dt + σ*S*dW
            let drift = (equity_return - 0.5 * volatility * volatility) * dt;
            let diffusion = volatility * dt.sqrt();

            for _ in 1..n_steps {
                let dw = normal.sample(&mut rng);
                price *= (drift + diffusion * dw).exp();
                path.push(price);
            }

            path
        })
        .collect();

    Ok(paths)
}

/// Single mortgage simulation with pre-generated paths
/// This is the core Monte Carlo engine
#[pyfunction]
#[allow(clippy::too_many_arguments)]
fn single_mortgage_rust(
    total_loan: f64,
    reinvest_fraction: f64,
    loan_duration: usize,
    annual_income: f64,
    annuity_duration: usize,
    insurance_profit_margin: f64,
    insurance_cost: f64,
    cash_rate: f64,
    wholesale_lending_margin: f64,
    additional_loan_margins: f64,
    holiday_enter_fraction: f64,
    holiday_exit_fraction: f64,
    subperform_loan_threshold_quarters: usize,
    price_paths: Vec<Vec<f64>>,
    s0: f64,
    principal_repayment: bool,
    hedged: bool,
    hedging_max_loss: f64,
    hedging_cap: f64,
    hedging_cost_pa: f64,
) -> PyResult<Vec<MortgageResult>> {
    let num_paths = price_paths.len();
    let total_periods = loan_duration * 4; // Quarterly periods

    // Calculate initial values
    let insurance_pv = (insurance_cost * insurance_profit_margin)
        / (1.0 + cash_rate).powi(loan_duration as i32);
    let initial_investment = total_loan * reinvest_fraction - insurance_pv;
    let initial_units = initial_investment / s0;

    let quarterly_income = annual_income / 4.0;
    let holiday_enter_threshold = initial_investment * holiday_enter_fraction;
    let holiday_exit_threshold = initial_investment * holiday_exit_fraction;

    // Pre-calculate constants outside the loop
    let quarterly_cash_rate = cash_rate / 4.0;
    let total_margin = wholesale_lending_margin + additional_loan_margins;
    let quarterly_interest_rate = quarterly_cash_rate + (total_margin / 4.0);
    let hedging_cost_quarterly = if hedged {
        hedging_cost_pa * total_loan / 4.0
    } else {
        0.0
    };
    let annuity_duration_quarters = annuity_duration * 4;
    let loan_duration_quarters = loan_duration * 4;

    // Process all paths in parallel
    let results: Vec<MortgageResult> = (0..num_paths)
        .into_par_iter()
        .map(|path_idx| {
            let price_path = &price_paths[path_idx];

            let mut sp500_units = initial_units;  // holdings in Python
            let mut loan_size = total_loan * reinvest_fraction + quarterly_income;  // KEY: starts HIGHER than principal
            let mut cum_interest_deficit = 0.0;  // deferred in Python
            let mut on_holiday = holiday_enter_fraction > 1.0;  // Start on holiday if threshold > 1
            let mut quarters_in_holiday = 0;
            let mut last_yearly_hedge_price = s0;
            let mut last_5yearly_hedge_price = s0;

            // Simulate each quarter
            for period in 1..=total_periods {
                // Python uses: price_indices = (period * dt_quarter_inv - 1)
                // where dt_quarter_inv = 1.0 / (dt * 4) = 1.0 / (1/120 * 4) = 30
                let month_idx = ((period * 30) - 1).min(price_path.len() - 1);
                let sp500_price = price_path[month_idx];

                // Calculate holdings value
                let holdings_value = sp500_units * sp500_price;

                // Calculate interest on GROWING loan_size
                let interest_due = loan_size * quarterly_interest_rate;
                let interest_due_per_share = interest_due / sp500_price;

                // Holiday logic - EXACTLY as Python
                let mut interest_paid = 0.0;

                if on_holiday {
                    if holdings_value > holiday_exit_threshold {
                        // Exit holiday and pay interest
                        on_holiday = false;
                        sp500_units -= interest_due_per_share;
                        interest_paid = interest_due;
                        quarters_in_holiday = 0;
                    } else {
                        // Stay on holiday, defer interest
                        quarters_in_holiday += 1;
                        cum_interest_deficit += interest_due;
                    }
                } else {
                    if holdings_value < holiday_enter_threshold {
                        // Enter holiday, defer interest
                        cum_interest_deficit += interest_due;
                        on_holiday = true;
                        quarters_in_holiday += 1;
                    } else {
                        // Normal operation - pay interest
                        quarters_in_holiday = 0;
                        sp500_units -= interest_due_per_share;
                        interest_paid = interest_due;

                        // Superpay logic: If holdings are above exit threshold and there's deferred interest,
                        // use surplus to pay down the deficit (Python lines 256-264)
                        // Default params: max_superpay_factor=1.0, superpay_start_factor=1.0, insured_units=0
                        if holdings_value > holiday_exit_threshold && cum_interest_deficit > 0.0 {
                            // Pay down deficit using surplus (up to 1x current interest payment)
                            let surplus_pay = interest_due.min(cum_interest_deficit);
                            let surplus_pay_per_share = surplus_pay / sp500_price;
                            sp500_units -= surplus_pay_per_share;
                            cum_interest_deficit -= surplus_pay;
                        }
                    }
                }

                // Principal repayment (if enabled)
                if principal_repayment {
                    let principal_payment = total_loan / loan_duration_quarters as f64;
                    let units_for_principal = principal_payment / sp500_price;
                    sp500_units -= units_for_principal;
                }

                // Hedging logic - EXACTLY as Python
                if hedged {
                    // Yearly hedge (every 4 quarters)
                    if period % 4 == 0 {
                        // Deduct hedging cost
                        sp500_units -= sp500_units * hedging_cost_pa;

                        // Check if need to buy units (protection against drops > 20%)
                        let year_move = (sp500_price - last_yearly_hedge_price) / last_yearly_hedge_price;
                        if year_move < -hedging_max_loss {
                            let buy_units = ((last_yearly_hedge_price / sp500_price) * (1.0 - hedging_max_loss) - 1.0) * sp500_units;
                            sp500_units += buy_units;
                        }
                        last_yearly_hedge_price = sp500_price;
                    }

                    // 5-yearly hedge cap (every 20 quarters)
                    if period % 20 == 0 {
                        let year_move = (sp500_price - last_5yearly_hedge_price) / last_5yearly_hedge_price;
                        let adj_holds = sp500_units * (last_5yearly_hedge_price / sp500_price) * (1.0 + hedging_cap * 5.0);
                        if sp500_units > adj_holds {
                            sp500_units -= sp500_units - adj_holds;  // Sell excess
                        }
                        last_5yearly_hedge_price = sp500_price;
                    }
                }

                // Pay annuity (AFTER interest calculations, and grows loan_size)
                // Python uses: if t < annuity_duration_quarters (NOT <=)
                if period < annuity_duration_quarters {
                    // KEY: Only sell units if doing progressive repayment!
                    // Otherwise just increase the loan size
                    if principal_repayment {
                        let units_for_principal = quarterly_income / sp500_price;
                        sp500_units -= units_for_principal;
                    } else {
                        // NOT progressive repayment: loan grows, units stay same
                        loan_size += quarterly_income;
                    }
                }
            }

            // Final values
            let final_price = price_path[price_path.len() - 1];
            let final_reinvestment = sp500_units * final_price;

            MortgageResult {
                reinvestment: final_reinvestment,
                interest_deficit: cum_interest_deficit,
                quarters_in_holiday,
            }
        })
        .collect();

    Ok(results)
}

/// Optimized: Generate paths and simulate in one pass (no memory overhead)
/// This avoids storing all paths in memory - generates them on-the-fly
#[pyfunction]
#[allow(clippy::too_many_arguments)]
fn single_mortgage_integrated(
    total_loan: f64,
    reinvest_fraction: f64,
    loan_duration: usize,
    annual_income: f64,
    annuity_duration: usize,
    insurance_profit_margin: f64,
    insurance_cost: f64,
    cash_rate: f64,
    wholesale_lending_margin: f64,
    additional_loan_margins: f64,
    holiday_enter_fraction: f64,
    holiday_exit_fraction: f64,
    subperform_loan_threshold_quarters: usize,
    num_paths: usize,
    equity_return: f64,
    volatility: f64,
    s0: f64,
    principal_repayment: bool,
    hedged: bool,
    hedging_max_loss: f64,
    hedging_cap: f64,
    hedging_cost_pa: f64,
) -> PyResult<Vec<MortgageResult>> {
    let dt = 1.0 / 120.0;
    let n_steps = ((loan_duration as f64) / dt).round() as usize;
    let total_periods = loan_duration * 4; // Quarterly periods

    // Calculate initial values
    let insurance_pv = (insurance_cost * insurance_profit_margin)
        / (1.0 + cash_rate).powi(loan_duration as i32);
    let initial_investment = total_loan * reinvest_fraction - insurance_pv;
    let initial_units = initial_investment / s0;

    let quarterly_income = annual_income / 4.0;
    let holiday_enter_threshold = initial_investment * holiday_enter_fraction;
    let holiday_exit_threshold = initial_investment * holiday_exit_fraction;

    // GBM parameters
    let drift = (equity_return - 0.5 * volatility * volatility) * dt;
    let diffusion = volatility * dt.sqrt();

    // Pre-calculate constants outside the loop
    let quarterly_cash_rate = cash_rate / 4.0;
    let total_margin = wholesale_lending_margin + additional_loan_margins;
    let quarterly_interest_rate = quarterly_cash_rate + (total_margin / 4.0);
    let hedging_cost_quarterly = if hedged {
        hedging_cost_pa * total_loan / 4.0
    } else {
        0.0
    };
    let annuity_duration_quarters = annuity_duration * 4;
    let loan_duration_quarters = loan_duration * 4;

    // Process all paths in parallel, generating paths on-the-fly
    let results: Vec<MortgageResult> = (0..num_paths)
        .into_par_iter()
        .map(|seed| {
            // Generate path on-the-fly for this simulation
            let mut rng = rand::rngs::StdRng::seed_from_u64(seed as u64);
            let normal = Normal::new(0.0, 1.0).unwrap();

            // Generate full path but only store it transiently
            let mut path = Vec::with_capacity(n_steps);
            let mut price = s0;
            path.push(price);

            for _ in 1..n_steps {
                let dw = normal.sample(&mut rng);
                price *= (drift + diffusion * dw).exp();
                path.push(price);
            }

            // Now simulate mortgage using the generated path
            let mut sp500_units = initial_units;  // holdings in Python
            let mut loan_size = total_loan * reinvest_fraction + quarterly_income;  // KEY: starts HIGHER than principal
            let mut cum_interest_deficit = 0.0;  // deferred in Python
            let mut on_holiday = holiday_enter_fraction > 1.0;  // Start on holiday if threshold > 1
            let mut quarters_in_holiday = 0;
            let mut last_yearly_hedge_price = s0;
            let mut last_5yearly_hedge_price = s0;

            for period in 1..=total_periods {
                // Python uses: price_indices = (period * dt_quarter_inv - 1)
                // where dt_quarter_inv = 1.0 / (dt * 4) = 1.0 / (1/120 * 4) = 30
                let month_idx = ((period * 30) - 1).min(path.len() - 1);
                let sp500_price = path[month_idx];

                // Calculate holdings value
                let holdings_value = sp500_units * sp500_price;

                // Calculate interest on GROWING loan_size
                let interest_due = loan_size * quarterly_interest_rate;
                let interest_due_per_share = interest_due / sp500_price;

                // Holiday logic - EXACTLY as Python
                if on_holiday {
                    if holdings_value > holiday_exit_threshold {
                        // Exit holiday and pay interest
                        on_holiday = false;
                        sp500_units -= interest_due_per_share;
                        quarters_in_holiday = 0;
                    } else {
                        // Stay on holiday, defer interest
                        quarters_in_holiday += 1;
                        cum_interest_deficit += interest_due;
                    }
                } else {
                    if holdings_value < holiday_enter_threshold {
                        // Enter holiday, defer interest
                        cum_interest_deficit += interest_due;
                        on_holiday = true;
                        quarters_in_holiday += 1;
                    } else {
                        // Normal operation - pay interest
                        quarters_in_holiday = 0;
                        sp500_units -= interest_due_per_share;

                        // Superpay logic: If holdings are above exit threshold and there's deferred interest,
                        // use surplus to pay down the deficit (Python lines 256-264)
                        if holdings_value > holiday_exit_threshold && cum_interest_deficit > 0.0 {
                            let surplus_pay = interest_due.min(cum_interest_deficit);
                            let surplus_pay_per_share = surplus_pay / sp500_price;
                            sp500_units -= surplus_pay_per_share;
                            cum_interest_deficit -= surplus_pay;
                        }
                    }
                }

                // Principal repayment (if enabled)
                if principal_repayment {
                    let principal_payment = total_loan / loan_duration_quarters as f64;
                    let units_for_principal = principal_payment / sp500_price;
                    sp500_units -= units_for_principal;
                }

                // Hedging logic - EXACTLY as Python
                if hedged {
                    // Yearly hedge (every 4 quarters)
                    if period % 4 == 0 {
                        // Deduct hedging cost
                        sp500_units -= sp500_units * hedging_cost_pa;

                        // Check if need to buy units (protection against drops > 20%)
                        let year_move = (sp500_price - last_yearly_hedge_price) / last_yearly_hedge_price;
                        if year_move < -hedging_max_loss {
                            let buy_units = ((last_yearly_hedge_price / sp500_price) * (1.0 - hedging_max_loss) - 1.0) * sp500_units;
                            sp500_units += buy_units;
                        }
                        last_yearly_hedge_price = sp500_price;
                    }

                    // 5-yearly hedge cap (every 20 quarters)
                    if period % 20 == 0 {
                        let adj_holds = sp500_units * (last_5yearly_hedge_price / sp500_price) * (1.0 + hedging_cap * 5.0);
                        if sp500_units > adj_holds {
                            sp500_units -= sp500_units - adj_holds;  // Sell excess
                        }
                        last_5yearly_hedge_price = sp500_price;
                    }
                }

                // Pay annuity (AFTER all calculations for THIS period)
                // This affects NEXT period's holdings
                if period < annuity_duration_quarters {
                    // KEY: Only sell units if doing progressive repayment!
                    // Otherwise just increase the loan size
                    if principal_repayment {
                        let units_for_principal = quarterly_income / sp500_price;
                        sp500_units -= units_for_principal;
                    } else {
                        // NOT progressive repayment: loan grows, units stay same
                        loan_size += quarterly_income;
                    }
                }
            }

            // Final values
            let final_price = path[path.len() - 1];
            let final_reinvestment = sp500_units * final_price;

            MortgageResult {
                reinvestment: final_reinvestment,
                interest_deficit: cum_interest_deficit,
                quarters_in_holiday,
            }
        })
        .collect();

    Ok(results)
}

#[pyclass]
#[derive(Clone)]
struct MortgageResult {
    #[pyo3(get)]
    reinvestment: f64,
    #[pyo3(get)]
    interest_deficit: f64,
    #[pyo3(get)]
    quarters_in_holiday: usize,
}

/// Calculate IRR (Internal Rate of Return) using Newton-Raphson method
/// This is equivalent to numpy_financial.irr() in Python
#[pyfunction]
fn calculate_irr(cashflows: Vec<f64>) -> PyResult<Option<f64>> {
    if cashflows.is_empty() {
        return Ok(None);
    }

    // Check if all cashflows are zero (invalid case)
    if cashflows.iter().all(|&x| x.abs() < 1e-10) {
        return Ok(None);
    }

    // Newton-Raphson parameters
    let max_iterations = 100;
    let tolerance = 1e-7;
    let mut rate = 0.1; // Initial guess: 10%

    for _ in 0..max_iterations {
        let mut npv: f64 = 0.0;
        let mut dnpv: f64 = 0.0; // Derivative of NPV with respect to rate

        for (t, &cf) in cashflows.iter().enumerate() {
            let discount: f64 = (1.0_f64 + rate).powi(t as i32);
            npv += cf / discount;
            dnpv -= (t as f64) * cf / ((1.0 + rate) * discount);
        }

        // Check convergence
        if npv.abs() < tolerance {
            return Ok(Some(rate));
        }

        // Newton-Raphson update: rate_new = rate - f(rate)/f'(rate)
        if dnpv.abs() < 1e-10 {
            // Derivative too small, can't continue
            return Ok(None);
        }

        let rate_new = rate - npv / dnpv;

        // Prevent rate from going too negative (loans can't have < -100% return)
        if rate_new < -0.99 {
            rate = -0.99;
        } else {
            rate = rate_new;
        }

        // Check if we're oscillating or diverging
        if rate.abs() > 1000.0 || rate.is_nan() {
            return Ok(None);
        }
    }

    // If we didn't converge, return None
    Ok(None)
}

/// Calculate XIRR (Extended Internal Rate of Return) for irregular cashflows
/// This matches the XIRR calculation in the Python code
#[pyfunction]
fn calculate_xirr(cashflows: Vec<f64>) -> PyResult<Option<f64>> {
    // For regular periodic cashflows (quarterly), XIRR = IRR
    // The Python code uses numpy_financial.irr which assumes regular periods
    calculate_irr(cashflows)
}

/// Comprehensive metrics calculation from simulation results
/// Returns a dictionary with all profitability metrics
#[pyclass]
#[derive(Clone)]
struct MetricsResult {
    #[pyo3(get)]
    mean_reinvestment: f64,
    #[pyo3(get)]
    std_reinvestment: f64,
    #[pyo3(get)]
    p10_reinvestment: f64,
    #[pyo3(get)]
    p25_reinvestment: f64,
    #[pyo3(get)]
    p50_reinvestment: f64,
    #[pyo3(get)]
    p75_reinvestment: f64,
    #[pyo3(get)]
    p90_reinvestment: f64,
    #[pyo3(get)]
    mean_deficit: f64,
    #[pyo3(get)]
    total_holiday_quarters: f64,
    #[pyo3(get)]
    pct_quarters_holiday: f64,
    #[pyo3(get)]
    mean_funder_earned: f64,
    #[pyo3(get)]
    mean_funder_profit_share: f64,
    #[pyo3(get)]
    mean_net_position: f64,
    #[pyo3(get)]
    mean_cagr: f64,
    #[pyo3(get)]
    xirr: Option<f64>,
    #[pyo3(get)]
    prob_insurance_payout: f64,
    #[pyo3(get)]
    mean_insurance_payout_npv: f64,
}

#[pyfunction]
fn calculate_metrics(
    results: Vec<MortgageResult>,
    total_loan: f64,
    reinvest_fraction: f64,
    loan_duration: usize,
    annual_income: f64,
    annuity_duration: usize,
    cash_rate: f64,
) -> PyResult<MetricsResult> {
    let num_paths = results.len() as f64;

    // Extract reinvestments and deficits
    let mut reinvestments: Vec<f64> = results.iter().map(|r| r.reinvestment).collect();
    let deficits: Vec<f64> = results.iter().map(|r| r.interest_deficit).collect();
    let holiday_quarters: Vec<f64> = results.iter().map(|r| r.quarters_in_holiday as f64).collect();

    // Basic statistics
    let mean_reinvestment: f64 = reinvestments.iter().sum::<f64>() / num_paths;
    let mean_deficit: f64 = deficits.iter().sum::<f64>() / num_paths;

    // Standard deviation
    let variance: f64 = reinvestments.iter()
        .map(|x| (x - mean_reinvestment).powi(2))
        .sum::<f64>() / num_paths;
    let std_reinvestment = variance.sqrt();

    // Percentiles (need to sort for percentiles)
    reinvestments.sort_by(|a, b| a.partial_cmp(b).unwrap());
    let p10_reinvestment = percentile(&reinvestments, 0.10);
    let p25_reinvestment = percentile(&reinvestments, 0.25);
    let p50_reinvestment = percentile(&reinvestments, 0.50);
    let p75_reinvestment = percentile(&reinvestments, 0.75);
    let p90_reinvestment = percentile(&reinvestments, 0.90);

    // Holiday statistics
    let total_holiday_quarters: f64 = holiday_quarters.iter().sum();
    let pct_quarters_holiday: f64 = total_holiday_quarters / (num_paths * (loan_duration * 4) as f64);

    // Funder metrics (simplified - no pool profits in current implementation)
    let lender_profit_share = 0.5;

    let mut profit_shares = Vec::with_capacity(results.len());
    for r in &results {
        let profit = lender_profit_share * (r.reinvestment - total_loan - r.interest_deficit);
        profit_shares.push(profit.max(0.0));
    }

    let mean_funder_earned = 0.0; // Simplified
    let mean_funder_profit_share: f64 = profit_shares.iter().sum::<f64>() / num_paths;
    let mean_net_position = mean_funder_earned + mean_funder_profit_share;

    // CAGR calculation
    let initial_investment = total_loan * reinvest_fraction;
    let final_value = mean_reinvestment + mean_funder_profit_share;
    let mean_cagr = if final_value > 0.0 && initial_investment > 0.0 {
        (final_value / initial_investment).powf(1.0 / loan_duration as f64) - 1.0
    } else {
        f64::NAN
    };

    // XIRR calculation (simplified - quarterly cashflows)
    let quarterly_income = annual_income / 4.0;
    let initial_outlay = initial_investment + quarterly_income;

    let mut npcf = vec![0.0; loan_duration * 4];
    npcf[0] = -initial_outlay;
    // Simplified: assume net cashflow is zero for intermediate periods
    // Final recovery
    npcf[loan_duration * 4 - 1] = final_value;

    let xirr = calculate_irr(npcf).ok().flatten();

    // Insurance metrics
    let repayment_amount = (annuity_duration as f64) * annual_income;

    let mut insurance_payouts = Vec::with_capacity(results.len());
    let mut insurance_triggers = 0;

    for r in &results {
        let payout = (total_loan + r.interest_deficit - r.reinvestment - repayment_amount).max(0.0);
        insurance_payouts.push(payout);
        if r.reinvestment + repayment_amount < total_loan + r.interest_deficit {
            insurance_triggers += 1;
        }
    }

    let prob_insurance_payout = insurance_triggers as f64 / num_paths;
    let mean_insurance_payout: f64 = insurance_payouts.iter().sum::<f64>() / num_paths;
    let mean_insurance_payout_npv = mean_insurance_payout / (1.0 + cash_rate).powi(loan_duration as i32);

    Ok(MetricsResult {
        mean_reinvestment,
        std_reinvestment,
        p10_reinvestment,
        p25_reinvestment,
        p50_reinvestment,
        p75_reinvestment,
        p90_reinvestment,
        mean_deficit,
        total_holiday_quarters,
        pct_quarters_holiday,
        mean_funder_earned,
        mean_funder_profit_share,
        mean_net_position,
        mean_cagr,
        xirr,
        prob_insurance_payout,
        mean_insurance_payout_npv,
    })
}

/// Calculate percentile from sorted array
fn percentile(sorted_data: &[f64], p: f64) -> f64 {
    let n = sorted_data.len();
    if n == 0 {
        return 0.0;
    }

    let index = p * (n - 1) as f64;
    let lower = index.floor() as usize;
    let upper = index.ceil() as usize;
    let fraction = index - lower as f64;

    if lower >= n - 1 {
        return sorted_data[n - 1];
    }

    sorted_data[lower] * (1.0 - fraction) + sorted_data[upper] * fraction
}

/// A Python module implemented in Rust
#[pymodule]
fn monte_carlo_engine(_py: Python, m: &Bound<'_, PyModule>) -> PyResult<()> {
    m.add_function(wrap_pyfunction!(gen_monte_carlo_paths, m)?)?;
    m.add_function(wrap_pyfunction!(single_mortgage_rust, m)?)?;
    m.add_function(wrap_pyfunction!(single_mortgage_integrated, m)?)?;
    m.add_function(wrap_pyfunction!(calculate_irr, m)?)?;
    m.add_function(wrap_pyfunction!(calculate_xirr, m)?)?;
    m.add_function(wrap_pyfunction!(calculate_metrics, m)?)?;
    m.add_class::<MortgageResult>()?;
    m.add_class::<MetricsResult>()?;
    Ok(())
}
