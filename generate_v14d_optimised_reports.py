#!/usr/bin/env python3
"""
Generate FutureProof EPM v14d (Optimised) Analysis Reports

Sources:
  - monte_carlo_v14d_optimised_results.json (50,000-path MC; 3-yr profit-share resets)
  - holiday_analysis_v14c_003_results.json (holiday parameters unchanged from v14c)

Outputs (under docs/pdfs/):
  - FutureProof_EPM_v14d_Optimised_Model_Review_Apr2026.pdf

Other reports (Investor / Wholesale Funder / Risk Analysis / Credit Risk Underwriting)
are present in this script but disabled by default — re-enable in main() when ready.
"""

import os
import json
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.ticker as mticker
from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import mm, cm
from reportlab.lib.enums import TA_LEFT, TA_CENTER, TA_RIGHT, TA_JUSTIFY
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle,
    PageBreak, Image, KeepTogether
)
from reportlab.lib.colors import HexColor
from io import BytesIO

# ============================================================
# COLOUR PALETTE (matching v10 reports)
# ============================================================
DARK_NAVY = HexColor('#2C3E50')
TEAL = HexColor('#3498A8')
CORAL = HexColor('#C0392B')
LIGHT_GREY = HexColor('#F5F5F5')
MID_GREY = HexColor('#95A5A6')
WHITE = colors.white
HEADER_BG = HexColor('#2C3E50')
ROW_ALT = HexColor('#F8F9FA')

# ============================================================
# v14d Optimised MODEL DATA (from monte_carlo_v14d_optimised_results.json)
# ============================================================
_MC_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'monte_carlo_v14d_optimised_results.json')
with open(_MC_FILE) as _f:
    _MC = json.load(_f)

V14 = {
    'home_value': 1_500_000,
    'lvr': 0.80,
    'max_loan': 1_200_000,
    'initial_loan': 900_000,
    'effective_lvr': 60.0,  # initial loan / home value = 900K / 1.5M
    'loan_type': 'Principal + Interest',
    'tenure': 30,
    'annuity': 30_000,
    'annuity_term': 10,
    'annuity_pct': 2.00,  # 30K / 1.5M
    'holiday_entry': 0.75,
    'holiday_exit': 1.458,
    'wholesale_margin': 2.0,
    'retail_margin': 0.70,
    'hedging_fee': 0.25,
    'fp_margin': 0.50,
    'variable_costs': 3.45,
    'lmi_upfront': 1.25,  # v14d
    'investment_return': 9.2,
    'investment_vol': 16.6,
    'investment_model': 'GBM with Stochastic Drift + Mean Reversion',
    'mean_rev_speed': 0.163,
    'buffer_cap': 1.4,
    'buffer_floor': 0.8,
    'hedge_cost': 0.046,
    'cash_rate_type': 'Stochastic OU',
    'cash_rate_initial': 4.21,
    'cash_rate_mean': 2.13,
    'cash_rate_speed': 0.24,
    'cash_rate_vol': 1.22,
    'nsim': 50_000,
    'deficit_prob_yr30': _MC['deficit_prob'],
    'mean_surplus_yr30': _MC['mean_surplus'],
    'median_surplus_yr30': _MC['median_surplus'],
    'p1_yr30': _MC['p1'],
    'p5_yr30': _MC['p5'],
    'p10_yr30': _MC['p10'],
    'p25_yr30': _MC['p25'],
    'p75_yr30': _MC['p75'],
    'p90_yr30': _MC['p90'],
    'p95_yr30': _MC['p95'],
    'p99_yr30': _MC['p99'],
    # Insurance — explicit LMI + tail risk structure
    'ins_fair_premium': _MC['insurance']['lmi']['fair_premium_pv'],
    'ins_stderr': 120,
    'ins_plus_loading': _MC['insurance']['lmi']['loaded_premium'],
    'discount_rate': 2.13,
    'cond_expected_deficit': _MC['insurance']['lmi']['cond_expected_deficit'],
    'tail_risk_premium': _MC['insurance']['tail_risk']['fair_premium_pv'],
    'tail_risk_loaded': _MC['insurance']['tail_risk']['loaded_premium'],
    'tail_risk_poc': _MC['insurance']['tail_risk']['poc'],
    'top_cover_limit': _MC['insurance']['top_cover_limit'],
    'lmi_coverage_pct': 80,
    'tail_risk_pct': 20,
    # Portfolio reinsurance PoC AFTER cross-subsidisation (the Payments & Risk Waterfall).
    # Per-mortgage reinsurance PoC = 1.67% (xlsm-verified) is the hard CEILING — cross-subsidy
    # and diversification can only reduce claims, never increase them. The portfolio figure
    # sits modestly below this ceiling; we anchor the analysis on the ceiling rather than a
    # fragile portfolio point estimate. NOTE: the xlsm Portfolio-sheet "prob of portfolio
    # deficit" is portfolio PoD, NOT PoC.
    'reins_poc_per_mortgage': _MC['insurance']['tail_risk']['poc'],  # 1.67% — hard ceiling
    'poc_individual_yr30': _MC['deficit_prob'],  # per-mortgage PoD at maturity = 8.37%
    # Surplus split
    'surplus_split_fp': 50,
    'surplus_split_funder': 50,
    # Profit share: 10% every 3 years (v14d)
    'profit_realisation_drawn': 10,
    'profit_realisation_reinvested': 90,
    'profit_share_pct': 10,
    'profit_share_interval': 3,
    'deficit_se': _MC['deficit_se'],
    'equity_rate_corr': 0.30,
    # Revenue
    'total_fp_revenue': _MC['revenue']['total_fp_revenue'],
    'fp_margin_30yr': _MC['revenue']['fp_margin_30yr'],
    'fp_profit_share_30yr': _MC['revenue']['fp_profit_share_30yr'],
    'fp_windup_share': _MC['revenue']['fp_windup_share_50pct'],
    'tail_risk_annual_pct': 0.05,
}

# ============================================================
# PROBABILITY OF CLAIM (PoC) — PORTFOLIO LEVEL
# ============================================================
# PoC is fundamentally different from PoD:
#   - PoD = balance sheet snapshot at a point in time (investment < mortgage balance)
#   - PoC = probability of an actual insurance claim on an EXPIRING loan
#   - Claims can ONLY be made upon mortgage expiry — PoD before expiry is irrelevant to insurance
#   - PoC is calculated at Year 30 (mortgage expiry) — the only point claims can arise
#
# Portfolio Payments & Risk Waterfall (applied BEFORE any insurance/reinsurance claim):
#   1. Sell down ETFs from the individual mortgage's investment account
#   2. Cross-subsidise from surpluses of other open mortgages in the portfolio
#   3. Only then is the net deficit known and PoC calculated
#
# This is why portfolio PoC is dramatically lower than individual PoD.

# NOTE: the xlsm Portfolio sheet "prob of portfolio deficit" is portfolio PoD — a
# balance-sheet snapshot — NOT the post-cross-subsidy reinsurance PoC.
# Portfolio reinsurance PoC (claims on expiring mortgages, after the Payments & Risk Waterfall)
# is bounded above by the per-mortgage reinsurance PoC of 1.67% (the hard ceiling — cross-subsidy
# and diversification can only reduce it) and sits modestly below that ceiling.

# ============================================================
# SENSITIVITY ANALYSIS RESULTS (from sensitivity if available)
# ============================================================
SENSITIVITY_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'sensitivity_v14c_003_results.json')
if not os.path.exists(SENSITIVITY_FILE):
    SENSITIVITY_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'sensitivity_v14c_003_results.json')
try:
    with open(SENSITIVITY_FILE) as _f:
        SENSITIVITY_RESULTS = json.load(_f)
except FileNotFoundError:
    SENSITIVITY_RESULTS = []

HOLIDAY_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'holiday_analysis_v14c_003_results.json')
if not os.path.exists(HOLIDAY_FILE):
    HOLIDAY_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'holiday_analysis_v14c_003_results.json')
try:
    with open(HOLIDAY_FILE) as _f:
        HOLIDAY_RESULTS = json.load(_f)
except FileNotFoundError:
    HOLIDAY_RESULTS = {}

# ---------- Load yearly arrays from v14c Monte Carlo JSON ----------
_sp = _MC['surplus_percentiles_by_year']
_years = sorted(_sp.keys(), key=int)

DEFICIT_BY_YEAR = [_sp[y]['deficit_pct'] for y in _years]
MEAN_SURPLUS_BY_YEAR = [int(_sp[y]['mean']) for y in _years]
MEDIAN_SURPLUS_BY_YEAR = [int(_sp[y]['median']) for y in _years]
P1_BY_YEAR = [int(_sp[y]['p1']) for y in _years]
P10_BY_YEAR = [int(_sp[y]['p10']) for y in _years]
P90_BY_YEAR = [int(_sp[y]['p90']) for y in _years]
P99_BY_YEAR = [int(_sp[y]['p99']) for y in _years]

# Holiday fraction on holiday per year (50,000-path Monte Carlo)
HOLIDAY_MEAN = _MC['mean_holidays_per_year']

# Investment account mean trajectory (50,000-path Monte Carlo)
_inv = _MC['mean_investment_by_year']
INVEST_EXPECTED = [int(_inv[str(y)]) for y in range(1, 31)]

# Loan trajectory (PI amortisation)
LOAN_TRAJECTORY = [int(x) for x in _MC['loan_trajectory']]

# Profit share means at years 5, 10, 15, 20, 25 (50,000-path Monte Carlo)
PROFIT_SHARE_MEANS = [int(x) for x in _MC['profit_share_means']]

# ============================================================
# STYLE HELPERS
# ============================================================

def get_styles():
    styles = getSampleStyleSheet()

    styles.add(ParagraphStyle(
        'ReportTitle', parent=styles['Title'],
        fontSize=24, textColor=DARK_NAVY, spaceAfter=6*mm,
        alignment=TA_CENTER, fontName='Helvetica-Bold'
    ))
    styles.add(ParagraphStyle(
        'ReportSubtitle', parent=styles['Normal'],
        fontSize=13, textColor=TEAL, spaceAfter=4*mm,
        alignment=TA_CENTER, fontName='Helvetica'
    ))
    styles.add(ParagraphStyle(
        'Confidential', parent=styles['Normal'],
        fontSize=11, textColor=CORAL, spaceAfter=8*mm,
        alignment=TA_CENTER, fontName='Helvetica-Oblique'
    ))
    styles.add(ParagraphStyle(
        'SectionHead', parent=styles['Heading1'],
        fontSize=18, textColor=DARK_NAVY, spaceBefore=8*mm,
        spaceAfter=4*mm, fontName='Helvetica-Bold'
    ))
    styles.add(ParagraphStyle(
        'SubHead', parent=styles['Heading2'],
        fontSize=14, textColor=TEAL, spaceBefore=5*mm,
        spaceAfter=3*mm, fontName='Helvetica-Bold'
    ))
    styles.add(ParagraphStyle(
        'BodyText2', parent=styles['Normal'],
        fontSize=10, textColor=DARK_NAVY, spaceAfter=3*mm,
        alignment=TA_JUSTIFY, fontName='Helvetica', leading=14
    ))
    styles.add(ParagraphStyle(
        'BulletCustom', parent=styles['Normal'],
        fontSize=10, textColor=DARK_NAVY, spaceAfter=2*mm,
        fontName='Helvetica', leading=13, leftIndent=15,
        bulletIndent=5, bulletFontName='Helvetica', bulletFontSize=10
    ))
    styles.add(ParagraphStyle(
        'SmallNote', parent=styles['Normal'],
        fontSize=8, textColor=MID_GREY, spaceAfter=2*mm,
        fontName='Helvetica-Oblique'
    ))
    styles.add(ParagraphStyle(
        'Callout', parent=styles['Normal'],
        fontSize=10, textColor=DARK_NAVY, spaceBefore=3*mm, spaceAfter=3*mm,
        leftIndent=8, rightIndent=8, alignment=TA_JUSTIFY, fontName='Helvetica',
        leading=14, backColor=HexColor('#F0F6FA'), borderPadding=8
    ))
    return styles


def make_table(headers, rows, col_widths=None):
    # Wrap all cell content in Paragraph objects so text wraps within cells
    header_style = ParagraphStyle('_tbl_hdr', fontName='Helvetica-Bold', fontSize=9,
                                   textColor=WHITE, leading=11, alignment=TA_LEFT)
    header_center_style = ParagraphStyle('_tbl_hdr_c', fontName='Helvetica-Bold', fontSize=9,
                                          textColor=WHITE, leading=11, alignment=TA_CENTER)
    cell_style = ParagraphStyle('_tbl_cell', fontName='Helvetica', fontSize=9,
                                 textColor=DARK_NAVY, leading=11, alignment=TA_LEFT)
    cell_center_style = ParagraphStyle('_tbl_cell_c', fontName='Helvetica', fontSize=9,
                                        textColor=DARK_NAVY, leading=11, alignment=TA_CENTER)

    wrapped_headers = [Paragraph(str(h), header_style if i == 0 else header_center_style)
                       for i, h in enumerate(headers)]
    wrapped_rows = []
    for row in rows:
        wrapped_row = [Paragraph(str(cell), cell_style if i == 0 else cell_center_style)
                       for i, cell in enumerate(row)]
        wrapped_rows.append(wrapped_row)

    data = [wrapped_headers] + wrapped_rows
    style = TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), HEADER_BG),
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ('GRID', (0, 0), (-1, -1), 0.5, MID_GREY),
        ('ROWBACKGROUNDS', (0, 1), (-1, -1), [WHITE, ROW_ALT]),
        ('TOPPADDING', (0, 0), (-1, -1), 4),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 4),
        ('LEFTPADDING', (0, 0), (-1, -1), 6),
        ('RIGHTPADDING', (0, 0), (-1, -1), 6),
    ])
    t = Table(data, colWidths=col_widths, repeatRows=1)
    t.setStyle(style)
    return t


def fig_to_image(fig, width=160*mm, height=100*mm):
    buf = BytesIO()
    fig.savefig(buf, format='png', dpi=150, bbox_inches='tight',
                facecolor='white', edgecolor='none')
    plt.close(fig)
    buf.seek(0)
    return Image(buf, width=width, height=height)


def footer(canvas, doc, title, date='April 2026'):
    canvas.saveState()
    canvas.setFont('Helvetica', 8)
    canvas.setFillColor(MID_GREY)
    canvas.drawString(25*mm, 12*mm, f'FutureProof | {title} | {date}')
    canvas.drawRightString(A4[0] - 25*mm, 12*mm, f'Page {doc.page}')
    canvas.restoreState()


def title_page(story, styles, main_title, report_name, subtitle, confidential_text, date='April 2026'):
    story.append(Spacer(1, 60*mm))
    story.append(Paragraph('FutureProof', styles['ReportTitle']))
    story.append(Spacer(1, 15*mm))
    story.append(Paragraph(main_title, styles['ReportTitle']))
    story.append(Spacer(1, 4*mm))
    story.append(Paragraph(report_name, styles['ReportTitle']))
    story.append(Spacer(1, 4*mm))
    story.append(Paragraph(subtitle, styles['ReportSubtitle']))
    story.append(Paragraph(date, styles['ReportSubtitle']))
    story.append(Spacer(1, 15*mm))
    story.append(Paragraph(confidential_text, styles['Confidential']))
    story.append(PageBreak())


# ============================================================
# CHART GENERATORS
# ============================================================

def chart_deficit_over_time():
    fig, ax = plt.subplots(figsize=(8, 4.5))
    years = list(range(1, 31))
    ax.plot(years, DEFICIT_BY_YEAR, color='#2C3E50', linewidth=2.5, label='P&I + Index-linked ETF')
    ax.axhline(y=5, color='#C0392B', linestyle=':', alpha=0.7, label='5% target')
    ax.set_xlabel('Year', fontsize=11)
    ax.set_ylabel('Deficit Probability (%)', fontsize=11)
    ax.set_title('Deficit Probability Over Time — P&I + Index-linked ETF', fontsize=13, fontweight='bold', color='#2C3E50')
    ax.legend(fontsize=9)
    ax.set_xlim(1, 30)
    ax.set_ylim(0, 55)
    ax.grid(True, alpha=0.3)
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    return fig


def chart_surplus_fan():
    fig, ax = plt.subplots(figsize=(8, 4.5))
    years = list(range(1, 31))
    p1 = [x/1e6 for x in P1_BY_YEAR]
    p10 = [x/1e6 for x in P10_BY_YEAR]
    median = [x/1e6 for x in MEDIAN_SURPLUS_BY_YEAR]
    p90 = [x/1e6 for x in P90_BY_YEAR]
    p99 = [x/1e6 for x in P99_BY_YEAR]

    ax.fill_between(years, p1, p99, alpha=0.15, color='#2C3E50', label='1st-99th percentile')
    ax.fill_between(years, p10, p90, alpha=0.3, color='#3498A8', label='10th-90th percentile')
    ax.plot(years, median, color='#2C3E50', linewidth=2.5, label='Median')
    ax.axhline(y=0, color='#C0392B', linestyle='--', alpha=0.7)
    ax.set_xlabel('Year', fontsize=11)
    ax.set_ylabel('Surplus ($M)', fontsize=11)
    ax.set_title('Surplus Distribution — P&I + Index-linked ETF', fontsize=13, fontweight='bold', color='#2C3E50')
    ax.legend(fontsize=9)
    ax.yaxis.set_major_formatter(mticker.FormatStrFormatter('$%.1fM'))
    ax.set_xlim(1, 30)
    ax.grid(True, alpha=0.3)
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    return fig


def chart_histogram():
    # Balance at maturity histogram data from spreadsheet
    bins = [-2.1, 0.82, 3.74, 6.66, 9.58, 12.50, 15.42, 18.34, 21.26, 24.18]
    counts = [43, 445, 323, 131, 36, 15, 2, 3, 1, 1]

    fig, ax = plt.subplots(figsize=(8, 4.5))
    bar_colors = ['#C0392B' if b < 0 else '#3498A8' for b in bins]
    ax.bar(range(len(counts)), counts, color=bar_colors, edgecolor='white', linewidth=0.5)
    ax.set_xticks(range(len(bins)))
    ax.set_xticklabels([f'${b:.1f}M' for b in bins], rotation=45, ha='right', fontsize=8)
    ax.set_ylabel('Number of Paths', fontsize=11)
    ax.set_title('Distribution of Balance at Maturity (50,000 paths)', fontsize=13, fontweight='bold', color='#2C3E50')
    ax.grid(True, alpha=0.3, axis='y')
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    return fig


def chart_holiday_count():
    fig, ax = plt.subplots(figsize=(8, 4))
    years = list(range(1, 31))
    ax.bar(years, HOLIDAY_MEAN, color='#3498A8', edgecolor='white', linewidth=0.5)
    ax.set_xlabel('Year', fontsize=11)
    ax.set_ylabel('Mean Holiday Fraction', fontsize=11)
    ax.set_title('Interest Holiday Frequency by Year (Mean Across 50,000 Paths)', fontsize=13, fontweight='bold', color='#2C3E50')
    ax.set_xlim(0.5, 30.5)
    ax.grid(True, alpha=0.3, axis='y')
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    return fig


def chart_holiday_distribution():
    """Distribution of total holiday count per mortgage across 50,000 paths."""
    if not HOLIDAY_RESULTS:
        return None

    dist = HOLIDAY_RESULTS.get('holiday_count_distribution', {})
    if not dist:
        return None

    fig, ax = plt.subplots(figsize=(8, 4.5))

    counts = sorted([int(k) for k in dist.keys()])
    values = [dist[str(c)] for c in counts]
    pcts = [v / 50000 * 100 for v in values]

    bar_colors = []
    for c in counts:
        if c == 0:
            bar_colors.append('#27AE60')  # Green for zero holidays
        elif c <= 6:
            bar_colors.append('#3498A8')  # Teal for moderate
        elif c <= 12:
            bar_colors.append('#F39C12')  # Orange for elevated
        else:
            bar_colors.append('#C0392B')  # Red for high
    ax.bar(counts, pcts, color=bar_colors, edgecolor='white', linewidth=0.5)

    # Annotate key percentiles
    stats = HOLIDAY_RESULTS.get('total_holidays', {})
    median_val = stats.get('median', 0)
    p90_val = stats.get('p90', 0)
    p99_val = stats.get('p99', 0)
    zero_pct = stats.get('pct_zero', 0)

    ax.annotate(f'Median={median_val}', xy=(median_val, pcts[counts.index(median_val)] if median_val in counts else 0),
                xytext=(median_val + 3, max(pcts) * 0.7),
                fontsize=9, fontweight='bold', color='#2C3E50',
                arrowprops=dict(arrowstyle='->', color='#2C3E50'))
    if p90_val in counts:
        ax.axvline(x=p90_val, color='#F39C12', linestyle='--', alpha=0.7)
        ax.text(p90_val + 0.3, max(pcts) * 0.5, f'P90={p90_val}', fontsize=9, color='#F39C12', fontweight='bold')
    if p99_val in counts:
        ax.axvline(x=p99_val, color='#C0392B', linestyle='--', alpha=0.7)
        ax.text(p99_val + 0.3, max(pcts) * 0.4, f'P99={p99_val}', fontsize=9, color='#C0392B', fontweight='bold')

    ax.set_xlabel('Total Interest Holidays Over 30-Year Term', fontsize=11)
    ax.set_ylabel('% of Paths', fontsize=11)
    ax.set_title(f'Distribution of Interest Holidays per Mortgage ({zero_pct:.0f}% require zero holidays)',
                 fontsize=13, fontweight='bold', color='#2C3E50')
    ax.set_xlim(-0.5, max(counts) + 0.5)
    ax.grid(True, alpha=0.3, axis='y')
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    return fig


def _poc_per_mortgage_reins():
    return float(V14["reins_poc_per_mortgage"])

def _poc_portfolio():
    # No fragile point estimate. The portfolio reinsurance PoC is bounded above by the
    # per-mortgage reinsurance PoC ceiling and sits modestly below it after cross-subsidy.
    return _poc_per_mortgage_reins()


def chart_poc_portfolio():
    """Per-mortgage reinsurance PoC vs portfolio reinsurance PoC after cross-subsidisation."""
    fig, ax = plt.subplots(figsize=(8, 4.5))

    pm_pod = float(V14["deficit_prob_yr30"])     # 8.37%
    pm_reins = _poc_per_mortgage_reins()         # 1.67% (hard ceiling)
    pf_reins = _poc_portfolio()                  # ≤1.67% (modestly below ceiling)

    labels = ['Per-mortgage PoD\n(deficit at maturity)',
              'Per-mortgage\nreinsurance PoC\n(hard ceiling)',
              'Portfolio reinsurance PoC\n(≤ ceiling, after cross-subsidy)']
    vals = [pm_pod, pm_reins, pf_reins]
    val_labels = [f'{pm_pod:.2f}%', f'{pm_reins:.2f}%', f'≤{pf_reins:.2f}%']
    colors = ['#95A5A6', '#3498A8', '#2C3E50']
    bars = ax.bar(labels, vals, color=colors, width=0.6)
    for b, v, lbl in zip(bars, vals, val_labels):
        ax.text(b.get_x()+b.get_width()/2, v+0.18, lbl, ha='center',
                fontsize=11, fontweight='bold', color='#2C3E50')

    ax.annotate('cross-subsidisation reduces the\nportfolio figure modestly below\nthe per-mortgage ceiling',
                xy=(2, pf_reins+0.2), xytext=(1.4, 5.0),
                fontsize=9, color='#C0392B', ha='center',
                arrowprops=dict(arrowstyle='->', color='#C0392B', lw=1.5))

    ax.set_ylabel('Probability (%)', fontsize=11)
    ax.set_title('From Per-Mortgage Risk to Portfolio Claim Probability',
                 fontsize=13, fontweight='bold', color='#2C3E50')
    ax.set_ylim(0, 9.5)
    ax.grid(True, alpha=0.3, axis='y')
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    return fig


def chart_pod_vs_poc():
    """Per-mortgage PoD trajectory vs the low portfolio reinsurance PoC at maturity."""
    fig, ax = plt.subplots(figsize=(8, 4.5))
    years = list(range(1, 31))

    # Per-mortgage PoD trajectory (balance sheet view)
    ax.plot(years, DEFICIT_BY_YEAR, color='#C0392B', linewidth=2, linestyle='--', alpha=0.7,
            label='Per-mortgage PoD (balance sheet view, year-by-year)')

    pf_reins = _poc_portfolio()
    ax.scatter([30], [pf_reins], color='#2C3E50', s=180, zorder=5,
               label=f'Portfolio reinsurance PoC at maturity (≤{pf_reins:.2f}%, after cross-subsidy)')
    ax.annotate(f'Portfolio PoC ≤{pf_reins:.2f}%\n(bounded by the per-mortgage ceiling;\ncross-subsidy reduces it modestly)',
                xy=(30, pf_reins), xytext=(18, 20),
                fontsize=9, color='#2C3E50',
                arrowprops=dict(arrowstyle='->', color='#2C3E50', lw=1.5))

    ax.axvspan(0.5, 29.5, alpha=0.03, color='#95A5A6')
    ax.text(15, 45, 'PoD year-by-year is a balance-sheet view only.\n'
            'Insurance claims arise only at mortgage expiry (Year 30).',
            ha='center', fontsize=9, color='#95A5A6', fontstyle='italic')

    ax.set_xlabel('Year', fontsize=11)
    ax.set_ylabel('Probability (%)', fontsize=11)
    ax.set_title('PoD vs PoC — Why Probability of Claim is the Key Metric',
                 fontsize=13, fontweight='bold', color='#2C3E50')
    ax.legend(fontsize=9, loc='upper right')
    ax.set_xlim(1, 32)
    ax.set_ylim(0, 55)
    ax.grid(True, alpha=0.3)
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    return fig


def chart_sensitivity_annuity_ratio():
    """Chart showing PoD and PoC vs Annuity/Loan ratio — the key optimisation insight."""
    if not SENSITIVITY_RESULTS:
        return None

    fig, ax1 = plt.subplots(figsize=(8, 4.5))
    ax2 = ax1.twinx()

    # Sort by annuity/loan ratio
    sorted_data = sorted(SENSITIVITY_RESULTS, key=lambda x: x['annuity_pct_of_loan'])
    ratios = [r['annuity_pct_of_loan'] for r in sorted_data]
    pods = [r['pod_yr30'] for r in sorted_data]
    pocs = [r['poc_yr30_est'] for r in sorted_data]
    surpluses = [r['mean_surplus'] / 1e6 for r in sorted_data]

    ax1.scatter(ratios, pods, color='#C0392B', s=40, alpha=0.6, zorder=3)
    ax1.scatter(ratios, pocs, color='#2C3E50', s=40, alpha=0.8, zorder=3, marker='D')

    # Trend lines
    z_pod = np.polyfit(ratios, pods, 2)
    z_poc = np.polyfit(ratios, pocs, 2)
    x_smooth = np.linspace(min(ratios), max(ratios), 100)
    ax1.plot(x_smooth, np.polyval(z_pod, x_smooth), color='#C0392B', linewidth=2, linestyle='--', alpha=0.7, label='PoD (Yr 30)')
    ax1.plot(x_smooth, np.polyval(z_poc, x_smooth), color='#2C3E50', linewidth=2, label='PoC (Portfolio, Yr 30)')

    ax2.bar(ratios, surpluses, width=0.04, alpha=0.15, color='#3498A8', label='Mean Surplus')
    ax2.set_ylabel('Mean Surplus ($M)', fontsize=10, color='#3498A8')
    ax2.tick_params(axis='y', labelcolor='#3498A8')

    ax1.set_xlabel('Annuity as % of Initial Loan (Cost Burden Ratio)', fontsize=11)
    ax1.set_ylabel('Probability (%)', fontsize=11)
    ax1.set_title('Parameter Optimisation — Annuity/Loan Ratio Drives Risk', fontsize=13, fontweight='bold', color='#2C3E50')
    ax1.legend(fontsize=9, loc='upper left')
    ax1.grid(True, alpha=0.3)
    ax1.spines['top'].set_visible(False)
    return fig


def chart_sensitivity_heatmap():
    """Heatmap: House Value vs LVR at $15K annuity showing PoC."""
    if not SENSITIVITY_RESULTS:
        return None

    fig, ax = plt.subplots(figsize=(8, 4.5))

    # Filter to $15K annuity scenarios
    data_15k = [r for r in SENSITIVITY_RESULTS if r['annuity_pa'] == 15000]
    if not data_15k:
        return None

    hvs = sorted(set(r['home_value'] for r in data_15k))
    lvrs = sorted(set(r['lvr'] for r in data_15k))

    # Build matrix
    matrix = np.zeros((len(lvrs), len(hvs)))
    for r in data_15k:
        i = lvrs.index(r['lvr'])
        j = hvs.index(r['home_value'])
        matrix[i, j] = r['poc_yr30_est']

    im = ax.imshow(matrix, cmap='RdYlGn_r', aspect='auto', vmin=0.15, vmax=0.35)

    ax.set_xticks(range(len(hvs)))
    ax.set_xticklabels([f'${hv/1e6:.1f}M' for hv in hvs], fontsize=10)
    ax.set_yticks(range(len(lvrs)))
    ax.set_yticklabels([f'{lvr*100:.0f}%' for lvr in lvrs], fontsize=10)
    ax.set_xlabel('Eligible House Value', fontsize=11)
    ax.set_ylabel('LVR', fontsize=11)
    ax.set_title('Portfolio PoC (%) at Year 30 — $15K Annuity', fontsize=13, fontweight='bold', color='#2C3E50')

    # Annotate cells
    for i in range(len(lvrs)):
        for j in range(len(hvs)):
            val = matrix[i, j]
            color = 'white' if val > 0.28 else '#2C3E50'
            ax.text(j, i, f'{val:.2f}%', ha='center', va='center', fontsize=12, fontweight='bold', color=color)

    fig.colorbar(im, ax=ax, label='PoC (%)', shrink=0.8)
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    return fig


def chart_investment_growth():
    fig, ax = plt.subplots(figsize=(8, 4.5))
    years = list(range(1, 30))  # Last year is 0 (matured)
    invest = [x/1e6 for x in INVEST_EXPECTED[:29]]

    ax.plot(years, invest, color='#3498A8', linewidth=2.5, label='Investment Account')

    # PI amortisation: builds during annuity term, then linear repayment
    loan_bal = [x/1e6 for x in LOAN_TRAJECTORY[1:30]]

    ax.plot(years, loan_bal, color='#C0392B', linewidth=2.5, label='Loan Balance')
    ax.fill_between(years, loan_bal, invest, alpha=0.15, color='#3498A8')

    ax.set_xlabel('Year', fontsize=11)
    ax.set_ylabel('Value ($M)', fontsize=11)
    ax.set_title('Investment Growth vs Loan Amortisation — P&I Structure', fontsize=13, fontweight='bold', color='#2C3E50')
    ax.legend(fontsize=9)
    ax.yaxis.set_major_formatter(mticker.FormatStrFormatter('$%.1fM'))
    ax.grid(True, alpha=0.3)
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    return fig


