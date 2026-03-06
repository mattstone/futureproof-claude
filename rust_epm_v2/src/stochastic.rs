//! Stochastic process generators: correlated GBM (equity, house) + Vasicek (rate).
//!
//! Uses Cholesky decomposition for 3-factor correlation and quarterly time-steps.

use rand::rngs::StdRng;
use rand_distr::{Distribution, StandardNormal};

/// Cholesky factor L for a 3×3 correlation matrix.
///
///   ┌ 1      ρ_er    ρ_eh ┐
///   │ ρ_er   1       ρ_rh │
///   └ ρ_eh   ρ_rh    1    ┘
///
/// Returns L such that LL^T = Σ.  Panics on non-positive-definite input.
pub fn cholesky3(rho_er: f64, rho_eh: f64, rho_rh: f64) -> [[f64; 3]; 3] {
    let l00 = 1.0;
    let l10 = rho_er;
    let l11 = (1.0 - l10 * l10).sqrt();
    let l20 = rho_eh;
    let l21 = (rho_rh - l20 * l10) / l11;
    let l22 = (1.0 - l20 * l20 - l21 * l21).sqrt();
    [
        [l00, 0.0, 0.0],
        [l10, l11, 0.0],
        [l20, l21, l22],
    ]
}

/// Pre-computed Cholesky + model parameters, shared across all paths.
#[derive(Clone, Debug)]
pub struct StochasticParams {
    pub chol: [[f64; 3]; 3],
    // Equity GBM
    pub eq_drift: f64, // (μ - 0.5σ²) * dt
    pub eq_diff: f64,  // σ √dt
    // Vasicek rate
    pub rate_kappa: f64,
    pub rate_theta: f64,
    pub rate_vol: f64,
    pub rate_init: f64,
    // House GBM
    pub house_drift: f64,
    pub house_diff: f64,
    // timestep
    pub dt: f64,
}

impl StochasticParams {
    pub fn new(
        eq_mean: f64, eq_vol: f64,
        rate_kappa: f64, rate_theta: f64, rate_vol: f64, rate_init: f64,
        house_mean: f64, house_vol: f64,
        rho_er: f64, rho_eh: f64, rho_rh: f64,
        dt: f64,
    ) -> Self {
        Self {
            chol: cholesky3(rho_er, rho_eh, rho_rh),
            eq_drift: (eq_mean - 0.5 * eq_vol * eq_vol) * dt,
            eq_diff: eq_vol * dt.sqrt(),
            rate_kappa, rate_theta, rate_vol, rate_init,
            house_drift: (house_mean - 0.5 * house_vol * house_vol) * dt,
            house_diff: house_vol * dt.sqrt(),
            dt,
        }
    }
}

/// One quarterly step of the 3-factor model.
///
/// Returns (equity_return_factor, new_rate, house_return_factor).
/// equity_return_factor and house_return_factor are multiplicative (e.g. 1.025).
#[inline]
pub fn step(
    p: &StochasticParams,
    rate: f64,
    rng: &mut StdRng,
) -> (f64, f64, f64) {
    let z0: f64 = StandardNormal.sample(rng);
    let z1: f64 = StandardNormal.sample(rng);
    let z2: f64 = StandardNormal.sample(rng);

    // Correlated shocks
    let w_eq = p.chol[0][0] * z0;
    let w_rate = p.chol[1][0] * z0 + p.chol[1][1] * z1;
    let w_house = p.chol[2][0] * z0 + p.chol[2][1] * z1 + p.chol[2][2] * z2;

    // Equity (GBM)
    let eq_factor = (p.eq_drift + p.eq_diff * w_eq).exp();

    // Rate (Vasicek) – Euler–Maruyama, floored at 0
    let new_rate = (rate + p.rate_kappa * (p.rate_theta - rate) * p.dt
        + p.rate_vol * p.dt.sqrt() * w_rate)
        .max(0.0);

    // House (GBM)
    let house_factor = (p.house_drift + p.house_diff * w_house).exp();

    (eq_factor, new_rate, house_factor)
}
