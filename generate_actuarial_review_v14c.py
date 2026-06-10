#!/usr/bin/env python3
"""
Generate FutureProof EPM v14c (003) — Independent Actuarial Review
Comprehensive stress testing and sensitivity analysis
Based on 50,000-path Monte Carlo with GBM+MeanRev equity model
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
# COLOUR PALETTE
# ============================================================
DARK_NAVY = HexColor('#2C3E50')
TEAL = HexColor('#3498A8')
CORAL = HexColor('#C0392B')
LIGHT_GREY = HexColor('#F5F5F5')
MID_GREY = HexColor('#95A5A6')
WHITE = colors.white
HEADER_BG = HexColor('#2C3E50')
ROW_ALT = HexColor('#F8F9FA')
GREEN = HexColor('#27AE60')
AMBER = HexColor('#F39C12')
RED = HexColor('#E74C3C')

# ============================================================
# LOAD DATA
# ============================================================
_dir = os.path.dirname(os.path.abspath(__file__))
with open(os.path.join(_dir, 'monte_carlo_v14c_003_results.json')) as f:
    MC = json.load(f)
with open(os.path.join(_dir, 'monte_carlo_v14c_003_comprehensive_results.json')) as f:
    COMP = json.load(f)

BASE = COMP['base_case']
SENS = COMP['sensitivity']
CORR = COMP['correlation_stress']
RATE = COMP['rate_stress']
COMB = COMP['combined_stress']

# ============================================================
# STYLES
# ============================================================
def get_styles():
    styles = getSampleStyleSheet()
    styles.add(ParagraphStyle('ReportTitle', parent=styles['Title'],
        fontSize=24, textColor=DARK_NAVY, spaceAfter=6*mm,
        alignment=TA_CENTER, fontName='Helvetica-Bold'))
    styles.add(ParagraphStyle('ReportSubtitle', parent=styles['Normal'],
        fontSize=13, textColor=TEAL, spaceAfter=4*mm,
        alignment=TA_CENTER, fontName='Helvetica'))
    styles.add(ParagraphStyle('Confidential', parent=styles['Normal'],
        fontSize=11, textColor=CORAL, spaceAfter=8*mm,
        alignment=TA_CENTER, fontName='Helvetica-Oblique'))
    styles.add(ParagraphStyle('SectionHead', parent=styles['Heading1'],
        fontSize=18, textColor=DARK_NAVY, spaceBefore=8*mm,
        spaceAfter=4*mm, fontName='Helvetica-Bold'))
    styles.add(ParagraphStyle('SubHead', parent=styles['Heading2'],
        fontSize=14, textColor=TEAL, spaceBefore=5*mm,
        spaceAfter=3*mm, fontName='Helvetica-Bold'))
    styles.add(ParagraphStyle('SubHead3', parent=styles['Heading3'],
        fontSize=12, textColor=DARK_NAVY, spaceBefore=4*mm,
        spaceAfter=2*mm, fontName='Helvetica-Bold'))
    styles.add(ParagraphStyle('BodyText2', parent=styles['Normal'],
        fontSize=10, textColor=DARK_NAVY, spaceAfter=3*mm,
        alignment=TA_JUSTIFY, fontName='Helvetica', leading=14))
    styles.add(ParagraphStyle('BulletCustom', parent=styles['Normal'],
        fontSize=10, textColor=DARK_NAVY, spaceAfter=2*mm,
        fontName='Helvetica', leading=13, leftIndent=15,
        bulletIndent=5))
    styles.add(ParagraphStyle('SmallNote', parent=styles['Normal'],
        fontSize=8, textColor=MID_GREY, spaceAfter=2*mm,
        fontName='Helvetica-Oblique'))
    styles.add(ParagraphStyle('KeyFinding', parent=styles['Normal'],
        fontSize=11, textColor=DARK_NAVY, spaceAfter=3*mm,
        fontName='Helvetica-Bold', leading=15, leftIndent=10,
        borderColor=TEAL, borderWidth=1, borderPadding=5))
    return styles


def make_table(headers, rows, col_widths=None):
    hdr_style = ParagraphStyle('_h', fontName='Helvetica-Bold', fontSize=9,
                                textColor=WHITE, leading=11, alignment=TA_CENTER)
    hdr_left = ParagraphStyle('_hl', fontName='Helvetica-Bold', fontSize=9,
                               textColor=WHITE, leading=11, alignment=TA_LEFT)
    cell_style = ParagraphStyle('_c', fontName='Helvetica', fontSize=9,
                                 textColor=DARK_NAVY, leading=11, alignment=TA_CENTER)
    cell_left = ParagraphStyle('_cl', fontName='Helvetica', fontSize=9,
                                textColor=DARK_NAVY, leading=11, alignment=TA_LEFT)

    wh = [Paragraph(str(h), hdr_left if i == 0 else hdr_style) for i, h in enumerate(headers)]
    wr = []
    for row in rows:
        wr.append([Paragraph(str(c), cell_left if i == 0 else cell_style) for i, c in enumerate(row)])

    data = [wh] + wr
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


def footer(canvas, doc):
    canvas.saveState()
    canvas.setFont('Helvetica', 8)
    canvas.setFillColor(MID_GREY)
    canvas.drawString(25*mm, 12*mm, 'FutureProof | Independent Actuarial Review | April 2025')
    canvas.drawRightString(A4[0] - 25*mm, 12*mm, f'Page {doc.page}')
    canvas.restoreState()


# ============================================================
# CHARTS
# ============================================================

def chart_sensitivity_heatmap():
    returns = [0.070, 0.075, 0.080, 0.085, 0.090, 0.092, 0.100, 0.110]
    vols = [0.120, 0.150, 0.166, 0.200, 0.250]
    grid = np.zeros((len(returns), len(vols)))
    for i, ret in enumerate(returns):
        for j, vol in enumerate(vols):
            key = f"ret_{ret:.3f}_vol_{vol:.3f}"
            grid[i, j] = SENS[key]['poc']

    fig, ax = plt.subplots(figsize=(9, 5.5))
    im = ax.imshow(grid, cmap='RdYlGn_r', aspect='auto', vmin=0, vmax=70)
    ax.set_xticks(range(len(vols)))
    ax.set_xticklabels([f'{v*100:.1f}%' for v in vols])
    ax.set_yticks(range(len(returns)))
    ax.set_yticklabels([f'{r*100:.1f}%' for r in returns])
    ax.set_xlabel('Equity Volatility', fontsize=11)
    ax.set_ylabel('Equity Return', fontsize=11)
    ax.set_title('PoD at Year 30 (%) — Sensitivity to Return & Volatility', fontsize=13,
                 fontweight='bold', color='#2C3E50')

    for i in range(len(returns)):
        for j in range(len(vols)):
            val = grid[i, j]
            color = 'white' if val > 35 else 'black'
            ax.text(j, i, f'{val:.1f}', ha='center', va='center', fontsize=9,
                    fontweight='bold', color=color)

    plt.colorbar(im, ax=ax, label='PoD (%)')
    fig.tight_layout()
    return fig


def chart_deficit_trajectory():
    fig, ax = plt.subplots(figsize=(8, 4.5))
    # Base case from MC results
    sp = MC['surplus_percentiles_by_year']
    years = list(range(1, 31))
    deficit_pcts = [sp[str(y)]['deficit_pct'] for y in years]

    ax.plot(years, deficit_pcts, color='#2C3E50', linewidth=2.5, label='v14c (003) — GBM+MeanRev')
    ax.axhline(y=5, color='#C0392B', linestyle=':', alpha=0.7, label='5% target')
    ax.set_xlabel('Year', fontsize=11)
    ax.set_ylabel('Deficit Probability (%)', fontsize=11)
    ax.set_title('Deficit Probability Over Time — v14c (003)', fontsize=13,
                 fontweight='bold', color='#2C3E50')
    ax.legend(fontsize=9)
    ax.set_xlim(1, 30)
    ax.set_ylim(0, 60)
    ax.grid(True, alpha=0.3)
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    return fig


def chart_surplus_fan():
    fig, ax = plt.subplots(figsize=(8, 4.5))
    sp = MC['surplus_percentiles_by_year']
    years = list(range(1, 31))
    p1 = [sp[str(y)]['p1']/1e6 for y in years]
    p10 = [sp[str(y)]['p10']/1e6 for y in years]
    median = [sp[str(y)]['median']/1e6 for y in years]
    p90 = [sp[str(y)]['p90']/1e6 for y in years]
    p99 = [sp[str(y)]['p99']/1e6 for y in years]

    ax.fill_between(years, p1, p99, alpha=0.15, color='#2C3E50', label='1st-99th percentile')
    ax.fill_between(years, p10, p90, alpha=0.3, color='#3498A8', label='10th-90th percentile')
    ax.plot(years, median, color='#2C3E50', linewidth=2.5, label='Median')
    ax.axhline(y=0, color='#C0392B', linestyle='--', alpha=0.7)
    ax.set_xlabel('Year', fontsize=11)
    ax.set_ylabel('Surplus ($M)', fontsize=11)
    ax.set_title('Surplus Distribution — v14c (003) GBM+MeanRev', fontsize=13,
                 fontweight='bold', color='#2C3E50')
    ax.legend(fontsize=9)
    ax.yaxis.set_major_formatter(mticker.FormatStrFormatter('$%.1fM'))
    ax.set_xlim(1, 30)
    ax.grid(True, alpha=0.3)
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    return fig


def chart_correlation_stress():
    fig, ax = plt.subplots(figsize=(8, 4))
    corrs = [-0.3, -0.15, 0.0, 0.15, 0.30, 0.45, 0.60]
    pocs = [CORR[str(c)]['poc'] for c in corrs]
    ax.plot(corrs, pocs, 'o-', color='#2C3E50', linewidth=2, markersize=8)
    ax.axvline(x=0.30, color='#3498A8', linestyle='--', alpha=0.5, label='Base (0.30)')
    ax.set_xlabel('Equity-Cash Rate Correlation', fontsize=11)
    ax.set_ylabel('PoD at Year 30 (%)', fontsize=11)
    ax.set_title('Correlation Stress Test', fontsize=13, fontweight='bold', color='#2C3E50')
    ax.legend(fontsize=9)
    ax.grid(True, alpha=0.3)
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    return fig


def chart_rate_stress():
    fig, ax = plt.subplots(figsize=(8, 4))
    scenarios = list(RATE.keys())
    pocs = [RATE[s]['poc'] for s in scenarios]
    colors_list = ['#27AE60', '#3498A8', '#F39C12', '#E74C3C', '#C0392B', '#8E44AD']
    bars = ax.barh(range(len(scenarios)), pocs, color=colors_list[:len(scenarios)],
                   edgecolor='white', height=0.6)
    ax.set_yticks(range(len(scenarios)))
    ax.set_yticklabels(scenarios, fontsize=9)
    ax.set_xlabel('PoD at Year 30 (%)', fontsize=11)
    ax.set_title('Cash Rate Stress Test', fontsize=13, fontweight='bold', color='#2C3E50')
    for i, v in enumerate(pocs):
        ax.text(v + 0.5, i, f'{v:.1f}%', va='center', fontsize=9, fontweight='bold')
    ax.grid(True, alpha=0.3, axis='x')
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    fig.tight_layout()
    return fig


def chart_combined_stress():
    fig, ax = plt.subplots(figsize=(9, 5))
    names = list(COMB.keys())
    pocs = [COMB[n]['poc'] for n in names]
    bar_colors = []
    for p in pocs:
        if p < 10:
            bar_colors.append('#27AE60')
        elif p < 25:
            bar_colors.append('#F39C12')
        elif p < 50:
            bar_colors.append('#E67E22')
        else:
            bar_colors.append('#E74C3C')

    bars = ax.barh(range(len(names)), pocs, color=bar_colors, edgecolor='white', height=0.6)
    ax.set_yticks(range(len(names)))
    short_names = [n.split(':')[0] if ':' in n else n for n in names]
    ax.set_yticklabels(short_names, fontsize=9)
    ax.set_xlabel('PoD at Year 30 (%)', fontsize=11)
    ax.set_title('Combined Stress Scenarios', fontsize=13, fontweight='bold', color='#2C3E50')
    for i, v in enumerate(pocs):
        ax.text(v + 0.5, i, f'{v:.1f}%', va='center', fontsize=9, fontweight='bold')
    ax.axvline(x=15, color='#27AE60', linestyle=':', alpha=0.5, label='15% threshold')
    ax.legend(fontsize=8)
    ax.grid(True, alpha=0.3, axis='x')
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    fig.tight_layout()
    return fig


# ============================================================
# BUILD REPORT
# ============================================================

def build_actuarial_review():
    filename = os.path.join(_dir, 'docs', 'pdfs', 'FutureProof_EPM_v14c_Actuarial_Review_Apr2025.pdf')
    os.makedirs(os.path.dirname(filename), exist_ok=True)

    doc = SimpleDocTemplate(filename, pagesize=A4,
                            topMargin=25*mm, bottomMargin=25*mm,
                            leftMargin=25*mm, rightMargin=25*mm)
    styles = get_styles()
    story = []

    # ---- COVER PAGE ----
    story.append(Spacer(1, 60*mm))
    story.append(Paragraph('Futureproof', styles['ReportTitle']))
    story.append(Spacer(1, 15*mm))
    story.append(Paragraph('Equity Preservation Mortgage v14c', styles['ReportTitle']))
    story.append(Spacer(1, 4*mm))
    story.append(Paragraph('Independent Actuarial Review', styles['ReportTitle']))
    story.append(Spacer(1, 4*mm))
    story.append(Paragraph('50,000-Path Monte Carlo with Sensitivity &amp; Stress Analysis', styles['ReportSubtitle']))
    story.append(Paragraph('April 2025', styles['ReportSubtitle']))
    story.append(Spacer(1, 15*mm))
    story.append(Paragraph('CONFIDENTIAL — For Internal Distribution Only', styles['Confidential']))
    story.append(PageBreak())

    # ---- EXECUTIVE SUMMARY ----
    story.append(Paragraph('Executive Summary', styles['SectionHead']))
    story.append(Paragraph(
        'This report presents an independent actuarial review of the FutureProof Equity Preservation Mortgage '
        '(EPM) v14c (003) model. The model uses a <b>GBM + Mean Reversion</b> equity return model based on '
        'MLE parameter estimation (Shevchenko, April 2026), a 2.0% wholesale funding margin, and a ±40%/−20% '
        'volatility buffer collar.',
        styles['BodyText2']))

    story.append(Paragraph(
        'The conclusions in this report are conditional on the model parameter set. A separate '
        'companion paper (<i>Model Assumptions &amp; Parameter Risk</i>, April 2025) performs independent '
        'empirical calibration and re-runs the headline PoD across the data-supported range for each '
        'input. That paper finds a materially wider plausible PoD range than is evident from the base case '
        'alone. Summary:',
        styles['BodyText2']))

    story.append(make_table(
        ['Parameter scenario', 'PoD (30yr)', 'Basis'],
        [
            ['Base case (model as written)', f'{BASE["poc"]}%', 'Parameters per v14c-003'],
            ['Realistic central', '16.9%', 'Each input at empirical midpoint'],
            ['Adverse plausible', '43.2%', 'Each input inside empirical range, non-tail'],
        ], col_widths=[65*mm, 30*mm, 60*mm]))
    story.append(Spacer(1, 3*mm))
    story.append(Paragraph(
        'This range is driven primarily by μ (equity drift), γ (mean-reversion strength), and collar cost. '
        'Readers should anchor capital and reinsurance sizing on the adverse-plausible leg; the base case '
        'is retained here for traceability against the production model, not as a central expectation.',
        styles['KeyFinding']))

    story.append(Paragraph('Key Findings', styles['SubHead']))

    findings = [
        f'<b>Base case PoD: {BASE["poc"]}%</b> (SE: {BASE["poc_se"]}%) — headline from the model-as-written',
        f'<b>Empirically-centred PoD: 16.9%</b> — each parameter at data-supported midpoint, joint re-run',
        f'<b>Adverse plausible PoD: 43.2%</b> — each parameter shifted inside (not beyond) empirical range',
        f'<b>Median surplus at maturity (base): ${BASE["median_surplus"]:,.0f}</b> — typical mortgage still generates substantial surplus',
        f'<b>LMI fair premium (base): ${BASE["lmi_fair"]:,.0f}</b> — commercially viable at base parameters; would rise materially under realistic-central',
        f'<b>Primary uncertainty drivers:</b> equity drift μ, mean-reversion γ, and collar cost — each individually capable of shifting PoD by &gt;5pp',
        f'<b>Cash-rate θ is secondary but material:</b> +130bp lifts PoD from {BASE["poc"]}% to 6.4%',
        f'<b>Correlation ρ, volatility σ, and κ are well-calibrated</b> and do not drive material uncertainty',
    ]
    for f_text in findings:
        story.append(Paragraph(f_text, styles['BulletCustom'], bulletText='•'))

    story.append(PageBreak())

    # ---- MODEL OVERVIEW ----
    story.append(Paragraph('Model Overview — v14c (003) Parameters', styles['SectionHead']))
    story.append(Paragraph(
        'The table below summarises all key model parameters.',
        styles['BodyText2']))

    param_table = make_table(
        ['Parameter', 'Value'],
        [
            ['Home Value', '$2,000,000'],
            ['LVR', '80%'],
            ['Initial Loan', '$1,300,000'],
            ['Annuity', '$30,000/yr × 10yr'],
            ['Equity Model', 'GBM + Mean Reversion (Shevchenko 2026)'],
            ['Expected Return', '9.2%'],
            ['Equity Volatility', '16.6%'],
            ['Mean Reversion Speed (γ)', '0.163'],
            ['Buffer Cap / Floor', '140% / 80%'],
            ['Wholesale Margin', '2.0%'],
            ['NIM', '0.70%'],
            ['FP Margin', '0.50%'],
            ['Hedging Fee', '0.25%'],
            ['Total Variable Costs', '3.45%'],
            ['Cash Rate (θ / κ / σ)', '2.13% / 0.24 / 1.22%'],
            ['Cash Rate Initial', '4.21%'],
            ['Correlation (equity-rate)', '0.30'],
            ['Collar Price', '+0.046% (near zero net cost)'],
            ['Simulation Paths', '50,000'],
        ],
        col_widths=[65*mm, 90*mm]
    )
    story.append(param_table)

    story.append(Paragraph(
        '<b>Note on the Mean-Reverting Equity Model:</b> The Shevchenko (2026) paper proposes a novel model: '
        'S(t+1) = S(t)(1 + μ + σε) + γ(M(t) - S(t)), where M(t) is a deterministic trend growing at the '
        'expected return rate. The mean reversion parameter γ = 0.163 means that roughly 16% of any deviation '
        'from trend is corrected each year. Pure GBM (γ = 0) lets deviations compound indefinitely.',
        styles['BodyText2']))

    story.append(Paragraph(
        '<b>Parameter-risk caveat:</b> independent MLE on S&amp;P 500 TR 1988–2024 gives γ̂ = 0.173, which '
        'appears to confirm the model input. However, the 95% bootstrap CI runs [0.019, 0.447], and a '
        'likelihood-ratio test against γ = 0 yields p = 0.09 — not significant at the 5% level. A small-sample '
        'bias correction suggests the true γ most consistent with the data may sit closer to 0.05–0.10. At '
        'γ = 0.10, base-case PoD rises from 1.2% to 3.1%; at γ = 0, to 31.5%. γ is the single most '
        'load-bearing modelling choice in the product.',
        styles['Warning'] if 'Warning' in styles.byName else styles['BodyText2']))

    story.append(PageBreak())

    # ---- BASE CASE RESULTS ----
    story.append(Paragraph('Base Case Results — 50,000 Paths', styles['SectionHead']))

    story.append(Paragraph('Deficit Probability Over Time', styles['SubHead']))
    story.append(fig_to_image(chart_deficit_trajectory()))

    story.append(Paragraph(
        f'PoD starts at {BASE["deficit_by_year"]["1"]}% in year 1 (reflecting upfront costs and annuity payments) '
        f'and declines steadily to {BASE["poc"]}% by year 30. The steepest improvement occurs between years 10-20 '
        f'as P&amp;I amortisation reduces the mortgage balance and investment compounding accelerates.',
        styles['BodyText2']))

    story.append(PageBreak())
    story.append(Paragraph('Surplus Distribution — Fan Chart', styles['SubHead']))
    story.append(fig_to_image(chart_surplus_fan()))

    base_table = make_table(
        ['Metric', 'Value', 'Notes'],
        [
            ['PoD (Year 30)', f'{BASE["poc"]}%', f'SE: {BASE["poc_se"]}%'],
            ['Mean Surplus', f'${BASE["mean_surplus"]:,.0f}', 'Average across all paths'],
            ['Median Surplus', f'${BASE["median_surplus"]:,.0f}', '50th percentile'],
            ['1st Percentile', f'${BASE["p1"]:,.0f}', 'Worst 1% of paths'],
            ['5th Percentile', f'${BASE["p5"]:,.0f}', ''],
            ['10th Percentile', f'${BASE["p10"]:,.0f}', ''],
            ['25th Percentile', f'${BASE["p25"]:,.0f}', ''],
            ['75th Percentile', f'${BASE["p75"]:,.0f}', ''],
            ['90th Percentile', f'${BASE["p90"]:,.0f}', ''],
            ['99th Percentile', f'${BASE["p99"]:,.0f}', ''],
            ['Conditional Expected Deficit', f'${BASE["cond_deficit"]:,.0f}', 'Mean loss given deficit'],
            ['Mean Holiday Years (of 30)', f'{BASE["mean_holidays"]}', 'Average path: 0; mean across all simulated paths'],
            ['LMI Fair Premium (PV)', f'${BASE["lmi_fair"]:,.0f}', 'Discounted at 2.13%'],
            ['Tail Risk PoC', f'{BASE["tail_poc"]}%', 'Beyond top cover limit'],
        ],
        col_widths=[55*mm, 40*mm, 60*mm]
    )
    story.append(base_table)

    story.append(PageBreak())

    # ---- SENSITIVITY ANALYSIS ----
    story.append(Paragraph('Sensitivity Analysis — Equity Return vs Volatility', styles['SectionHead']))
    story.append(Paragraph(
        'The sensitivity grid tests 40 combinations of equity return (7.0–11.0%) and volatility (12.0–25.0%). '
        'All other parameters held at base case values. Each cell shows PoD at year 30 from a 50,000-path simulation.',
        styles['BodyText2']))

    story.append(fig_to_image(chart_sensitivity_heatmap(), width=165*mm, height=95*mm))

    # Sensitivity table
    returns = [0.070, 0.075, 0.080, 0.085, 0.090, 0.092, 0.100, 0.110]
    vols = [0.120, 0.150, 0.166, 0.200, 0.250]
    sens_rows = []
    for ret in returns:
        row = [f'{ret*100:.1f}%']
        for vol in vols:
            key = f"ret_{ret:.3f}_vol_{vol:.3f}"
            poc = SENS[key]['poc']
            row.append(f'{poc:.1f}')
        sens_rows.append(row)

    story.append(Spacer(1, 3*mm))
    story.append(Paragraph('PoD (%) at Year 30 — Equity Return vs Volatility', styles['SubHead']))
    sens_table = make_table(
        ['Return \\ Vol', '12.0%', '15.0%', '16.6%', '20.0%', '25.0%'],
        sens_rows,
        col_widths=[25*mm, 25*mm, 25*mm, 25*mm, 25*mm, 25*mm]
    )
    story.append(sens_table)

    story.append(Spacer(1, 3*mm))
    story.append(Paragraph('<b>Key observations:</b>', styles['BodyText2']))
    story.append(Paragraph(
        f'Every 1pp of equity return is worth roughly 3–5pp of PoD. Every 5pp of volatility adds 5–10pp. '
        f'The base case (9.2% / 16.6%) sits comfortably at {BASE["poc"]}%. '
        f'The mean-reverting model is central — it reduces long-term tail risk by pulling returns back '
        f'toward trend after deviations.',
        styles['BodyText2']))

    story.append(PageBreak())

    # ---- CORRELATION STRESS ----
    story.append(Paragraph('Correlation Stress Test', styles['SectionHead']))
    story.append(fig_to_image(chart_correlation_stress(), height=75*mm))

    corr_rows = []
    for c in [-0.3, -0.15, 0.0, 0.15, 0.30, 0.45, 0.60]:
        d = CORR[str(c)]
        label = f'{c:.2f}' + (' (base)' if c == 0.30 else '')
        corr_rows.append([label, f'{d["poc"]:.1f}%', f'${d["mean_surplus"]:,.0f}',
                          f'${d["cond_deficit"]:,.0f}'])

    story.append(make_table(
        ['Correlation', 'PoD', 'Mean Surplus', 'Cond. Deficit'],
        corr_rows,
        col_widths=[35*mm, 25*mm, 40*mm, 40*mm]
    ))

    story.append(Spacer(1, 3*mm))
    story.append(Paragraph(
        '<b>Interpretation:</b> Correlation has minimal impact — the full range from -0.3 to +0.6 moves PoD '
        'by only ~2.3pp. This is because the cash rate mean-reverts quickly (kappa=0.24) and the funding cost '
        'is dominated by the wholesale margin (2%) rather than the cash rate level. '
        '<b>Correlation mis-specification is not a material risk for this product.</b>',
        styles['BodyText2']))

    story.append(PageBreak())

    # ---- CASH RATE STRESS ----
    story.append(Paragraph('Cash Rate Stress Test', styles['SectionHead']))
    story.append(fig_to_image(chart_rate_stress(), height=80*mm))

    rate_rows = []
    for name, d in RATE.items():
        rate_rows.append([name, f'{d["theta"]*100:.2f}%', f'{d["kappa"]}',
                          f'{d["poc"]:.1f}%', f'${d["mean_surplus"]:,.0f}'])

    story.append(make_table(
        ['Scenario', 'Theta', 'Kappa', 'PoD', 'Mean Surplus'],
        rate_rows,
        col_widths=[45*mm, 20*mm, 15*mm, 20*mm, 40*mm]
    ))

    story.append(Spacer(1, 3*mm))
    story.append(Paragraph(
        '<b>Interpretation:</b> Cash rates matter significantly — the spread between low (1.5%) and high (4.5%) '
        f'theta is {RATE["High rates (theta=4.5%)"]["poc"] - RATE["Low rates (theta=1.5%)"]["poc"]:.0f}pp of PoD. '
        'Higher cash rates directly increase wholesale funding costs (2.0% + cash rate), accelerating the cost drag. '
        f'The base assumption (theta=2.13%) reflects a low-rate environment. If the neutral rate settles at 3.5% '
        f'(plausible post-COVID), PoD rises to {RATE["Medium rates (theta=3.5%)"]["poc"]}%. At 4.5%, PoD rises '
        f'to {RATE["High rates (theta=4.5%)"]["poc"]}%.',
        styles['BodyText2']))

    story.append(Paragraph(
        f'Note: faster mean reversion (kappa=0.5) barely changes the high-rate result — what matters is where '
        f'rates settle, not how fast they get there. However, slow reversion (kappa=0.1) at low theta increases '
        f'PoD to {RATE["Low + slow reversion"]["poc"]}% because the cash rate takes longer to fall from its '
        f'current 4.21% starting point.',
        styles['BodyText2']))

    story.append(PageBreak())

    # ---- COMBINED STRESS ----
    story.append(Paragraph('Combined Stress Scenarios', styles['SectionHead']))
    story.append(Paragraph(
        'Combined scenarios test multiple adverse conditions simultaneously, representing plausible '
        'macroeconomic regimes over a 30-year horizon.',
        styles['BodyText2']))

    story.append(fig_to_image(chart_combined_stress(), height=85*mm))

    comb_rows = []
    for name, d in COMB.items():
        short = name.split(':')[0] if ':' in name else name
        comb_rows.append([short, f'{d["poc"]:.1f}%', f'${d["median_surplus"]:,.0f}',
                          f'${d["cond_deficit"]:,.0f}', f'${d["lmi_fair"]:,.0f}'])

    story.append(make_table(
        ['Scenario', 'PoD', 'Median Surplus', 'Cond. Deficit', 'LMI Fair'],
        comb_rows,
        col_widths=[40*mm, 18*mm, 32*mm, 32*mm, 28*mm]
    ))

    story.append(Spacer(1, 3*mm))
    story.append(Paragraph('<b>Key observations:</b>', styles['BodyText2']))
    observations = [
        f'The <b>Goldilocks scenario</b> (11% return, 12% vol, moderate rates) produces PoD of just {COMB["Goldilocks: high ret, low vol, moderate rates"]["poc"]}% — essentially zero risk.',
        f'The <b>Japan scenario</b> (low returns but low vol and low rates) gives {COMB["Japan scenario: 7% ret, 12% vol, low rates"]["poc"]}% PoD — low rates partially offset low returns.',
        f'<b>Mild adverse</b> (8% return, 20% vol) pushes PoD to {COMB["Mild adverse: 8% return, 20% vol"]["poc"]}% — a material deterioration from base case.',
        f'<b>Stagflation</b> (low returns + high vol + high rates) is {COMB["Stagflation: low ret, high rates, high vol"]["poc"]}% PoD. This is the scenario the product must insure against.',
        f'The <b>GFC-like</b> scenario (25% vol, negative correlation) gives {COMB["GFC-like: 8% but 25% vol, neg corr"]["poc"]}% — sustained 2008-level volatility for 30 years is extremely adverse.',
    ]
    for obs in observations:
        story.append(Paragraph(obs, styles['BulletCustom'], bulletText='•'))

    story.append(PageBreak())

    # ---- ACTUARIAL ASSESSMENT ----
    story.append(Paragraph('Actuarial Assessment', styles['SectionHead']))

    story.append(Paragraph('Is the Model Sound?', styles['SubHead']))
    story.append(Paragraph(
        '<b>The model structure is sound.</b> The v14c (003) model is well-constructed: the Vasicek/OU process '
        'for cash rates uses exact discretisation with MLE-estimated parameters; the GBM+MeanRev equity model '
        'is grounded in Shevchenko (2026); the insurance structure (LMI + tail risk reinsurance) is correctly '
        'implemented; and the Payments Waterfall provides genuine portfolio-level risk mitigation.',
        styles['BodyText2']))

    story.append(Paragraph(
        'The <b>critical qualifier</b> is that headline results are highly sensitive to three specific '
        'input parameters — equity drift μ, mean-reversion strength γ, and collar cost — each of which '
        'has a wide empirical confidence interval relative to the base-case point estimate. The Model '
        'Assumptions &amp; Parameter Risk companion paper performs an independent calibration on S&amp;P '
        '500 TR 1988–2024 data. Its findings, which qualify the base-case PoD reported in this paper, are:',
        styles['BodyText2']))

    story.append(make_table(
        ['Parameter', 'Model', 'Empirical', 'Impact on PoD'],
        [
            ['Mean-reversion γ', '0.163', 'MLE 0.173; 95% CI [0.019, 0.447]',
             'γ = 0.10 → PoD 3.1%; γ = 0 → 31.5%'],
            ['Equity drift μ', '9.2%', 'MLE 11.0%; CAPE-implied forward 5–6%',
             'μ = 8.0% → PoD 9.7%; μ = 7.0% → 30.4%'],
            ['Collar cost', '0.046% p.a.', 'Black-Scholes central 0.30–0.40%',
             '0.30% → PoD 2.0%; 1.0% → 7.6%'],
        ], col_widths=[30*mm, 22*mm, 55*mm, 53*mm]))
    story.append(Spacer(1, 3*mm))

    story.append(Paragraph('Are the Numbers Investable?', styles['SubHead']))
    story.append(Paragraph(
        f'<b>At base-case parameters, yes.</b> A {BASE["poc"]}% PoD with a conditional deficit of '
        f'${abs(BASE["cond_deficit"]):,.0f} against a $2M property is a reasonable risk profile. '
        f'The LMI fair premium of ${BASE["lmi_fair"]:,.0f} is commercially viable. The portfolio-level '
        'PoC after the Payments Waterfall is well below the 1% threshold that reinsurers typically '
        'require under the model as written.',
        styles['BodyText2']))

    story.append(Paragraph(
        '<b>Under an empirically-centred parameter set, the product remains viable but is materially '
        'less favourable.</b> Joint re-simulation at γ = 0.13, μ = 8.5%, θ = 2.7%, collar = 0.30%, '
        'margin = 2.2% produces PoD = 16.9% and mean surplus = $995K. Under an adverse-plausible set '
        '(γ = 0.10, μ = 8.0%, θ = 3.0%, collar = 0.40%, margin = 2.5% — each parameter inside its '
        'empirical range, not at the tail), PoD = 43.2% and mean surplus = $253K.',
        styles['BodyText2']))

    story.append(Paragraph(
        'This is the dominant finding of the review: parameter uncertainty alone — before any '
        'model-structure uncertainty (Gaussian shocks, no jumps, no regime switches) — produces a '
        'PoD range spanning more than an order of magnitude. Capital allocation, reinsurance attachment, '
        'and investor risk disclosure should be anchored on the adverse-plausible leg rather than the '
        'base case.',
        styles['KeyFinding']))

    story.append(Paragraph('Recommendations', styles['SubHead']))
    recs = [
        '<b>1. Report headline PoD as a range, not a point.</b> The model-as-written produces 1.2% PoD. '
        'Realistic-central (empirically-centred parameters) produces 16.9%. Adverse-plausible produces '
        '43.2%. All three should appear alongside each other in internal, investor, and reinsurer '
        'materials. The base case alone overstates confidence in the product.',
        '<b>2. Anchor capital and reinsurance sizing on the adverse-plausible leg.</b> Reinsurance '
        'attachment, wholesale-funder subordination, and internal solvency capital should be calibrated '
        'to the 43% PoD scenario, not the 1.2% base case. Designing to the base case embeds a '
        'material under-reserve.',
        '<b>3. Use conservative μ for pricing.</b> At μ = 8.0–8.5% (rather than 9.2%), PoD sits at '
        '4–10% — still competitive as a product — without reliance on in-sample 1988–2024 US equity '
        'performance continuing for the next 30 years. Forward-looking estimates that account for '
        'current valuation (CAPE-implied 5–6%) are lower; 8.5% is a defensible middle ground.',
        '<b>4. Replace the collar cost assumption.</b> The 0.046% model input is inconsistent with '
        'Black-Scholes pricing at current AU rates (0.16–0.44%), before skew or transaction costs. '
        'Move to 0.30% minimum for pricing. Re-test at 0.50% to stress for skew and roll slippage.',
        '<b>5. Governance: annual re-estimation of γ.</b> The mean-reversion parameter is the single '
        'most load-bearing modelling choice. Establish a policy for annual MLE refresh with each year '
        'of added data, track drift against the 0.163 assumption, and hold reserves against downward '
        'revision.',
        '<b>6. Track θ to AU cash, not US Fed Funds.</b> The 2.13% long-run mean is 50bp below the '
        'US MLE and 250bp below the AU analogue. Update the cash process to match the funding '
        'currency. At θ = 3.0% (still below the AU historical mean), PoD is 6.4%.',
        '<b>7. Stress test the wholesale margin annually.</b> The 2.0% modelled margin is at the low '
        'end of the 2.0–3.0% range priced for comparable AU wholesale risk. Lock terms for '
        'the warehouse facility at issuance; re-test economics at 2.5% on each new tranche.',
        '<b>8. Increase simulation paths in the spreadsheet tool to 10,000+.</b> The production '
        'spreadsheet runs 1,000 paths and produces PoD estimates with unacceptable standard error '
        'at the base-case rate. 10,000 paths is the minimum for internal decisioning.',
        '<b>9. Document the Shevchenko model and its parameter uncertainty thoroughly.</b> For '
        'investor and reinsurer materials, disclose the γ bootstrap distribution, the LRT against '
        'γ = 0, the small-sample bias finding, and the full range of headline PoD across the joint '
        'parameter scenarios.',
    ]
    for rec in recs:
        story.append(Paragraph(rec, styles['BodyText2']))

    story.append(PageBreak())

    # ---- EPM VS CURRENT INVESTMENT LANDSCAPE ----
    story.append(Paragraph('EPM vs Current Investment Landscape', styles['SectionHead']))
    story.append(Paragraph(
        'To place the EPM risk profile in context, we benchmark its key actuarial metrics against '
        'established credit instruments and traditional residential lending. The table below presents '
        'the EPM under both the base-case parameters (as modelled) and the realistic-central parameter '
        'scenario developed in the companion Model Assumptions paper. The adverse-plausible scenario '
        'is discussed separately in the commentary.',
        styles['BodyText2']))

    story.append(make_table(
        ['Metric', 'EPM (base)', 'EPM (realistic)', 'Prime AU Mortgage', "Moody's AA Bond", 'AU RMBS (AA)'],
        [
            ['Cumulative PoD (30yr)', f'{BASE["poc"]}%', '16.9%', '3–5%', '~1.5%', '~1–2%'],
            ['Loss severity (LGD)', '~21% of peak', '~21% of peak', '20–40%', '40–60%', 'Subord.'],
            ['Expected loss (30yr)', '0.13%', '~2.3%', '0.6–1.25%', '0.6–0.9%', '0.05–0.15%'],
            ['Ratings equivalent', 'AA/AAA', 'BBB-ish', 'A/BBB', 'AA', 'AA'],
        ],
        col_widths=[32*mm, 22*mm, 24*mm, 25*mm, 22*mm, 22*mm]
    ))

    story.append(Spacer(1, 3*mm))
    story.append(Paragraph('<b>Actuarial Assessment of Comparative Risk Position</b>', styles['BodyText2']))

    act_landscape = [
        f'<b>Credit quality depends on which scenario is selected.</b> At base-case parameters, the EPM\'s '
        f'{BASE["poc"]}% cumulative PoD places it between Moody\'s AAA and AA 30-year cumulative default rates. '
        'At realistic-central parameters (empirically-centred μ, γ, collar cost), the 16.9% PoD corresponds '
        'more closely to investment-grade speculative territory (BBB to BB range on a pure-PoD basis). '
        'The low 21% severity moderates the expected loss, but no single rating can be attached to the product '
        'without first committing to a parameter set.',
        '<b>Comparison to traditional residential lending is parameter-dependent.</b> Standard Australian '
        'prime mortgages carry a 3–5% cumulative default rate over 30 years. At base-case parameters the EPM '
        'is 3–4× safer on a PoD basis; at realistic-central parameters it is of the same order as prime '
        'mortgage risk; at adverse-plausible parameters (43.2% PoD) it is materially riskier than prime '
        'mortgages. The structural features (mean reversion, collar, holiday, run-off) remain protective '
        'across all scenarios, but the magnitude of protection depends on whether the underlying drift and '
        'mean-reversion inputs hold.',
        '<b>Risk driver is fundamentally different from traditional mortgages.</b> Traditional mortgage '
        'default risk is driven by borrower income, employment, and interest-rate affordability. EPM risk '
        'is driven by long-term equity-market performance relative to interest rates. These factors are '
        'largely uncorrelated, which preserves a diversification benefit for reinsurers regardless of '
        'scenario — this structural feature is robust to the parameter uncertainty discussed above.',
        '<b>Structural protections are real but not unconditional.</b> Mean-reverting equity, collar '
        'hedging, holiday mechanism, P&I amortisation, and insurance coverage from $0 form a genuine '
        'multi-layered protection framework. However, the protective value of the collar and of mean '
        'reversion is itself sensitive to parameter calibration — a collar priced at 0.30% (Black-Scholes) '
        'rather than 0.046% (model input) meaningfully erodes the base-case surplus, and a weaker γ removes '
        'the self-correcting feature on which the 1.2% base-case PoD depends.',
    ]
    for al in act_landscape:
        story.append(Paragraph(f'<bullet>&bull;</bullet> {al}', styles['BulletCustom']))

    story.append(PageBreak())

    # ---- CONCLUSION ----
    story.append(Paragraph('Conclusion', styles['SectionHead']))
    story.append(Paragraph(
        'The v14c (003) model is a structurally sound quantitative framework. The Monte Carlo engine, '
        'the Shevchenko mean-reverting equity process, the Ornstein-Uhlenbeck cash-rate model, and the '
        'treatment of the collar, holiday, P&I amortisation and insurance layers are implemented correctly '
        'and consistently. As a piece of quantitative engineering, the model is credible.',
        styles['BodyText2']))

    story.append(Paragraph(
        f'The headline base-case results (PoD {BASE["poc"]}%, mean surplus ${BASE["mean_surplus"]:,.0f}) '
        'are, however, contingent on three parameter assumptions that each carry wide empirical confidence '
        'intervals: equity drift μ, mean-reversion strength γ, and collar cost. The companion paper '
        '"Model Assumptions and Parameter Risk" (April 2025) shows that moving each of these to an '
        'empirically-centred estimate produces a joint PoD of 16.9%, and that moving to the lower bound '
        'of each confidence interval produces a joint PoD of 43.2%. The headline result should therefore '
        'be reported as a range, with explicit disclosure of the scenarios that produce each point.',
        styles['BodyText2']))

    story.append(Paragraph(
        'Under realistic-central parameters, the product remains viable and insurable, but at a materially '
        'higher claims rate than the base case suggests. Capital and reinsurance sizing should be '
        'calibrated to the adverse-plausible leg, not the base case. Pricing should use conservative μ '
        '(8.0–8.5%) and a Black-Scholes-anchored collar cost (0.30% minimum). With these adjustments, '
        'the product is defensible to an external actuary, investor, or reinsurer. Without them, the '
        '1.2% headline overstates the confidence the parameter evidence supports.',
        styles['BodyText2']))

    story.append(Spacer(1, 10*mm))

    # Methodology appendix
    story.append(Paragraph('Appendix: Methodology', styles['SectionHead']))

    meth_table = make_table(
        ['Component', 'Model', 'Parameters'],
        [
            ['Equity Returns', 'GBM + Mean Reversion (Shevchenko 2026)', 'μ=9.2%, σ=16.6%, γ=0.163'],
            ['Volatility Buffer', 'Cap/Floor on annual returns', 'Cap: +40%, Floor: -20%'],
            ['Cash Rate', 'Ornstein-Uhlenbeck (exact discretisation)', 'θ=2.13%, κ=0.24, σ=1.22%, r₀=4.21%'],
            ['Equity-Rate Correlation', 'Cholesky decomposition', 'ρ = 0.30'],
            ['Collar Hedge', 'Calculated put-call', 'Net cost: +0.046% p.a. (near zero)'],
            ['Variable Costs', 'Fixed spread', '3.45% (wholesale 2.0% + NIM 0.70% + hedge 0.25% + FP 0.50%)'],
            ['P&I Amortisation', 'Linear paydown Years 11-30', 'Peak $1.6M, annual $80K repayment'],
            ['Interest Payment Holiday', 'Entry 0.75×, Exit 1.458×', 'Interest payments pause; annuity to borrower continues'],
            ['Insurance Discount', 'Continuous (exp(-θT))', 'Rate = 2.13% (cash rate theta)'],
            ['LMI Coverage', '80% of deficit paths', 'Top cover limit: P20 of deficit distribution'],
            ['Tail Risk', '20% of deficit paths', 'Excess beyond top cover limit'],
            ['Profit Share', '10% every 5 years', 'On positive surplus only'],
            ['Simulation', '50,000 paths', 'Seed: 42, NumPy default_rng'],
        ],
        col_widths=[40*mm, 55*mm, 60*mm]
    )
    story.append(meth_table)

    doc.build(story, onFirstPage=footer, onLaterPages=footer)
    print(f'  Generated: {filename}')
    return filename


if __name__ == '__main__':
    print('Generating FutureProof EPM v14c (003) — Independent Actuarial Review...\n')
    os.chdir(os.path.dirname(os.path.abspath(__file__)))
    f = build_actuarial_review()
    print(f'\nDone: {f}')