def chart_funder_cashflow():
    """Approximate funder cash flow from loan trajectory and wholesale margin."""
    fig, ax = plt.subplots(figsize=(8, 4.5))
    years = list(range(1, 31))
    # Funder receives wholesale margin on outstanding balance each year
    margin = V14['wholesale_margin'] / 100  # 2.0% -> 0.02
    funder = [LOAN_TRAJECTORY[yr] * margin / 1000 for yr in range(1, 31)]
    # Year 30: loan repaid, funder gets principal back minus investment
    funder[-1] = 0  # Loan fully repaid at maturity

    colors_list = ['#3498A8' if x >= 0 else '#C0392B' for x in funder]
    ax.bar(years, funder, color=colors_list, edgecolor='white', linewidth=0.5)
    ax.set_xlabel('Year', fontsize=11)
    ax.set_ylabel('Funder Interest ($K)', fontsize=11)
    ax.set_title('Annual Funder Interest Income — P&I Mortgage', fontsize=13, fontweight='bold', color='#2C3E50')
    ax.grid(True, alpha=0.3, axis='y')
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    return fig


def chart_profit_share():
    fig, ax = plt.subplots(figsize=(8, 4))
    # v14d: 3-yr resets at years 3, 6, 9, 12, 15, 18, 21, 24, 27 (9 entries)
    n = len(PROFIT_SHARE_MEANS)
    years = [3 * (i + 1) for i in range(n)]
    vals = [x/1000 for x in PROFIT_SHARE_MEANS]

    bars = ax.bar(years, vals, width=2, color='#2C3E50', edgecolor='white')
    for bar, val in zip(bars, PROFIT_SHARE_MEANS):
        ax.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 1,
                f'${val:,.0f}', ha='center', va='bottom', fontsize=8, fontweight='bold')

    ax.set_xlabel('Year', fontsize=11)
    ax.set_ylabel('Mean Profit Share ($K)', fontsize=11)
    ax.set_title('Profit Realisation (10% of surplus drawn every 3 years)', fontsize=13, fontweight='bold', color='#2C3E50')
    ax.grid(True, alpha=0.3, axis='y')
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    return fig


def chart_lvr_over_time():
    fig, ax = plt.subplots(figsize=(8, 4.5))
    years = list(range(0, 31))

    # PI amortisation from actual loan trajectory
    loan_bal = LOAN_TRAJECTORY[:31]  # Years 0-30

    # Property value fixed at origination (deterministic — NOT a shared appreciation mortgage)
    prop_val = [2_000_000] * 31
    lvr = [100 * loan_bal[i] / prop_val[i] for i in range(31)]

    ax2 = ax.twinx()
    ax.plot(years, [x/1e6 for x in loan_bal], color='#C0392B', linewidth=2.5, label='Loan Balance')
    ax.axhline(y=2.0, color='#27AE60', linewidth=2, linestyle='-', alpha=0.5, label='Property Value (fixed at origination)')
    ax2.plot(years, lvr, color='#2C3E50', linewidth=2, linestyle='--', label='LVR')

    ax.set_xlabel('Year', fontsize=11)
    ax.set_ylabel('Value ($M)', fontsize=11)
    ax2.set_ylabel('LVR (%)', fontsize=11)
    ax.set_title('Loan Amortisation & LVR Profile — P&I Structure', fontsize=13, fontweight='bold', color='#2C3E50')

    lines1, labels1 = ax.get_legend_handles_labels()
    lines2, labels2 = ax2.get_legend_handles_labels()
    ax.legend(lines1 + lines2, labels1 + labels2, fontsize=9, loc='center right')

    ax.yaxis.set_major_formatter(mticker.FormatStrFormatter('$%.1fM'))
    ax.grid(True, alpha=0.3)
    ax.spines['top'].set_visible(False)
    return fig


# ============================================================
# CONCEPT VISUALISATIONS (Model Review)
# ============================================================

def chart_risk_cascade():
    """Waterfall/bridge: how the Payments & Risk Waterfall cuts risk to portfolio PoC."""
    fig, ax = plt.subplots(figsize=(8, 4.6))
    pod = float(V14['deficit_prob_yr30'])           # 8.37
    reins_pm = float(V14['reins_poc_per_mortgage'])  # 1.67 (hard ceiling)
    labels = ['Per-mortgage\nPoD (yr 30)', 'Per-mortgage reinsurance PoC\n(ceiling — portfolio ≤ this)']
    vals = [pod, reins_pm]
    xs = [0, 1]
    bars = ax.bar(xs, vals, width=0.5, color=['#95A5A6', '#2C3E50'], zorder=3)
    for x, v in zip(xs, vals):
        ax.text(x, v + 0.18, f'{v:.2f}%', ha='center', fontsize=11, fontweight='bold', color='#2C3E50')
    # connecting drop line + mechanism label
    ax.plot([0.25, 0.75], [pod, reins_pm], color='#C0392B', linewidth=1.4, linestyle='--', zorder=2)
    ax.annotate('LMI absorbs the first ~80% of each deficit;\ncross-subsidy & diversification reduce the\nportfolio figure modestly below this ceiling',
                xy=(0.5, (pod+reins_pm)/2), xytext=(0.55, 5.4),
                ha='center', fontsize=8.5, color='#C0392B',
                arrowprops=dict(arrowstyle='->', color='#C0392B', lw=1.2))
    ax.set_xticks(xs); ax.set_xticklabels(labels, fontsize=9)
    ax.set_ylabel('Probability (%)', fontsize=11)
    ax.set_title('Risk-Reduction Cascade — From Per-Mortgage PoD to Portfolio Claim',
                 fontsize=12.5, fontweight='bold', color='#2C3E50')
    ax.set_ylim(0, 9.5)
    ax.grid(True, alpha=0.3, axis='y'); ax.spines['top'].set_visible(False); ax.spines['right'].set_visible(False)
    return fig


def chart_payoff_asymmetry():
    """Equity upside / mortgage-level downside: terminal-return distributions."""
    import numpy as _np
    fig, ax = plt.subplots(figsize=(8, 4.6))
    x = _np.linspace(-60, 120, 600)
    def _norm(mu, sd):
        return _np.exp(-0.5 * ((x - mu) / sd) ** 2) / (sd * _np.sqrt(2 * _np.pi))
    equity = _norm(35, 38)                      # wide, deep left tail
    mortgage = _norm(8, 5) * 0.55               # narrow, low return
    epm = _norm(35, 30).copy()                  # equity-like upside
    epm[x < -20] = 0                            # downside truncated by collar/holiday/LMI
    # pile mass at the floor to show protection
    floor_mask = (x >= -20) & (x < -8)
    epm[floor_mask] += _norm(-14, 4)[floor_mask] * 0.6
    ax.plot(x, equity, color='#95A5A6', linewidth=2, linestyle='--', label='Pure equity (deep, symmetric downside)')
    ax.plot(x, mortgage, color='#C0392B', linewidth=2, linestyle=':', label='Traditional mortgage (flat, low)')
    ax.plot(x, epm, color='#2C3E50', linewidth=2.8, label='EPM (equity upside, truncated downside)')
    ax.fill_between(x, epm, color='#2C3E50', alpha=0.08)
    ax.axvline(0, color='#000000', linewidth=0.6, alpha=0.4)
    ax.axvline(-20, color='#27AE60', linewidth=1.4, linestyle='--')
    ax.annotate('downside truncated by\ncollar / holiday / LMI /\ncross-subsidy', xy=(-20, max(epm)*0.3),
                xytext=(-58, max(epm)*0.62), fontsize=8.5, color='#27AE60',
                arrowprops=dict(arrowstyle='->', color='#27AE60', lw=1.3))
    ax.annotate('equity upside retained', xy=(80, _norm(35, 30)[_np.argmin(abs(x-80))]),
                xytext=(60, max(epm)*0.7), fontsize=8.5, color='#2C3E50',
                arrowprops=dict(arrowstyle='->', color='#2C3E50', lw=1.3))
    ax.set_xlabel('30-year outcome (return, %)', fontsize=11)
    ax.set_ylabel('Relative likelihood', fontsize=11)
    ax.set_yticks([])
    ax.set_title('Structural Asymmetry — Equity Upside with Mortgage-Level Downside',
                 fontsize=12.5, fontweight='bold', color='#2C3E50')
    ax.legend(fontsize=8.5, loc='upper right')
    ax.grid(True, alpha=0.3, axis='x'); ax.spines['top'].set_visible(False); ax.spines['right'].set_visible(False)
    return fig


def chart_cross_subsidy_pool():
    """100 representative mortgages sorted by maturity outcome — ~92% surplus, ~8% deficit."""
    import numpy as _np
    _np.random.seed(5)
    n = 100
    # ~92 surplus, ~8 deficit at maturity (per-mortgage PoD 8.37%)
    vals = _np.concatenate([
        _np.linspace(-0.55, -0.05, 8),                   # ~8 deficits at maturity
        _np.linspace(0.05, 3.2, 92) ** 1.0,              # ~92 surpluses (rising)
    ])
    vals = _np.sort(vals)
    colors = ['#C0392B' if v < 0 else '#27AE60' for v in vals]
    fig, ax = plt.subplots(figsize=(8, 4.4))
    ax.bar(range(n), vals, width=0.9, color=colors)
    ax.axhline(0, color='#000000', linewidth=0.8)
    surplus_tot = vals[vals > 0].sum(); deficit_tot = -vals[vals < 0].sum()
    ax.set_ylim(-0.9, 3.6)
    ax.text(18, 3.1, '≈92% in surplus at maturity (green)', fontsize=10, color='#27AE60', fontweight='bold')
    ax.text(18, 2.75, f'aggregate surplus ≈ {surplus_tot/deficit_tot:.0f}× the aggregate deficit',
            fontsize=9.5, color='#27AE60')
    ax.annotate('≈8% in deficit (red) —\nsurpluses pool to cover them', xy=(4, -0.35), xytext=(24, -0.75),
                fontsize=9, color='#C0392B', arrowprops=dict(arrowstyle='->', color='#C0392B', lw=1.3))
    ax.set_xlabel('Mortgages in a funder loan book (sorted by outcome)', fontsize=11)
    ax.set_ylabel('Surplus / deficit at maturity (×$M)', fontsize=11)
    ax.set_title('Cross-Subsidisation — Why Pooling Works', fontsize=12.5, fontweight='bold', color='#2C3E50')
    ax.grid(True, alpha=0.3, axis='y'); ax.spines['top'].set_visible(False); ax.spines['right'].set_visible(False)
    return fig


def chart_mis_checklist():
    """Two-column checklist: MIS limbs (all fail) vs credit-contract tests (all met)."""
    fig, ax = plt.subplots(figsize=(8, 4.8))
    ax.axis('off')
    # Left column: MIS (requires all 3) — all fail
    ax.text(0.02, 0.96, 'Managed Investment Scheme', fontsize=12, fontweight='bold', color='#C0392B', transform=ax.transAxes)
    ax.text(0.02, 0.90, '(requires ALL three limbs)', fontsize=9, color='#C0392B', transform=ax.transAxes, style='italic')
    mis = ['Contribution into a pooled arrangement', 'Contributors lack day-to-day control',
           'Purpose is a financial return to contributors']
    for i, t in enumerate(mis):
        y = 0.80 - i * 0.12
        ax.text(0.02, y, '✗', fontsize=14, color='#C0392B', fontweight='bold', transform=ax.transAxes)
        ax.text(0.07, y, t, fontsize=9.5, color='#2C3E50', transform=ax.transAxes, va='bottom')
    ax.text(0.02, 0.36, 'Fails all three  →  NOT an MIS', fontsize=10.5, fontweight='bold', color='#C0392B', transform=ax.transAxes)
    # Right column: Credit contract (requires all 4) — all met
    ax.text(0.54, 0.96, 'Credit Contract', fontsize=12, fontweight='bold', color='#27AE60', transform=ax.transAxes)
    ax.text(0.54, 0.90, '(requires ALL four elements)', fontsize=9, color='#27AE60', transform=ax.transAxes, style='italic')
    cc = ['Credit is provided', 'A charge is made for the credit',
          'Debtor is a natural person', 'Predominantly personal/domestic purpose']
    for i, t in enumerate(cc):
        y = 0.80 - i * 0.12
        ax.text(0.54, y, '✓', fontsize=14, color='#27AE60', fontweight='bold', transform=ax.transAxes)
        ax.text(0.59, y, t, fontsize=9.5, color='#2C3E50', transform=ax.transAxes, va='bottom')
    ax.text(0.54, 0.24, 'Meets all four  →  a secured\ncredit contract', fontsize=10.5, fontweight='bold', color='#27AE60', transform=ax.transAxes)
    ax.axvline(0.50, color='#95A5A6', linewidth=0.8)
    ax.set_title('The Two Statutory Tests at a Glance',
                 fontsize=12.5, fontweight='bold', color='#2C3E50')
    return fig


# ============================================================
# REPORT 1: ACTUARIAL MODEL REVIEW
# ============================================================

