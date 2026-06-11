#!/usr/bin/env python3
"""
Generate FutureProof EPM v14a Inflation-Indexed Annuity Analysis Report
Matches the style of existing v14 reports.
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
# COLOUR PALETTE (matching existing reports)
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
ORANGE = HexColor('#E67E22')
BLUE = HexColor('#2980B9')

SCENARIO_COLOURS = [
    DARK_NAVY,           # Baseline (flat)
    BLUE,                # 2.0%
    TEAL,                # 2.5%
    GREEN,               # 3.0%
    ORANGE,              # 3.5%
    CORAL,               # 4.0%
]

SCENARIO_COLOURS_MPL = [
    '#2C3E50',  # Baseline
    '#2980B9',  # 2.0%
    '#3498A8',  # 2.5%
    '#27AE60',  # 3.0%
    '#E67E22',  # 3.5%
    '#C0392B',  # 4.0%
]


# ============================================================
# STYLES
# ============================================================
def get_styles():
    styles = getSampleStyleSheet()

    styles.add(ParagraphStyle(
        'ReportTitle', parent=styles['Title'],
        fontSize=28, leading=34, textColor=DARK_NAVY,
        spaceAfter=6*mm, alignment=TA_LEFT,
        fontName='Helvetica-Bold'
    ))
    styles.add(ParagraphStyle(
        'ReportSubtitle', parent=styles['Normal'],
        fontSize=14, leading=18, textColor=TEAL,
        spaceAfter=10*mm, alignment=TA_LEFT,
        fontName='Helvetica'
    ))
    styles.add(ParagraphStyle(
        'SectionHead', parent=styles['Heading1'],
        fontSize=16, leading=20, textColor=DARK_NAVY,
        spaceBefore=8*mm, spaceAfter=4*mm,
        fontName='Helvetica-Bold',
        borderWidth=0, borderColor=TEAL, borderPadding=0,
    ))
    styles.add(ParagraphStyle(
        'SubSection', parent=styles['Heading2'],
        fontSize=13, leading=16, textColor=TEAL,
        spaceBefore=5*mm, spaceAfter=3*mm,
        fontName='Helvetica-Bold'
    ))
    styles.add(ParagraphStyle(
        'BodyText2', parent=styles['Normal'],
        fontSize=10, leading=14, textColor=DARK_NAVY,
        spaceAfter=3*mm, alignment=TA_JUSTIFY,
        fontName='Helvetica'
    ))
    styles.add(ParagraphStyle(
        'SmallNote', parent=styles['Normal'],
        fontSize=8, leading=10, textColor=MID_GREY,
        spaceAfter=2*mm, fontName='Helvetica-Oblique'
    ))
    styles.add(ParagraphStyle(
        'BulletItem', parent=styles['Normal'],
        fontSize=10, leading=14, textColor=DARK_NAVY,
        leftIndent=15, spaceAfter=2*mm,
        fontName='Helvetica', bulletIndent=5,
    ))
    styles.add(ParagraphStyle(
        'KeyFinding', parent=styles['Normal'],
        fontSize=11, leading=15, textColor=DARK_NAVY,
        leftIndent=10, spaceAfter=3*mm,
        fontName='Helvetica-Bold',
        borderWidth=1, borderColor=TEAL, borderPadding=6,
        backColor=HexColor('#F0F8FF'),
    ))

    return styles


def make_table(data, col_widths=None, header_rows=1):
    """Create a styled table."""
    style_cmds = [
        ('BACKGROUND', (0, 0), (-1, header_rows - 1), HEADER_BG),
        ('TEXTCOLOR', (0, 0), (-1, header_rows - 1), WHITE),
        ('FONTNAME', (0, 0), (-1, header_rows - 1), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 0), (-1, header_rows - 1), 9),
        ('FONTNAME', (0, header_rows), (-1, -1), 'Helvetica'),
        ('FONTSIZE', (0, header_rows), (-1, -1), 9),
        ('ALIGN', (1, 0), (-1, -1), 'RIGHT'),
        ('ALIGN', (0, 0), (0, -1), 'LEFT'),
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ('GRID', (0, 0), (-1, -1), 0.5, MID_GREY),
        ('TOPPADDING', (0, 0), (-1, -1), 4),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 4),
        ('LEFTPADDING', (0, 0), (-1, -1), 6),
        ('RIGHTPADDING', (0, 0), (-1, -1), 6),
    ]
    # Alternate row shading
    for i in range(header_rows, len(data)):
        if (i - header_rows) % 2 == 1:
            style_cmds.append(('BACKGROUND', (0, i), (-1, i), ROW_ALT))

    t = Table(data, colWidths=col_widths, repeatRows=header_rows)
    t.setStyle(TableStyle(style_cmds))
    return t


def fig_to_image(fig, width=160*mm, height=100*mm):
    """Convert matplotlib figure to ReportLab Image."""
    buf = BytesIO()
    fig.savefig(buf, format='png', dpi=150, bbox_inches='tight')
    plt.close(fig)
    buf.seek(0)
    return Image(buf, width=width, height=height)


def fmt_dollar(val):
    """Format dollar amount."""
    if val >= 0:
        return f"${val:,.0f}"
    return f"-${abs(val):,.0f}"


def fmt_pct(val):
    return f"{val:.2f}%"


def fmt_pp(val):
    if val >= 0:
        return f"+{val:.2f}pp"
    return f"{val:.2f}pp"


# ============================================================
# CHART GENERATORS
# ============================================================

def chart_annuity_schedule(data):
    """Bar chart of annuity payments by year for each scenario."""
    fig, ax = plt.subplots(figsize=(10, 5))

    baseline = data['baseline']
    scenarios = [baseline] + data['inflation_scenarios']
    labels = ['Flat'] + [f"{s['inflation_rate']*100:.0f}%" for s in data['inflation_scenarios']]
    years = list(range(1, 11))

    x = np.arange(len(years))
    width = 0.13
    offsets = np.arange(len(scenarios)) - (len(scenarios) - 1) / 2

    for i, (scenario, label, colour) in enumerate(zip(scenarios, labels, SCENARIO_COLOURS_MPL)):
        payments = [scenario['annuity_schedule'][yr] for yr in years]
        ax.bar(x + offsets[i] * width, payments, width * 0.9, label=label, color=colour, alpha=0.85)

    ax.set_xlabel('Year', fontsize=11)
    ax.set_ylabel('Annual Payout ($)', fontsize=11)
    ax.set_title('Annuity Payout Schedule — Flat vs Inflation-Indexed', fontsize=13, fontweight='bold')
    ax.set_xticks(x)
    ax.set_xticklabels(years)
    ax.yaxis.set_major_formatter(mticker.FuncFormatter(lambda v, p: f'${v:,.0f}'))
    ax.legend(title='Inflation Rate', fontsize=9, title_fontsize=10)
    ax.grid(axis='y', alpha=0.3)
    fig.tight_layout()

    return fig_to_image(fig, width=170*mm, height=95*mm)


def chart_poc_by_year(data):
    """Line chart of PoC by year for each scenario."""
    fig, ax = plt.subplots(figsize=(10, 5.5))

    baseline = data['baseline']
    scenarios = [baseline] + data['inflation_scenarios']
    labels = ['Flat $25K'] + [f"{s['inflation_rate']*100:.0f}% Indexed" for s in data['inflation_scenarios']]

    years = list(range(1, 31))
    for i, (scenario, label, colour) in enumerate(zip(scenarios, labels, SCENARIO_COLOURS_MPL)):
        poc_vals = scenario['deficit_by_year']
        lw = 2.5 if i == 0 else 1.5
        ls = '-' if i == 0 else '--'
        ax.plot(years, poc_vals, label=label, color=colour, linewidth=lw, linestyle=ls)

    ax.set_xlabel('Year', fontsize=11)
    ax.set_ylabel('Probability of Claim (%)', fontsize=11)
    ax.set_title('PoC Trajectory — Flat vs Inflation-Indexed Annuity', fontsize=13, fontweight='bold')
    ax.legend(fontsize=9, loc='upper right')
    ax.grid(alpha=0.3)
    ax.set_xlim(1, 30)
    ax.set_ylim(0, None)
    fig.tight_layout()

    return fig_to_image(fig, width=170*mm, height=100*mm)


def chart_impact_summary(data):
    """Bar chart showing PoC increase and surplus decrease by inflation rate."""
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(12, 5))

    baseline = data['baseline']
    rates = [f"{s['inflation_rate']*100:.0f}%" for s in data['inflation_scenarios']]
    poc_deltas = [s['deficit_prob'] - baseline['deficit_prob'] for s in data['inflation_scenarios']]
    surplus_deltas = [s['mean_surplus'] - baseline['mean_surplus'] for s in data['inflation_scenarios']]

    colours = SCENARIO_COLOURS_MPL[1:]

    ax1.bar(rates, poc_deltas, color=colours, alpha=0.85)
    ax1.set_xlabel('Inflation Rate', fontsize=11)
    ax1.set_ylabel('PoC Increase (pp)', fontsize=11)
    ax1.set_title('PoC Impact', fontsize=13, fontweight='bold')
    ax1.grid(axis='y', alpha=0.3)
    for i, v in enumerate(poc_deltas):
        ax1.text(i, v + 0.05, f"+{v:.2f}pp", ha='center', va='bottom', fontsize=9, fontweight='bold')

    ax2.bar(rates, [d / 1000 for d in surplus_deltas], color=colours, alpha=0.85)
    ax2.set_xlabel('Inflation Rate', fontsize=11)
    ax2.set_ylabel('Mean Surplus Change ($K)', fontsize=11)
    ax2.set_title('Mean Surplus Impact', fontsize=13, fontweight='bold')
    ax2.grid(axis='y', alpha=0.3)
    for i, v in enumerate(surplus_deltas):
        ax2.text(i, v / 1000 - 2, f"-${abs(v)/1000:.0f}K", ha='center', va='top', fontsize=9, fontweight='bold')

    fig.tight_layout()
    return fig_to_image(fig, width=170*mm, height=90*mm)


def chart_total_payout(data):
    """Bar chart of total annuity paid over 10 years."""
    fig, ax = plt.subplots(figsize=(8, 4.5))

    baseline = data['baseline']
    scenarios = [baseline] + data['inflation_scenarios']
    labels = ['Flat'] + [f"{s['inflation_rate']*100:.0f}% Indexed" for s in data['inflation_scenarios']]
    totals = [s['total_annuity'] / 1000 for s in scenarios]

    bars = ax.bar(labels, totals, color=SCENARIO_COLOURS_MPL, alpha=0.85)
    ax.set_ylabel('Total Annuity Paid ($K)', fontsize=11)
    ax.set_title('Total Annuity Payments Over 10-Year Term', fontsize=13, fontweight='bold')
    ax.grid(axis='y', alpha=0.3)

    for bar, val in zip(bars, totals):
        ax.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 1,
                f'${val:.0f}K', ha='center', va='bottom', fontsize=9, fontweight='bold')

    fig.tight_layout()
    return fig_to_image(fig, width=160*mm, height=85*mm)


def chart_tail_risk(data):
    """Bar chart of P5 surplus for each scenario."""
    fig, ax = plt.subplots(figsize=(8, 4.5))

    baseline = data['baseline']
    scenarios = [baseline] + data['inflation_scenarios']
    labels = ['Flat'] + [f"{s['inflation_rate']*100:.0f}%" for s in data['inflation_scenarios']]
    p5_vals = [s['p5'] / 1000 for s in scenarios]

    bars = ax.bar(labels, p5_vals, color=SCENARIO_COLOURS_MPL, alpha=0.85)
    ax.set_ylabel('P5 Surplus ($K)', fontsize=11)
    ax.set_title('5th Percentile Surplus (Tail Risk) — Year 30', fontsize=13, fontweight='bold')
    ax.grid(axis='y', alpha=0.3)
    ax.axhline(y=0, color='black', linewidth=0.8)

    for bar, val in zip(bars, p5_vals):
        ax.text(bar.get_x() + bar.get_width()/2, val - 15,
                f'-${abs(val):.0f}K', ha='center', va='top', fontsize=9, fontweight='bold', color='white')

    fig.tight_layout()
    return fig_to_image(fig, width=160*mm, height=85*mm)


# ============================================================
# REPORT BUILDER
# ============================================================

def build_report(data):
    output_path = 'FutureProof_EPM_v14a_Inflation_Analysis_Mar2025.pdf'
    doc = SimpleDocTemplate(
        output_path, pagesize=A4,
        leftMargin=20*mm, rightMargin=20*mm,
        topMargin=20*mm, bottomMargin=20*mm
    )

    styles = get_styles()
    story = []

    baseline = data['baseline']
    scenarios = data['inflation_scenarios']

    # ============================================================
    # TITLE PAGE
    # ============================================================
    story.append(Spacer(1, 30*mm))
    story.append(Paragraph('FutureProof EPM', styles['ReportTitle']))
    story.append(Paragraph('Inflation-Indexed Annuity<br/>Impact Analysis', styles['ReportTitle']))
    story.append(Spacer(1, 5*mm))
    story.append(Paragraph('v14a Model — 50,000-Path Monte Carlo Simulation', styles['ReportSubtitle']))
    story.append(Spacer(1, 10*mm))

    story.append(Paragraph('March 2025', styles['BodyText2']))
    story.append(Paragraph('Confidential — For Internal Use Only', styles['SmallNote']))
    story.append(Spacer(1, 15*mm))

    # Summary box
    summary_data = [
        ['Metric', 'Value'],
        ['Model Version', 'v14a (50,000 paths)'],
        ['Property Value', '$2,000,000'],
        ['Initial Mortgage', '$1,350,000'],
        ['Baseline Annuity', '$25,000/year flat (10 years)'],
        ['Inflation Rates Tested', '2.0%, 2.5%, 3.0%, 3.5%, 4.0%'],
        ['Baseline PoC (Year 30)', fmt_pct(baseline['deficit_prob'])],
        ['Analysis Objective', 'Impact of inflation-indexing annuity payouts'],
    ]
    story.append(make_table(summary_data, col_widths=[60*mm, 110*mm]))

    story.append(PageBreak())

    # ============================================================
    # 1. EXECUTIVE SUMMARY
    # ============================================================
    story.append(Paragraph('1. Executive Summary', styles['SectionHead']))

    story.append(Paragraph(
        'This analysis examines the impact of indexing the EPM annuity payout to inflation, '
        'compared with the current flat-rate structure. Under the baseline v14a model, the borrower '
        'receives $25,000 per year for 10 years — a total of $250,000 added to the mortgage principal. '
        'Under inflation indexing, the initial $25,000 grows each year by the assumed inflation rate, '
        'increasing the total payout and the peak mortgage balance.',
        styles['BodyText2']
    ))

    story.append(Paragraph(
        'We test five inflation scenarios (2.0% to 4.0%) against the flat baseline using '
        'identical random paths (same seed) for clean, apples-to-apples comparison across all 50,000 '
        'Monte Carlo simulations.',
        styles['BodyText2']
    ))

    story.append(Spacer(1, 3*mm))
    story.append(Paragraph('Key Findings', styles['SubSection']))

    # 3% scenario as the reference
    ref = next(s for s in scenarios if s['inflation_rate'] == 0.03)
    poc_delta = ref['deficit_prob'] - baseline['deficit_prob']
    surplus_delta = ref['mean_surplus'] - baseline['mean_surplus']
    extra_annuity = ref['total_annuity'] - baseline['total_annuity']

    findings = [
        f'At 3% inflation, PoC rises from {fmt_pct(baseline["deficit_prob"])} to '
        f'{fmt_pct(ref["deficit_prob"])} ({fmt_pp(poc_delta)}) — a moderate increase '
        f'that remains within acceptable risk parameters.',

        f'Total annuity payout increases by {fmt_dollar(extra_annuity)} (from {fmt_dollar(baseline["total_annuity"])} '
        f'to {fmt_dollar(ref["total_annuity"])}), a {extra_annuity/baseline["total_annuity"]*100:.1f}% increase.',

        f'Mean surplus decreases by {fmt_dollar(abs(surplus_delta))} ({abs(surplus_delta/baseline["mean_surplus"])*100:.1f}% '
        f'of baseline), reflecting the higher mortgage balance and associated costs.',

        f'The cost multiplier is approximately 2.2x — each additional dollar of annuity reduces '
        f'mean surplus by ~$2.20 due to compounding effects on interest, retail margin, and LMI.',

        f'Tail risk (P5 surplus) worsens disproportionately: {fmt_dollar(abs(ref["p5"] - baseline["p5"]))} '
        f'decline vs {fmt_dollar(abs(surplus_delta))} mean decline, indicating inflation indexing '
        f'has a larger impact on adverse scenarios.',

        f'Insurance premium (fair + 50% loading) increases from {fmt_dollar(baseline["fair_premium_loaded"])} '
        f'to {fmt_dollar(ref["fair_premium_loaded"])} ({(ref["fair_premium_loaded"]/baseline["fair_premium_loaded"]-1)*100:.0f}% increase).',
    ]

    for f in findings:
        story.append(Paragraph(f'• {f}', styles['BulletItem']))

    story.append(PageBreak())

    # ============================================================
    # 2. ANNUITY SCHEDULE COMPARISON
    # ============================================================
    story.append(Paragraph('2. Annuity Payout Schedule', styles['SectionHead']))

    story.append(Paragraph(
        'Under inflation indexing, the initial $25,000 annuity grows each year by the assumed '
        'rate. This back-loads the payout — Year 1 is identical across all scenarios, but by '
        'Year 10, the difference is material. The chart below shows the annual payout profile.',
        styles['BodyText2']
    ))

    story.append(chart_annuity_schedule(data))
    story.append(Spacer(1, 5*mm))

    # Annuity table
    story.append(Paragraph('Annual Payout by Scenario', styles['SubSection']))

    header = ['Year', 'Flat'] + [f'{s["inflation_rate"]*100:.0f}% Indexed' for s in scenarios]
    annuity_rows = [header]
    for yr in [1, 2, 3, 5, 7, 10]:
        row = [f'Year {yr}', fmt_dollar(baseline['annuity_schedule'][yr])]
        for s in scenarios:
            row.append(fmt_dollar(s['annuity_schedule'][yr]))
        annuity_rows.append(row)

    # Totals
    total_row = ['Total', fmt_dollar(baseline['total_annuity'])]
    for s in scenarios:
        total_row.append(fmt_dollar(s['total_annuity']))
    annuity_rows.append(total_row)

    extra_row = ['Extra vs Flat', '—']
    for s in scenarios:
        extra_row.append(fmt_dollar(s['total_annuity'] - baseline['total_annuity']))
    annuity_rows.append(extra_row)

    widths = [22*mm] + [28*mm] * (len(scenarios) + 1)
    story.append(make_table(annuity_rows, col_widths=widths))

    story.append(Spacer(1, 5*mm))
    story.append(chart_total_payout(data))

    story.append(PageBreak())

    # ============================================================
    # 3. RISK IMPACT
    # ============================================================
    story.append(Paragraph('3. Risk Impact Analysis', styles['SectionHead']))

    story.append(Paragraph(
        'The higher mortgage balance from inflation-indexed payouts increases funder interest costs, '
        'retail margin charges, and LMI premiums. These flow through the investment account over '
        '30 years, reducing surplus and increasing the probability of claim.',
        styles['BodyText2']
    ))

    story.append(Paragraph('3.1 PoC Trajectory', styles['SubSection']))
    story.append(chart_poc_by_year(data))

    story.append(Paragraph(
        'The PoC curves diverge most during years 5–15 (the annuity payment period and immediately '
        'after), then maintain a roughly constant spread through to maturity. This is because the '
        'additional mortgage balance is fixed after Year 10 — no further indexing occurs — but the '
        'higher base continues to generate larger interest and margin costs.',
        styles['BodyText2']
    ))

    story.append(Spacer(1, 3*mm))

    # PoC comparison table
    story.append(Paragraph('3.2 PoC by Year — All Scenarios', styles['SubSection']))

    poc_header = ['Year', 'Flat'] + [f'{s["inflation_rate"]*100:.0f}%' for s in scenarios]
    poc_rows = [poc_header]
    for yr_idx in [0, 4, 9, 14, 19, 24, 29]:
        row = [f'Year {yr_idx+1}', fmt_pct(baseline['deficit_by_year'][yr_idx])]
        for s in scenarios:
            row.append(fmt_pct(s['deficit_by_year'][yr_idx]))
        poc_rows.append(row)

    widths_poc = [22*mm] + [25*mm] * (len(scenarios) + 1)
    story.append(make_table(poc_rows, col_widths=widths_poc))

    story.append(PageBreak())

    # ============================================================
    # 4. SURPLUS DISTRIBUTION
    # ============================================================
    story.append(Paragraph('4. Surplus Distribution Impact', styles['SectionHead']))

    story.append(chart_impact_summary(data))
    story.append(Spacer(1, 5*mm))

    # Full metrics table
    story.append(Paragraph('4.1 Key Metrics — All Scenarios (Year 30)', styles['SubSection']))

    metrics_header = ['Metric', 'Flat'] + [f'{s["inflation_rate"]*100:.0f}% Indexed' for s in scenarios]
    metrics_rows = [metrics_header]

    metric_defs = [
        ('PoC', 'deficit_prob', '%'),
        ('Mean Surplus', 'mean_surplus', '$'),
        ('Median Surplus', 'median_surplus', '$'),
        ('P1 Surplus', 'p1', '$'),
        ('P5 Surplus', 'p5', '$'),
        ('P10 Surplus', 'p10', '$'),
        ('P25 Surplus', 'p25', '$'),
        ('P75 Surplus', 'p75', '$'),
        ('P90 Surplus', 'p90', '$'),
        ('P95 Surplus', 'p95', '$'),
        ('P99 Surplus', 'p99', '$'),
    ]

    for label, key, fmt in metric_defs:
        row = [label]
        if fmt == '%':
            row.append(fmt_pct(baseline[key]))
            for s in scenarios:
                row.append(fmt_pct(s[key]))
        else:
            row.append(fmt_dollar(baseline[key]))
            for s in scenarios:
                row.append(fmt_dollar(s[key]))
        metrics_rows.append(row)

    widths_m = [28*mm] + [27*mm] * (len(scenarios) + 1)
    story.append(make_table(metrics_rows, col_widths=widths_m))

    story.append(Spacer(1, 5*mm))

    # Tail risk chart
    story.append(Paragraph('4.2 Tail Risk — 5th Percentile Surplus', styles['SubSection']))
    story.append(chart_tail_risk(data))

    story.append(PageBreak())

    # ============================================================
    # 5. INSURANCE & COST IMPACT
    # ============================================================
    story.append(Paragraph('5. Insurance & Cost Impact', styles['SectionHead']))

    story.append(Paragraph(
        'Higher mortgage balances increase the LMI upfront premium (calculated on maximum loan) '
        'and widen the potential deficit in adverse scenarios, directly impacting insurance pricing.',
        styles['BodyText2']
    ))

    ins_header = ['Metric', 'Flat'] + [f'{s["inflation_rate"]*100:.0f}%' for s in scenarios]
    ins_rows = [ins_header]

    ins_metrics = [
        ('Max Mortgage', 'max_loan', '$'),
        ('Paths in Deficit', 'n_deficit', '#'),
        ('Cond. Expected Deficit', 'cond_expected_deficit', '$'),
        ('Fair Premium (PV)', 'fair_premium', '$'),
        ('Premium + 50% Loading', 'fair_premium_loaded', '$'),
        ('Mean Profit Share', 'mean_profit_share', '$'),
    ]

    for label, key, fmt in ins_metrics:
        row = [label]
        if fmt == '$':
            row.append(fmt_dollar(baseline[key]))
            for s in scenarios:
                row.append(fmt_dollar(s[key]))
        elif fmt == '#':
            row.append(f'{baseline[key]:,}')
            for s in scenarios:
                row.append(f'{s[key]:,}')
        else:
            row.append(fmt_pct(baseline[key]))
            for s in scenarios:
                row.append(fmt_pct(s[key]))
        ins_rows.append(row)

    widths_ins = [35*mm] + [25*mm] * (len(scenarios) + 1)
    story.append(make_table(ins_rows, col_widths=widths_ins))

    story.append(Spacer(1, 5*mm))

    # Profit share impact
    story.append(Paragraph(
        'Profit share (25% of surplus drawn every 5 years) decreases with inflation indexing '
        'because the higher mortgage balance reduces surplus at each 5-year checkpoint. At 3% '
        f'inflation, mean cumulative profit share falls by '
        f'{fmt_dollar(abs(baseline["mean_profit_share"] - ref["mean_profit_share"]))} '
        f'({abs(baseline["mean_profit_share"] - ref["mean_profit_share"])/baseline["mean_profit_share"]*100:.1f}%).',
        styles['BodyText2']
    ))

    story.append(PageBreak())

    # ============================================================
    # 6. COST MULTIPLIER ANALYSIS
    # ============================================================
    story.append(Paragraph('6. Cost Multiplier Analysis', styles['SectionHead']))

    story.append(Paragraph(
        'Each additional dollar of inflation-indexed annuity does not simply add one dollar to '
        'the mortgage balance. It triggers a cascade of compounding costs over the remaining '
        'term of the mortgage:',
        styles['BodyText2']
    ))

    cost_drivers = [
        '<b>Funder Interest</b> — The wholesale funder charges (cash rate + 2%) on the '
        'average mortgage balance. A higher balance means more interest deducted from the '
        'investment account each year, compounding over 20+ years after the annuity term ends.',

        '<b>Retail Margin</b> — The 0.70% retail margin is applied to the average mortgage '
        'balance, not the investment. Higher mortgage = higher margin cost.',

        '<b>LMI Premium</b> — The upfront LMI is 1.6% of the maximum mortgage balance. '
        'Inflation indexing increases the max balance, raising the day-one cost.',

        '<b>Reduced Compounding Base</b> — Higher costs mean less capital remaining in the '
        'investment account, which then earns lower returns, creating a negative feedback loop.',
    ]

    for driver in cost_drivers:
        story.append(Paragraph(f'• {driver}', styles['BulletItem']))

    story.append(Spacer(1, 3*mm))

    # Cost multiplier table
    story.append(Paragraph('Effective Cost Multiplier by Scenario', styles['SubSection']))

    mult_header = ['Inflation', 'Extra Annuity', 'Mean Surplus Loss', 'Cost Multiplier']
    mult_rows = [mult_header]
    for s in scenarios:
        extra = s['total_annuity'] - baseline['total_annuity']
        loss = baseline['mean_surplus'] - s['mean_surplus']
        multiplier = loss / extra if extra > 0 else 0
        mult_rows.append([
            f'{s["inflation_rate"]*100:.1f}%',
            fmt_dollar(extra),
            fmt_dollar(loss),
            f'{multiplier:.2f}x'
        ])

    story.append(make_table(mult_rows, col_widths=[30*mm, 40*mm, 40*mm, 40*mm]))

    story.append(Spacer(1, 5*mm))
    story.append(Paragraph(
        'The cost multiplier ranges from 2.1x to 2.2x across scenarios. This means that for '
        'every additional $1 paid to the borrower through inflation indexing, the model loses '
        'approximately $2.20 in expected surplus at maturity. This is a fundamental feature of '
        'the EPM structure: additional mortgage balance compounds through multiple cost layers '
        'over the remaining 20+ year term.',
        styles['BodyText2']
    ))

    story.append(PageBreak())

    # ============================================================
    # 7. CONCLUSIONS & RECOMMENDATIONS
    # ============================================================
    story.append(Paragraph('7. Conclusions & Recommendations', styles['SectionHead']))

    story.append(Paragraph(
        'Inflation indexing the annuity payout is feasible within the EPM structure but carries '
        'measurable costs. The key trade-off is between protecting the borrower\'s purchasing power '
        'and maintaining surplus adequacy for all stakeholders.',
        styles['BodyText2']
    ))

    story.append(Spacer(1, 3*mm))
    story.append(Paragraph('Assessment by Inflation Assumption', styles['SubSection']))

    assessments = [
        ('<b>2.0% (Low Inflation)</b> — PoC increases by +1.28pp to 15.15%. '
         'The additional $23,743 in total payouts is a modest step-up that keeps '
         'risk metrics well within tolerance. This is the most conservative option.'),

        ('<b>2.5% (Below-Target)</b> — PoC increases by +1.71pp to 15.58%. '
         'Still within acceptable range. Total extra payout of $30,085 represents '
         'a 12% increase in borrower income.'),

        ('<b>3.0% (Target Inflation)</b> — PoC increases by +2.13pp to 16.00%. '
         'Total extra payout of $36,597 (14.6% increase). Manageable impact on '
         'surplus and insurance, but approaches the boundary of comfortable risk.'),

        ('<b>3.5–4.0% (Above-Target)</b> — PoC increases by +2.49pp to +2.91pp. '
         'P5 surplus deteriorates by $134K–$158K. Insurance premiums rise 24–28%. '
         'These scenarios may require offsetting adjustments (e.g., lower initial '
         'annuity or higher LMI loading).'),
    ]

    for a in assessments:
        story.append(Paragraph(f'• {a}', styles['BulletItem']))

    story.append(Spacer(1, 5*mm))
    story.append(Paragraph('Implementation Considerations', styles['SubSection']))

    considerations = [
        'If inflation indexing is adopted, consider linking to a specific CPI measure '
        '(e.g., trimmed mean CPI) rather than a fixed assumed rate, to avoid overshoot risk.',

        'The initial annuity amount could be reduced slightly (e.g., $24,000) when '
        'indexing is applied, to keep total expected payout and risk metrics closer to '
        'the flat baseline.',

        'Insurance pricing should be updated to reflect the higher conditional expected '
        'deficit under indexed payouts — the current LMI upfront of 1.6% may need '
        'adjustment.',

        'Profit share calculations are unaffected in structure but yield lower absolute '
        'amounts due to reduced surplus at 5-year checkpoints.',
    ]

    for c in considerations:
        story.append(Paragraph(f'• {c}', styles['BulletItem']))

    story.append(Spacer(1, 10*mm))

    # Methodology note
    story.append(Paragraph('Methodology', styles['SubSection']))
    story.append(Paragraph(
        'All scenarios use the v14a model parameters with 50,000 Monte Carlo paths and identical '
        'random number generation (seed=42). This ensures that differences between scenarios '
        'are attributable solely to the inflation indexing mechanism, not to sampling variation. '
        'Investment returns follow geometric Brownian motion with buffer cap (120%) and floor (80%). '
        'Cash rates follow an Ornstein-Uhlenbeck process with mean reversion to 4.4%. '
        'The holiday mechanism, profit share (25% every 5 years), and collar pricing are all '
        'applied identically across scenarios.',
        styles['BodyText2']
    ))

    story.append(Spacer(1, 5*mm))
    story.append(Paragraph(
        'This report is confidential and intended for internal use only. '
        'FutureProof Financial — March 2025.',
        styles['SmallNote']
    ))

    # Build PDF
    doc.build(story)
    print(f"\nReport generated: {output_path}")
    return output_path


if __name__ == '__main__':
    with open('inflation_analysis_results.json') as f:
        data = json.load(f)
    build_report(data)