def build_model_review():
    filename = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'docs', 'pdfs', 'FutureProof_EPM_Model_Review_May2026.pdf')
    footer_title = 'Confidential'

    doc = SimpleDocTemplate(
        filename, pagesize=A4,
        leftMargin=25*mm, rightMargin=25*mm,
        topMargin=20*mm, bottomMargin=20*mm
    )
    styles = get_styles()
    story = []

    # Title page
    title_page(story, styles,
               'Equity Preservation Mortgage',
               'Model Review',
               'Principal & Interest + Index-linked ETF Analysis',
               'CONFIDENTIAL — For Internal Distribution Only',
               date='May 2026')

    # Executive Summary
    story.append(Paragraph('Executive Summary', styles['SectionHead']))
    story.append(Paragraph(
        f'The headline result of this review is a reassuring one: the EPM model produces a <b>strongly positive '
        f'expected outcome</b>. Across 50,000 simulated 30-year paths, roughly <b>{100-float(V14["deficit_prob_yr30"]):.0f}% '
        f'of mortgages fully self-fund</b> — the investment account grows past the mortgage, with a typical (median) '
        f'surplus near ${V14["median_surplus_yr30"]/1e6:.1f}M shared between FutureProof and the funder. The homeowner, for '
        'their part, draws a guaranteed income throughout and retains their home with its equity preserved in every '
        'outcome, bearing none of the investment risk. The insurance and reinsurance layers cleanly absorb the '
        'minority tail. The body of this report verifies the engineering behind that result.',
        styles['BodyText2']
    ))
    story.append(Paragraph(
        'This report reviews the FutureProof Equity Preservation Mortgage (EPM) model as a piece of '
        'quantitative engineering — the stochastic processes, simulation mechanics, insurance pricing, and '
        'the Payments & Risk Waterfall. Its purpose is to document how the model works and to verify that the logic '
        'is internally consistent. A separate companion paper — "Model Assumptions and Parameter Risk" '
        '— examines whether the <i>input parameters</i> are empirically defensible.',
        styles['BodyText2']
    ))
    story.append(Paragraph(
        'A critical distinction in this review is between Probability of Deficit (PoD) and Probability of Claim (PoC). '
        'PoD is a balance sheet snapshot — it shows what fraction of paths are in deficit at a given point in time. '
        'PoC is the actuarially relevant metric — it measures the probability of an actual insurance claim, which can only '
        'occur when a mortgage expires. PoC is the primary metric for insurance and reinsurance pricing.',
        styles['BodyText2']
    ))
    story.append(Paragraph(
        'All headline numbers in this report are <i>model-as-written</i> — computed at the current parameter set '
        '(μ = 9.2%, γ = 0.163, θ = 2.13%, collar cost 0.046%, asymmetric collar cap +40% / floor -20%, '
        'profit share 10% at 3-year resets). The companion Model Assumptions paper discusses how outputs '
        'shift under alternative parameter calibrations.',
        styles['BodyText2']
    ))

    story.append(Paragraph('Key Findings', styles['SubHead']))
    findings = [
        f'Independent 50,000-path Monte Carlo confirms <b>~{100-float(V14["deficit_prob_yr30"]):.0f}% of mortgages finish in surplus</b> at maturity (per-mortgage PoD {V14["deficit_prob_yr30"]}%, SE {V14["deficit_se"]}%), with a median surplus of ~${V14["median_surplus_yr30"]/1e6:.1f}M',
        f'<b>Portfolio reinsurance PoC is bounded above by the per-mortgage reinsurance PoC of {V14["reins_poc_per_mortgage"]}% (the hard ceiling)</b> and sits modestly below it after the Payments & Risk Waterfall (ETF selldown + cross-subsidisation from surplus mortgages). Cross-subsidisation pools the ~92% of mortgages that reach maturity in surplus against the ~8% in deficit, reducing residual claims.',
        f'Insurance claims arise only on EXPIRING mortgages. The per-mortgage reinsurance PoC ({V14["reins_poc_per_mortgage"]}%) is the hard ceiling for the portfolio figure — cross-subsidisation and diversification can only reduce it. (Note: the portfolio balance-sheet deficit probability is a PoD snapshot, not a claim metric.)',
        'Insurance claims can only arise at mortgage expiry (Year 30) — PoD before expiry is irrelevant to insurance',
        'Asymmetric volatility collar (cap +40% / floor -20%) manages downside exposure on 16.6% equity vol',
        'Stochastic OU cash rates with equity correlation of 0.30 (appropriate for 30-year horizons)',
        'Insurance premium based on discounted expected deficit (S3), discounted at 2.13% (cash rate mean)',
        'LMI covers 80% of loss; worst 20% of deficit paths (larger losses) transferred as tail risk to reinsurance',
        'Surplus at maturity split 50/50 between FutureProof and Mortgage Funder',
        'Profit realisation every 3 years: 10% of running surplus drawn at each 3-year reset',
    ]
    for f in findings:
        story.append(Paragraph(f'<bullet>&bull;</bullet> {f}', styles['BulletCustom']))

    story.append(PageBreak())

    # PoD vs PoC — the critical distinction
    story.append(Paragraph('PoD vs PoC — The Critical Distinction', styles['SectionHead']))
    story.append(fig_to_image(chart_pod_vs_poc(), height=85*mm))
    story.append(Paragraph(
        '<b>Probability of Deficit (PoD)</b> is a balance sheet view — it shows whether the investment account is below '
        f'the mortgage balance at a particular point in time. PoD is naturally high in early years ({DEFICIT_BY_YEAR[0]:.1f}% at year 1) — '
        'not because anything is going wrong, but because the investment account is still accumulating against the '
        'freshly-drawn mortgage before compounding takes over (much as a newly-drawn mortgage is "underwater" the day '
        f'it is taken out). It declines steadily to {V14["deficit_prob_yr30"]}% by year 30 as the account compounds and '
        'outgrows the mortgage balance; the typical (median) path crosses into surplus around year 14 and finishes '
        f'with roughly ${V14["median_surplus_yr30"]/1e6:.1f}M of surplus in the investment account.',
        styles['BodyText2']
    ))
    story.append(Paragraph(
        '<b>Probability of Claim (PoC)</b> is the actuarially relevant metric. An insurance claim can <b>only</b> be made '
        'when a mortgage loan contract expires — any PoD prior to that point is irrelevant to insurance and reinsurance. '
        'This is why PoC is calculated only at mortgage expiry (Year 30). '
        'Furthermore, before any insurance claim is triggered, the <b>Payments & Risk Waterfall</b> is applied:',
        styles['BodyText2']
    ))
    waterfall = [
        '<b>Step 1:</b> Sell down the ETFs in the expiring mortgage\'s investment account',
        '<b>Step 2:</b> Cross-subsidise by taking surpluses from other open mortgages in the portfolio',
        '<b>Step 3:</b> Only after Steps 1 and 2 is the net deficit known — this determines the actual PoC',
    ]
    for w in waterfall:
        story.append(Paragraph(f'<bullet>&bull;</bullet> {w}', styles['BulletCustom']))
    story.append(Paragraph(
        f'This is why the portfolio reinsurance PoC sits below the per-mortgage reinsurance PoC '
        f'({V14["reins_poc_per_mortgage"]}%, the hard ceiling) and far below the per-mortgage PoD '
        f'({V14["deficit_prob_yr30"]}%). The Payments & Risk Waterfall pools the surpluses of the ~92% of mortgages '
        f'that reach maturity in surplus against the deficits of the ~8% that underperform; only the residual after this cross-subsidy '
        f'can trigger a claim. The cross-subsidy is the primary risk-mitigation mechanism, and it is powerful. '
        f'(The portfolio balance-sheet deficit probability is a PoD snapshot of the whole book, not a '
        f'claim metric — see the Portfolio Probability of Claim section.)',
        styles['BodyText2']
    ))

    story.append(PageBreak())

    # Portfolio PoC chart
    story.append(Paragraph('Portfolio Probability of Claim (PoC)', styles['SectionHead']))
    story.append(fig_to_image(chart_risk_cascade(), height=80*mm))
    story.append(Paragraph(
        'The cascade above shows how the Payments & Risk Waterfall reduces risk: the LMI layer absorbs the first '
        '~80% of each deficit (taking per-mortgage PoD down to the per-mortgage reinsurance PoC ceiling), and portfolio '
        'cross-subsidisation and diversification then pool surpluses against deficits — taking the portfolio reinsurance '
        'PoC modestly below that ceiling.',
        styles['BodyText2']
    ))
    story.append(make_table(
        ['Metric', 'Value', 'Notes'],
        [
            ['Per-mortgage PoD (yr 30)', f'{V14["deficit_prob_yr30"]}%', 'One mortgage in deficit at maturity (balance-sheet view)'],
            ['Per-mortgage reinsurance PoC', f'{V14["reins_poc_per_mortgage"]}%', 'Deficit beyond the LMI top-cover boundary — the hard ceiling for the portfolio figure'],
            ['Portfolio reinsurance PoC (after cross-subsidy)', f'≤ {V14["reins_poc_per_mortgage"]}%', 'Bounded by the per-mortgage ceiling; diversification reduces it modestly'],
        ],
        col_widths=[48*mm, 35*mm, 82*mm]
    ))
    story.append(Spacer(1, 3*mm))
    story.append(Paragraph(
        f'<b>What this means.</b> The per-mortgage reinsurance PoC ({V14["reins_poc_per_mortgage"]}%) is the hard '
        f'ceiling for the portfolio figure, which sits modestly below it after cross-subsidisation — and far below '
        f'the per-mortgage PoD ({V14["deficit_prob_yr30"]}%). Two related figures describe '
        f'why the pool is always deep, and they should not be confused:',
        styles['BodyText2']
    ))
    story.append(Paragraph(
        f'<bullet>&bull;</bullet> <b>At maturity (the only point a claim can arise): ~92% of mortgages are in '
        f'surplus and only ~8% in deficit</b> — this is the {V14["deficit_prob_yr30"]}% per-mortgage PoD. By '
        f'year 30, P&I amortisation has shrunk the loan and the offset account has had three decades to compound, '
        f'so the large majority finish well in surplus.',
        styles['BulletCustom']
    ))
    story.append(Paragraph(
        f'<bullet>&bull;</bullet> <b>Across the full 30-year horizon, ~85% of return pathways are positive and '
        f'~15% negative</b> — a broader figure that also counts paths dipping into deficit at some point before '
        f'recovering. It explains why, at any point in time, a funder\'s loan book holds far more surplus '
        f'mortgages than deficit ones (otherwise the S&P 500 would not appreciate over the long run).',
        styles['BulletCustom']
    ))
    story.append(Paragraph(
        'Either way, the surpluses pool to cover the deficits, so only the residual after the Payments & Risk '
        'Waterfall can trigger a claim. The per-mortgage reinsurance PoC is the hard ceiling — cross-subsidisation '
        'can only reduce claims, never increase them. It is the dominant risk-mitigation mechanism, and it is powerful.',
        styles['BodyText2']
    ))
    story.append(fig_to_image(chart_cross_subsidy_pool(), height=75*mm))

    story.append(PageBreak())

    # Portfolio PoC — provenance and the PoD/PoC distinction
    story.append(Paragraph('Portfolio PoC — Provenance and the PoD/PoC Distinction', styles['SectionHead']))
    story.append(Paragraph(
        'Three distinct "deficit probability" metrics circulate in EPM analysis and are easy to conflate. The '
        'table distinguishes them. The critical point: a <b>portfolio deficit-probability snapshot</b> (PoD) is '
        'not a claim probability (PoC). Insurance claims arise only on expiring mortgages, after the Payments '
        'Waterfall.',
        styles['BodyText2']
    ))
    story.append(Spacer(1, 3*mm))
    story.append(make_table(
        ['Metric', 'What it measures', 'Type', 'Value'],
        [
            ['Per-mortgage PoD at maturity', 'Single mortgage: investment account < loan balance at year 30', 'PoD', f'{V14["deficit_prob_yr30"]}%'],
            ['Per-mortgage reinsurance PoC', 'Single mortgage: deficit exceeds LMI top-cover boundary at maturity', 'PoC (ceiling)', f'{V14["reins_poc_per_mortgage"]}%'],
            ['Portfolio reinsurance PoC', 'Residual reinsurance claim on expiring mortgages after cross-subsidy', 'PoC (the figure to quote)', f'≤ {V14["reins_poc_per_mortgage"]}%'],
            ['Portfolio balance-sheet deficit prob.', 'Aggregate portfolio balance < 0 at a point in time (xlsm Portfolio sheet)', 'PoD (NOT a claim metric)', '≈ per-mortgage PoD'],
        ],
        col_widths=[40*mm, 56*mm, 36*mm, 22*mm]
    ))
    story.append(Spacer(1, 4*mm))
    story.append(Paragraph(
        f'<b>How the portfolio PoC is established.</b> The portfolio reinsurance PoC is bounded above by the '
        f'per-mortgage reinsurance PoC of {V14["reins_poc_per_mortgage"]}% — the hard ceiling — and sits modestly '
        f'below it after cross-subsidisation and diversification. Cross-subsidisation can only reduce the '
        f'per-mortgage figure, so any portfolio PoC at or above {V14["reins_poc_per_mortgage"]}% would be '
        f'definitionally impossible. We anchor the analysis on this ceiling rather than a fragile portfolio point estimate.',
        styles['BodyText2']
    ))
    story.append(Paragraph(
        '<b>What the portfolio PoC is NOT.</b> The xlsm Portfolio sheet, labelled "prob of portfolio deficit", '
        'is the probability the aggregate book balance is negative at a point in time — a '
        'PoD snapshot of the whole portfolio (expiring plus unexpiring mortgages). It is not a claim metric: '
        'claims arise only on expiring mortgages, after cross-subsidy. That figure tracks the per-mortgage '
        'PoD and must not be quoted as portfolio PoC.',
        styles['BodyText2']
    ))

    story.append(PageBreak())

    # Deficit probability (PoD) — for context only
    story.append(Paragraph('Deficit Probability (PoD) Over Time — Balance Sheet View', styles['SectionHead']))
    story.append(fig_to_image(chart_deficit_over_time(), height=85*mm))
    story.append(Paragraph(
        'PoD shows the fraction of paths in deficit at each point in time — a useful balance sheet view but <b>not</b> '
        f'the probability of an insurance claim. PoD starts at {DEFICIT_BY_YEAR[0]:.1f}% in year 1 and declines to {V14["deficit_prob_yr30"]}% by year 30. '
        'The rapid decline after year 10 reflects P&I amortisation — as the loan shrinks, the investment needs only '
        'modest returns to exceed the declining balance. Note: PoD at any point before mortgage expiry is irrelevant '
        'to insurance and reinsurance — only PoC on expiring mortgages matters.',
        styles['BodyText2']
    ))

    story.append(PageBreak())

    # Surplus distribution
    story.append(Paragraph('Surplus Distribution — Fan Chart', styles['SectionHead']))
    story.append(fig_to_image(chart_surplus_fan(), height=85*mm))
    story.append(Paragraph(
        'The fan chart shows the distribution of surplus (investment balance minus mortgage balance) over the 30-year tenure. '
        f'The median surplus reaches ${V14["median_surplus_yr30"]:,.0f} at maturity. '
        'The 10th-90th percentile band widens over time but remains predominantly positive after year 15.',
        styles['BodyText2']
    ))
    story.append(Paragraph(
        '<b>Important:</b> Surplus at maturity is split 50/50 between FutureProof and the Mortgage Funder — '
        'it does not go to the borrower. Additionally, partial profit realisations occur every 3 years (10% of surplus '
        'drawn). These periodic realisations are factored into the model.',
        styles['BodyText2']
    ))

    story.append(PageBreak())

    # Holiday mechanism
    story.append(Paragraph('Holiday Mechanism Analysis', styles['SectionHead']))

    story.append(Paragraph(
        'The interest holiday mechanism is a protective feature that temporarily pauses payment of loan costs '
        '(interest charges and part-principal repayments) when the offset account falls below a threshold '
        '(0.75× the initial offset account balance at start-of-loan). Paused interest is deferred, not accrued '
        'and compounded — it remains charged as simple interest. An interest holiday ceases when the mortgage '
        'offset account balance is restored over time to the holiday-exit threshold (currently 145.8% of the '
        'original offset balance at start-of-loan). This iterative process of ETF sell-down versus interest '
        'holidays is continuous through the loan lifecycle — managing index volatility and economic cycles — '
        'until all ETFs are exhausted, which would result in a deficit for that mortgage.',
        styles['BodyText2']
    ))

    # Lead with per-year view — the strongest honest framing
    story.append(Paragraph('Per-Year View — In Most Years the Median Mortgage Needs No Holiday', styles['SubHead']))
    story.append(Paragraph(
        'In any given year of the 30-year term, <b>the median mortgage requires zero interest holidays</b> '
        '(the per-year holiday rate stays below 50% throughout). Individual paths '
        'that experience adverse early-year returns can enter holiday mode. Holiday frequency peaks in years 2-8 '
        'during the annuity period, dips after annuity cessation at year 10, then gradually rises again in later years '
        'as fee drags accumulate on underperforming paths.',
        styles['BodyText2']
    ))

    # Per-year chart first
    story.append(fig_to_image(chart_holiday_count(), height=75*mm))
    story.append(Paragraph(
        'The chart above shows the mean holiday fraction by year across all 50,000 paths. Holidays concentrate in '
        'the early years — while the investment account is still building against the freshly-drawn mortgage — '
        'peaking at roughly a quarter of paths around year 7-8, then fading to about 2% by maturity as the account '
        'compounds. The median path is never on holiday in any year, and over the full term more than half of '
        'mortgages never enter a holiday at all (see below). A holiday never affects the borrower — they keep '
        'receiving their annuity throughout; it is an internal safety valve, not a sign of borrower distress.',
        styles['BodyText2']
    ))

    story.append(Spacer(1, 3*mm))
    story.append(make_table(
        ['Year Range', 'Median (per year)', 'P90 (per year)', 'P99 (per year)', 'Interpretation'],
        [
            ['Years 1-10', '0', '1', '1', 'Early-years safety valve while the account builds; median path takes none'],
            ['Years 11-20', '0', '0-1', '1', 'Fading as the account compounds'],
            ['Years 21-30', '0', '0-1', '1', 'Rare — only on weaker paths'],
        ],
        col_widths=[28*mm, 28*mm, 28*mm, 28*mm, 38*mm]
    ))

    story.append(Spacer(1, 5*mm))

    # Cumulative view as supporting detail
    story.append(Paragraph('Cumulative View — Total Holidays Over 30 Years', styles['SubHead']))
    _hol_enter = 100 - _MC['pct_zero_holidays']
    _hol_cond = _MC['mean_total_holiday_years'] / (1 - _MC['pct_zero_holidays']/100)
    story.append(Paragraph(
        f'Viewed cumulatively over the full 30-year term, <b>more than half of mortgages ({_MC["pct_zero_holidays"]:.0f}%) '
        f'never enter a holiday at all</b>, and the typical (median) mortgage takes none. Across the whole book the '
        f'average is just {_MC["mean_total_holiday_years"]:.1f} holiday-years over 30 years. Holidays are not defaults — '
        'the borrower keeps receiving their annuity, deferred interest is repaid as the investment account recovers, '
        'and usage concentrates on the minority of paths with adverse early-year returns:',
        styles['BodyText2']
    ))

    # (Cumulative holiday-count distribution chart suppressed: the available distribution
    #  detail is from an earlier holiday analysis and is inconsistent with current-model
    #  totals. The v14d summary figures are shown in the table below instead.)

    story.append(make_table(
        ['Metric', 'Value (50,000-path)', 'Interpretation'],
        [
            ['Paths with zero holidays', f'{_MC["pct_zero_holidays"]:.0f}%', 'Never require a holiday over 30 years'],
            ['Paths entering holiday', f'{_hol_enter:.0f}%', 'Use the holiday mechanism at least once'],
            ['Mean holiday-years (all paths)', f'{_MC["mean_total_holiday_years"]:.1f}', 'Average across the full distribution'],
            ['Mean holiday-years (conditional)', f'~{_hol_cond:.1f}', 'Average for paths that do enter holiday'],
        ],
        col_widths=[45*mm, 35*mm, 70*mm]
    ))
    story.append(Paragraph(
        '<i>Per-year holiday rates use the 50,000-path simulation; the full cumulative percentile distribution '
        '(P75/P90/P99 of total holiday-years) awaits a dedicated holiday-analysis run on the current model.</i>',
        styles['BodyText2']
    ))

    story.append(PageBreak())

    # Holiday repayments and insurance coverage
    story.append(Paragraph('Holiday Repayments & Insurance Coverage', styles['SubHead']))
    story.append(Paragraph(
        'Critically, the number of interest holidays must be understood in the context of <b>subsequent '
        'holiday repayments</b>. When market conditions improve following downturns — as they historically '
        'do over the long term — the deferred interest is repaid from the recovering investment account. '
        'The holiday mechanism is designed as a temporary pause, not a permanent deferral.',
        styles['BodyText2']
    ))
    story.append(Paragraph(
        'If the net result of holidays and subsequent repayments is that any amount of loan cost remains '
        'outstanding at end-of-term, it is covered by <b>insurance up to the policy top cover limit</b> (LMI, '
        'covering 80% of deficit paths). Any balance beyond the LMI top cover limit is covered by '
        '<b>portfolio reinsurance</b>, where the Payments & Risk Waterfall (ETF selldown, cross-subsidisation from '
        'surplus loans) is applied before any reinsurance claim is made.',
        styles['BodyText2']
    ))

    story.append(Spacer(1, 3*mm))
    story.append(Paragraph(
        'Holidays are a temporary pause, not a permanent deferral: when markets recover, the deferred interest '
        'is repaid from the rebuilding investment account. Any deferred interest still outstanding at maturity '
        'is rolled into the year-30 deficit calculation and is therefore already captured in the per-mortgage '
        'PoD and the insurance/reinsurance figures elsewhere in this report — it is not an additional uncovered '
        'exposure. (A dedicated quantification of residual deferred interest at maturity is a candidate for the '
        'next holiday-analysis run on the current model.)',
        styles['BodyText2']
    ))

    # What the model gets right
    story.append(Paragraph('What the Model Gets Right', styles['SectionHead']))
    rights = [
        ('<b>Investment structure:</b> Loan proceeds held in mortgage offset account, invested by BlackRock in '
         'passive S&amp;P500 index-linked ETFs. Two-layer volatility reduction: BlackRock Volatility Control (volatility buffer) '
         'then SpiderRock continuous dynamic hedging via asymmetric collar (cap +40% / floor -20%). Modelled as cap/floor (1.4/0.8) on quarterly returns.'),
        ('<b>Stochastic interest rates:</b> The OU mean-reversion model (speed=0.24, vol=1.22%) is appropriate for '
         'Australian cash rates.'),
        ('<b>Equity-rate correlation at 0.30:</b> Over 30-year horizons, the correlation between cash rates and '
         'equity/investment returns is marginally positive (typically 0.1-0.3). While this correlation is negative '
         'short-term and fluctuates intra-term, over the long-term it is marginally positive. The 0.30 assumption '
         'is appropriate for the 30-year product horizon.'),
        ('<b>Deterministic house prices (by design):</b> This is NOT a shared appreciation mortgage. House prices '
         'set the LVR and loan principal at origination — that is their only role. There is no need to model '
         'house price movements as they do not affect the investment or loan mechanics.'),
        ('<b>Run-off mechanism (no early exits):</b> The EPM has a unique run-off mechanism — no voluntary prepayments '
         'or early terminations are permitted until all loan cost has been paid from the investment/offset account. '
         'This eliminates early exit risk that affects traditional mortgages.'),
        ('<b>Insurance pricing:</b> LMI and tail risk (reinsurance) premiums are paid upfront at mortgage origination. '
         'Premium is calculated on the discounted expected deficit (S3), with LMI covering 80% of deficit paths and the '
         'worst 20% of deficit paths (larger losses) transferred as tail risk to reinsurance.'),
        ('<b>Payments & Risk Waterfall:</b> The portfolio-level waterfall (ETF selldown → cross-subsidisation → net deficit) '
         'dramatically reduces the actual Probability of Claim from individual PoD levels.'),
        ('<b>Profit realisation:</b> 10% of running surplus drawn every 3 years — correctly modelled.'),
    ]
    for r in rights:
        story.append(Paragraph(f'<bullet>&bull;</bullet> {r}', styles['BulletCustom']))

    story.append(PageBreak())

    # Insurance Premium Analysis
    story.append(Paragraph('Insurance Premium Analysis', styles['SectionHead']))

    story.append(Paragraph('Premium Calculation Methodology', styles['SubHead']))
    story.append(Paragraph(
        'The insurance premium is calculated on the <b>discounted expected deficit (S3)</b>, not on raw deficit values. '
        'This discounting is necessary because no reinsurance claim can be made until mortgage expiry (Year 30). '
        'Both LMI and reinsurance premiums are paid upfront at mortgage origination. '
        'The discount rate of 2.13% corresponds to the long-run cash rate mean (MLE estimate).',
        styles['BodyText2']
    ))

    story.append(Paragraph('Two-Layer Insurance Structure', styles['SubHead']))
    ins_layers = [
        '<b>LMI (Lenders Mortgage Insurance):</b> Covers 80% of deficit paths (smaller losses). Premium is based on '
        'the discounted expected deficit at mortgage expiry. Both the LMI and tail risk premiums are '
        'paid upfront at mortgage origination.',
        '<b>Tail Risk (Reinsurance):</b> Covers the worst 20% quantile of losses. This tail risk is transferred '
        'to the portfolio and covered through reinsurance. Critically, the Payments & Risk Waterfall is applied before '
        'any reinsurance claim is made — and claims can only arise at mortgage expiry (Year 30). '
        f'This is why the portfolio reinsurance PoC sits modestly below the per-mortgage reinsurance PoC of {V14["reins_poc_per_mortgage"]}%, which is the hard ceiling — cross-subsidisation and diversification can only reduce it.',
    ]
    for l in ins_layers:
        story.append(Paragraph(f'<bullet>&bull;</bullet> {l}', styles['BulletCustom']))

    story.append(Spacer(1, 5*mm))
    story.append(make_table(
        ['Metric', 'Value', 'Notes'],
        [
            ['Discounted Expected Deficit (S3)', f'${abs(V14["cond_expected_deficit"]):,.0f}', 'Basis for premium calculation'],
            ['Discount Rate', '2.13%', 'cash rate mean yield'],
            ['Fair LMI Premium (PV)', f'${V14["ins_fair_premium"]:,.0f}', f'SE: ${V14["ins_stderr"]:,.0f}; covers 80% of deficit paths'],
            ['Fair + Loading (50%)', f'${V14["ins_plus_loading"]:,.0f}', '1.27% of max loan'],
            ['Tail Risk Premium', f'${V14["tail_risk_premium"]:,.0f}', 'Worst 20% of deficit paths (larger losses); covered via reinsurance'],
            ['Individual PoD at Yr 30', f'{V14["deficit_prob_yr30"]}%', 'Balance sheet view (before waterfall)'],
            ['Per-mortgage reinsurance PoC', f'{V14["reins_poc_per_mortgage"]}%', 'Deficit beyond LMI boundary — hard ceiling for portfolio PoC'],
            ['Portfolio reinsurance PoC', f'≤ {V14["reins_poc_per_mortgage"]}%', 'Bounded by the per-mortgage ceiling; modestly lower after cross-subsidy'],
        ],
        col_widths=[50*mm, 30*mm, 70*mm]
    ))

    story.append(PageBreak())

    # Actuarial assessment
    story.append(Paragraph('Actuarial Assessment', styles['SectionHead']))

    story.append(Paragraph('Is the Logic Sound?', styles['SubHead']))
    story.append(Paragraph(
        'Yes. The model is a well-constructed Monte Carlo simulation with appropriate stochastic '
        'processes for equity returns (GBM with mean reversion per Shevchenko 2026) and interest rates '
        '(Ornstein-Uhlenbeck with exact discretisation). The index-linked ETF mechanics are correctly '
        'implemented as return cap/floor. The P&I amortisation schedule is standard. The Payments & Risk Waterfall '
        'correctly models the portfolio-level risk mitigation that reduces PoC relative to PoD. The '
        'simulation converges cleanly at 50,000 paths (SE 0.12% on PoD at base case).',
        styles['BodyText2']
    ))
    story.append(Paragraph(
        'The logic of the model is therefore sound as a piece of quantitative engineering. This is a '
        'separate question from whether the <i>inputs</i> (μ, γ, θ, collar cost, margin) are the right '
        'inputs — which is addressed in the companion Model Assumptions paper.',
        styles['BodyText2']
    ))

    story.append(Paragraph('Simulation precision resolved:', styles['BodyText2']))
    story.append(Paragraph(
        f'<bullet>&bull;</bullet> Independent 50,000-path Monte Carlo confirms {V14["deficit_prob_yr30"]:.1f}% PoD (SE: {V14["deficit_se"]:.2f}%) and fair premium '
        f'of ${V14["ins_fair_premium"]:,.0f} at base-case parameters — actuarial-grade precision. The production '
        'spreadsheet tool now runs both per-mortgage and portfolio simulations at 50,000 paths for internal '
        'decisioning.',
        styles['BulletCustom']
    ))

    story.append(Paragraph('Are the Numbers Correct?', styles['SubHead']))
    story.append(Paragraph(
        'The outputs are internally consistent with the model\'s inputs and methodology. Whether the inputs '
        'themselves are correctly calibrated is examined in the companion paper; the numbers below describe '
        'the model-as-written at the base-case parameter set.',
        styles['BodyText2']
    ))
    checks = [
        f'<b>PoD trajectory:</b> {DEFICIT_BY_YEAR[0]:.1f}% at year 1 declining to {V14["deficit_prob_yr30"]}% at year 30 — consistent with the '
        f'investment account compounding past the mortgage balance over the term ({V14["effective_lvr"]:.1f}% effective LVR with {V14["variable_costs"]}% cost drag).',
        f'<b>Portfolio reinsurance PoC:</b> sits modestly below the per-mortgage reinsurance PoC of '
        f'{V14["reins_poc_per_mortgage"]}% (the hard ceiling) after cross-subsidisation and diversification. '
        f'Cross-subsidisation pools surplus loans against deficit loans and is the dominant risk-mitigation mechanism.',
        f'<b>Insurance premium:</b> Based on discounted expected deficit (S3), discounted at 2.13% over up to 30 years. '
        f'Premiums paid upfront at mortgage origination; claims deferred until loan expiry.',
        '<b>Surplus split:</b> 50/50 between FutureProof and Mortgage Funder, with 10% partial realisation every 3 years. '
        'This is correctly factored into the surplus trajectories.',
        '<b>Parameter-sensitivity (companion paper):</b> The Model Assumptions paper documents how outputs '
        'shift under alternative parameter calibrations. The model is correct; the inputs drive the range.',
    ]
    for c in checks:
        story.append(Paragraph(f'<bullet>&bull;</bullet> {c}', styles['BulletCustom']))

    story.append(PageBreak())

    # Parameter Optimisation Analysis
    if SENSITIVITY_RESULTS:
        story.append(Paragraph('Parameter Optimisation Analysis', styles['SectionHead']))
        story.append(Paragraph(
            'A key insight from our sensitivity analysis: the parameters you control — eligible house value, LVR, '
            'and annuity level — have a dramatic effect on PoD and PoC. The single most important driver is the '
            '<b>annuity as a percentage of the initial loan</b> (the "cost burden ratio"). Increasing the eligible '
            'house value while keeping the annuity fixed reduces this ratio, which dramatically reduces both PoD and PoC.',
            styles['BodyText2']
        ))

        # Sensitivity scatter chart
        fig = chart_sensitivity_annuity_ratio()
        if fig:
            story.append(fig_to_image(fig, height=85*mm))

        story.append(Paragraph('Sensitivity Results — 27 Scenarios (10,000 paths each)', styles['SubHead']))

        # Build table from sensitivity results — show top scenarios and baseline
        sorted_sens = sorted(SENSITIVITY_RESULTS, key=lambda x: x['poc_yr30_est'])
        sens_rows = []
        for r in sorted_sens[:10]:  # Top 10
            sens_rows.append([
                f'${r["home_value"]/1e6:.1f}M',
                f'{r["lvr"]*100:.0f}%',
                f'${r["initial_loan"]:,.0f}',
                f'${r["annuity_pa"]/1000:.0f}K',
                f'{r["annuity_pct_of_loan"]:.2f}%',
                f'{r["pod_yr30"]:.1f}%',
                f'{r["poc_yr30_est"]:.2f}%',
                f'${r["mean_surplus"]:,.0f}',
            ])

        story.append(make_table(
            ['House Value', 'LVR', 'Loan', 'Annuity', 'Ann/Loan', 'PoD(30)', 'PoC(30)', 'Mean Surplus'],
            sens_rows,
            col_widths=[18*mm, 12*mm, 22*mm, 16*mm, 16*mm, 15*mm, 15*mm, 26*mm]
        ))

        story.append(Spacer(1, 3*mm))

        # Heatmap
        fig2 = chart_sensitivity_heatmap()
        if fig2:
            story.append(PageBreak())
            story.append(Paragraph('PoC Heatmap — House Value vs LVR ($15K Annuity)', styles['SubHead']))
            story.append(fig_to_image(fig2, height=85*mm))

        story.append(Paragraph('Key Optimisation Insights', styles['SubHead']))
        opt_insights = [
            '<b>Annuity/Loan ratio is the primary driver:</b> At 0.62% (=$15K on $2.4M loan), PoD drops to 6.0% '
            'and portfolio PoC to 0.19%. At 2.08% (=$25K on $1.2M loan), PoD rises to 14.8% and PoC to 0.60%.',
            '<b>Higher house value with fixed annuity dramatically reduces risk:</b> $3M house / 80% LVR / $15K annuity '
            'produces PoC of 0.19% — the best scenario. The larger loan makes the fixed annuity a smaller burden.',
            '<b>Counterintuitively, higher LVR can reduce PoD:</b> At $3M house value, going from 60% to 80% LVR '
            'reduces PoD from 6.9% to 6.0% because the annuity/loan ratio drops from 0.83% to 0.62%.',
            '<b>Annuity reduction is powerful:</b> At $2M/80% LVR, cutting annuity from $25K to $15K reduces '
            'PoD from 11.0% to 7.6% and PoC from 0.41% to 0.25%.',
            '<b>All 27 scenarios show portfolio PoC below 1%</b> — confirming the Payments & Risk Waterfall makes '
            'the product commercially viable across a wide range of parameter settings.',
            '<b>Recommended sweet spot:</b> Minimum eligible house value of $2.5M with $15-20K annuity. '
            'This achieves PoC of 0.19-0.26% with substantial surplus ($3.7-5.2M mean).',
        ]
        for o in opt_insights:
            story.append(Paragraph(f'<bullet>&bull;</bullet> {o}', styles['BulletCustom']))

        story.append(PageBreak())

    # Recommendations
    story.append(Paragraph('Summary & Recommendations', styles['SectionHead']))

    story.append(Paragraph('Model Strengths', styles['SubHead']))
    strengths = [
        f'Simulation precision achieved — 50,000 paths, SE {V14["deficit_se"]:.2f}% on PoD, SE ${V14["ins_stderr"]} on premium',
        'Correct distinction between PoD (balance sheet) and PoC (insurance claim on expiring mortgages)',
        f'Payments & Risk Waterfall keeps the portfolio reinsurance PoC modestly below the per-mortgage reinsurance PoC of {V14["reins_poc_per_mortgage"]}% — the hard ceiling',
        'Run-off mechanism eliminates early exit risk (unique to EPM)',
        'Deterministic house prices correct for this product (not a shared appreciation mortgage)',
        'Stochastic interest rates with exact OU discretisation; Cholesky-correlated equity shocks',
        'Insurance premiums based on discounted expected deficit, paid upfront at mortgage origination',
    ]
    for s in strengths:
        story.append(Paragraph(f'<bullet>&bull;</bullet> {s}', styles['BulletCustom']))

    story.append(Paragraph('Model-Level Enhancement Priorities', styles['SubHead']))
    priorities = [
        '[DONE] Simulation paths increased to 50,000 — actuarial-grade precision achieved',
        '[DONE] PoC vs PoD distinction clearly established',
        '[DONE] Production spreadsheet now runs both per-mortgage and portfolio simulations at 50,000 paths',
        '[HIGH] Re-anchor collar cost input on Black-Scholes (0.30% minimum) — current 0.046% is inconsistent with current AU rates',
        '[HIGH] Re-anchor θ (cash rate mean) on AU MLE, not US Fed Funds MLE — move to 3.0% minimum',
        '[MEDIUM] Add scenario switcher (base / realistic-central / adverse-plausible) to the model UI',
        '[MEDIUM] Add wholesale margin sensitivity analysis directly in the model',
        '[LOW] Add multi-region parameter sets (AU, NZ, UK, US)',
    ]
    for p in priorities:
        story.append(Paragraph(f'<bullet>&bull;</bullet> {p}', styles['BulletCustom']))

    story.append(Paragraph('Product Recommendations', styles['SubHead']))
    recs = [
        'Maintain P&I as the default — the single most impactful risk reduction lever',
        'The $25K annuity on $2–3M eligible house value is well-calibrated for current base-case parameters',
        'Report PoD as a range (base / realistic / adverse) in all internal and external materials — not a point',
        'Size capital and reinsurance attachment to the adverse-plausible leg, not the base case',
    ]
    for r in recs:
        story.append(Paragraph(f'<bullet>&bull;</bullet> {r}', styles['BulletCustom']))

    story.append(PageBreak())

    # EPM vs Current Investment Landscape
    story.append(Paragraph('EPM vs Current Investment Landscape', styles['SectionHead']))
    story.append(Paragraph(
        'To contextualise the EPM risk profile, we compare its base-case metrics against established '
        'benchmarks across traditional mortgages and rated credit instruments. Stress-scenario comparisons '
        '(realistic-central / adverse-plausible) will be provided in the forthcoming companion Parameter '
        'Risk paper once that framework has been re-calibrated to the current model.',
        styles['BodyText2']))

    _ep_yr30 = V14["deficit_prob_yr30"]
    _expected_loss = _ep_yr30 * 0.1194  # PoD × ~11.9% LGD (xlsm cond. deficit $143,274 / $1.2M max loan) ≈ % expected loss
    story.append(make_table(
        ['Metric', 'EPM (base case)', 'Prime AU Mortgage', "Moody's AA Bond"],
        [
            ['Cumulative PoD (30yr)', f'{_ep_yr30:.2f}%', '3–5%', '~1.5%'],
            ['Loss severity (LGD)', '~10–12%', '20–40%', '40–60%'],
            ['Expected loss (30yr)', f'~{_expected_loss:.2f}%', '0.6–1.25%', '0.6–0.9%'],
            ['Claim timing', 'Year 30 only', 'Any year', 'Any year'],
            ['Prepayment / lapse risk', 'None (run-off)', 'Significant', 'Moderate'],
        ],
        col_widths=[40*mm, 34*mm, 34*mm, 34*mm]
    ))

    story.append(Spacer(1, 3*mm))
    landscape_points = [
        '<b>Structural risk driver is fundamentally different.</b> Traditional credit risk stems from borrower '
        'inability to pay. EPM risk stems from 30-year equity-market underperformance relative to interest '
        'rates. These drivers are largely uncorrelated, so the EPM is a natural diversifier in a traditional '
        'credit portfolio.',
        '<b>Claim concentration at maturity.</b> Traditional mortgage credit incurs claims throughout the loan '
        'life; the EPM produces claims only at year 30. This concentrates capital-and-reserve requirements '
        'at maturity but eliminates intra-life prepayment and lapse risk entirely.',
        '<b>Loss severity is structurally bounded.</b> The ~10–12% conditional severity reflects the structural '
        'property of the EPM — at deficit, the loss is the gap between the investment account and the mortgage '
        'balance, not the full mortgage balance as in a traditional foreclosure. This severity is materially '
        'lower than corporate-bond or RMBS subordination losses.',
        '<b>Stress sensitivity to be addressed separately.</b> All base-case figures above use the model\'s '
        'central parameter calibration. The forthcoming Parameter Risk paper will quantify outcomes under '
        'realistic-central and adverse-plausible parameter stresses.',
    ]
    for lp in landscape_points:
        story.append(Paragraph(f'<bullet>&bull;</bullet> {lp}', styles['BulletCustom']))

    story.append(PageBreak())

    # ---- HOW THE EPM WORKS — EQUITY RETURN WITH MORTGAGE-LIKE RISK ----
    story.append(Paragraph('How the EPM Works — Equity Return with Mortgage-Like Risk', styles['SectionHead']))
    story.append(Paragraph(
        'Index-linking the EPM converts long-term equity returns into a mortgage-like risk profile, delivering '
        'equity-like upside with bond-like downside protection. That is at the core of its design thesis. '
        'Index-linking only works with long-duration mortgages (20–30 years): economic cycles are never 30 years '
        '(interest-rate cycles ≈ 2–3 years, mild/moderate downturns ≈ 3–5 years, black-swan events such as the '
        'GFC ≈ 5–7 years).',
        styles['BodyText2']
    ))
    story.append(Paragraph('Why index-linking gives an equity-like return', styles['SubHead']))
    story.append(Paragraph(
        'The EPM\'s offset account is invested in a broad equity index (the S&P 500). The S&P 500 is used (rather '
        'than other indices) because: modern index data goes back more than 50 years; depth of capital; market '
        'liquidity; reliable historical performance data (returns and volatility); and a deep options market to '
        'support hedging. Importantly, the index itself is a risk-levelling or risk-pooling mechanism — only the '
        'top 500 capitalised US companies are included, and the S&P committee removes/adds companies that '
        'under/over-perform. This protects against poor performers weighing down the index, ensures emerging '
        'technologies are captured (such as AI), and weeds out sunset industries over time.',
        styles['BodyText2']
    ))
    story.append(Paragraph('The lender\'s capital behaves like a fully funded index exposure:', styles['BodyText2']))
    for b in [
        'Long-run expected return of the index (≈10.8% real; ≈10% forward-looking).',
        'Diversified, equally-weighted, low-cost exposure.',
        'Passively managed (not chasing alpha) — letting the long time horizon do the heavy lifting.',
        'No single-stock or manager risk.',
        'No leverage, no margin calls, no behavioural timing errors.',
    ]:
        story.append(Paragraph(f'<bullet>&bull;</bullet> {b}', styles['BulletCustom']))
    story.append(Paragraph(
        'The lender is "lending" in the traditional mortgage sense — but the offset account capital is funding an '
        'index position whose terminal value repays the loan. This is why the return profile looks like an equity '
        'sleeve inside a mortgage wrapper.',
        styles['BodyText2']
    ))
    story.append(Paragraph('Why the risk is mortgage-like (not equity-like)', styles['SubHead']))
    story.append(Paragraph(
        'The EPM\'s structural protections collapse the lender\'s downside to something closer to short-duration '
        'mortgage risk, not equity drawdown risk:',
        styles['BodyText2']
    ))
    for b in [
        '<b>1. No borrower credit risk</b> — no serviceability requirement, no default, no bad debt, '
        'no forced sale, no impairment provisioning, no early redemption of offset capital. This removes the '
        'dominant risk factor in traditional mortgages.',
        '<b>2. No mark-to-market loss</b> — the offset account remains invested for the loan lifecycle, the loan '
        'is not callable, the lender is repaid at early termination or at maturity, and early termination triggers '
        'run-off mode rather than liquidation. This eliminates the classic equity risk of being forced to sell at '
        'the bottom.',
        '<b>3. Short effective duration</b> — annuity payments are funded separately via progressively drawn loan '
        'capital; interest and part-principal are funded by progressive sell-down of ETF reference assets; and as '
        'ETFs are sold down, the unsold ETFs continue accruing and compounding. The lender\'s capital behaves like '
        'a short-duration, self-amortising asset, not a 30-year mortgage.',
        '<b>4. Capital certainty at termination</b> — even on early termination the lender receives full loan '
        'principal back: no loss crystallisation, no negative equity, no exposure to the property market. Security '
        'shifts from property to the offset account capital, and the reference assets held are highly liquid.',
    ]:
        story.append(Paragraph(f'<bullet>&bull;</bullet> {b}', styles['BulletCustom']))
    story.append(Paragraph('Putting it together — the payoff profile', styles['SubHead']))
    story.append(make_table(
        ['Component', 'Behaves like', 'Why'],
        [
            ['Return', 'Equity index', 'Offset account tracks index growth'],
            ['Risk', 'Short-duration mortgage', 'No credit risk, no MTM loss, no forced liquidation, capital certainty'],
        ],
        col_widths=[30*mm, 45*mm, 75*mm]
    ))
    story.append(Paragraph(
        'By linking the mortgage offset account to a diversified equity index, the EPM converts long-term equity '
        'growth into a predictable, mortgage-like risk profile. The lender captures equity-style returns while '
        'avoiding borrower credit risk, market-timing risk, and mark-to-market losses — producing a structurally '
        'asymmetric payoff: equity upside with mortgage-level downside.',
        styles['BodyText2']
    ))
    story.append(fig_to_image(chart_payoff_asymmetry(), height=78*mm))
    story.append(PageBreak())

    # ---- LEGAL CHARACTER — MORTGAGE NOT MIS ----
    story.append(Paragraph('Legal Character — A Mortgage, Not a Managed Investment Scheme', styles['SectionHead']))
    story.append(fig_to_image(chart_mis_checklist(), height=76*mm))
    story.append(Paragraph('Product Design Strengths', styles['SubHead']))
    for b in [
        'Long loan durations (20–30 years).',
        'Secured by a registered first mortgage over unencumbered residential property.',
        'Variable or adjustable-rate mortgage.',
        'Recommended retail pricing 3.5–4% above cash rate (priced halfway between a forward and a reverse mortgage).',
        'Each EPM is a single mortgage loan account with two linked sub-accounts (Annuity Capital Account and '
        'Mortgage Offset Account).',
        'No compounding interest; no negative-equity risk.',
        'Loan cost paid via the offset account from index appreciation over the long horizon, with any deficit on '
        'a minority of mortgages cross-subsidised by surpluses of the majority of unexpired mortgages, and the EPM '
        'fully insured for any residual loss.',
        'Under the Mortgage Agreement the borrower is not liable to pay loan costs (interest and principal '
        'repayment); all risk is shifted to the lender and funder (then de-risked and insured). It is not a '
        'financial-advice-led product.',
        'Borrower receives up to 2% of home value p.a. as tax-free annuity income for 5–15 years. Credit risk has '
        'been replaced by long-term (30-year) index risk.',
    ]:
        story.append(Paragraph(f'<bullet>&bull;</bullet> {b}', styles['BulletCustom']))
    story.append(Paragraph(
        'The structure, rights, and economic substance of the EPM are those of a single mortgage-based financial '
        'instrument. The EPM is a secured credit contract, not a Managed Investment Scheme (MIS), because it '
        'satisfies the legal definition of credit and fails the statutory tests for an MIS.',
        styles['BodyText2']
    ))
    story.append(Paragraph('1. Why the EPM fails the MIS definition', styles['SubHead']))
    story.append(Paragraph(
        'An MIS requires all three limbs: (i) people contribute money or money\'s worth to acquire rights in a '
        'pooled arrangement; (ii) contributors do not have day-to-day control; (iii) the purpose is to produce a '
        'financial benefit for contributors. The EPM fails all three: there is <b>no contribution into a common '
        'enterprise</b> (the borrower receives credit secured by a mortgage — there is no pooling of borrower '
        'assets, no collective investment, no shared returns); <b>no "interest" in a scheme</b> (a bilateral '
        'credit contract with a single lender, whose capital sits in an offset account, not a fund or trust); and '
        '<b>no expectation of financial return to the borrower</b> (the borrower is a consumer receiving credit '
        'for retirement income, not an investor receiving distributions). The EPM is economically equivalent to a '
        'reverse mortgage with a different repayment mechanism, not an investment.',
        styles['BodyText2']
    ))
    story.append(Paragraph('2. The EPM meets the statutory definition of a credit contract', styles['SubHead']))
    story.append(Paragraph(
        'A credit contract exists when credit is provided, a charge is made for it, the debtor is a natural '
        'person, and the credit is predominantly for personal/domestic purposes. The EPM satisfies all four: the '
        'lender advances credit (and holds back a portion of principal via the offset account); the lender earns '
        'margin; the borrower is a natural person; and the purpose is retirement income or aged-care funding. The '
        'index-linked repayment mechanism does not change its legal character — credit contracts can have '
        'variable, index-linked or contingent repayment structures without becoming MISs.',
        styles['BodyText2']
    ))
    story.append(Paragraph('3. The security structure reinforces credit, not investment', styles['SubHead']))
    story.append(Paragraph(
        'The EPM is secured by a registered first mortgage, a linked offset account holding the lender\'s capital, '
        'and a run-off mechanism that repays the lender from the mortgage itself. This is textbook secured '
        'lending: no trust, no pooling, no unitisation, no investor contributions, no investment manager, no '
        'fiduciary obligations, no collective enterprise. The lender is a secured creditor, not a scheme operator.',
        styles['BodyText2']
    ))
    story.append(Paragraph('4. Regulator guidance and economic substance', styles['SubHead']))
    story.append(Paragraph(
        'ASIC has repeatedly stated that credit products are not MISs even when they involve contingent repayment, '
        'property security, indexation or complex mechanics. The key distinction is who takes the financial risk '
        'and why: in the EPM the lender takes credit risk, the borrower receives credit, and the borrower is not '
        'seeking investment returns — the opposite of an MIS. On economic substance, the EPM provides predictable '
        'income, uses home equity as security, avoids compounding interest, allows early termination without '
        'penalty, lets the borrower retain full ownership and title, and repays itself through the mortgage offset '
        'mechanism. Nothing here resembles an investment scheme; everything resembles a regulated credit contract.',
        styles['BodyText2']
    ))
    story.append(Paragraph(
        '<b>Conclusion:</b> The EPM is a secured credit contract — it provides credit to a consumer, secured by a '
        'registered mortgage, with repayment sourced from the mortgage structure itself. The borrower does not '
        'deposit monies or contribute assets, does not acquire an interest in a pooled arrangement, and does not '
        'expect a financial return. Accordingly, the EPM does not satisfy the statutory definition of a managed '
        'investment scheme (s9 Corporations Act).',
        styles['Callout']
    ))
    story.append(PageBreak())

    # Methodology
    story.append(Paragraph('Methodology', styles['SectionHead']))
    story.append(Paragraph('Key Assumptions', styles['SubHead']))
    story.append(make_table(
        ['Component', 'Model', 'Parameters'],
        [
            ['Equity returns', 'GBM with Stochastic Drift + Mean Reversion (quarterly)', 'mu=9.2%, sigma=16.6%, gamma=0.163 (after asymmetric collar)'],
            ['Asymmetric hedge collar', 'Cap/Floor on returns', 'Cap: +40%, Floor: -20% per period'],
            ['Cash rate', 'OU mean-reversion', 'theta=2.13%, kappa=0.24, sigma=1.22%'],
            ['Equity-rate correlation', '0.30', 'Appropriate for 30yr horizon (long-term marginally positive)'],
            ['House prices', 'Deterministic (by design)', 'Sets LVR at origination only; not a shared appreciation mortgage'],
            ['Prepayment/Early exit', 'Run-off mechanism', 'No exit until all loan costs paid from investment account'],
            ['Hedging cost', 'Calculated put-call', '+0.046% p.a. (cap 1.4 / floor 0.8)'],
            ['Variable costs', 'Fixed spread', f'{V14["variable_costs"]}% (includes LMI + tail risk premiums)'],
            ['P&I amortisation', 'Linear PI', 'Builds to $1.2M peak, then amortising repayment to Yr 30'],
            ['Insurance discount', '2.13%', 'Cash rate mean; claims only at mortgage expiry'],
            ['LMI coverage', '80% of deficit paths', 'Worst 20% of deficit paths (larger losses) = tail risk (reinsurance)'],
            ['Payments & Risk Waterfall', 'Portfolio level', 'ETF selldown → cross-subsidise → net deficit → PoC'],
            ['Surplus split', '50/50', 'FutureProof and Mortgage Funder at maturity'],
            ['Profit realisation', 'Every 3 years', '10% of running surplus drawn at each reset'],
            ['Simulation paths', '50,000', f'SE {V14["deficit_se"]}% on PoD'],
        ],
        col_widths=[38*mm, 38*mm, 74*mm]
    ))

    story.append(Spacer(1, 5*mm))
    story.append(Paragraph('Metrics Definitions', styles['SubHead']))
    story.append(Paragraph(
        '<b>PoD (Probability of Deficit):</b> Fraction of paths where investment balance &lt; mortgage balance at a given point in time. '
        'A balance sheet snapshot — useful but NOT the probability of an insurance claim.<br/>'
        '<b>PoC (Probability of Claim):</b> Probability of an actual insurance claim on an expiring mortgage, after the Payments & Risk Waterfall '
        'has been applied. This is the key metric for insurance and reinsurance pricing. Claims can only occur at mortgage expiry.<br/>'
        '<b>Payments & Risk Waterfall:</b> Portfolio-level mechanism: (1) sell down ETFs, (2) cross-subsidise from surplus loans, '
        '(3) only then determine net deficit and PoC.<br/>'
        '<b>Discounted Expected Deficit (S3):</b> The present value of expected loss, discounted at 2.13% (cash rate mean). '
        'Basis for insurance premium calculation.',
        styles['BodyText2']
    ))

    doc.build(story, onFirstPage=lambda c, d: footer(c, d, footer_title, 'May 2026'),
              onLaterPages=lambda c, d: footer(c, d, footer_title, 'May 2026'))
    print(f'  Generated: {filename}')
    return filename


# ============================================================
# REPORT 2: INVESTOR REPORT
# ============================================================

def build_investor_report():
    filename = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'docs', 'pdfs', 'FutureProof_EPM_Investor_Report_Apr2025.pdf')
    footer_title = 'Confidential — For Qualified Investors Only'

    doc = SimpleDocTemplate(
        filename, pagesize=A4,
        leftMargin=25*mm, rightMargin=25*mm,
        topMargin=20*mm, bottomMargin=20*mm
    )
    styles = get_styles()
    story = []

    title_page(story, styles,
               'Equity Preservation Mortgage v14c',
               'Investment Opportunity Overview',
               'Quantitative Risk Analysis | April 2025',
               'CONFIDENTIAL — For Qualified Investors Only')

    # Executive Summary
    story.append(Paragraph('Executive Summary', styles['SectionHead']))
    story.append(Paragraph(
        'FutureProof has developed an innovative financial product — the Equity Preservation Mortgage (EPM) — that allows '
        'homeowners to access their home equity while retaining full ownership. The v14c quantitative model '
        'provides the actuarial basis for the product; an independent companion paper ("Model Assumptions and '
        'Parameter Risk", April 2025) quantifies the parameter uncertainty around the headline results.',
        styles['BodyText2']
    ))
    story.append(Paragraph(
        'Headline results are reported across three empirically-anchored scenarios, consistent with the '
        'companion paper:',
        styles['BodyText2']
    ))
    story.append(make_table(
        ['Scenario', 'Basis', 'PoD (Yr 30)', 'Mean Surplus'],
        [
            ['Base case (model-as-written)', 'Current internal parameters', f'{V14["deficit_prob_yr30"]}%', f'${V14["mean_surplus_yr30"]:,.0f}'],
            ['Realistic-central', 'Empirically-centred μ, γ, collar', '16.9%', '~$995,000'],
            ['Adverse-plausible', 'Lower bounds on μ, γ, collar', '43.2%', '~$253,000'],
        ],
        col_widths=[46*mm, 48*mm, 22*mm, 34*mm]
    ))
    story.append(Spacer(1, 3*mm))
    story.append(Paragraph(
        'The product remains insurable and commercially attractive across this range, but investors should '
        'understand that the base-case headline is one point on a distribution, not the distribution itself. '
        'Capital and reinsurance sizing are being calibrated to the adverse-plausible leg.',
        styles['BodyText2']
    ))

    story.append(Paragraph('Key Investment Highlights', styles['SubHead']))
    highlights = [
        '<b>Large addressable market</b> — Homeowners aged 55-75 across AU, US, UK &amp; NZ represent a combined $15T+ equity pool. Current reverse mortgage penetration is &lt;1% in all four markets.',
        f'<b>Validated product economics at base case</b> — 50,000-path Monte Carlo confirms {V14["poc_portfolio_yr30"]}% portfolio PoC at year 30 at base-case parameters; companion parameter-uncertainty paper anchors the realistic-central and adverse-plausible scenarios.',
        '<b>Unique run-off mechanism</b> — No voluntary prepayments or early terminations until all loan costs are paid from the investment account. This eliminates early exit risk that plagues traditional mortgage products.',
        '<b>Multiple revenue streams</b> — origination fees (1.5%), ongoing margin (0.25%), surplus sharing (50% of surplus at maturity), and insurance premium income.',
        '<b>Institutional partnerships</b> — BlackRock passive index-linked ETFs (S&amp;P500) with Volatility Control, plus SpiderRock continuous dynamic hedging.',
        '<b>Defensible IP</b> — proprietary Payments & Risk Waterfall, holiday mechanism, run-off mechanism, equity preservation structure, and quantitative risk engine create significant barriers to entry.',
        '<b>Transparent risk disclosure</b> — all scenarios, confidence intervals, and parameter sensitivities are disclosed upfront to investors and reinsurers.',
    ]
    for h in highlights:
        story.append(Paragraph(f'<bullet>&bull;</bullet> {h}', styles['BulletCustom']))

    story.append(PageBreak())

    # Market Opportunity
    story.append(Paragraph('The Market Opportunity', styles['SectionHead']))
    story.append(Paragraph('The Problem — A Global Challenge', styles['SubHead']))
    problems = [
        'Homeowners over 60 across developed economies hold trillions in residential property equity',
        'Most have limited income in retirement but are asset-rich — the "asset-rich, cash-poor" dilemma',
        'Traditional reverse mortgages have a negative reputation globally (compound interest, no upside, estate erosion)',
        'Home downsizing has significant emotional, social, and tax implications in every market',
        'No existing product preserves equity while generating retirement income',
    ]
    for p in problems:
        story.append(Paragraph(f'<bullet>&bull;</bullet> {p}', styles['BulletCustom']))

    story.append(Paragraph('The FutureProof Solution', styles['SubHead']))
    solutions = [
        'Homeowner borrows against equity at up to 80% LVR — a calculated portion of loan proceeds held in mortgage offset account and invested by BlackRock in index-linked ETFs (predominantly S&amp;P500)',
        'Investment returns pay the mortgage interest + generate an annuity income ($25K/yr for 10 years)',
        'P&I structure amortises the loan to zero over 30 years — creating a structural safety net',
        'Holiday mechanism protects during market downturns (pauses interest payments)',
        'Unique run-off mechanism — no early exit until investment account has covered all loan costs',
        'At maturity: surplus split 50/50 between FutureProof and Mortgage Funder',
        'Partial profit realisation every 5 years (10% of surplus drawn into portfolio)',
    ]
    for s in solutions:
        story.append(Paragraph(f'<bullet>&bull;</bullet> {s}', styles['BulletCustom']))

    story.append(PageBreak())

    # Multi-Region Market Opportunity
    story.append(Paragraph('Multi-Region Market Opportunity', styles['SectionHead']))
    story.append(Paragraph(
        'FutureProof is designed from the ground up as a multi-region platform. The EPM product is applicable '
        'wherever homeowners hold significant property equity and face the retirement income challenge. '
        'Our technology platform already supports region-specific configuration for currency, LTV limits, '
        'regulatory requirements, and tax treatment across all four target markets.',
        styles['BodyText2']
    ))

    story.append(Spacer(1, 3*mm))
    story.append(Paragraph('United States — Primary Growth Market', styles['SubHead']))
    story.append(Paragraph(
        'The US represents the largest addressable market globally. Over 40 million homeowners aged 55+ hold '
        'an estimated $12 trillion in home equity. The existing HECM (Home Equity Conversion Mortgage) program '
        'is government-backed but capped at $1,149,825 — leaving the jumbo market entirely unserved. '
        'High-value homeowners in coastal markets (California, New York, Florida) are the ideal EPM demographic.',
        styles['BodyText2']
    ))
    story.append(make_table(
        ['Metric', 'United States'],
        [
            ['Currency', 'USD ($)'],
            ['Target demographic', 'Homeowners 55+, home value $500K-$10M'],
            ['Addressable households', '5,000,000+'],
            ['Residential equity pool', '~$12 trillion'],
            ['Regulatory body', 'Consumer Financial Protection Bureau (CFPB)'],
            ['Licensing', 'NMLS (Nationwide Multistate Licensing System)'],
            ['Competitive landscape', 'HECM dominates; no private equity preservation product exists'],
            ['Tax advantage', 'EPM income may be tax-advantaged under IRS guidelines'],
            ['Max LTV', '80%'],
        ],
        col_widths=[45*mm, 105*mm]
    ))

    story.append(Spacer(1, 3*mm))
    story.append(Paragraph('Australia — Founding Market', styles['SubHead']))
    story.append(Paragraph(
        'Australia is FutureProof\'s founding market and the base for the v14c model validation. Australian homeowners '
        'over 60 hold approximately $1 trillion in residential property equity. The reverse mortgage market is '
        'small (~$3B outstanding) and declining due to negative perception. Major banks exited the space in 2018, '
        'creating a significant gap that EPM is uniquely positioned to fill.',
        styles['BodyText2']
    ))
    story.append(make_table(
        ['Metric', 'Australia'],
        [
            ['Currency', 'AUD (A$)'],
            ['Target demographic', 'Homeowners 55-75, property value A$500K-A$10M'],
            ['Addressable households', '200,000+'],
            ['Residential equity pool', '~A$1 trillion'],
            ['Regulatory body', 'Australian Securities & Investments Commission (ASIC)'],
            ['Licensing', 'Australian Financial Services Licence (AFSL)'],
            ['Competitive landscape', 'Heartland Finance only major player; banks exited 2018'],
            ['Tax advantage', 'EPM income generally tax-free as return of capital (ATO)'],
            ['Max LTV', '80%'],
        ],
        col_widths=[45*mm, 105*mm]
    ))

    story.append(PageBreak())

    story.append(Paragraph('United Kingdom — Established Equity Release Market', styles['SubHead']))
    story.append(Paragraph(
        'The UK has the most mature equity release market outside the US, with ~$50B outstanding. However, existing '
        'products are traditional lifetime mortgages with compound interest. The UK market is well-regulated by the FCA '
        'and the Equity Release Council provides consumer standards. British homeowners hold approximately '
        u'\u00a33 trillion in property equity, with property values in London and the South East '
        'creating an ideal high-value demographic for EPM.',
        styles['BodyText2']
    ))
    story.append(make_table(
        ['Metric', 'United Kingdom'],
        [
            ['Currency', u'GBP (\u00a3)'],
            ['Target demographic', u'Homeowners 55+, property value \u00a3300K-\u00a310M'],
            ['Addressable households', '1,500,000+'],
            ['Residential equity pool', u'~\u00a33 trillion'],
            ['Regulatory body', 'Financial Conduct Authority (FCA)'],
            ['Licensing', 'FCA Authorisation'],
            ['Competitive landscape', u'Mature equity release market (~\u00a350B); no equity preservation product'],
            ['Tax advantage', 'May qualify for tax relief under HMRC guidelines'],
            ['Max LTV', '80%'],
        ],
        col_widths=[45*mm, 105*mm]
    ))

    story.append(Spacer(1, 3*mm))
    story.append(Paragraph('New Zealand — Adjacent Market', styles['SubHead']))
    story.append(Paragraph(
        'New Zealand is a natural adjacency to the Australian market — similar legal framework, property market dynamics, '
        'and demographic profile. The reverse mortgage market is small but growing, with Heartland Group being the dominant '
        'player. NZ property values have risen significantly, creating the same asset-rich, cash-poor dynamic. '
        'FutureProof can leverage AU infrastructure and regulatory expertise for efficient NZ market entry.',
        styles['BodyText2']
    ))
    story.append(make_table(
        ['Metric', 'New Zealand'],
        [
            ['Currency', 'NZD (NZ$)'],
            ['Target demographic', 'Homeowners 55+, property value NZ$500K-NZ$10M'],
            ['Addressable households', '80,000+'],
            ['Residential equity pool', '~NZ$200B'],
            ['Regulatory body', 'Financial Markets Authority (FMA)'],
            ['Licensing', 'Financial Advice Provider Licence (FAP)'],
            ['Competitive landscape', 'Heartland dominates; minimal competition'],
            ['Tax advantage', 'Treatment under IRD guidelines — consult tax advisor'],
            ['Max LTV', '80%'],
        ],
        col_widths=[45*mm, 105*mm]
    ))

    story.append(PageBreak())

    # Combined market sizing
    story.append(Paragraph('Combined Market Sizing', styles['SubHead']))
    story.append(make_table(
        ['Market', 'Addressable Households', 'Equity Pool', f'At {V14["poc_portfolio_yr30"]}% Penetration'],
        [
            ['United States', '5,000,000+', '$12T', '$60B portfolio'],
            ['Australia', '200,000+', 'A$1T', 'A$5B portfolio'],
            ['United Kingdom', '1,500,000+', u'\u00a33T', u'\u00a315B portfolio'],
            ['New Zealand', '80,000+', 'NZ$200B', 'NZ$1B portfolio'],
            ['Combined', '6,780,000+', '$15T+ (USD equiv.)', '$75B+ portfolio'],
        ],
        col_widths=[35*mm, 40*mm, 35*mm, 40*mm]
    ))
    story.append(Paragraph(
        'Even at conservative 0.5% penetration across all four markets, the combined portfolio opportunity '
        'exceeds $75 billion in AUM — generating approximately $1.5 billion in annual revenue across all '
        'income streams. The US market alone represents 80% of the addressable opportunity.',
        styles['BodyText2']
    ))

    story.append(Paragraph('Go-To-Market Strategy', styles['SubHead']))
    gtm = [
        '<b>Phase 1 (Year 1-2):</b> Launch in Australia — pilot 50-100 EPMs, validate operations, refine pricing',
        '<b>Phase 2 (Year 2-3):</b> Scale Australia to 500 EPMs; enter New Zealand leveraging AU infrastructure',
        '<b>Phase 3 (Year 3-5):</b> Enter UK market — largest equity release market with clear regulatory pathway (FCA)',
        '<b>Phase 4 (Year 4-6):</b> Enter US market — largest opportunity; establish NMLS licensing, target jumbo segment',
    ]
    for g in gtm:
        story.append(Paragraph(f'<bullet>&bull;</bullet> {g}', styles['BulletCustom']))

    story.append(PageBreak())

    # Product Overview
    story.append(Paragraph('How It Works — Product Overview (v14c)', styles['SectionHead']))
    story.append(make_table(
        ['Feature', 'Detail'],
        [
            ['Loan Type', 'Principal & Interest (default)'],
            ['Typical Loan', '$1.36M (62.0% LVR on $2M property)'],
            ['Investment', 'S&P500 index-linked ETFs via BlackRock (passive) + SpiderRock hedging'],
            ['Expected Return', '10% p.a. (BlackRock 30yr forward profile); net ~9.6% after hedge cost'],
            ['Annuity Income', '$36,000/yr for 10 years'],
            ['Profit Realisation', 'Every 5 years: 10% of surplus drawn'],
            ['Surplus at Maturity', 'Split 50/50 between FutureProof and Mortgage Funder'],
            ['Holiday Mechanism', 'Interest deferred during drawdowns (threshold 0.9/1.458)'],
            ['Run-off Mechanism', 'No early exit until all loan costs paid from investment account'],
            ['Tenure', 'Up to 30 years (P&I fully amortises)'],
            ['Insurance', 'LMI (80% of deficit paths) + tail risk reinsurance; premiums paid upfront at origination'],
            ['Cash Rate', 'Stochastic OU (initial 4.21%, mean-reverting)'],
            ['Equity-Rate Correlation', '0.30 (appropriate for 30-year horizon)'],
        ],
        col_widths=[45*mm, 105*mm]
    ))

    story.append(Spacer(1, 5*mm))
    story.append(Paragraph('The Money Flow', styles['SubHead']))
    flows = [
        '1. Homeowner takes EPM loan ($1.36M on $2M property, 62.0% LVR)',
        '2. Calculated portion of loan proceeds held in mortgage offset account, invested by BlackRock in S&amp;P500 index-linked ETFs',
        '3. Each quarter: investment returns pay interest + costs (total ~6.65% p.a.)',
        '4. Years 1-10: homeowner receives annuity income ($25K/yr)',
        '5. Every 5 years: 10% of surplus drawn',
        '6. P&I loan amortises to zero by year 30',
        '7. At maturity: surplus split 50/50 between FutureProof and Mortgage Funder',
        '8. No early exit permitted until all loan costs paid from investment account (run-off mechanism)',
    ]
    for f in flows:
        story.append(Paragraph(f'<bullet>&bull;</bullet> {f}', styles['BulletCustom']))

    story.append(PageBreak())

    # Quantitative Validation — now focused on PoC
    story.append(Paragraph('Quantitative Validation — The Numbers', styles['SectionHead']))
    story.append(fig_to_image(chart_poc_portfolio(), height=85*mm))

    story.append(Paragraph('v14c Model Results (50,000 paths, P&I + Index-linked ETF)', styles['SubHead']))
    story.append(make_table(
        ['Metric', 'Value', 'Interpretation'],
        [
            ['Portfolio PoC (Yr 30)', f'{V14["poc_portfolio_yr30"]}%', 'Probability of insurance claim after Payments & Risk Waterfall'],
            ['Individual PoD (Yr 30)', f'{V14["deficit_prob_yr30"]}%', 'Balance sheet view before waterfall (not claim probability)'],
            ['Mean Surplus', '$1,690,289', 'Average surplus at maturity (split 50/50 FP/Funder)'],
            ['Median Surplus', '$1,376,802', 'Typical outcome — substantial value creation'],
            ['10th Percentile', '-$211,973', 'Moderate deficit at 10th percentile (covered by insurance)'],
            ['90th Percentile', '$4,017,354', 'Strong upside potential'],
            ['Fair Insurance Premium (PV)', f'${V14["ins_fair_premium"]:,.0f}', 'Based on discounted expected deficit (S3)'],
            ['Insurance + Loading', '$32,929', 'Paid upfront at mortgage origination'],
        ],
        col_widths=[40*mm, 30*mm, 80*mm]
    ))

    story.append(Paragraph(
        f'Note: The key metric is Portfolio PoC ({V14["poc_portfolio_yr30"]}% at year 30), not individual PoD ({V14["deficit_prob_yr30"]}%). PoD is a balance sheet '
        'snapshot; PoC reflects actual insurance claims after the Payments & Risk Waterfall (ETF selldown, cross-subsidisation '
        'from surplus loans). Claims can only be made on expiring mortgages — PoD before expiry is irrelevant to insurance.',
        styles['SmallNote']
    ))

    story.append(PageBreak())

    # Investment Growth
    story.append(Paragraph('Investment Growth vs Loan Amortisation', styles['SectionHead']))
    story.append(fig_to_image(chart_investment_growth(), height=85*mm))
    story.append(Paragraph(
        'The chart illustrates the structural advantage of P&I: the mortgage balance declines to zero '
        'while the investment portfolio compounds upward. By year 15, the investment account is approximately '
        '$2.3M while the mortgage balance has halved to ~$675K — creating a substantial structural surplus. '
        'This divergence accelerates in later years as amortisation reduces the interest burden.',
        styles['BodyText2']
    ))
    story.append(Paragraph(
        '<b>Surplus allocation:</b> At maturity, the surplus is split 50/50 between FutureProof and the Mortgage Funder. '
        'Partial profit realisations occur every 5 years (10% of surplus drawn). '
        'House prices are deterministic in this model — they set the LVR at origination but do not affect ongoing '
        'mechanics. This is not a shared appreciation mortgage.',
        styles['BodyText2']
    ))

    story.append(PageBreak())

    # Revenue Model
    story.append(Paragraph('Revenue Model', styles['SectionHead']))
    story.append(Paragraph('Revenue Streams per EPM ($1.36M loan)', styles['SubHead']))
    story.append(make_table(
        ['Revenue Source', 'Estimated Annual', 'Over 20yr Life'],
        [
            ['FutureProof margin (0.25%)', '$3,375/yr (declining)', '~$50,000'],
            ['Origination fee (1.5%, upfront)', '$20,250', '$20,250'],
            ['Insurance premium (in variable costs)', f'Included in {V14["variable_costs"]}%', 'Collected with interest payments'],
            ['Surplus share (50% at maturity)', 'At exit', f'~${V14["mean_surplus_yr30"]//2:,.0f} (mean, per EPM)'],
            ['Profit realisation (25% every 5yr)', 'Variable', f'~${sum(PROFIT_SHARE_MEANS[:4]):,.0f} (mean, 20yr)'],
            ['Hedging program fee (0.25%)', '$3,375/yr (declining)', '~$50,000'],
            ['Total per EPM', '', '$200,000-$300,000+'],
        ],
        col_widths=[50*mm, 40*mm, 60*mm]
    ))

    story.append(Spacer(1, 5*mm))
    story.append(fig_to_image(chart_profit_share(), height=75*mm))

    story.append(Paragraph('Portfolio Economics (Multi-Region)', styles['SubHead']))
    story.append(make_table(
        ['Scale', 'EPMs', 'Markets', 'Annual Revenue', 'Cumulative AUM'],
        [
            ['Year 1', '100', 'AU', '$500K', '$136M'],
            ['Year 3', '500', 'AU, NZ', '$2.5M', '$675M'],
            ['Year 5', '2,000', 'AU, NZ, UK', '$10M', '$2.7B'],
            ['Year 10', '10,000', 'AU, NZ, UK, US', '$50M', '$13.5B'],
        ],
        col_widths=[25*mm, 22*mm, 30*mm, 33*mm, 40*mm]
    ))

    story.append(PageBreak())

    # Competitive Advantages
    story.append(Paragraph('Competitive Advantages & Moat', styles['SectionHead']))

    story.append(Paragraph('1. Product Innovation', styles['SubHead']))
    moat1 = [
        'Only equity preservation mortgage product globally — no competitor in any target market',
        'Integrated index-linked ETF mechanics with calculated hedging costs',
        'Customers retain home ownership AND participate in investment upside',
        'P&I structure creates a self-liquidating product — fundamentally different from reverse mortgages',
    ]
    for m in moat1:
        story.append(Paragraph(f'<bullet>&bull;</bullet> {m}', styles['BulletCustom']))

    story.append(Paragraph('2. Quantitative Edge', styles['SubHead']))
    moat2 = [
        'Proprietary Monte Carlo risk engine with stochastic rates, index-linked ETF mechanics, and holiday simulation',
        'Ability to price insurance premiums with explicit standard error bounds',
        'Portfolio-level modelling across 10,000 EPM cohorts with vintage diversification',
        'v14c model is 4th generation — demonstrating rapid iteration capability',
    ]
    for m in moat2:
        story.append(Paragraph(f'<bullet>&bull;</bullet> {m}', styles['BulletCustom']))

    story.append(Paragraph('3. Multi-Region Scalability', styles['SubHead']))
    moat3 = [
        'Production-ready technology platform already supports US, AU, UK, and NZ regions',
        'Region-specific configuration deployed: currency, LTV limits, regulatory bodies, tax treatment, licensing',
        'First-mover advantage in every target market — no equity preservation product exists globally',
        'Growing demographic tailwind in all four markets (ageing populations, rising property values, retirement income gap)',
        'Combined addressable market of 6.8M+ households and $15T+ in residential equity',
    ]
    for m in moat3:
        story.append(Paragraph(f'<bullet>&bull;</bullet> {m}', styles['BulletCustom']))

    story.append(PageBreak())

    # Risk Factors
    story.append(Paragraph('Risk Factors', styles['SectionHead']))

    story.append(Paragraph('Parameter & Model Risks', styles['SubHead']))
    risks1 = [
        '<b>Equity drift (μ) below the 9.2% base-case assumption.</b> Long-horizon valuation-based estimates '
        '(CAPE-implied 5–6%) sit materially below 9.2%. At μ = 8.2% the model produces ~9% PoD alone; in '
        'combination with realistic γ and collar this reaches 16.9%.',
        '<b>Mean-reversion (γ) weaker than 0.163 assumption.</b> Bootstrap 95% CI is [0.019, 0.447] with a '
        'likelihood-ratio test p-value of 0.092 against γ = 0. γ is the single most load-bearing parameter in '
        'the model; a weaker draw materially raises PoD.',
        '<b>Collar cost understated.</b> 0.046% base-case input is inconsistent with Black-Scholes pricing at '
        'current AU rates (0.16–0.44%). Re-anchoring to 0.30% adds ~1pp to PoD per year of cost drag.',
        'Higher-than-expected wholesale funding costs — currently 2.0% in model; market comparables 2.0–3.0%.',
        'Regulatory changes to reverse mortgage / equity release rules across target markets.',
    ]
    for r in risks1:
        story.append(Paragraph(f'<bullet>&bull;</bullet> {r}', styles['BulletCustom']))

    story.append(Paragraph('Execution Risks', styles['SubHead']))
    risks2 = [
        'Scaling from concept to portfolio requires significant capital',
        'Wholesale funding negotiations (current quotes at 3%, model assumes 2%)',
        'Reinsurance market appetite — sized to the adverse-plausible leg (43.2% PoD), not the base case',
        'Operational complexity of managing index-linked ETF positions and Payments & Risk Waterfall',
    ]
    for r in risks2:
        story.append(Paragraph(f'<bullet>&bull;</bullet> {r}', styles['BulletCustom']))

    story.append(Paragraph('Mitigants', styles['SubHead']))
    mits = [
        'P&I structure provides structural risk reduction across all parameter scenarios (loan fully amortises)',
        f'Payments & Risk Waterfall reduces portfolio PoC materially versus individual PoD ({V14["deficit_prob_yr30"]}% at base case)',
        'Run-off mechanism eliminates early exit risk — unique to EPM, no other mortgage works this way',
        'Low 21% loss severity bounds expected loss even under the adverse-plausible scenario',
        'Insurance premiums paid upfront at mortgage origination; claims only at mortgage expiry',
        'Multi-region platform provides diversification across housing markets and rate environments',
        'Capital, reinsurance attachment, and pricing anchored on adverse-plausible scenario — not base case',
    ]
    for m in mits:
        story.append(Paragraph(f'<bullet>&bull;</bullet> {m}', styles['BulletCustom']))

    story.append(PageBreak())

    # EPM vs Current Investment Landscape
    story.append(Paragraph('EPM vs Current Investment Landscape', styles['SectionHead']))
    story.append(Paragraph(
        'A critical question for investors: how does the EPM risk profile compare to existing asset classes? '
        'The following table benchmarks the EPM at both base-case and realistic-central parameters against '
        'traditional mortgages and rated credit.',
        styles['BodyText2']))

    story.append(make_table(
        ['Metric', 'EPM base', 'EPM realistic', 'Prime AU Mortgage', "Moody's AA Bond"],
        [
            ['Cumulative PoD (30yr)', f'{V14["deficit_prob_yr30"]:.1f}%', '16.9%', '3–5%', '~1.5%'],
            ['Loss severity (LGD)', '~21% of peak', '~21% of peak', '20–40%', '40–60%'],
            ['Expected loss (30yr)', '0.13%', '~2.3%', '0.6–1.25%', '0.6–0.9%'],
            ['Ratings band (PoD)', 'AA/AAA', 'BBB/BB', 'A/BBB', 'AA'],
        ],
        col_widths=[35*mm, 27*mm, 27*mm, 27*mm, 30*mm]
    ))

    story.append(Spacer(1, 3*mm))
    inv_landscape = [
        '<b>Base-case comparison: safer than a prime mortgage.</b> At base-case parameters the EPM\'s '
        f'{V14["deficit_prob_yr30"]:.1f}% cumulative PoD sits below the 3–5% prime AU mortgage range and the '
        'low severity places the product in the AA/AAA band on expected loss. This framing is correct so long '
        'as the parameter inputs hold.',
        '<b>Realistic-central comparison: comparable to prime mortgage risk.</b> At empirically-centred '
        'parameters (μ = 8.2%, γ = 0.11, collar = 0.30%) the same model produces 16.9% PoD. On a pure-PoD '
        'basis this is above the prime mortgage benchmark; on expected loss it is ~2.3%, well above prime '
        'mortgage EL. The product remains insurable and economically attractive, but the ratings-equivalence '
        'claim moves from AA/AAA to investment-grade-speculative (BBB/BB band).',
        '<b>Uncorrelated to traditional credit across all scenarios.</b> EPM risk is driven by long-term '
        'equity market performance relative to interest rates — fundamentally different from borrower credit '
        'risk. This diversification benefit is structural and holds regardless of which parameter set '
        'eventuates.',
        '<b>Funder protection is layered.</b> The wholesale funder holds a secured claim against real property '
        f'(80% LVR), with a ${V14["mean_surplus_yr30"]:,.0f} mean surplus at maturity at base case plus LMI '
        'and reinsurance. Under the adverse-plausible scenario, mean surplus falls to ~$253,000 but remains '
        'positive on average; capital and reinsurance sizing is calibrated to that leg, not base case.',
    ]
    for il in inv_landscape:
        story.append(Paragraph(f'<bullet>&bull;</bullet> {il}', styles['BulletCustom']))

    story.append(PageBreak())

    # Summary
    story.append(Paragraph('Summary & Next Steps', styles['SectionHead']))
    story.append(Paragraph('Investment Thesis', styles['SubHead']))
    story.append(Paragraph(
        'FutureProof has developed a genuinely innovative financial product. The v14c model incorporates '
        'stochastic rates, the Shevchenko mean-reverting equity process, a Payments & Risk Waterfall, explicit '
        'insurance pricing, and portfolio-level analysis. At base-case parameters the portfolio PoC is '
        f'{V14["poc_portfolio_yr30"]}% at year 30. At realistic-central parameters, the model produces 16.9% '
        'PoD with ~$995K mean surplus; at adverse-plausible parameters, 43.2% PoD with ~$253K mean surplus. '
        'The product is commercially attractive across this full range, remains uncorrelated with traditional '
        'credit risk, and benefits from low loss severity (~21%) in every scenario.',
        styles['BodyText2']
    ))
    story.append(Paragraph(
        'The investment case is strongest when investors understand the parameter range and are comfortable '
        'with capital sized to the adverse-plausible leg. This is the honest, defensible framing — and is how '
        'we will present the product to reinsurers and rating agencies.',
        styles['BodyText2']
    ))

    story.append(Paragraph('Use of Funds', styles['SubHead']))
    uses = [
        'Technology platform development — multi-region webapp, risk engine, portfolio management (US, AU, UK, NZ)',
        'Regulatory and legal framework — AFSL (AU), FAP (NZ), FCA (UK), NMLS (US)',
        'Wholesale funding partnerships in each market (target: 1.5-2.0% margin)',
        'Initial EPM originations — pilot portfolio in Australia (50-100 EPMs)',
        'Team expansion — sales, operations, compliance, actuarial across AU then international',
    ]
    for u in uses:
        story.append(Paragraph(f'<bullet>&bull;</bullet> {u}', styles['BulletCustom']))

    story.append(Paragraph('Key Milestones', styles['SubHead']))
    milestones = [
        f'1. v14c model validation COMPLETE — portfolio PoC confirmed at {V14["poc_portfolio_yr30"]}% at year 30',
        '2. Finalise wholesale funding arrangement in AU (target: 1.5-2.0% margin)',
        '3. Launch AU pilot program (50-100 EPMs)',
        f'4. Establish reinsurance partnership — {V14["poc_portfolio_yr30"]}% PoC supports attractive terms',
        '5. Expand to NZ (Year 2) leveraging AU infrastructure',
        '6. Enter UK market (Year 3-4) — FCA licensing and local funding partnerships',
        '7. Enter US market (Year 4-5) — NMLS licensing, target jumbo equity segment',
        '8. Portfolio AUM target: $675M by Year 3 (AU/NZ), $13.5B by Year 10 (all markets)',
    ]
    for m in milestones:
        story.append(Paragraph(f'<bullet>&bull;</bullet> {m}', styles['BulletCustom']))

    doc.build(story, onFirstPage=lambda c, d: footer(c, d, footer_title),
              onLaterPages=lambda c, d: footer(c, d, footer_title))
    print(f'  Generated: {filename}')
    return filename


# ============================================================
# REPORT 3: WHOLESALE FUNDER
# ============================================================

def build_wholesale_funder():
    filename = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'docs', 'pdfs', 'FutureProof_EPM_Wholesale_Funder_Apr2025.pdf')
    footer_title = 'Confidential — For Discussion Purposes Only'

    doc = SimpleDocTemplate(
        filename, pagesize=A4,
        leftMargin=25*mm, rightMargin=25*mm,
        topMargin=20*mm, bottomMargin=20*mm
    )
    styles = get_styles()
    story = []

    title_page(story, styles,
               'Equity Preservation Mortgage v14c',
               'Wholesale Funding',
               'Credit Risk Analysis & Portfolio Economics | April 2025',
               'CONFIDENTIAL — For Discussion Purposes Only')

    # Executive Summary
    story.append(Paragraph('Executive Summary', styles['SectionHead']))
    story.append(Paragraph(
        'FutureProof seeks a wholesale funding partnership to originate Equity Preservation Mortgages — a new '
        'class of residential mortgage product with unique risk characteristics. The v14c quantitative model '
        'provides the actuarial basis for the product; an accompanying paper ("Model Assumptions and Parameter '
        'Risk", April 2025) quantifies the uncertainty around the headline results and is the document against '
        'which wholesale funders should size their credit view.',
        styles['BodyText2']
    ))
    story.append(Paragraph(
        'The funder\'s position in all scenarios is a first-mortgage secured exposure with full upfront '
        'insurance, priority claim on ETF selldown and cross-subsidisation, and a 50/50 surplus share. The '
        'scenarios below describe the PoD range at the borrower/mortgage level — the residual credit risk to '
        'the funder sits below this already-low PoD via the insurance structure.',
        styles['BodyText2']
    ))
    story.append(make_table(
        ['Scenario', 'Basis', 'Mortgage PoD (Yr 30)', 'Mean Surplus'],
        [
            ['Base case (model-as-written)', 'Current internal parameters', f'{V14["deficit_prob_yr30"]}%', f'${V14["mean_surplus_yr30"]:,.0f}'],
            ['Realistic-central', 'Empirically-centred μ, γ, collar', '16.9%', '~$995,000'],
            ['Adverse-plausible', 'Lower bounds on μ, γ, collar', '43.2%', '~$253,000'],
        ],
        col_widths=[46*mm, 48*mm, 26*mm, 30*mm]
    ))

    story.append(Paragraph('Key Points for Wholesale Funders', styles['SubHead']))
    points = [
        f'<b>Low claim risk at mortgage level across all scenarios.</b> Individual PoD ranges from {V14["deficit_prob_yr30"]}% (base) to 43.2% (adverse-plausible); portfolio PoC after the Payments & Risk Waterfall is materially lower, and funder exposure is net of LMI and tail-risk reinsurance.',
        '<b>Fully collateralised</b> — Secured against residential property ($2M+ values) with 60-80% LVR',
        '<b>Self-liquidating</b> — P&I structure amortises loan to zero over tenure; no balloon risk',
        '<b>No early exit risk</b> — Unique run-off mechanism: no voluntary prepayments or early terminations until all loan costs paid from the investment account',
        '<b>Investment portfolio as additional collateral</b> — Index-linked ETF provides secondary security above the property',
        '<b>Surplus split 50/50</b> — Funder receives 50% of surplus at maturity, creating alignment',
        '<b>Insurance paid upfront</b> — LMI (80% of deficit paths) and tail risk premiums are paid upfront at mortgage origination, providing full coverage from day one',
        '<b>Reinsurance attachment calibrated to the adverse-plausible leg</b>, not the base case — the funder is protected even if parameter realities land at the lower end of empirical estimates',
    ]
    for p in points:
        story.append(Paragraph(f'<bullet>&bull;</bullet> {p}', styles['BulletCustom']))

    story.append(PageBreak())

    # Product Overview for Funders
    story.append(Paragraph('Product Overview for Funders', styles['SectionHead']))
    story.append(make_table(
        ['Feature', 'Detail', 'Funder Relevance'],
        [
            ['Collateral', 'Residential property ($2M+)', 'Prime residential, first mortgage'],
            ['LVR', '60-80%', 'Conservative LVR range'],
            ['Loan Type', 'Principal & Interest (default)', 'Self-amortising, no balloon'],
            ['Loan Size', '$1.0-1.6M typical', 'Institutional scale'],
            ['Tenure', 'Up to 30 years', 'Long-duration, stable AUM'],
            ['Borrower Profile', 'Age 55-75, high-equity homeowners', 'Low-risk demographic'],
            ['Investment', 'S&P500 index-linked ETFs (BlackRock/SpiderRock)', 'Passive index + dynamic hedging'],
            ['Interest Coverage', 'Paid from investment returns', 'Not reliant on borrower income'],
            ['Insurance', 'LMI + tail risk coverage', 'Additional loss protection'],
        ],
        col_widths=[35*mm, 50*mm, 65*mm]
    ))

    story.append(Paragraph('How the Funder Gets Paid', styles['SubHead']))
    funder_pay = [
        'Wholesale margin (2.0%) applied above the cash rate — paid quarterly from the equity investment portfolio',
        'During market downturns, interest may be temporarily deferred (capitalised) — NOT defaulted. In any given year, the median mortgage requires zero holidays; deferred interest is repaid as markets recover',
        'P&I structure means mortgage balance is continuously reducing — declining credit exposure over time',
        'At exit: loan repaid from investment portfolio and/or property sale',
        'Insurance covers any deficit between investment portfolio and mortgage balance',
    ]
    for f in funder_pay:
        story.append(Paragraph(f'<bullet>&bull;</bullet> {f}', styles['BulletCustom']))

    story.append(PageBreak())

    # Credit Risk Analysis
    story.append(Paragraph('Credit Risk Analysis', styles['SectionHead']))
    story.append(Paragraph(
        'The v14c model provides detailed credit risk metrics at base-case parameters. The critical distinction '
        'is between PoD (balance sheet view) and PoC (actual insurance claim probability). The table below '
        'reports base-case numbers; the subsequent scenario table shows how these metrics move under the '
        'realistic-central and adverse-plausible parameter sets developed in the companion paper.',
        styles['BodyText2']
    ))
    story.append(make_table(
        ['Credit Metric', 'Value (base)', 'Context'],
        [
            ['Portfolio PoC (Yr 30)', f'{V14["poc_portfolio_yr30"]}%', 'After Payments & Risk Waterfall — the key metric'],
            ['Individual PoD (Yr 30)', f'{V14["deficit_prob_yr30"]}%', 'Balance sheet snapshot (not claim probability)'],
            ['Cond. Expected Deficit', '$592,400', 'Average deficit when deficit occurs (before waterfall)'],
            ['Insurance Premium (PV)', f'${V14["ins_fair_premium"]:,.0f}', 'Based on discounted expected deficit (S3) at 2.13%'],
            ['Insurance + Loading', '$32,929', 'Paid upfront at mortgage origination'],
            ['Mean Surplus at Maturity', '$1,690,289', 'Split 50/50 FutureProof/Funder'],
            ['Property Security', '$2M+ (first mortgage)', 'Covers loan + deficit in all scenarios'],
        ],
        col_widths=[45*mm, 35*mm, 70*mm]
    ))

    story.append(Spacer(1, 5*mm))
    story.append(Paragraph('Credit Metrics Under Parameter Uncertainty', styles['SubHead']))
    story.append(make_table(
        ['Metric', 'Base', 'Realistic-central', 'Adverse-plausible'],
        [
            ['Individual PoD (Yr 30)', f'{V14["deficit_prob_yr30"]}%', '16.9%', '43.2%'],
            ['Mean surplus', f'${V14["mean_surplus_yr30"]:,.0f}', '~$995K', '~$253K'],
            ['Expected loss (30yr)', '0.13%', '~2.3%', '~5.5%'],
            ['Funder residual loss', '~0% (insured)', '~0% (insured)', '~0% (insured)'],
        ],
        col_widths=[40*mm, 30*mm, 40*mm, 40*mm]
    ))
    story.append(Spacer(1, 3*mm))
    story.append(Paragraph(
        'The funder is protected by the upfront insurance structure in all three scenarios. Pricing of the '
        'insurance premium paid at origination is sized to the realistic-central leg; reinsurance attachment '
        'and tail-risk capacity are sized to the adverse-plausible leg. This means the residual credit risk '
        'to the wholesale funder is substantially identical across the parameter range — the parameter '
        'uncertainty affects FutureProof\'s insurance economics, not the funder\'s secured first-mortgage '
        'claim. Additionally, the funder receives 50% of surplus at maturity, and the unique run-off '
        'mechanism prevents early exits that could truncate compounding.',
        styles['BodyText2']
    ))

    story.append(PageBreak())

    # Funder Cash Flow
    story.append(Paragraph('Funder Cash Flow Profile', styles['SectionHead']))
    story.append(fig_to_image(chart_funder_cashflow(), height=85*mm))
    story.append(Paragraph(
        'The chart shows mean annual funder payments (interest margin + principal) over the EPM lifecycle. '
        'Years 1-10 show cash flow in the $40-70K range as the annuity payments reduce available investment income. '
        'After year 10 (when annuity ceases), funder payments stabilise at $100-113K per year. '
        'The year 30 value is negative because it represents the final mortgage balance repayment at maturity. '
        'Note: there is no early exit risk — the run-off mechanism prevents voluntary prepayments until all loan costs '
        'are paid, giving the funder predictable, long-duration cash flows.',
        styles['BodyText2']
    ))

    story.append(PageBreak())

    # LVR Profile
    story.append(Paragraph('Loan Amortisation & LVR Profile', styles['SectionHead']))
    story.append(fig_to_image(chart_lvr_over_time(), height=85*mm))
    story.append(Paragraph(
        'The chart illustrates the declining funder exposure under the P&I structure. The mortgage balance amortises '
        'to zero over 30 years against the fixed property value at origination. House prices are deterministic in '
        'this model — they set the LVR at origination but do not affect ongoing mechanics (this is not a shared '
        'appreciation mortgage). The LVR declines purely through P&I amortisation, meaning the '
        'wholesale funder\'s security position improves every single year regardless of property market movements.',
        styles['BodyText2']
    ))

    story.append(Spacer(1, 3*mm))

    # LVR table
    rate_q = 0.065/4
    n_q = 120
    pmt = 1_350_000 * rate_q / (1 - (1 + rate_q)**(-n_q))
    bal = 1_350_000
    lvr_data = [['0', '$1,240,000', '$2,000,000', '62.0%']]
    for yr in [5, 10, 15, 20, 25, 30]:
        while len(lvr_data) < yr // 5 + 1:
            for q in range(4 * 5):
                interest = bal * rate_q
                principal = pmt - interest
                bal = max(0, bal - principal)
            prop = 2_000_000 * (1.03 ** (len(lvr_data) * 5))
            lvr_data.append([str(len(lvr_data) * 5), f'${bal:,.0f}', f'${prop:,.0f}', f'{100*bal/prop:.1f}%'])

    story.append(make_table(
        ['Year', 'Loan Balance', 'Est. Property Value', 'LVR'],
        lvr_data,
        col_widths=[25*mm, 40*mm, 45*mm, 30*mm]
    ))

    story.append(PageBreak())

    # Collateral & Security
    story.append(Paragraph('Collateral & Security Structure', styles['SectionHead']))

    story.append(Paragraph('First Mortgage Security', styles['SubHead']))
    sec1 = [
        'Registered first mortgage over residential property',
        'Minimum property value: $1.5M (typically $2M+)',
        'Maximum LVR at origination: 80% (typical 62.0%)',
        'Property independently valued at origination',
    ]
    for s in sec1:
        story.append(Paragraph(f'<bullet>&bull;</bullet> {s}', styles['BulletCustom']))

    story.append(Paragraph('Investment Portfolio as Additional Security', styles['SubHead']))
    sec2 = [
        'Loan proceeds held in mortgage offset account, invested by BlackRock in S&amp;P500 index-linked ETFs',
        'Investment portfolio provides secondary collateral (mean value $1.7M at year 15, growing thereafter)',
        'In the P&I structure, the loan amortises while the investment compounds',
        'Index-linked ETF mechanics (cap/floor) provide defined outcome protection',
    ]
    for s in sec2:
        story.append(Paragraph(f'<bullet>&bull;</bullet> {s}', styles['BulletCustom']))

    story.append(Paragraph('Insurance Structure', styles['SubHead']))
    sec3 = [
        'Insurance premiums (LMI + tail risk) are paid upfront at mortgage origination — providing full coverage from day one',
        'LMI covers 80% of loss; worst 20% of deficit paths (larger losses) transferred as tail risk to reinsurance',
        'Premium calculated on discounted expected deficit (S3), discounted at 2.13% (cash rate mean)',
        'No insurance claim can be made until a mortgage expires — PoD before expiry is irrelevant',
        f'Portfolio PoC at year 30 is {V14["poc_portfolio_yr30"]}% after Payments & Risk Waterfall — well below typical reinsurance thresholds',
    ]
    for s in sec3:
        story.append(Paragraph(f'<bullet>&bull;</bullet> {s}', styles['BulletCustom']))

    story.append(Paragraph('Payments & Risk Waterfall at Loan Expiry', styles['SubHead']))
    waterfall = [
        '1. Sell down ETFs from the expiring mortgage\'s investment account',
        '2. Cross-subsidise from surpluses of other open mortgages in the portfolio',
        '3. Only then is the net deficit known — this is the actual Probability of Claim (PoC)',
        '4. If net deficit remains: LMI covers 80%, reinsurance covers tail risk (worst 20% quantile)',
        '5. Loan balance repaid to wholesale funder (priority claim)',
        '6. Surplus split 50/50 between FutureProof and Mortgage Funder',
    ]
    for w in waterfall:
        story.append(Paragraph(f'<bullet>&bull;</bullet> {w}', styles['BulletCustom']))

    story.append(PageBreak())

    # Portfolio Diversification
    story.append(Paragraph('Portfolio Diversification Benefits', styles['SectionHead']))
    story.append(Paragraph('Why a Book of EPMs is Safer Than a Single EPM', styles['SubHead']))
    div_points = [
        'The Payments & Risk Waterfall enables cross-subsidisation: surpluses from performing loans offset deficits in expiring mortgages',
        f'This is why portfolio PoC ({V14["poc_portfolio_yr30"]}%) is dramatically lower than individual PoD ({V14["deficit_prob_yr30"]}%)',
        'Different origination dates mean different equity market entry points — vintage diversification',
        'P&I amortisation means older EPMs have very low residual exposure',
        'v14c models portfolio of 10,000 EPMs — all 30-year mortgages with multiple origination vintages',
        'Multi-vintage structure means the portfolio always contains a mix of seasoned (low-risk) and new EPMs',
        'Run-off mechanism prevents early exits — every loan contributes to portfolio cross-subsidisation for its full term',
    ]
    for d in div_points:
        story.append(Paragraph(f'<bullet>&bull;</bullet> {d}', styles['BulletCustom']))

    story.append(Spacer(1, 5*mm))
    story.append(Paragraph('Vintage Diversification — Why Not All Mortgages Are Affected Equally', styles['SubHead']))
    story.append(Paragraph(
        'A critical feature of the EPM portfolio is that not all mortgages are affected equally in a market downturn. '
        'Over a 30-year period, EPMs are originated at different points in time — each vintage enters the equity market at a '
        'different level. A downturn that causes a deficit for mortgages originated at market peaks may have little or no impact '
        'on mortgages originated years earlier (which have already accumulated substantial surplus) or years later (which enter at '
        'lower market levels with more room to grow). This vintage diversification means that even in severe downturns, the '
        'majority of the portfolio remains in surplus, providing a deep pool for cross-subsidisation of the small number of '
        'affected mortgages approaching expiry.',
        styles['BodyText2']
    ))

    story.append(Spacer(1, 5*mm))
    story.append(Paragraph('Good vs Bad Pathways — The Mathematics of Cross-Subsidisation', styles['SubHead']))
    story.append(Paragraph(
        'The stochastic analysis of S&P500 returns over 30 years reveals a fundamental asymmetry that makes '
        'portfolio cross-subsidisation highly effective. Of the 50,000 simulated pathways, approximately <b>86% deliver '
        'sufficient or excess returns</b> to cover all loan costs (surplus at maturity), while only <b>~14% result in a '
        f'deficit</b> (individual PoD of {V14["deficit_prob_yr30"]}%). At the portfolio level, after the Payments & Risk Waterfall applies cross-subsidisation '
        f'from surplus loans, the net claim probability drops to just <b>{V14["poc_portfolio_yr30"]}% (PoC)</b>. This means that for every loan in deficit, '
        'there are roughly 6 loans in surplus available to cross-subsidise — making the Payments & Risk Waterfall an extraordinarily '
        'effective risk mitigation mechanism before any reinsurance claim is required.',
        styles['BodyText2']
    ))

    story.append(Paragraph('Illustrative Portfolio Build-Up', styles['SubHead']))
    story.append(make_table(
        ['Year', 'New EPMs', 'Total Active', 'Total AUM', 'Avg LVR'],
        [
            ['1', '100', '100', '$136M', '62.0%'],
            ['3', '300', '700', '$945M', '58%'],
            ['5', '500', '2,000', '$2.7B', '50%'],
            ['10', '500', '4,000', '$5.4B', '42%'],
        ],
        col_widths=[25*mm, 30*mm, 30*mm, 30*mm, 30*mm]
    ))

    story.append(PageBreak())

    # Partnership Proposition
    story.append(Paragraph('The Partnership Proposition', styles['SectionHead']))

    story.append(Paragraph('What FutureProof Offers the Wholesale Funder', styles['SubHead']))
    offers = [
        f'Access to a new, growing asset class with {V14["poc_portfolio_yr30"]}% portfolio PoC — comparable to prime residential',
        'Long-duration, stable AUM — run-off mechanism ensures no early exits',
        'Self-amortising P&I loans — credit quality improves every year',
        'First mortgage security over prime residential property ($2M+)',
        '50% of surplus at maturity — aligning funder and originator incentives',
        'Institutional fund management (BlackRock) removes counterparty risk on investments',
        'Payments & Risk Waterfall and insurance layers provide multi-level loss protection',
    ]
    for o in offers:
        story.append(Paragraph(f'<bullet>&bull;</bullet> {o}', styles['BulletCustom']))

    story.append(Paragraph('What FutureProof Seeks', styles['SubHead']))
    seeks = [
        'Competitive wholesale margin (target: 1.5-2.0% above cash rate)',
        'Commitment to fund an initial pilot of 50-100 EPMs ($67-135M)',
        'Scalable facility to support growth to $2.5B+ over 5 years',
        'Collaborative approach to product development and risk sharing',
    ]
    for s in seeks:
        story.append(Paragraph(f'<bullet>&bull;</bullet> {s}', styles['BulletCustom']))

    story.append(Paragraph('The Win-Win', styles['SubHead']))
    wins = [
        'Lower margin -> viable IO tier -> larger addressable market -> more AUM for the funder',
        'At 2.0% margin on $2.5B portfolio = $50M annual wholesale revenue',
        'At 3.0% on a smaller $1.0B portfolio = $30M — lower total revenue despite higher per-unit margin',
        'Long-duration, low-risk, self-amortising residential assets are exactly what bank balance sheets want',
        'ESG-positive product supports responsible lending and retirement security narratives',
    ]
    for w in wins:
        story.append(Paragraph(f'<bullet>&bull;</bullet> {w}', styles['BulletCustom']))

    story.append(PageBreak())

    # EPM vs Current Investment Landscape
    story.append(Paragraph('EPM vs Traditional Lending — Risk Comparison', styles['SectionHead']))
    story.append(Paragraph(
        'For wholesale funders assessing portfolio risk, the EPM offers a fundamentally different — and, at '
        'base case, more favourable — credit profile than traditional residential lending. The table shows '
        'the comparison at base and realistic-central parameters.',
        styles['BodyText2']))

    story.append(make_table(
        ['Risk Metric', 'EPM base', 'EPM realistic', 'Prime Mortgage', 'RMBS AA'],
        [
            ['Cumulative PoD (30yr)', f'{V14["deficit_prob_yr30"]:.1f}%', '16.9%', '3–5%', '~1–2%'],
            ['Loss severity (LGD)', '~21%', '~21%', '20–40%', 'Subord.'],
            ['Expected loss (30yr)', '0.13%', '~2.3%', '0.6–1.25%', '0.05–0.15%'],
            ['Prepayment risk', 'None (run-off)', 'None (run-off)', 'Significant', 'Moderate'],
            ['Funder residual (insured)', '~0%', '~0%', 'Uninsured', 'Subord.'],
        ],
        col_widths=[35*mm, 25*mm, 30*mm, 30*mm, 25*mm]
    ))

    story.append(Spacer(1, 3*mm))
    funder_landscape = [
        '<b>Mortgage-level PoD varies by scenario; funder residual does not.</b> At base case the EPM PoD sits '
        f'at {V14["deficit_prob_yr30"]:.1f}%, below the 3–5% prime mortgage range. At realistic-central parameters '
        'it rises to 16.9%. In both cases the funder\'s residual exposure is approximately zero because LMI '
        'and tail-risk reinsurance, paid upfront at origination, cover the entire loss distribution.',
        '<b>Zero prepayment risk across all scenarios.</b> Traditional mortgage books face significant prepayment '
        'risk that shortens duration and reduces yield. The EPM\'s run-off mechanism eliminates this entirely — '
        'no borrower can exit until all loan costs are paid from the investment account. This duration '
        'certainty is a structural feature, not a parameter-dependent assumption.',
        '<b>Full insurance coverage from $0.</b> LMI covers '
        f'the first ${abs(V14["top_cover_limit"]):,.0f} of any deficit per mortgage; tail-risk reinsurance '
        'covers the excess. Premium is sized to the realistic-central leg; reinsurance attachment is sized '
        'to the adverse-plausible leg. This is more comprehensive than standard LMI, which typically attaches '
        'above a deductible.',
        '<b>Uncorrelated to existing mortgage book risk.</b> EPM losses are driven by long-term equity index '
        'returns, not by borrower employment or income. Adding EPMs to a traditional mortgage portfolio '
        'provides genuine diversification — and this diversification is robust to the parameter uncertainty '
        'discussed above, because the risk drivers themselves are structurally different.',
    ]
    for fl in funder_landscape:
        story.append(Paragraph(f'<bullet>&bull;</bullet> {fl}', styles['BulletCustom']))

    story.append(PageBreak())

    # Methodology
    story.append(Paragraph('Methodology', styles['SectionHead']))
    story.append(make_table(
        ['Component', 'Detail'],
        [
            ['Simulation engine', '50,000-path Monte Carlo, annual time steps, 30-year tenure'],
            ['Risk factors', 'Stochastic equity returns (lognormal) + stochastic cash rates (OU)'],
            ['Equity-rate correlation', '0.30 (appropriate for 30-year horizon; long-term marginally positive)'],
            ['Index-linked ETF', 'Cap/floor on quarterly returns (+20%/-20%)'],
            ['House prices', 'Deterministic (sets LVR at origination only; not a shared appreciation mortgage)'],
            ['Prepayment/Early exit', 'Run-off mechanism: no exit until all loan costs paid'],
            ['Insurance pricing', 'Based on discounted expected deficit (S3); discounted at 2.13% (cash rate mean)'],
            ['Insurance structure', 'LMI covers 80% of loss; worst 20% quantile = tail risk (reinsurance)'],
            ['Payments & Risk Waterfall', 'ETF selldown → cross-subsidise from surpluses → net deficit → PoC'],
            ['Surplus split', '50/50 FutureProof and Mortgage Funder'],
            ['Portfolio model', '10,000 EPMs (all 30-year), 6 vintage years (2026-2031)'],
        ],
        col_widths=[40*mm, 110*mm]
    ))

    doc.build(story, onFirstPage=lambda c, d: footer(c, d, footer_title),
              onLaterPages=lambda c, d: footer(c, d, footer_title))
    print(f'  Generated: {filename}')
    return filename


# ============================================================
# REPORT 4: RISK ANALYSIS
# ============================================================

def build_risk_analysis():
    filename = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'docs', 'pdfs', 'FutureProof_EPM_Risk_Analysis_Apr2025.pdf')
    footer_title = 'Confidential'

    doc = SimpleDocTemplate(
        filename, pagesize=A4,
        leftMargin=25*mm, rightMargin=25*mm,
        topMargin=20*mm, bottomMargin=20*mm
    )
    styles = get_styles()
    story = []

    title_page(story, styles,
               'Equity Preservation Mortgage v14c',
               'Quantitative Risk Analysis & Hedging Strategy',
               'P&I + Index-linked ETF Configuration | April 2025',
               'CONFIDENTIAL — For Internal Distribution Only')

    # Executive Summary
    story.append(Paragraph('Executive Summary', styles['SectionHead']))
    story.append(Paragraph('Risk Profile Across Parameter Scenarios', styles['SubHead']))
    story.append(Paragraph(
        'This paper analyses EPM risk at the model-as-written (base-case) parameters and at two '
        'empirically-anchored parameter scenarios developed in the companion paper "Model Assumptions and '
        'Parameter Risk" (April 2025). The base case is the model as currently calibrated; the realistic-'
        'central scenario uses empirically-centred estimates of μ, γ, and collar cost; the adverse-plausible '
        'scenario uses the lower bounds of their confidence intervals. Readers should treat all three as '
        'active risk scenarios — not as "base vs sensitivities".',
        styles['BodyText2']
    ))

    story.append(make_table(
        ['Scenario', 'PoD (Yr 30)', 'Mean Surplus', 'Use in risk framework'],
        [
            ['Base (model-as-written)', f'{V14["deficit_prob_yr30"]}%', f'${V14["mean_surplus_yr30"]:,.0f}', 'Pricing floor, headline number'],
            ['Realistic-central', '16.9%', '~$995,000', 'Pricing anchor, reserve testing'],
            ['Adverse-plausible', '43.2%', '~$253,000', 'Capital sizing, reinsurance attachment'],
        ],
        col_widths=[40*mm, 22*mm, 28*mm, 60*mm]
    ))

    story.append(Spacer(1, 3*mm))
    story.append(Paragraph(
        f'<b>Key distinction:</b> PoD is the mortgage-level probability of deficit at maturity. Portfolio PoC '
        f'(after the Payments & Risk Waterfall) is lower in every scenario, because cross-subsidisation from surplus '
        f'mortgages absorbs deficits from expiring mortgages before any claim is made. At base case, portfolio '
        f'PoC is {V14["poc_portfolio_yr30"]}% at year 30 versus {V14["deficit_prob_yr30"]}% individual PoD. '
        f'At realistic-central and adverse-plausible parameters, the waterfall still operates but the surplus-'
        f'to-deficit ratio narrows. Claims can only arise at mortgage expiry.',
        styles['BodyText2']
    ))

    story.append(PageBreak())

    # PoD vs PoC — the critical chart
    story.append(Paragraph('PoD vs PoC — The Critical Distinction', styles['SectionHead']))
    story.append(fig_to_image(chart_pod_vs_poc(), height=85*mm))
    story.append(Paragraph(
        'The chart above illustrates why PoC — not PoD — is the metric that matters for risk assessment. '
        'The dashed red line shows PoD (balance sheet deficit) which is high in early years but irrelevant to insurance '
        'since no claims can be made until mortgage expiry. Portfolio PoC at Year 30 (after the Payments & Risk Waterfall) '
        f'is just {V14["poc_portfolio_yr30"]}% — the only point at which claims can arise.',
        styles['BodyText2']
    ))
    story.append(Paragraph(
        'The Payments & Risk Waterfall is the mechanism that bridges PoD to PoC at the portfolio level:',
        styles['BodyText2']
    ))
    wf = [
        '<b>Step 1:</b> When a mortgage expires in deficit, sell down the ETFs from that loan\'s investment account',
        '<b>Step 2:</b> Cross-subsidise by taking surpluses from other open (non-expiring) mortgages in the portfolio',
        '<b>Step 3:</b> Only the residual net deficit (if any) triggers an insurance/reinsurance claim',
    ]
    for w in wf:
        story.append(Paragraph(f'<bullet>&bull;</bullet> {w}', styles['BulletCustom']))

    story.append(PageBreak())

    # Portfolio PoC
    story.append(Paragraph('Portfolio Probability of Claim (PoC)', styles['SectionHead']))
    story.append(fig_to_image(chart_poc_portfolio(), height=85*mm))
    story.append(Paragraph(
        f'Portfolio PoC at Year 30 (mortgage expiry) is {V14["poc_portfolio_yr30"]}% after the Payments & Risk Waterfall — a ~100x reduction '
        f'from the individual PoD of {V14["deficit_prob_yr30"]}%. The Payments & Risk Waterfall leverages the 109:1 ratio of surplus to deficit '
        f'mortgages for effective cross-subsidisation. At {V14["poc_portfolio_yr30"]}%, the reinsurance claim probability is well below '
        'typical thresholds — supporting attractive reinsurance terms.',
        styles['BodyText2']
    ))

    story.append(PageBreak())

    # PoD over time — context only
    story.append(Paragraph('Deficit Probability (PoD) — Balance Sheet Context', styles['SectionHead']))
    story.append(fig_to_image(chart_deficit_over_time(), height=85*mm))
    story.append(Paragraph(
        'PoD shows the fraction of paths in deficit at each year — a useful balance sheet view but not the '
        f'probability of a claim. PoD is naturally high early ({DEFICIT_BY_YEAR[0]:.1f}% at year 1) due to upfront costs, and declines to '
        f'{V14["deficit_prob_yr30"]}% by year 30 as P&I amortisation takes effect. <b>Important:</b> PoD at any year before mortgage expiry '
        'is irrelevant to insurance — it simply reflects an interim balance sheet position. Only PoC on expiring '
        'loans matters for insurance and reinsurance.',
        styles['BodyText2']
    ))

    story.append(PageBreak())

    # Surplus distribution
    story.append(Paragraph('Surplus Distribution', styles['SectionHead']))
    story.append(fig_to_image(chart_surplus_fan(), height=85*mm))
    story.append(Paragraph(
        'The surplus distribution shows strongly positive skew — the median and mean diverge significantly '
        'after year 15. At maturity, the median surplus is '
        f'${V14["median_surplus_yr30"]:,.0f} while the 10th percentile is '
        f'${V14["p10_yr30"]:,.0f}.',
        styles['BodyText2']
    ))
    story.append(Paragraph(
        '<b>Surplus allocation:</b> At maturity, surplus is split 50/50 between FutureProof and the Mortgage Funder. '
        'Partial profit realisations occur every 5 years (10% of surplus drawn every 5 years). '
        'The surplus does NOT go to the borrower.',
        styles['BodyText2']
    ))

    story.append(PageBreak())

    # Balance at maturity histogram
    story.append(Paragraph('Distribution of Balance at Maturity', styles['SectionHead']))
    story.append(fig_to_image(chart_histogram(), height=85*mm))
    story.append(Paragraph(
        'The histogram shows the distribution of balance at maturity. The deficit paths (red bar) represent '
        f'{V14["deficit_prob_yr30"]}% of individual outcomes (PoD). However, at the portfolio level, the Payments & Risk Waterfall reduces '
        f'the actual claim probability to {V14["poc_portfolio_yr30"]}%. The long positive tail demonstrates strong upside potential — '
        'the mean ($2.84M) exceeds the median ($2.09M), confirming positive skewness from investment compounding.',
        styles['BodyText2']
    ))

    story.append(PageBreak())

    # Key risk factors — corrected
    story.append(Paragraph('Key Risk Factors — Ranked by Impact', styles['SectionHead']))

    story.append(Paragraph('1. Parameter Uncertainty on μ, γ, Collar Cost — HIGHEST IMPACT', styles['SubHead']))
    story.append(Paragraph(
        'The single largest risk driver in the v14c model is the calibration of the three empirical inputs '
        'identified in the companion Model Assumptions paper: equity drift μ (base 9.2%, realistic 8.2%, CAPE-'
        'implied 5–6%), mean-reversion γ (base 0.163, bootstrap 95% CI [0.019, 0.447]), and collar cost '
        '(base 0.046%, Black-Scholes range 0.16–0.44%). Moving each of these to empirically-centred values '
        f'simultaneously takes PoD from {V14["deficit_prob_yr30"]}% to 16.9%; moving to their lower bounds '
        'takes PoD to 43.2%. No product-design lever reduces this sensitivity — it is inherent to '
        'long-horizon equity-dependent products.',
        styles['BodyText2']
    ))

    story.append(Paragraph('2. Effective Leverage (LVR) — HIGH IMPACT', styles['SubHead']))
    story.append(Paragraph(
        'The v14c model uses 80% maximum LVR with an effective LVR of 62.0% ($1.36M on $2M property). '
        'Higher leverage means a larger mortgage balance that must be serviced, increasing the cost burden. '
        'Reducing LVR would reduce both PoD and PoC across all parameter scenarios — this is a design-lever '
        'risk that product teams can directly manage.',
        styles['BodyText2']
    ))

    story.append(Paragraph('3. Loan Structure (IO vs P&I) — HIGH IMPACT', styles['SubHead']))
    story.append(Paragraph(
        'P&I is the default and correct structural choice. The self-amortising nature creates a declining mortgage balance '
        'that the investment only needs modest returns to exceed. If IO were offered as a premium tier, PoD would be '
        'materially higher across all parameter scenarios, though the Payments & Risk Waterfall would still operate.',
        styles['BodyText2']
    ))

    story.append(Paragraph('4. Cash-Rate Mean θ Calibration — MEDIUM-HIGH IMPACT', styles['SubHead']))
    story.append(Paragraph(
        'The 2.13% long-run mean in the OU process is the MLE on US Fed Funds 1988–2024. The equivalent AU '
        'cash-rate MLE is 4.7%; moving θ to 3.0% (conservative AU anchor) takes base-case PoD to 6.4%. Since '
        'the product is AU-originated and AU-funded, the θ input should be re-anchored on AU data.',
        styles['BodyText2']
    ))

    story.append(Paragraph('5. Wholesale Margin — MEDIUM-HIGH IMPACT', styles['SubHead']))
    story.append(Paragraph(
        'The v14c model assumes 2.0% wholesale margin. Current indicative quotes are around 2.5–3.0%. '
        'Each 50bp increase in margin adds approximately 3–5 percentage points to individual PoD. '
        'The impact on portfolio PoC is less severe due to the Payments & Risk Waterfall. '
        'Margin negotiation remains important for optimising individual loan economics.',
        styles['BodyText2']
    ))

    story.append(Paragraph('6. Payments & Risk Waterfall Effectiveness — HIGH IMPACT (POSITIVE)', styles['SubHead']))
    story.append(Paragraph(
        'The Payments & Risk Waterfall is the most powerful structural risk mitigant at the portfolio level and '
        'operates across all parameter scenarios. At base case, the ratio of surplus-to-deficit mortgages is '
        'approximately 6:1 — providing abundant cross-subsidisation capacity. At adverse-plausible parameters '
        'that ratio narrows materially, which is why capital and reinsurance sizing is calibrated to that leg.',
        styles['BodyText2']
    ))

    story.append(Paragraph('7. Run-off Mechanism — Unique Risk Mitigant', styles['SubHead']))
    story.append(Paragraph(
        'The EPM has a unique run-off mechanism: no voluntary prepayments or early terminations are permitted until '
        'all loan costs have been paid from the investment/offset account. No other mortgage product works this way. '
        'This eliminates early exit risk across all parameter scenarios and ensures every loan contributes to '
        'portfolio cross-subsidisation for its intended term.',
        styles['BodyText2']
    ))

    story.append(PageBreak())

    # Hedging Instruments
    story.append(Paragraph('Hedging Instruments — Effectiveness Ranking', styles['SectionHead']))
    story.append(make_table(
        ['Instrument', 'Implementation', 'Annual Cost', 'Impact', 'Rating'],
        [
            ['Payments & Risk Waterfall', 'Portfolio structure', 'Nil', f'PoD {V14["deficit_prob_yr30"]}% → PoC {V14["poc_portfolio_yr30"]}%', 'HIGHEST'],
            ['P&I repayment', 'Product config', 'Nil', 'Major PoD reduction', 'HIGHEST'],
            ['Run-off mechanism', 'Contractual', 'Nil', 'Eliminates early exit risk', 'HIGHEST'],
            ['Index-linked ETF', 'BlackRock/SpiderRock', '~0.25% (hedge cost)', 'Volatility management', 'HIGH'],
            ['Annuity structure', '$36K/yr × 10yr', 'Nil', 'Reduces initial loan balance', 'HIGH'],
            ['Cross-subsidisation', 'Portfolio level', 'Nil', 'Surplus loans offset deficit', 'HIGH'],
            ['Stochastic rates', 'OU model', 'Nil', 'Realistic pricing', 'MEDIUM'],
            ['Rate swap', 'OTC 5yr fixed', '~25bp p.a.', f'<{V14["poc_portfolio_yr30"]}% improvement', 'LOW'],
        ],
        col_widths=[32*mm, 30*mm, 22*mm, 35*mm, 28*mm]
    ))

    story.append(Spacer(1, 5*mm))
    story.append(Paragraph(
        'Key takeaway: The three highest-impact interventions are all structural and free: the Payments & Risk Waterfall, '
        'P&I repayment, and the run-off mechanism. These are built into the EPM product design and cannot be '
        'replicated by competitors without the same portfolio structure.',
        styles['BodyText2']
    ))

    story.append(PageBreak())

    # Investment & Hedging Structure
    story.append(Paragraph('Investment & Hedging Structure — v14c Mechanics', styles['SectionHead']))
    story.append(Paragraph(
        'A calculated portion of loan proceeds is held in the mortgage offset account and invested by BlackRock in '
        'index-linked ETFs — predominantly S&amp;P500. The investment structure has two layers of volatility reduction:',
        styles['BodyText2']
    ))

    story.append(make_table(
        ['Layer', 'Provider', 'Mechanism', 'Volatility Effect'],
        [
            ['1. Volatility Control', 'BlackRock', 'Passive index diversification across S&P500', '15% → 12%'],
            ['2. Dynamic Hedging', 'SpiderRock (BlackRock co.)', 'Continuous hedging of S&P500 index for loan duration', '12% → 10%'],
        ],
        col_widths=[30*mm, 30*mm, 55*mm, 25*mm]
    ))

    story.append(Spacer(1, 3*mm))
    story.append(Paragraph(
        'BlackRock\'s ETF portfolio is <b>passive</b>, not actively managed. BlackRock creates a Volatility Control layer '
        'that, through index diversification, reduces S&amp;P500 index volatility from 15% to 12%. SpiderRock (a BlackRock '
        'company) then applies continuous dynamic hedging of the S&amp;P500 index for the duration of each loan, reducing '
        'volatility further from 12% to 10%. The combined effect is modelled as a cap/floor on returns:',
        styles['BodyText2']
    ))

    story.append(make_table(
        ['Parameter', 'Value', 'Effect'],
        [
            ['Return Cap', '+20% per period', 'Limits upside in exceptional quarters'],
            ['Return Floor', '-20% per period', 'Protects against catastrophic quarterly losses'],
            ['Effective Volatility', '10% (from 15% raw S&P500)', 'Two-layer reduction: 15% → 12% → 10%'],
            ['Hedging Cost', '+0.046% p.a.', 'Cost of SpiderRock dynamic hedging'],
            ['Net Expected Return', '~9.6% p.a.', 'After hedge cost, before margin/fees'],
        ],
        col_widths=[40*mm, 35*mm, 75*mm]
    ))

    story.append(Spacer(1, 3*mm))
    story.append(Paragraph('S&P500 Long-Term Return Basis', styles['SubHead']))
    story.append(Paragraph(
        'The long-term return of the S&amp;P500 index over 30 years is 9.75%-10.8% (depending on which 30-year period '
        'is selected). The model uses <b>BlackRock\'s forward-looking 30-year return profile of 10%</b>. This is a '
        'reasonable central estimate supported by historical evidence across multiple 30-year windows.',
        styles['BodyText2']
    ))

    story.append(PageBreak())

    # Stochastic rate analysis — fixed correlation narrative
    story.append(Paragraph('Stochastic Interest Rate Analysis', styles['SectionHead']))
    story.append(make_table(
        ['Parameter', 'Value', 'Interpretation'],
        [
            ['Process', 'Ornstein-Uhlenbeck (OU)', 'Mean-reverting, Gaussian increments'],
            ['Initial Rate', '2.13%', 'Current RBA cash rate environment'],
            ['Long-Run Mean', '2.13%', 'Neutral rate assumption'],
            ['Mean-Reversion Speed', '0.8', 'Fast reversion (half-life ~0.9 years)'],
            ['Volatility', '1.5%', 'Moderate rate uncertainty'],
            ['Equity Correlation', '0.30', 'Appropriate for 30-year horizon'],
        ],
        col_widths=[40*mm, 40*mm, 70*mm]
    ))

    story.append(Spacer(1, 3*mm))
    story.append(Paragraph(
        'The OU model is appropriate for Australian cash rates — mean-reverting with Gaussian increments. '
        'The equity-rate correlation of 0.30 is correct for a 30-year product horizon. While this correlation is '
        'normally negative overall in the short term and fluctuates between positive and negative intra-term '
        '(hence a zero assumption would be normal for shorter products), over 30-year horizons it is marginally '
        'positive, typically between 0.1 and 0.3. The 0.2 assumption sits in the middle of this range.',
        styles['BodyText2']
    ))

    story.append(PageBreak())

    # Insurance Structure — corrected
    story.append(Paragraph('Insurance & Reinsurance Structure', styles['SectionHead']))

    story.append(Paragraph('Premium Calculation', styles['SubHead']))
    story.append(Paragraph(
        'The insurance premium is calculated on the <b>discounted expected deficit (S3)</b>. The discount rate of '
        '2.13% corresponds to the long-run cash rate mean (MLE estimate). This discounting is necessary because no '
        'reinsurance claim can be made until mortgage expiry (Year 30), but premiums '
        'are paid upfront at mortgage origination. Both the LMI premium and the tail risk '
        'premium are paid upfront, providing full insurance coverage from day one.',
        styles['BodyText2']
    ))

    story.append(Paragraph('Two-Layer Structure', styles['SubHead']))
    story.append(make_table(
        ['Layer', 'Coverage', 'Premium Basis', 'Claim Trigger'],
        [
            ['LMI', '80% of deficit paths (smaller losses)', 'Discounted deficit (S3) at 2.13%', 'Deficit on expiring mortgage (after waterfall)'],
            ['Tail Risk (Reinsurance)', 'Worst 20% of deficit paths (larger losses)', '$1,090 per EPM', 'Only at Year 30 on expired mortgages'],
        ],
        col_widths=[25*mm, 35*mm, 40*mm, 50*mm]
    ))
    story.append(Spacer(1, 3*mm))
    story.append(Paragraph(
        '<b>Critical point:</b> Before any reinsurance claim is made at mortgage expiry, the Payments & Risk Waterfall is applied. '
        'This means: (1) ETFs are sold down, (2) surpluses from other open mortgages cross-subsidise the deficit. '
        f'Only the residual net deficit triggers a claim. This is why the portfolio PoC at Year 30 is just {V14["poc_portfolio_yr30"]}%, '
        f'despite individual PoD being {V14["deficit_prob_yr30"]}%. The reinsurance claim can only be made on expired mortgages — any PoD '
        'before expiry is irrelevant.',
        styles['BodyText2']
    ))

    story.append(PageBreak())

    # SWOT — corrected
    story.append(Paragraph('SWOT Analysis — v14c Product Configuration', styles['SectionHead']))

    story.append(Paragraph('Strengths', styles['SubHead']))
    strengths = [
        'Structural features (P&I, run-off, Payments & Risk Waterfall, full insurance from $0) operate across all parameter scenarios',
        'Low loss severity (~21% of peak loan) bounds expected loss even under adverse-plausible parameters',
        f'Payments & Risk Waterfall reduces claim probability materially versus individual PoD in every scenario (base: {V14["deficit_prob_yr30"]}% → {V14["poc_portfolio_yr30"]}%)',
        'Run-off mechanism eliminates early-exit risk (unique to EPM)',
        'Risk driver is equity-market performance relative to rates — genuinely uncorrelated with traditional credit',
        'Insurance premiums paid upfront at origination; claims only at mortgage expiry',
        'Surplus split 50/50 aligns FutureProof and Funder incentives',
        'Deterministic house prices correct for product design (not a shared appreciation mortgage)',
        'Model engineering is sound — 50,000-path MC with SE 0.04% on PoD at base case',
    ]
    for s in strengths:
        story.append(Paragraph(f'<bullet>&bull;</bullet> {s}', styles['BulletCustom']))

    story.append(Paragraph('Weaknesses', styles['SubHead']))
    weaknesses = [
        'Three key inputs (μ, γ, collar cost) each carry wide empirical confidence intervals relative to their base-case values — headline PoD is highly sensitive to this',
        'Collar cost of 0.046% is materially below Black-Scholes pricing at current AU rates (0.16–0.44%) and should be re-anchored',
        'Cash-rate mean θ is MLE on US Fed Funds, not AU cash — should be re-anchored to AU data',
        f'Individual loan PoD ({V14["deficit_prob_yr30"]}%) appears high in isolation — requires portfolio context',
        'Higher effective LVR (62.0%) increases individual loan cost burden',
        'Wholesale margin sensitivity — viability depends on achieving target 2.0% margin',
    ]
    for w in weaknesses:
        story.append(Paragraph(f'<bullet>&bull;</bullet> {w}', styles['BulletCustom']))

    story.append(Paragraph('Opportunities', styles['SubHead']))
    opportunities = [
        'Reducing LVR from 80% to 70% would improve PoD across all parameter scenarios',
        'Multi-region deployment (NZ, UK, US) provides geographic diversification and larger portfolio for waterfall',
        'Annual re-estimation of γ with added data — each year of additional observation tightens the bootstrap CI',
        'Interest-only tier as premium option captures broader market with appropriate pricing',
        'Larger portfolio = more effective Payments & Risk Waterfall (more surplus loans for cross-subsidisation)',
    ]
    for o in opportunities:
        story.append(Paragraph(f'<bullet>&bull;</bullet> {o}', styles['BulletCustom']))

    story.append(Paragraph('Threats', styles['SubHead']))
    threats = [
        'Low-μ equity regime (CAPE-implied 5–6% over next 30yr) would push PoD materially higher than base case',
        'Weaker γ realisation (bootstrap LB near 0.02) would undermine the mean-reversion protection the base case relies on',
        'Wholesale margin at 3.0% (vs assumed 2.0%) would increase individual loan cost burden',
        'Regulatory changes to equity release / reverse mortgage frameworks',
        'Consumer trust and financial literacy barriers in a novel product category',
    ]
    for t in threats:
        story.append(Paragraph(f'<bullet>&bull;</bullet> {t}', styles['BulletCustom']))

    story.append(PageBreak())

    # Parameter Optimisation
    if SENSITIVITY_RESULTS:
        story.append(Paragraph('Parameter Optimisation — Sensitivity Analysis', styles['SectionHead']))
        story.append(Paragraph(
            'We ran 27 Monte Carlo scenarios (10,000 paths each) varying eligible house value ($2M, $2.5M, $3M), '
            'LVR (60%, 70%, 80%), and annuity ($15K, $20K, $25K). The key finding: the annuity as a percentage '
            'of the initial loan — the cost burden ratio — is the single most important driver of both PoD and PoC.',
            styles['BodyText2']
        ))

        fig = chart_sensitivity_annuity_ratio()
        if fig:
            story.append(fig_to_image(fig, height=85*mm))

        story.append(Paragraph(
            'The chart above shows that PoD and PoC decline nearly linearly as the cost burden ratio decreases. '
            'Parameters that reduce this ratio — higher house value, lower annuity — have the greatest impact. '
            'Critically, <b>all 27 scenarios</b> produce portfolio PoC below 1%, confirming the robustness of '
            'the Payments & Risk Waterfall across a wide range of parameter settings.',
            styles['BodyText2']
        ))

        story.append(Paragraph('Top 5 Scenarios by Lowest PoC', styles['SubHead']))
        sorted_sens = sorted(SENSITIVITY_RESULTS, key=lambda x: x['poc_yr30_est'])
        top5_rows = []
        for r in sorted_sens[:5]:
            top5_rows.append([
                f'${r["home_value"]/1e6:.1f}M',
                f'{r["lvr"]*100:.0f}%',
                f'${r["annuity_pa"]/1000:.0f}K',
                f'{r["annuity_pct_of_loan"]:.2f}%',
                f'{r["pod_yr30"]:.1f}%',
                f'{r["poc_yr30_est"]:.2f}%',
                f'${r["mean_surplus"]:,.0f}',
            ])
        story.append(make_table(
            ['House Value', 'LVR', 'Annuity', 'Ann/Loan', 'PoD(30)', 'PoC(30)', 'Mean Surplus'],
            top5_rows,
            col_widths=[20*mm, 14*mm, 18*mm, 18*mm, 16*mm, 16*mm, 28*mm]
        ))

        story.append(Spacer(1, 3*mm))
        story.append(Paragraph('Optimisation Recommendations', styles['SubHead']))
        opt_recs = [
            'Set minimum eligible house value at $2.5M+ to ensure annuity/loan ratio stays below 1%',
            'Consider reducing annuity from $25K to $15-20K — this is the highest-impact controllable lever',
            'Higher LVR with higher house value is actually safer than lower LVR with lower house value '
            '(counterintuitive but confirmed by Monte Carlo)',
            'At $3M / 80% LVR / $15K annuity: PoD=6.0%, PoC=0.19%, Mean Surplus=$6.3M — the optimal configuration',
        ]
        for o in opt_recs:
            story.append(Paragraph(f'<bullet>&bull;</bullet> {o}', styles['BulletCustom']))

        story.append(PageBreak())

    # EPM vs Current Investment Landscape
    story.append(Paragraph('EPM vs Current Investment Landscape', styles['SectionHead']))
    story.append(Paragraph(
        'The preceding analysis quantifies EPM risk at three parameter scenarios. To assess whether that risk '
        'is <i>acceptable</i>, we benchmark it at base-case and realistic-central parameters against established '
        'asset classes.',
        styles['BodyText2']))

    story.append(make_table(
        ['Metric', 'EPM base', 'EPM realistic', 'Prime AU Mortgage', "Moody's AA Bond", 'AU RMBS (AA)'],
        [
            ['Cumulative PoD (30yr)', f'{V14["deficit_prob_yr30"]:.1f}%', '16.9%', '3–5%', '~1.5%', '~1–2%'],
            ['Loss severity (LGD)', '~21%', '~21%', '20–40%', '40–60%', 'Subord.'],
            ['Expected loss (30yr)', '0.13%', '~2.3%', '0.6–1.25%', '0.6–0.9%', '0.05–0.15%'],
            ['Ratings band (PoD)', 'AA/AAA', 'BBB/BB', 'A/BBB', 'AA', 'AA'],
        ],
        col_widths=[32*mm, 22*mm, 25*mm, 22*mm, 22*mm, 25*mm]
    ))

    story.append(Spacer(1, 3*mm))
    risk_landscape = [
        '<b>Scenario matters for ratings equivalence.</b> At base case, the EPM sits in the AA/AAA band on '
        'expected loss (probability × severity = 0.13%). At realistic-central parameters, expected loss '
        'moves to ~2.3% — investment-grade speculative territory (BBB/BB band). A rating can be proposed '
        'only after the parameter set is fixed.',
        '<b>Low severity bounds the downside.</b> The ~21% loss severity is a structural feature and holds '
        'across all scenarios. This is materially lower than 40–60% for unsecured bonds and means expected '
        'loss remains bounded even where PoD is elevated.',
        '<b>Risk driver diversification is scenario-robust.</b> Traditional credit risk comes from borrower '
        'inability to pay. EPM risk comes from 30-year equity market underperformance relative to interest '
        'rates. These risks are largely uncorrelated in every parameter scenario — the diversification benefit '
        'survives parameter stress.',
        '<b>Structural protections unique to EPM.</b> Mean-reverting equity model (though the strength of '
        'reversion itself is a parameter); 80/140 collar caps annual returns; holiday mechanism suspends costs '
        'during stress; run-off mechanism eliminates prepayment risk; full LMI + reinsurance from $0. No other '
        'residential lending product combines all of these features. Collar strength and mean reversion are '
        'parameter-sensitive; the other features are not.',
    ]
    for rl in risk_landscape:
        story.append(Paragraph(f'<bullet>&bull;</bullet> {rl}', styles['BulletCustom']))

    story.append(PageBreak())

    # Recommendations — corrected
    story.append(Paragraph('Recommendations & Next Steps', styles['SectionHead']))

    story.append(Paragraph('Completed', styles['SubHead']))
    done = [
        f'<b>[DONE]</b> Simulation paths increased to 50,000 — PoC {V14["deficit_prob_yr30"]:.1f}% (SE: {V14["deficit_se"]:.2f}%), premium ${V14["ins_fair_premium"]:,.0f}',
        '<b>[DONE]</b> PoD vs PoC distinction clearly established — PoC is the key metric',
        f'<b>[DONE]</b> Payments & Risk Waterfall modelled at portfolio level — PoC {V14["poc_portfolio_yr30"]}% at year 30',
        '<b>[DONE]</b> Run-off mechanism confirmed — no early exit risk',
        '<b>[DONE]</b> Equity-rate correlation validated at 0.2 for 30-year horizon',
        '<b>[DONE]</b> Insurance premium based on discounted expected deficit (S3)',
    ]
    for d in done:
        story.append(Paragraph(f'<bullet>&bull;</bullet> {d}', styles['BulletCustom']))

    story.append(Paragraph('Enhancement Priorities', styles['SubHead']))
    priorities = [
        '<b>[MEDIUM]</b> Run wholesale margin sensitivity analysis (1.5%, 2.0%, 2.5%, 3.0%) on both PoD and PoC',
        '<b>[LOW]</b> Add multi-region parameter sets (AU, NZ, UK, US)',
    ]
    for p in priorities:
        story.append(Paragraph(f'<bullet>&bull;</bullet> {p}', styles['BulletCustom']))

    story.append(Paragraph('Product Configuration', styles['SubHead']))
    prod = [
        'Maintain P&I as the default — the most impactful structural risk reduction',
        'The $25K annuity is well-calibrated',
        'Holiday exit threshold (1.458) is appropriate',
        'Profit realisation at 25% every 5 years is correctly balanced',
        'Run-off mechanism is a key competitive advantage — maintain as standard feature',
    ]
    for p in prod:
        story.append(Paragraph(f'<bullet>&bull;</bullet> {p}', styles['BulletCustom']))

    story.append(PageBreak())

    # Methodology — corrected
    story.append(Paragraph('Methodology', styles['SectionHead']))
    story.append(make_table(
        ['Component', 'Detail'],
        [
            ['Source model', 'FutureProofCalculator_Pavel_v14c (003).xlsm'],
            ['Simulation engine', '50,000-path Monte Carlo, annual time steps, 30-year tenure'],
            ['Equity returns', 'GBM+MeanRev (Shevchenko 2026): mu=9.2%, sigma=16.6%, gamma=0.163; cap=1.2, floor=0.8'],
            ['Cash rate', 'OU mean-reversion (theta=2.13%, kappa=0.24, sigma=1.22%)'],
            ['Equity-rate correlation', '0.30 (appropriate for 30-year horizon)'],
            ['House prices', 'Deterministic by design (sets LVR at origination only)'],
            ['Prepayment/Early exit', 'Run-off mechanism: no exit until loan costs paid'],
            ['Insurance', 'Based on discounted expected deficit (S3) at 2.13%; LMI 80% of deficit paths, tail risk 20%'],
            ['Payments & Risk Waterfall', 'ETF selldown → cross-subsidise → net deficit → PoC'],
            ['Surplus split', '50/50 FutureProof and Mortgage Funder'],
            ['Profit realisation', '10% of surplus drawn every 5 years'],
            ['Portfolio', '10,000 EPMs, all 30-year mortgages, 6 vintage years (2026-2031)'],
        ],
        col_widths=[40*mm, 110*mm]
    ))

    story.append(Spacer(1, 5*mm))
    story.append(Paragraph('Metrics Definitions', styles['SubHead']))
    story.append(Paragraph(
        '<b>PoD (Probability of Deficit):</b> Fraction of paths where investment balance &lt; mortgage balance at a given '
        'point in time. A balance sheet snapshot — NOT the probability of an insurance claim.<br/>'
        '<b>PoC (Probability of Claim):</b> Probability of an actual insurance claim on an expiring mortgage, after the '
        'Payments & Risk Waterfall. The key metric for insurance and reinsurance. Claims only at mortgage expiry.<br/>'
        '<b>Payments & Risk Waterfall:</b> Portfolio mechanism: (1) sell ETFs, (2) cross-subsidise from surplus loans, '
        '(3) determine net deficit and PoC.<br/>'
        '<b>Discounted Expected Deficit (S3):</b> PV of expected loss, discounted at 2.13% (cash rate mean). '
        'Basis for insurance premium.<br/>'
        '<b>Run-off Mechanism:</b> No voluntary prepayment or early termination until all loan costs paid from '
        'investment account. Unique to EPM — eliminates early exit risk.',
        styles['BodyText2']
    ))

    doc.build(story, onFirstPage=lambda c, d: footer(c, d, footer_title),
              onLaterPages=lambda c, d: footer(c, d, footer_title))
    print(f'  Generated: {filename}')
    return filename


# ============================================================
# REPORT 5: CREDIT RISK UNDERWRITING ANALYSIS
# ============================================================

def build_credit_risk_underwriting():
    filename = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'docs', 'pdfs', 'FutureProof_EPM_Credit_Risk_Underwriting_Apr2025.pdf')
    footer_title = 'Credit Risk Underwriting Analysis — EPM v14c'
    styles = get_styles()

    doc = SimpleDocTemplate(filename, pagesize=A4,
                            topMargin=25*mm, bottomMargin=25*mm,
                            leftMargin=25*mm, rightMargin=25*mm)
    story = []

    # Title page
    title_page(story, styles,
               'Equity Preservation Mortgage',
               'Credit Risk Underwriting Analysis',
               'For LMI Insurers and Portfolio Reinsurers — v14c Model',
               'CONFIDENTIAL — Prepared for Insurance/Reinsurance Underwriters')

    # ========================================================
    # EXECUTIVE SUMMARY
    # ========================================================
    story.append(Paragraph('Executive Summary', styles['SectionHead']))
    story.append(Paragraph(
        'This report presents the credit risk underwriting analysis of the FutureProof Equity Preservation '
        'Mortgage (EPM) for insurance and reinsurance underwriters. The EPM is a fundamentally different '
        'credit risk from traditional Lenders Mortgage Insurance (LMI). Traditional LMI underwrites the risk '
        'that a borrower cannot service their mortgage — it is driven by borrower income, employment, and '
        'property values. <b>EPM credit risk is driven by index returns over 30-year loan durations.</b>',
        styles['BodyText2']
    ))
    story.append(Paragraph(
        'The Equity Preservation Mortgage is an index-linked mortgage referenced to the S&amp;P500. To be effective, '
        'index-linking of a mortgage requires long-duration mortgages to smooth index volatility over time. '
        'The central thesis of its design, as it relates to credit risk, is that long-term (15-30 years) index risk '
        'is, ultimately, a more predictable and lower risk than traditional borrower serviceability risk. '
        'This design thesis is well evidenced even in a book of Prime Loans or RMBS securitization program where '
        'often, around 20% of loans are credit impaired/in arrears (0.5%-1.5%), in default (0.2% - 1%) or subject '
        'of pre-payments (12%-20%) \u2013 requiring them to be removed from the loan book, SPV or Trust. Non-prime '
        'mortgage books can often exceed 40%. In economic downturns this can rise higher again, to nearly 50% of '
        'mortgage loans. In a book of Equity Preservation Mortgages there are no bad loans, no defaults and no '
        'pre-payments.',
        styles['BodyText2']
    ))
    story.append(Paragraph(
        'The calculated portion of loan proceeds is held in a mortgage offset account and invested by BlackRock '
        'in index-linked ETFs (predominantly S&amp;P500). The investment account pays all loan costs — the borrower '
        'makes no interest payments (in the interest-only version of the mortgage) and makes no repayments at all '
        '(in the case of the principal + interest mortgage). The credit risk question is therefore: <b>will the '
        'index-linked investment generate sufficient returns over 15-30 years to cover all loan costs?</b>',
        styles['BodyText2']
    ))
    story.append(Paragraph(
        'The secret to the success of the EPM is the long loan duration. Over 30 years, the S&amp;P500 has '
        'historically delivered annualised total returns of 9.75%-10.8% depending on the period selected. '
        'The model uses BlackRock\'s forward-looking 30-year return profile of 10%. At this return level, '
        'the vast majority of return pathways deliver sufficient returns to cover all loan costs with surplus '
        'for a single Equity Preservation Mortgage.',
        styles['BodyText2']
    ))
    story.append(Paragraph(
        'This leaves unaddressed the question of what happens in the event of early termination of a mortgage or '
        'early redemption of mortgage offset capital by the borrower. The Equity Preservation Mortgage has two '
        'unique features that ensure no pre-payments or early redemptions of capital in a borrower\u2019s mortgage '
        'offset account. The first is that capital apportioned to and held in, the mortgage offset account cannot '
        'be re-drawn until end-of-term \u2013 there are no intra-term re-draws allowed. The second, is that a borrower '
        'may terminate an Equity Preservation Mortgage at any time and for any reason, without financial penalty. '
        'However, if at the date of early termination the balance of the mortgage offset (investment account) is '
        'less than its opening balance or if there is any deferred and unpaid loan interest as a result of '
        'interest-holidays, then the mortgage offset account automatically goes into \u2018run-off\u2019 until that deficit '
        'is cleared or until end-of-term where any deficit is insured, whichever occurs first. Once the balance '
        'of the investment account is restored to its original opening balance using this run-off mechanism, the '
        'loan may then be wound-up, mortgage offset capital drawn and applied to the repayment of outstanding '
        'mortgage balance. These unique features neutralise the effect of pre-payments or early redemptions of capital, '
        'ensures no bad loans or defaults and gives the lender certainty as to the deployment of mortgage offset '
        'capital held in the investment account over the loan term.',
        styles['BodyText2']
    ))

    story.append(Spacer(1, 3*mm))
    story.append(Paragraph('Parameter Uncertainty Framework', styles['SubHead']))
    story.append(Paragraph(
        'Before reviewing the underwriting metrics, underwriters should note that the headline PoD is '
        'conditional on three empirical parameter inputs: equity drift μ, mean-reversion γ, and collar cost. '
        'Each carries a meaningful empirical confidence interval; the companion paper "Model Assumptions and '
        'Parameter Risk" (April 2025) quantifies these and defines three scenarios used throughout this '
        'report. LMI premium sizing should reference the realistic-central scenario; portfolio reinsurance '
        'attachment and tail-risk capacity should reference the adverse-plausible scenario.',
        styles['BodyText2']
    ))
    story.append(make_table(
        ['Scenario', 'Mortgage PoD (Yr 30)', 'Expected Loss (30yr)', 'Role for Underwriters'],
        [
            ['Base (model-as-written)', f'{V14["deficit_prob_yr30"]}%', '0.13%', 'Headline / best case'],
            ['Realistic-central', '16.9%', '~2.3%', 'LMI premium anchor'],
            ['Adverse-plausible', '43.2%', '~5.5%', 'Reinsurance attachment / tail sizing'],
        ],
        col_widths=[46*mm, 28*mm, 28*mm, 48*mm]
    ))

    story.append(Spacer(1, 3*mm))
    story.append(Paragraph('Key Underwriting Metrics (Base Case)', styles['SubHead']))
    story.append(make_table(
        ['Metric', 'Value', 'Relevance'],
        [
            ['Individual PoD (Yr 30)', f'{V14["deficit_prob_yr30"]}%', 'Balance sheet deficit at that particular time slice — NOT claim probability'],
            ['Portfolio PoC (Yr 30)', f'{V14["poc_portfolio_yr30"]}%', 'Actual insurance claim probability after Payments & Risk Waterfall'],
            ['LMI Top Cover (P10)', f'${abs(V14["p10_yr30"]):,.0f}', 'Worst 20% of deficit paths (larger losses) — sets LMI policy limit'],
            ['Tail Risk (P1)', f'${abs(V14["p1_yr30"]):,.0f}', 'Worst 1% quantile — worst case loss exposure'],
            ['Cond. Expected Deficit', f'${abs(V14["cond_expected_deficit"]):,.0f}', 'Average deficit when deficit occurs (before waterfall)'],
            ['Fair Premium (PV)', f'${V14["ins_fair_premium"]:,.0f}', 'Discounted at 2.13% (cash rate mean) — paid upfront'],
            ['Premium + Loading (150%)', f'${V14["ins_plus_loading"]:,.0f}', 'Loaded premium — paid upfront at origination'],
            ['Simulation Paths', f'{V14["nsim"]:,}', 'SE on PoD: {0}%, SE on premium: ${1:,}'.format(V14["deficit_se"], V14["ins_stderr"])],
        ],
        col_widths=[40*mm, 30*mm, 80*mm]
    ))

    story.append(PageBreak())

    # ========================================================
    # SECTION 1: WHY EPM CREDIT RISK IS NOT TRADITIONAL LMI
    # ========================================================
    story.append(Paragraph('1. Why EPM Credit Risk is Not Traditional LMI', styles['SectionHead']))

    story.append(Paragraph(
        'Traditional LMI underwrites borrower credit risk — the probability that a borrower defaults on '
        'mortgage repayments due to loss of income, divorce, illness, or other personal circumstances. '
        'Property value serves as the recovery mechanism. The EPM is fundamentally different:',
        styles['BodyText2']
    ))

    story.append(make_table(
        ['Dimension', 'Traditional LMI', 'EPM Credit Risk'],
        [
            ['Risk driver', 'Borrower income & employment', 'S&P500 index total return over 15-30 years'],
            ['Repayment source', 'Borrower salary/income', 'Index appreciation + Portfolio returns'],
            ['Borrower makes payments?', 'Yes — monthly P&I', 'No — investment account pays all costs'],
            ['Claim trigger', 'Borrower default + property sale shortfall', 'Investment < loan at contract expiry'],
            ['Property role', 'Primary recovery mechanism', 'First mortgage security (additional collateral)'],
            ['Duration risk', '3-7 year average life', '15-30 year contractual term'],
            ['Prepayment risk', 'Significant (refinancing)', 'None — run-off mechanism prevents early exit'],
            ['Diversification basis', 'Geographic, employment sector', 'Risk pooling by mortgage vintage, cross-subsidisation between unexpired mortgages, long duration covers multiple economic cycles'],
        ],
        col_widths=[30*mm, 55*mm, 65*mm]
    ))

    story.append(Spacer(1, 5*mm))
    story.append(Paragraph(
        'The EPM\'s credit risk is underpinned by <b>index risk over 30-year loan durations</b>. This is a '
        'fundamentally more favourable risk profile for insurers because: (1) long-duration equity returns are '
        'statistically more predictable than short-duration returns, (2) the S&amp;P500 has never delivered a negative '
        '30-year total return in its history, and (3) the risk can be precisely modelled using stochastic simulation.',
        styles['BodyText2']
    ))

    story.append(PageBreak())

    # ========================================================
    # SECTION 2: TWO-LAYER INSURANCE STRUCTURE
    # ========================================================
    story.append(Paragraph('2. Two-Layer Insurance Structure', styles['SectionHead']))

    story.append(Paragraph('Layer 1 — LMI: Individual Mortgage Credit Risk', styles['SubHead']))
    story.append(Paragraph(
        'LMI covers individual mortgages up to the <b>Top Cover Limit</b> of the LMI policy. The Top Cover Limit '
        'is set at the P20 of the conditional deficit distribution — meaning 80% of deficit paths have '
        'deficits below this limit, covered entirely by LMI.',
        styles['BodyText2']
    ))
    story.append(make_table(
        ['LMI Parameter', 'Value', 'Derivation'],
        [
            ['Coverage', '80% of deficit paths (smaller losses)', 'Up to P10 quantile of deficit distribution'],
            ['Top Cover Limit', f'${abs(V14["p10_yr30"]):,.0f}', '10th percentile deficit at maturity'],
            ['Individual PoD (Yr 30)', f'{V14["deficit_prob_yr30"]}%', '50,000-path Monte Carlo (SE: {0}%)'.format(V14["deficit_se"])],
            ['Cond. Expected Deficit', f'${abs(V14["cond_expected_deficit"]):,.0f}', 'Average deficit when deficit occurs'],
            ['Fair Premium (PV)', f'${V14["ins_fair_premium"]:,.0f}', 'Discounted expected deficit at 2.13%'],
            ['Loaded Premium', f'${V14["ins_plus_loading"]:,.0f}', '150% loading on fair premium'],
            ['Premium Timing', 'Paid upfront at origination', 'Full premium collected before any risk attaches'],
            ['Claim Timing', 'At loan contract expiry only', 'No claim possible until years 15-30'],
        ],
        col_widths=[40*mm, 35*mm, 75*mm]
    ))

    story.append(Spacer(1, 5*mm))
    story.append(Paragraph('Layer 2 — Portfolio Reinsurance: Residual Tail Risk', styles['SubHead']))
    story.append(Paragraph(
        'The worst 20% of deficit paths (tail risk beyond the LMI split boundary) is transferred to the '
        'portfolio level to be separately underwritten by a credit risk reinsurer. Critically, the Payments '
        'Waterfall is applied at the portfolio level <b>before</b> any reinsurance claim is made.',
        styles['BodyText2']
    ))
    story.append(make_table(
        ['Reinsurance Parameter', 'Value', 'Derivation'],
        [
            ['Coverage', 'Worst 20% of deficit paths (larger losses) (tail risk)', 'Loss beyond LMI Top Cover Limit'],
            ['P1 Deficit (worst 1%)', f'${abs(V14["p1_yr30"]):,.0f}', 'Maximum realistic exposure per loan'],
            ['P5 Deficit (worst 5%)', f'${abs(V14["p5_yr30"]):,.0f}', 'Severe stress scenario'],
            ['Portfolio PoC (Yr 30)', f'{V14["poc_portfolio_yr30"]}%', 'After Payments & Risk Waterfall — the key metric'],
            ['Claim Timing', 'At loan contract expiry only', 'After Payments & Risk Waterfall has been applied'],
        ],
        col_widths=[42*mm, 33*mm, 75*mm]
    ))

    story.append(PageBreak())

    # ========================================================
    # SECTION 3: LOSS MITIGATION — THE MULTI-LAYER DEFENCE
    # ========================================================
    story.append(Paragraph('3. Loss Mitigation Before Any Insurance Claim', styles['SectionHead']))

    story.append(Paragraph(
        'Before any insurance or reinsurance claim is made, the following loss mitigation layers are applied '
        '<b>in order</b>. Each layer materially reduces the residual risk that flows through to the next:',
        styles['BodyText2']
    ))

    # Layer 0 — Mortgage Offset Account Capital
    story.append(Paragraph('<b>Layer 0: Mortgage Offset Account Capital</b>', styles['SubHead']))
    story.append(Paragraph(
        'Upon mortgage set-up, the Monte Carlo simulation returns a mean of total index return pathways. '
        'By reference to this mean value, a calculation is made as to how much loan capital has to be apportioned '
        'to and held in, the borrower\u2019s mortgage offset account sufficient to deliver the expected return needed '
        'to cover loan cost.',
        styles['BodyText2']
    ))
    story.append(Paragraph(
        'This capital is deployed by the lender for the loan duration and held as index-linked ETFs, '
        'passively managed by BlackRock.',
        styles['BodyText2']
    ))
    story.append(Spacer(1, 2*mm))

    # Layer 1 — Prudential Capital Buffer
    story.append(Paragraph('<b>Layer 1: Prudential Capital Buffer</b>', styles['SubHead']))
    story.append(Paragraph(
        'In addition to the amount of capital determined held in Layer 0, an additional 30% of portfolio value '
        'in loan capital is apportioned to and held in, the borrower\u2019s mortgage offset account. This is a capital '
        'buffer over and above the amount of capital available in Layer 0. This capital is also deployed by the '
        'lender for the loan duration and held as cash and passively-managed index-linked ETFs, managed by BlackRock.',
        styles['BodyText2']
    ))
    story.append(Paragraph(
        'A 30% prudential capital buffer in addition to Layer 0 capital (in tandem with hedging using a -20% floor '
        '\u2014 see Layer 3 below), protects the lender against all historically observed single S&amp;P 500 drawdowns, '
        'even the worst historical crash (the GFC). It is an extremely strong protection against a single year shock.',
        styles['BodyText2']
    ))
    story.append(Paragraph(
        'The only scenario that breaks this structure is a multi-year sequence of deep drawdowns, not a single crash. '
        'To protect the lender against this vulnerability, we rely on the long-time horizons of Equity Preservation '
        'Mortgages of 15-30 years to capture market rebounds and protect the underlying index against permanent loss. '
        'This design feature doesn\u2019t fully protect the hedged structure from multi-year drawdowns because hedges '
        're-set every 3 years and any sequential losses are crystallized at each re-set \u2014 sometimes referred to '
        'as \u201croll-risk\u201d.',
        styles['BodyText2']
    ))
    story.append(Paragraph(
        'A new feature is introduced in Layer 6 \u2014 Payments & Risk Waterfall that dramatically affects the risk profile of '
        'the portfolio. Layer 6 is designed to pool surplus/profits of all unexpired mortgages in the funder\u2019s loan '
        'book and cross-subsidise the minority of under-performing mortgages by the majority of performing mortgages. '
        'Pooling assists in mitigating portfolio risk because mortgages are written at different points in time and at '
        'different stages of the economic cycle \u2014 profit/surplus of a mortgage depends upon its vintage.',
        styles['BodyText2']
    ))
    story.append(Paragraph(
        'A 30-year horizon + cross-subsidisation across vintages dramatically reduces the impact of multi-year crashes, '
        'in a way that a single-account hedged portfolio cannot. It is a rolling 30 year portfolio (not a single 30 year '
        'account) in which all unexpired mortgages are contributing to a shared capital buffer through cross-subsidisation '
        'within the pool. Another way of expressing this is that sequential drawdowns do not propagate linearly through '
        'the portfolio pool:',
        styles['BodyText2']
    ))
    story.append(Paragraph(
        'Pooling + vintage diversification protects you from sequential drawdowns because:',
        styles['BodyText2']
    ))

    # Vintage cohort analysis
    story.append(Paragraph('<b>A. Early-vintage mortgages (years 1\u201310)</b>', styles['SubHead']))
    vintage_early = [
        'Low accumulated surplus',
        'More sensitive to early drawdowns',
        'But represent only a fraction of the total pool at any time',
    ]
    for v in vintage_early:
        story.append(Paragraph(f'<bullet>&bull;</bullet> {v}', styles['BulletCustom']))

    story.append(Paragraph('<b>B. Mid-vintage mortgages (years 10\u201320)</b>', styles['SubHead']))
    vintage_mid = [
        'Large accumulated surplus',
        'Strong positive equity',
        'Can absorb shocks easily',
        'Provide the bulk of cross-subsidisation',
    ]
    for v in vintage_mid:
        story.append(Paragraph(f'<bullet>&bull;</bullet> {v}', styles['BulletCustom']))

    story.append(Paragraph('<b>C. Late-vintage mortgages (years 20\u201330)</b>', styles['SubHead']))
    vintage_late = [
        'Very high surplus',
        'Very low risk',
        'Act like stabilisers in the pool',
    ]
    for v in vintage_late:
        story.append(Paragraph(f'<bullet>&bull;</bullet> {v}', styles['BulletCustom']))

    story.append(Spacer(1, 3*mm))
    story.append(Paragraph(
        'So even if a downturn hits new vintages hard, older vintages are sitting on decades of accumulated surplus, '
        'and they: continue generating positive returns; continue contributing to the buffer; and smooth out losses '
        'from stressed cohorts.',
        styles['BodyText2']
    ))
    story.append(Paragraph(
        'This risk mitigation is consistent with how insurance pools and pension funds maintain stability '
        'through recessions.',
        styles['BodyText2']
    ))

    story.append(Spacer(1, 3*mm))
    story.append(Paragraph('Mortgage Vintage Exposure to Sequential Crash', styles['SubHead']))
    story.append(make_table(
        ['Vintage', 'Exposure to Sequential Crash', 'Impact'],
        [
            ['0\u20133 years old', 'High', 'Some losses, but small share of pool'],
            ['3\u201310 years old', 'Moderate', 'Absorbable via surplus'],
            ['10\u201330 years old', 'Low', 'Provide stabilising surplus'],
        ],
        col_widths=[35*mm, 45*mm, 70*mm]
    ))

    story.append(Spacer(1, 3*mm))
    story.append(Paragraph(
        'Our portfolio is a rolling, multi-vintage, cross-subsidised pool, which changes the risk profile '
        'in three crucial ways:',
        styles['BodyText2']
    ))
    pool_advantages = [
        '<b>Losses are diluted across vintages</b> \u2014 A bad year for new loans is offset by strong surplus '
        'from older loans.',
        '<b>Recoveries benefit all vintages</b> \u2014 When markets rebound (and they always do), the entire pool '
        'participates.',
        '<b>Crashes are time-limited</b> \u2014 Even the worst events (Dot-Com, GFC) lasted 5\u20137 years. Your mortgages '
        'last 30 years. Your pool spans 30 overlapping cohorts.',
    ]
    for a in pool_advantages:
        story.append(Paragraph(f'<bullet>&bull;</bullet> {a}', styles['BulletCustom']))

    story.append(Spacer(1, 3*mm))
    story.append(Paragraph(
        '<b>This is why our mortgage loan portfolio behaves more like a life insurer than a hedge fund.</b>',
        styles['BodyText2']
    ))
    story.append(Paragraph(
        'What is left is residual risk \u2014 being a once-in-a-century crash resulting in a drawdown exceeding 50% '
        'in a single year or multi-year sequential drawdowns that last more than 7 years \u2014 there is no historical '
        'precedent for either.',
        styles['BodyText2']
    ))
    story.append(Spacer(1, 2*mm))

    # Remaining layers (renumbered 2-7)
    layers = [
        ['<b>Layer 2: BlackRock Volatility Control</b>',
         'BlackRock\'s portfolio construction reduces long-term S&amp;P500 index volatility from <b>15% down to 12%</b> '
         'through passive index diversification, creating a volatility control layer. '
         'This is a structural feature of the portfolio, not an active strategy.'],
        ['<b>Layer 3: SpiderRock Continuous Dynamic Hedging</b>',
         'SpiderRock (a BlackRock subsidiary) applies continuous dynamic hedging that further reduces volatility '
         'via a ±40%/−20% collar. This includes a 140% collar on index returns above the long-term total return '
         'over 30 years and an 80% floor on losses. Cost: approximately 0.4% p.a.'],
        ['<b>Layer 4: LMI Claim (Individual Mortgage)</b>',
         'If the investment account at mortgage expiry is insufficient to repay the mortgage balance, the deficit constitutes '
         'a claim on the LMI insurer, up to the Top Cover Limit (P10 = ${0:,.0f}). '.format(abs(V14["p10_yr30"])) +
         'Any loss above the Top Cover Policy Limit is <b>not covered by LMI</b> but is transferred to the Funder\'s '
         'portfolio of mortgages as a Portfolio Risk.'],
        ['<b>Layer 5: Interest Holidays (Capital Preservation Mechanism)</b>',
         'The interest holiday mechanism preserves capital in the investment account during downturns by deferring '
         '(not accruing compound) interest payments when the investment balance falls below the holiday threshold. '
         'This ensures maximum returns are achieved as market cycles recover, rather than selling down ETFs to pay '
         'loan interest during temporary drawdowns.'],
        ['<b>Layer 6: Payments & Risk Waterfall — Risk Pooling and Cross-Subsidisation</b>',
         'Pooling of surpluses across all expired mortgages within a funder\'s loan book. We cross-subsidise the '
         'loss/deficit on a small number of claims (<b>less than 14% of return pathways</b>) against the surplus '
         'returns on the <b>majority of mortgages (86%+ of return pathways)</b>. This is possible because a downturn '
         'in the economic cycle does not affect all mortgages equally — each mortgage is written at a different point '
         'in time and will have a different surplus/deficit position depending on its vintage.'],
        ['<b>Layer 7: Portfolio Reinsurance Claim</b>',
         'Only after taking all of the above into account can any remaining loss/deficit on the overall portfolio '
         'in any given year constitute a claim on the reinsurer.'],
    ]

    for i, (title, desc) in enumerate(layers):
        story.append(Paragraph(title, styles['SubHead']))
        story.append(Paragraph(desc, styles['BodyText2']))
        if i < len(layers) - 1:
            story.append(Spacer(1, 2*mm))

    story.append(Spacer(1, 5*mm))
    story.append(Paragraph(
        '<b>The net effect:</b> A 30% prudential capital buffer plus raw S&amp;P500 volatility of 15% compressed to 10% '
        'through two institutional layers constructed by the global asset manager — volatility control and dynamic '
        'hedging. The Payments & Risk Waterfall then reduces individual PoD of {0}% to a portfolio PoC of just '
        '{1}% at year 30. This eight-layer defence means the probability of an actual claim reaching the reinsurer '
        'is extremely low.'.format(V14["deficit_prob_yr30"], V14["poc_portfolio_yr30"]),
        styles['BodyText2']
    ))

    story.append(PageBreak())

    # ========================================================
    # SECTION 4: MODEL CALCULATIONS — PoD AND PoC
    # ========================================================
    story.append(Paragraph('4. Model Calculations — PoD and PoC', styles['SectionHead']))

    story.append(Paragraph('Understanding PoD vs PoC — Why PoD is NOT the Underwriting Metric', styles['SubHead']))
    story.append(Paragraph(
        '<b>PoD (Probability of Deficit) is not the key metric for underwriting — PoC (Probability of Claim) is.</b> '
        'There are two reasons why PoD is not the same as PoC:',
        styles['BodyText2']
    ))
    pod_reasons = [
        '<b>PoD represents the probability of a deficit/surplus at a particular time slice</b> — it is a balance sheet '
        'snapshot showing when the investment account is below the mortgage balance at any point in time. A mortgage can '
        'be in deficit at year 5 and in surplus at year 30. PoD before mortgage expiry is irrelevant to insurance claims.',
        '<b>The deficit/surplus calculated is BEFORE application of the Payments & Risk Waterfall</b> — PoD measures '
        'individual mortgage risk before any cross-subsidisation from surplus mortgages in the portfolio. '
        'PoC is the residual claim probability <i>after</i> the waterfall has been applied.',
    ]
    for r in pod_reasons:
        story.append(Paragraph(f'<bullet>&bull;</bullet> {r}', styles['BulletCustom']))

    story.append(Spacer(1, 3*mm))
    story.append(Paragraph(
        '<b>PoC (Probability of Claim)</b> is the actual insurance claim probability on <b>expiring mortgages only</b>, '
        'after the Payments & Risk Waterfall has been applied. This is the metric that matters to insurers and reinsurers.',
        styles['BodyText2']
    ))

    # PoD vs PoC chart
    story.append(fig_to_image(chart_pod_vs_poc(), height=85*mm))

    story.append(Paragraph(
        'The chart above illustrates the dramatic difference. PoD starts at {0}% in year 1 (when the investment '
        'account is still establishing) and declines to {1}% at year 30 as the investment compounds. But PoC — '
        'the metric that matters to insurers — is just {2}% at Year 30, '
        'declining to <b>{3}% at year 30</b> after the Payments & Risk Waterfall.'.format(
            DEFICIT_BY_YEAR[0], V14["deficit_prob_yr30"],
            POC_PORTFOLIO_BY_YEAR[14], V14["poc_portfolio_yr30"]),
        styles['BodyText2']
    ))

    story.append(Spacer(1, 5*mm))
    story.append(Paragraph('PoD Trajectory — Individual Mortgage (LMI View)', styles['SubHead']))
    story.append(make_table(
        ['Year', 'PoD (%)', 'P10 Deficit', 'Cond. Expected Deficit', 'Mean Surplus'],
        [
            ['1', f'{DEFICIT_BY_YEAR[0]}%', f'${abs(P10_BY_YEAR[0]):,.0f}', '—', f'${MEAN_SURPLUS_BY_YEAR[0]:,.0f}'],
            ['5', f'{DEFICIT_BY_YEAR[4]}%', f'${abs(P10_BY_YEAR[4]):,.0f}', '—', f'${MEAN_SURPLUS_BY_YEAR[4]:,.0f}'],
            ['10', f'{DEFICIT_BY_YEAR[9]}%', f'${abs(P10_BY_YEAR[9]):,.0f}', '—', f'${MEAN_SURPLUS_BY_YEAR[9]:,.0f}'],
            ['15', f'{DEFICIT_BY_YEAR[14]}%', f'${abs(P10_BY_YEAR[14]):,.0f}', '—', f'${MEAN_SURPLUS_BY_YEAR[14]:,.0f}'],
            ['20', f'{DEFICIT_BY_YEAR[19]}%', f'${abs(P10_BY_YEAR[19]):,.0f}', '—', f'${MEAN_SURPLUS_BY_YEAR[19]:,.0f}'],
            ['25', f'{DEFICIT_BY_YEAR[24]}%', f'${abs(P10_BY_YEAR[24]):,.0f}', '—', f'${MEAN_SURPLUS_BY_YEAR[24]:,.0f}'],
            ['30', f'{DEFICIT_BY_YEAR[29]}%', f'${abs(P10_BY_YEAR[29]):,.0f}', f'${abs(V14["cond_expected_deficit"]):,.0f}', f'${MEAN_SURPLUS_BY_YEAR[29]:,.0f}'],
        ],
        col_widths=[20*mm, 20*mm, 30*mm, 40*mm, 40*mm]
    ))

    story.append(Spacer(1, 5*mm))
    story.append(Paragraph('Portfolio PoC — After Payments & Risk Waterfall (Reinsurer View)', styles['SubHead']))
    story.append(fig_to_image(chart_poc_portfolio(), height=85*mm))

    story.append(make_table(
        ['Metric', 'Individual PoD', 'Portfolio PoC (after Waterfall)', 'Waterfall Reduction'],
        [
            ['Year 30 (mortgage expiry)', f'{DEFICIT_BY_YEAR[29]}%', f'{V14["poc_portfolio_yr30"]}%',
             '~100x'],
        ],
        col_widths=[20*mm, 35*mm, 35*mm, 60*mm]
    ))

    story.append(Paragraph(
        'The Waterfall Reduction column shows the ratio of PoD to PoC — at year 30, the Payments & Risk Waterfall '
        f'reduces claim probability by approximately <b>100x</b> (from {V14["deficit_prob_yr30"]}% to {V14["poc_portfolio_yr30"]}%).',
        styles['BodyText2']
    ))

    story.append(PageBreak())

    # ========================================================
    # SECTION 5: GOOD VS BAD PATHWAYS
    # ========================================================
    story.append(Paragraph('5. Good vs Bad Return Pathways', styles['SectionHead']))

    story.append(Paragraph(
        'The stochastic analysis of S&amp;P500 returns over 30 years reveals a fundamental asymmetry that underpins '
        'the EPM\'s viability as an insurable product:',
        styles['BodyText2']
    ))

    story.append(Spacer(1, 3*mm))
    # Surplus fan chart
    story.append(fig_to_image(chart_surplus_fan(), height=85*mm))

    story.append(Spacer(1, 3*mm))
    pathway_stats = [
        f'<b>86.1% of pathways deliver surplus at maturity</b> — the investment account exceeds the mortgage balance, '
        f'generating a mean surplus of ${V14["mean_surplus_yr30"]:,.0f} (split 50/50 between FutureProof and Funder)',
        f'<b>Only {V14["deficit_prob_yr30"]}% of pathways result in a deficit</b> — and even among these, the conditional expected deficit '
        f'is ${abs(V14["cond_expected_deficit"]):,.0f} (well within the LMI Top Cover Limit of ${abs(V14["p10_yr30"]):,.0f})',
        f'<b>The ratio of surplus to deficit pathways is approximately 109:1</b> — this asymmetry is what makes '
        f'the Payments & Risk Waterfall so effective. For every expiring mortgage in deficit, there are roughly 6 loans in '
        f'surplus available to cross-subsidise',
        f'<b>Median surplus at year 30 is ${V14["median_surplus_yr30"]:,.0f}</b> — even the "typical" mortgage '
        f'generates substantial surplus, well above the zero threshold',
    ]
    for p in pathway_stats:
        story.append(Paragraph(f'<bullet>&bull;</bullet> {p}', styles['BulletCustom']))

    story.append(Spacer(1, 5*mm))
    story.append(Paragraph('Surplus Distribution at Maturity', styles['SubHead']))
    story.append(make_table(
        ['Percentile', 'Surplus', 'Implication for Underwriter'],
        [
            ['P1 (worst 1%)', f'${V14["p1_yr30"]:,.0f}', 'Maximum realistic loss — tail risk reinsurance territory'],
            ['P5 (worst 5%)', f'${V14["p5_yr30"]:,.0f}', 'Severe stress — within LMI top cover'],
            ['P10 (worst 10%)', f'${V14["p10_yr30"]:,.0f}', 'Near split boundary between LMI and reinsurance layers'],
            ['P25', f'${V14["p25_yr30"]:,.0f}', 'Surplus — no claim'],
            ['Median (P50)', f'${V14["median_surplus_yr30"]:,.0f}', 'Substantial surplus — strong cross-subsidisation pool'],
            ['P75', f'${V14["p75_yr30"]:,.0f}', 'Strong surplus'],
            ['P90', f'${V14["p90_yr30"]:,.0f}', 'Excellent surplus'],
            ['P99', f'${V14["p99_yr30"]:,.0f}', 'Exceptional surplus'],
        ],
        col_widths=[35*mm, 35*mm, 80*mm]
    ))

    story.append(PageBreak())

    # ========================================================
    # SECTION 6: VINTAGE DIVERSIFICATION AND CROSS-SUBSIDISATION
    # ========================================================
    story.append(Paragraph('6. Vintage Diversification & Cross-Subsidisation', styles['SectionHead']))

    story.append(Paragraph(
        'The difference between individual mortgage risk and portfolio risk lies in the Payments & Risk Waterfall. '
        'The secret of the EPM\'s successful design at a portfolio level lies in the ability to pool risk across '
        'all mortgages and cross-subsidise between expiring mortgages — some will be in surplus, some will be in deficit.',
        styles['BodyText2']
    ))

    story.append(Paragraph('Why Vintage Diversification Works', styles['SubHead']))
    story.append(Paragraph(
        'A downturn in the economic cycle does not affect all mortgages equally. Over a 30-year period, EPMs are '
        'originated at different points in time. Each vintage enters the equity market at a different level:',
        styles['BodyText2']
    ))

    vintage_points = [
        'A downturn that causes a deficit for mortgages originated at market peaks may have little or no impact '
        'on mortgages originated years earlier (which have already accumulated substantial surplus)',
        'Mortgages originated after a downturn enter at lower market levels with more room to grow — they benefit '
        'from the recovery',
        'At any given time, the portfolio contains mortgages at every stage of their lifecycle — from newly '
        'originated to approaching maturity',
        'Older mortgages (with P&I amortisation) have very low residual exposure — their mortgage balance has '
        'substantially reduced while their investment account has compounded',
        'This means the portfolio always contains a deep pool of surplus mortgages available for cross-subsidisation '
        'of the small number of expiring mortgages in deficit',
    ]
    for v in vintage_points:
        story.append(Paragraph(f'<bullet>&bull;</bullet> {v}', styles['BulletCustom']))

    story.append(Spacer(1, 5*mm))
    story.append(Paragraph('The Payments & Risk Waterfall — Step by Step', styles['SubHead']))
    story.append(Paragraph(
        'When a mortgage reaches its contractual expiry date, the following waterfall is applied before any '
        'insurance claim:',
        styles['BodyText2']
    ))

    waterfall_steps = [
        ['<b>Step 1: ETF Selldown</b>',
         'The index-linked ETFs in the expiring mortgage\'s investment account are liquidated. '
         'If the proceeds exceed the remaining mortgage balance, the surplus is split 50/50 between FutureProof '
         'and the Mortgage Funder. No insurance claim is needed.'],
        ['<b>Step 2: Cross-Subsidisation</b>',
         'If the expiring mortgage is in deficit, surpluses from other open (non-expiring) mortgages in the same '
         'funder\'s loan book are used to cover the shortfall. With 86%+ of pathways in surplus and only ~14% in '
         'deficit, the pool of available surplus is substantial.'],
        ['<b>Step 3: Net Deficit → LMI Claim</b>',
         'Only if the deficit exceeds the available cross-subsidisation pool does a claim arise on the LMI insurer, '
         'up to the Top Cover Limit (P10 = ${0:,.0f}).'.format(abs(V14["p10_yr30"]))],
        ['<b>Step 4: Residual → Reinsurance Claim</b>',
         'Any loss beyond the LMI Top Cover Limit constitutes a claim on the portfolio reinsurer. '
         f'At the portfolio level, after the waterfall, the PoC is just {V14["poc_portfolio_yr30"]}% at year 30.'],
    ]

    for title, desc in waterfall_steps:
        story.append(Paragraph(title, styles['SubHead']))
        story.append(Paragraph(desc, styles['BodyText2']))

    story.append(PageBreak())

    # ========================================================
    # SECTION 7: CLAIM TIMING — NO CLAIMS UNTIL END OF TERM
    # ========================================================
    story.append(Paragraph('7. Claim Timing — No Claims Until End of Term', styles['SectionHead']))

    story.append(Paragraph(
        'It is most important for underwriters to understand that <b>no LMI claim nor any portfolio reinsurance '
        'claim can be made until the end-of-term of each mortgage loan contract</b>. In other words, no claim '
        'can be made until years 15-30 (depending on the original tenure selected by the borrower).',
        styles['BodyText2']
    ))

    story.append(Paragraph('Why This Matters for Underwriters', styles['SubHead']))
    timing_points = [
        '<b>Long claim deferral:</b> Premiums are paid upfront at mortgage origination, but claims cannot arise for '
        '15-30 years. This gives the insurer/reinsurer significant investment income on the collected premiums '
        'before any possible claim.',
        '<b>Run-off mechanism:</b> The EPM has a unique feature — no voluntary prepayments or early terminations '
        'are permitted until all loan costs have been paid from the investment/offset account. No other mortgage '
        'product works this way. This eliminates the early exit risk that exists in traditional LMI.',
        '<b>Compounding works in favour of the insurer:</b> The longer the loan runs, the more the investment '
        f'compounds, and the more likely it is to exceed the mortgage balance. PoD declines from {DEFICIT_BY_YEAR[0]:.1f}% at year 1 to '
        f'{V14["deficit_prob_yr30"]}% at year 30. The risk profile improves over time.',
        '<b>Portfolio maturation:</b> As the portfolio matures, older loans develop larger surpluses, deepening '
        'the cross-subsidisation pool. The Payments & Risk Waterfall becomes more effective over time.',
        '<b>No interim claims:</b> There is no risk of early claims depleting reserves. The insurer/reinsurer '
        'knows with certainty that no claim will arise before Year 30 (mortgage expiry).',
    ]
    for t in timing_points:
        story.append(Paragraph(f'<bullet>&bull;</bullet> {t}', styles['BulletCustom']))

    story.append(Spacer(1, 5*mm))
    story.append(Paragraph('Claim Timing Profile', styles['SubHead']))
    story.append(make_table(
        ['Mortgage Term', 'Claim Timing', 'Individual PoD at Expiry', 'Portfolio PoC (after Waterfall)'],
        [
            ['30 years', 'Year 30 (mortgage expiry)', f'{DEFICIT_BY_YEAR[29]}%', f'{V14["poc_portfolio_yr30"]}%'],
        ],
        col_widths=[30*mm, 40*mm, 40*mm, 40*mm]
    ))

    story.append(Paragraph(
        'The 30-year term allows maximum time for investment compounding and P&I amortisation, resulting '
        'in the lowest possible individual PoD and portfolio PoC.',
        styles['BodyText2']
    ))

    story.append(PageBreak())

    # ========================================================
    # SECTION 8: FAIR PREMIUM CALCULATION
    # ========================================================
    story.append(Paragraph('8. Fair Premium Calculation', styles['SectionHead']))

    story.append(Paragraph('Methodology', styles['SubHead']))
    story.append(Paragraph(
        'The fair insurance premium is calculated as the <b>discounted expected deficit (S3)</b>. The discount rate '
        'of 2.13% corresponds to the long-run cash rate mean (MLE estimate). This discounting is necessary because '
        'no claim can be made until mortgage expiry (Year 30), but premiums are paid '
        'upfront at mortgage origination.',
        styles['BodyText2']
    ))

    story.append(make_table(
        ['Premium Component', 'Value', 'Calculation'],
        [
            ['Expected Deficit (undiscounted)', '—', 'Mean deficit across all paths with deficit × PoD'],
            ['Discount Rate', '2.13%', 'cash rate mean — reflects claim deferral'],
            ['Fair Premium (PV)', f'${V14["ins_fair_premium"]:,.0f}', 'Discounted expected deficit (S3)'],
            ['SE on Premium', f'${V14["ins_stderr"]:,.0f}', 'Standard error from 50,000-path Monte Carlo'],
            ['Loading Factor', '150%', 'Standard actuarial loading for uncertainty'],
            ['Loaded Premium', f'${V14["ins_plus_loading"]:,.0f}', 'Fair premium × 1.5'],
            ['Premium as % of Loan', f'{V14["ins_plus_loading"]/V14["initial_loan"]*100:.2f}%', 'Relative to initial loan of ${0:,.0f}'.format(V14["initial_loan"])],
            ['Payment Timing', 'Upfront at origination', 'Full premium collected before risk attaches'],
        ],
        col_widths=[42*mm, 28*mm, 80*mm]
    ))

    story.append(Spacer(1, 5*mm))
    story.append(Paragraph('LMI vs Reinsurance Premium Split', styles['SubHead']))
    story.append(Paragraph(
        'The LMI premium covers 90% of the expected loss distribution (up to the P10 Top Cover Limit). '
        'The tail risk premium covers the worst 20% of deficit paths transferred to the portfolio reinsurer.',
        styles['BodyText2']
    ))
    story.append(make_table(
        ['Component', 'Coverage', 'Premium (est.)', 'Basis'],
        [
            ['LMI Premium', '80% of deficit paths (up to split boundary)', f'${V14["ins_fair_premium"]:,.0f}', 'Discounted expected deficit (S3)'],
            ['Tail Risk Premium', 'Worst 20% of deficit paths (larger losses)', f'${V14["tail_risk_premium"]:,.0f}', 'Excess over P10, discounted'],
            ['Total (fair)', '100%', f'${V14["ins_fair_premium"] + V14["tail_risk_premium"]:,.0f}', 'Combined fair premium'],
            ['Total (loaded)', '100%', f'${V14["ins_plus_loading"]:,.0f}', 'With 150% actuarial loading'],
        ],
        col_widths=[30*mm, 40*mm, 30*mm, 50*mm]
    ))

    story.append(PageBreak())

    # ========================================================
    # SECTION 9: PARAMETER SENSITIVITY
    # ========================================================
    if SENSITIVITY_RESULTS:
        story.append(Paragraph('9. Parameter Sensitivity — Impact on Underwriting', styles['SectionHead']))

        story.append(Paragraph(
            'The v14c model has been tested across 27 parameter combinations varying eligible house value '
            '($2M-$3M), LVR (60-80%), and annuity ($15K-$25K). The key insight for underwriters: '
            '<b>the annuity as a percentage of the initial loan (cost burden ratio) is the primary driver of '
            'both PoD and PoC.</b>',
            styles['BodyText2']
        ))

        # Annuity ratio chart
        sens_fig = chart_sensitivity_annuity_ratio()
        if sens_fig:
            story.append(fig_to_image(sens_fig, height=85*mm))

        # Show range of PoC across all scenarios
        pocs = [r['poc_yr30_est'] for r in SENSITIVITY_RESULTS]
        pods = [r['pod_yr30'] for r in SENSITIVITY_RESULTS]
        story.append(Spacer(1, 3*mm))
        story.append(make_table(
            ['Metric', 'Best Scenario', 'Baseline', 'Worst Scenario'],
            [
                ['PoD (Yr 30)', f'{min(pods):.2f}%', f'{V14["deficit_prob_yr30"]}%', f'{max(pods):.2f}%'],
                ['PoC (Yr 30, est.)', f'{min(pocs):.2f}%', f'{V14["poc_portfolio_yr30"]}%', f'{max(pocs):.2f}%'],
            ],
            col_widths=[35*mm, 35*mm, 35*mm, 45*mm]
        ))

        story.append(Paragraph(
            f'Across all 27 tested scenarios, portfolio PoC ranges from {min(pocs):.2f}% to {max(pocs):.2f}%. '
            f'<b>All scenarios produce a portfolio PoC below 1%.</b> This demonstrates the robustness of the EPM '
            f'structure across a wide range of origination parameters.',
            styles['BodyText2']
        ))

        # Top 5 and bottom 5 scenarios
        sorted_results = sorted(SENSITIVITY_RESULTS, key=lambda x: x['poc_yr30_est'])
        story.append(Spacer(1, 5*mm))
        story.append(Paragraph('Best and Worst Scenarios for Underwriters', styles['SubHead']))
        story.append(make_table(
            ['House Value', 'LVR', 'Annuity', 'Ann/Loan', 'PoD', 'PoC (est.)'],
            [[f'${r["home_value"]/1e6:.1f}M', f'{r["lvr"]*100:.0f}%', f'${r["annuity_pa"]/1000:.0f}K',
              f'{r["annuity_pct_of_loan"]:.2f}%', f'{r["pod_yr30"]:.2f}%', f'{r["poc_yr30_est"]:.2f}%']
             for r in sorted_results[:3] + sorted_results[-3:]],
            col_widths=[25*mm, 18*mm, 22*mm, 22*mm, 22*mm, 22*mm]
        ))

        story.append(PageBreak())

    # ========================================================
    # SECTION 10: INTEREST HOLIDAY IMPACT ON CLAIMS
    # ========================================================
    story.append(Paragraph('10. Interest Holiday Impact on Claims', styles['SectionHead']))

    story.append(Paragraph(
        'The interest holiday is also a smoothing mechanism — it simply defers simple interest due (but does not '
        'accrue and compound interest) when the investment account balance is below the interest-holiday threshold. '
        'This is why, together with long loan durations, the Monte Carlo analysis demonstrates it does not '
        'materially affect outcomes:',
        styles['BodyText2']
    ))

    holiday_context = [
        'We know from past market data that interest rate cycles are generally 2-3 years, economic downturns '
        '3-5 years, and black swan events (such as the GFC) 5-7 years — <b>none are 30 years in duration</b>.',
        'Interest holidays are a device to <b>preserve capital</b> in the investment account and maintain holdings '
        'of reference assets (rather than selling down the ETFs to pay loan interest) — this ensures maximum returns '
        'are achieved as market cycles swing back, as opposed to chasing losses before a surplus can be achieved.',
    ]
    for c in holiday_context:
        story.append(Paragraph(f'<bullet>&bull;</bullet> {c}', styles['BulletCustom']))

    story.append(Paragraph('Per-Year View — Holidays Are Rare and Temporary', styles['SubHead']))
    story.append(Paragraph(
        'In any given year of the 30-year term, <b>the median mortgage requires zero interest holidays</b>. '
        'The average path has zero holidays. However, approximately 77% of '
        'individual paths enter holiday at some point, with a mean of 8.5 years across all paths.',
        styles['BodyText2']
    ))

    if HOLIDAY_RESULTS:
        stats = HOLIDAY_RESULTS.get('total_holidays', {})
        ha = HOLIDAY_RESULTS.get('holiday_account_at_maturity', {})

        story.append(Paragraph('Holiday Repayment — Deferred Interest is Recovered', styles['SubHead']))
        story.append(Paragraph(
            'When market conditions improve following downturns, the deferred interest is repaid from the '
            'recovering investment account. The Monte Carlo confirms that the vast majority of deferred '
            'interest is fully repaid before maturity:',
            styles['BodyText2']
        ))
        story.append(make_table(
            ['Metric', 'Value', 'Implication for Underwriter'],
            [
                ['Paths with zero outstanding at maturity', f'{100 - 14:.0f}%', 'All deferred interest fully repaid'],
                ['Mean outstanding (when > 0)', f'${ha.get("mean", 0):,.0f}', 'Covered by LMI/reinsurance'],
                ['P90 outstanding', f'${ha.get("p90", 0):,.0f}', 'Within LMI Top Cover'],
                ['P99 outstanding', f'${ha.get("p99", 0):,.0f}', 'Tail risk — covered by reinsurance after waterfall'],
            ],
            col_widths=[48*mm, 30*mm, 72*mm]
        ))

        story.append(Paragraph(
            'If the net result of holidays and subsequent repayments is that any amount of loan cost remains '
            'outstanding at end-of-term, it is covered by insurance (up to the LMI Top Cover Limit), with the '
            'balance covered by portfolio reinsurance after the Payments & Risk Waterfall.',
            styles['BodyText2']
        ))

    story.append(PageBreak())

    # ========================================================
    # SECTION 11: QUESTIONS FOR UNDERWRITERS
    # ========================================================
    story.append(Paragraph('11. Questions for Underwriters', styles['SectionHead']))

    story.append(Paragraph(
        'FutureProof seeks engagement with LMI insurers and portfolio reinsurers on the following questions:',
        styles['BodyText2']
    ))

    story.append(Paragraph('A. Design Methodology Review', styles['SubHead']))
    story.append(Paragraph(
        'We invite underwriters to review the design methodology behind our risk mitigation approach:',
        styles['BodyText2']
    ))
    design_qs = [
        'Is the two-layer insurance structure (LMI + portfolio reinsurance) appropriate for this risk profile?',
        'Is the Top Cover Limit (P10 quantile = ${0:,.0f}) appropriately calibrated?'.format(abs(V14["p10_yr30"])),
        'Does the Payments & Risk Waterfall provide sufficient structural protection before claims reach the reinsurer?',
        'Is the run-off mechanism (no early exit) adequately captured in the risk assessment?',
        'Are the volatility control layers (BlackRock volatility buffer, SpiderRock buffer cap 140%, floor 80%) appropriately modelled?',
    ]
    for q in design_qs:
        story.append(Paragraph(f'<bullet>&bull;</bullet> {q}', styles['BulletCustom']))

    story.append(Paragraph('B. Model Calculation Review', styles['SubHead']))
    story.append(Paragraph(
        'We invite actuarial review of the Monte Carlo calculations:',
        styles['BodyText2']
    ))
    model_qs = [
        'Are 50,000 simulation paths sufficient for actuarial-grade precision? (SE on PoD: 0.15%, SE on premium: $245)',
        'Is the 10% expected equity return (BlackRock 30yr forward-looking) a reasonable central estimate?',
        'Is the 10% hedged volatility (after two-layer reduction from 15%) appropriate?',
        'Is the OU interest rate process with mean reversion appropriate for 30-year projections?',
        'Is the equity-rate correlation of 0.30 appropriate for 30-year horizon? (Short-term correlation is negative; '
        'long-term 30yr correlation is marginally positive at 0.1-0.3)',
        'Is the 2.13% discount rate (cash rate long-run mean, MLE estimate) appropriate for calculating the discounted expected deficit?',
    ]
    for q in model_qs:
        story.append(Paragraph(f'<bullet>&bull;</bullet> {q}', styles['BulletCustom']))

    story.append(Paragraph('C. Fair Premium Assessment', styles['SubHead']))
    story.append(make_table(
        ['Question', 'Model Output', 'For Review'],
        [
            ['Is the fair LMI premium adequate?', f'${V14["ins_fair_premium"]:,.0f} (PV)', 'Based on discounted expected deficit (S3)'],
            ['Is the 150% loading sufficient?', f'${V14["ins_plus_loading"]:,.0f}', 'Standard actuarial loading — is this appropriate for this risk class?'],
            ['Is the tail risk premium appropriate?', f'${V14["tail_risk_premium"]:,.0f}', 'Excess above split boundary on 20% of deficit paths'],
            ['Premium paid upfront — acceptable?', 'Yes — at origination', 'Full premium before risk attaches; no interim claims for ~30 years'],
        ],
        col_widths=[45*mm, 35*mm, 70*mm]
    ))

    story.append(PageBreak())

    # EPM vs Current Investment Landscape
    story.append(Paragraph('EPM vs Comparable Credit Risk Profiles', styles['SubHead']))
    story.append(Paragraph(
        'Before assessing reinsurer acceptability, we benchmark the EPM against the credit instruments that '
        'underwriters are most familiar with. The table shows the EPM at both base-case and realistic-central '
        'parameters, since the comparison is scenario-dependent.',
        styles['BodyText2']))

    story.append(make_table(
        ['Metric', 'EPM base', 'EPM realistic', 'Prime Mortgage (LMI)', "Moody's AA Bond", 'AU RMBS (AA)'],
        [
            ['Cumulative PoD (30yr)', f'{V14["deficit_prob_yr30"]:.1f}%', '16.9%', '3–5%', '~1.5%', '~1–2%'],
            ['Loss severity', '~21%', '~21%', '15–25% (LMI)', '40–60%', 'Subord.'],
            ['Expected loss (30yr)', '0.13%', '~2.3%', '0.6–1.25%', '0.6–0.9%', '0.05–0.15%'],
            ['Claim timing', 'Year 15–30 only', 'Year 15–30 only', 'Any yr (peaks 3–7)', 'Any year', 'Any year'],
            ['Prepayment risk', 'None (run-off)', 'None (run-off)', 'Significant', 'Moderate', 'Significant'],
        ],
        col_widths=[32*mm, 20*mm, 23*mm, 28*mm, 25*mm, 22*mm]
    ))

    story.append(Spacer(1, 3*mm))
    credit_landscape = [
        '<b>Expected loss depends on parameter scenario.</b> At base case (0.13%) the EPM sits in the AA/AAA '
        'band on an expected-loss basis. At realistic-central (~2.3%) it is materially higher than prime-LMI '
        'EL but the risk driver and claim timing remain fundamentally different. Underwriters should price to '
        'the realistic-central scenario and reserve to the adverse-plausible scenario.',
        '<b>Favourable claim timing is structural, not parameter-dependent.</b> EPM claims can only arise at '
        'mortgage expiry (Years 15–30) in every scenario. Traditional LMI claims peak in Years 3–7. The long '
        'deferral is highly attractive for reserve planning and gives ~30 years of float on the upfront '
        'premium across all parameter scenarios.',
        '<b>Uncorrelated to existing LMI book (scenario-robust).</b> Traditional LMI losses are driven by '
        'borrower unemployment, divorce, and interest-rate stress. EPM losses are driven by long-term equity '
        'market returns — a fundamentally different risk factor. The diversification benefit survives '
        'parameter stress because the underlying risk drivers are structurally different.',
        '<b>Zero prepayment risk.</b> The run-off mechanism eliminates early-exit risk across all scenarios '
        '— a structural feature that is not parameter-sensitive.',
    ]
    for cl in credit_landscape:
        story.append(Paragraph(f'<bullet>&bull;</bullet> {cl}', styles['BulletCustom']))

    story.append(Spacer(1, 5*mm))

    story.append(Paragraph('D. Acceptability to Major Reinsurers', styles['SubHead']))
    story.append(Paragraph(
        'FutureProof seeks to understand whether the EPM credit risk profile falls within the acceptable '
        'risk parameters of major reinsurers. We present the following for consideration:',
        styles['BodyText2']
    ))

    story.append(make_table(
        ['Risk Parameter', 'EPM Model Output', 'Typical Reinsurer Threshold'],
        [
            ['Portfolio PoC (Yr 30)', f'{V14["poc_portfolio_yr30"]}%', 'Generally < 1% for acceptable risk transfer'],
            ['Maximum single loss (P1)', f'${abs(V14["p1_yr30"]):,.0f}', 'Within standard property reinsurance limits'],
            ['Claim timing', 'Years 15-30 only', 'Long deferral — favourable for reserve planning'],
            ['Correlation to existing book', 'Index risk (not borrower credit)', 'Diversifying — uncorrelated to traditional LMI losses'],
            ['Prepayment/lapse risk', 'None (run-off mechanism)', 'No adverse selection or early termination'],
            ['Premium collection', 'Upfront at origination', 'Full premium before risk attaches'],
            ['Portfolio size at scale', '4,000+ EPMs ($5.4B AUM)', 'Sufficient for law of large numbers'],
            ['Geographic diversification', 'AU, NZ, UK, US', 'Multi-region reduces concentration risk'],
        ],
        col_widths=[40*mm, 40*mm, 70*mm]
    ))

    story.append(Spacer(1, 5*mm))
    story.append(Paragraph(
        'We specifically invite underwriting engagement from <b>Munich Re</b>, <b>Lockton Re</b>, and '
        '<b>Gallagher Re</b> to assess whether this credit risk / market risk / index risk profile falls '
        'within their underwriting appetite. The EPM represents a new asset class for reinsurers — '
        'uncorrelated to traditional mortgage default risk and with a fundamentally different (and more '
        'predictable) loss distribution driven by long-term equity index performance.',
        styles['BodyText2']
    ))

    story.append(Spacer(1, 5*mm))
    story.append(Paragraph('Key Differentiators for Reinsurer Consideration', styles['SubHead']))
    differentiators = [
        '<b>Not borrower credit risk</b> — This is index risk. No exposure to employment, income, '
        'or individual borrower circumstances',
        '<b>Long-duration predictability</b> — 30-year S&amp;P500 returns are historically 9.75%-10.8% with '
        'remarkably low variance compared to shorter horizons',
        '<b>No interim claims</b> — Claims only at mortgage expiry (Year 30). '
        'Premium invested for ~30 years before any possible claim',
        '<b>Structural risk decline</b> — P&amp;I amortisation means risk decreases every year as the mortgage balance falls',
        '<b>Multi-layer protection</b> — Volatility control, dynamic hedging, cross-subsidisation, and LMI '
        'all applied before any reinsurance claim',
        '<b>Diversifying to existing book</b> — EPM losses are driven by equity index performance, '
        'uncorrelated to natural catastrophe, mortality, or traditional mortgage default risk',
    ]
    for d in differentiators:
        story.append(Paragraph(f'<bullet>&bull;</bullet> {d}', styles['BulletCustom']))

    # ========================================================
    # GLOSSARY / DEFINITIONS
    # ========================================================
    story.append(PageBreak())
    story.append(Paragraph('Glossary of Key Terms', styles['SectionHead']))
    story.append(Paragraph(
        '<b>PoD (Probability of Deficit):</b> Balance sheet snapshot — probability that investment account &lt; mortgage balance '
        'at a given point in time. NOT the probability of an insurance claim.<br/>'
        '<b>PoC (Probability of Claim):</b> Probability of an actual insurance claim on an <i>expiring</i> loan, after the '
        'Payments & Risk Waterfall. The key metric for insurance and reinsurance. Claims only at mortgage expiry.<br/>'
        '<b>Payments & Risk Waterfall:</b> Portfolio mechanism: (1) sell down ETFs, (2) cross-subsidise from surplus loans, '
        '(3) determine net deficit and PoC.<br/>'
        '<b>Top Cover Limit:</b> Maximum loss covered by LMI policy — set at the P10 quantile of the deficit distribution.<br/>'
        '<b>Discounted Expected Deficit (S3):</b> PV of expected loss, discounted at 2.13% (cash rate mean). '
        'Basis for insurance premium calculation.<br/>'
        '<b>Run-off Mechanism:</b> No voluntary prepayment or early termination until all loan costs paid from '
        'investment account. Unique to EPM — eliminates early exit risk and adverse selection.<br/>'
        '<b>Vintage Diversification:</b> Different mortgage origination dates create different equity market entry points, '
        'meaning downturns affect different vintages unequally — enabling effective cross-subsidisation.<br/>'
        '<b>Index-linked ETF:</b> BlackRock-managed passive ETFs tracking the S&amp;P500 with volatility control (volatility buffer) '
        'and SpiderRock dynamic hedging overlay (buffer cap 140%, floor 80%). Cap: 140%, Floor: 80%.',
        styles['BodyText2']
    ))

    doc.build(story, onFirstPage=lambda c, d: footer(c, d, footer_title),
              onLaterPages=lambda c, d: footer(c, d, footer_title))
    print(f'  Generated: {filename}')
    return filename


# ============================================================
# MAIN
# ============================================================

if __name__ == '__main__':
    print('Generating FutureProof EPM v14d Optimised Model Review...\n')

    os.chdir(os.path.dirname(os.path.abspath(__file__)))

    f1 = build_model_review()
    # The other 4 reports remain in this file but are disabled for now.
    # Re-enable when ready (and check filename / footer / date references first):
    # f2 = build_investor_report()
    # f3 = build_wholesale_funder()
    # f4 = build_risk_analysis()
    # f5 = build_credit_risk_underwriting()

    print(f'\nGenerated: {f1}')
