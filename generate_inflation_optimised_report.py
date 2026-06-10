#!/usr/bin/env python3
"""
Generate FutureProof EPM v14a OPTIMISED Inflation-Indexed Annuity Analysis Report
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

# Colour palette
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

COLOURS_MPL = ['#2C3E50', '#2980B9', '#3498A8', '#27AE60', '#E67E22', '#C0392B']


def get_styles():
    styles = getSampleStyleSheet()
    styles.add(ParagraphStyle('ReportTitle', parent=styles['Title'], fontSize=28, leading=34,
        textColor=DARK_NAVY, spaceAfter=6*mm, alignment=TA_LEFT, fontName='Helvetica-Bold'))
    styles.add(ParagraphStyle('ReportSubtitle', parent=styles['Normal'], fontSize=14, leading=18,
        textColor=TEAL, spaceAfter=10*mm, alignment=TA_LEFT, fontName='Helvetica'))
    styles.add(ParagraphStyle('SectionHead', parent=styles['Heading1'], fontSize=16, leading=20,
        textColor=DARK_NAVY, spaceBefore=8*mm, spaceAfter=4*mm, fontName='Helvetica-Bold'))
    styles.add(ParagraphStyle('SubSection', parent=styles['Heading2'], fontSize=13, leading=16,
        textColor=TEAL, spaceBefore=5*mm, spaceAfter=3*mm, fontName='Helvetica-Bold'))
    styles.add(ParagraphStyle('BodyText2', parent=styles['Normal'], fontSize=10, leading=14,
        textColor=DARK_NAVY, spaceAfter=3*mm, alignment=TA_JUSTIFY, fontName='Helvetica'))
    styles.add(ParagraphStyle('SmallNote', parent=styles['Normal'], fontSize=8, leading=10,
        textColor=MID_GREY, spaceAfter=2*mm, fontName='Helvetica-Oblique'))
    styles.add(ParagraphStyle('BulletItem', parent=styles['Normal'], fontSize=10, leading=14,
        textColor=DARK_NAVY, leftIndent=15, spaceAfter=2*mm, fontName='Helvetica', bulletIndent=5))
    styles.add(ParagraphStyle('KeyFinding', parent=styles['Normal'], fontSize=11, leading=15,
        textColor=DARK_NAVY, leftIndent=10, spaceAfter=3*mm, fontName='Helvetica-Bold',
        borderWidth=1, borderColor=TEAL, borderPadding=6, backColor=HexColor('#F0F8FF')))
    return styles


def make_table(data, col_widths=None, header_rows=1):
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
    for i in range(header_rows, len(data)):
        if (i - header_rows) % 2 == 1:
            style_cmds.append(('BACKGROUND', (0, i), (-1, i), ROW_ALT))
    t = Table(data, colWidths=col_widths, repeatRows=header_rows)
    t.setStyle(TableStyle(style_cmds))
    return t


def fig_to_image(fig, width=160*mm, height=100*mm):
    buf = BytesIO()
    fig.savefig(buf, format='png', dpi=150, bbox_inches='tight')
    plt.close(fig)
    buf.seek(0)
    return Image(buf, width=width, height=height)


def fmt_dollar(val):
    return f"${val:,.0f}" if val >= 0 else f"-${abs(val):,.0f}"

def fmt_pct(val):
    return f"{val:.2f}%"

def fmt_pp(val):
    return f"+{val:.2f}pp" if val >= 0 else f"{val:.2f}pp"


def chart_annuity_schedule(data):
    fig, ax = plt.subplots(figsize=(10, 5))
    baseline = data['baseline']
    scenarios = [baseline] + data['inflation_scenarios']
    labels = ['Flat'] + [f"{s['inflation_rate']*100:.0f}%" for s in data['inflation_scenarios']]
    years = list(range(1, 11))
    x = np.arange(len(years))
    width = 0.13
    offsets = np.arange(len(scenarios)) - (len(scenarios) - 1) / 2
    for i, (scenario, label, colour) in enumerate(zip(scenarios, labels, COLOURS_MPL)):
        payments = [scenario['annuity_schedule'][yr] for yr in years]
        ax.bar(x + offsets[i] * width, payments, width * 0.9, label=label, color=colour, alpha=0.85)
    ax.set_xlabel('Year', fontsize=11)
    ax.set_ylabel('Annual Payout ($)', fontsize=11)
    ax.set_title('Annuity Payout Schedule — Flat vs Inflation-Indexed (Optimised PI)', fontsize=13, fontweight='bold')
    ax.set_xticks(x)
    ax.set_xticklabels(years)
    ax.yaxis.set_major_formatter(mticker.FuncFormatter(lambda v, p: f'${v:,.0f}'))
    ax.legend(title='Inflation Rate', fontsize=9, title_fontsize=10)
    ax.grid(axis='y', alpha=0.3)
    fig.tight_layout()
    return fig_to_image(fig, width=170*mm, height=95*mm)


def chart_poc_by_year(data):
    fig, ax = plt.subplots(figsize=(10, 5.5))
    baseline = data['baseline']
    scenarios = [baseline] + data['inflation_scenarios']
    labels = ['Flat $25K'] + [f"{s['inflation_rate']*100:.0f}% Indexed" for s in data['inflation_scenarios']]
    years = list(range(1, 31))
    for i, (scenario, label, colour) in enumerate(zip(scenarios, labels, COLOURS_MPL)):
        lw = 2.5 if i == 0 else 1.5
        ls = '-' if i == 0 else '--'
        ax.plot(years, scenario['deficit_by_year'], label=label, color=colour, linewidth=lw, linestyle=ls)
    ax.set_xlabel('Year', fontsize=11)
    ax.set_ylabel('Probability of Claim (%)', fontsize=11)
    ax.set_title('PoC Trajectory — Optimised PI Model', fontsize=13, fontweight='bold')
    ax.legend(fontsize=9, loc='upper right')
    ax.grid(alpha=0.3)
    ax.set_xlim(1, 30)
    ax.set_ylim(0, None)
    fig.tight_layout()
    return fig_to_image(fig, width=170*mm, height=100*mm)


def chart_mortgage_amortisation(data):
    fig, ax = plt.subplots(figsize=(10, 5))
    baseline = data['baseline']
    scenarios = [baseline] + data['inflation_scenarios']
    labels = ['Flat'] + [f"{s['inflation_rate']*100:.0f}% Indexed" for s in data['inflation_scenarios']]
    years = list(range(0, 31))
    for i, (scenario, label, colour) in enumerate(zip(scenarios, labels, COLOURS_MPL)):
        loan_vals = [scenario['loan_schedule'][yr] / 1000 for yr in years]
        lw = 2.5 if i == 0 else 1.5
        ls = '-' if i == 0 else '--'
        ax.plot(years, loan_vals, label=label, color=colour, linewidth=lw, linestyle=ls)
    ax.set_xlabel('Year', fontsize=11)
    ax.set_ylabel('Mortgage Balance ($K)', fontsize=11)
    ax.set_title('Mortgage Balance — PI Amortisation Profile', fontsize=13, fontweight='bold')
    ax.legend(fontsize=9)
    ax.grid(alpha=0.3)
    ax.axvline(x=10, color='grey', linewidth=0.8, linestyle=':', label='_')
    ax.text(10.5, 1650, 'Annuity ends\nAmortisation begins', fontsize=8, color='grey')
    ax.yaxis.set_major_formatter(mticker.FuncFormatter(lambda v, p: f'${v:,.0f}K'))
    fig.tight_layout()
    return fig_to_image(fig, width=170*mm, height=95*mm)


def chart_impact_summary(data):
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(12, 5))
    baseline = data['baseline']
    rates = [f"{s['inflation_rate']*100:.0f}%" for s in data['inflation_scenarios']]
    poc_deltas = [s['deficit_prob'] - baseline['deficit_prob'] for s in data['inflation_scenarios']]
    surplus_deltas = [s['mean_surplus'] - baseline['mean_surplus'] for s in data['inflation_scenarios']]
    colours = COLOURS_MPL[1:]

    ax1.bar(rates, poc_deltas, color=colours, alpha=0.85)
    ax1.set_xlabel('Inflation Rate', fontsize=11)
    ax1.set_ylabel('PoC Increase (pp)', fontsize=11)
    ax1.set_title('PoC Impact', fontsize=13, fontweight='bold')
    ax1.grid(axis='y', alpha=0.3)
    for i, v in enumerate(poc_deltas):
        ax1.text(i, v + 0.02, f"+{v:.2f}pp", ha='center', va='bottom', fontsize=9, fontweight='bold')

    ax2.bar(rates, [d / 1000 for d in surplus_deltas], color=colours, alpha=0.85)
    ax2.set_xlabel('Inflation Rate', fontsize=11)
    ax2.set_ylabel('Mean Surplus Change ($K)', fontsize=11)
    ax2.set_title('Mean Surplus Impact', fontsize=13, fontweight='bold')
    ax2.grid(axis='y', alpha=0.3)
    for i, v in enumerate(surplus_deltas):
        ax2.text(i, v / 1000 - 1, f"-${abs(v)/1000:.0f}K", ha='center', va='top', fontsize=9, fontweight='bold')

    fig.tight_layout()
    return fig_to_image(fig, width=170*mm, height=90*mm)


def chart_comparison_io_vs_pi(data, io_data):
    """Compare IO (unoptimised) vs PI (optimised) inflation sensitivity."""
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(12, 5))

    rates = [s['inflation_rate'] * 100 for s in data['inflation_scenarios']]

    # PI (optimised)
    pi_poc_deltas = [s['deficit_prob'] - data['baseline']['deficit_prob'] for s in data['inflation_scenarios']]
    # IO (unoptimised)
    io_poc_deltas = [s['deficit_prob'] - io_data['baseline']['deficit_prob'] for s in io_data['inflation_scenarios']]

    x = np.arange(len(rates))
    w = 0.35
    ax1.bar(x - w/2, io_poc_deltas, w, label='IO (Unoptimised)', color='#C0392B', alpha=0.7)
    ax1.bar(x + w/2, pi_poc_deltas, w, label='PI (Optimised)', color='#27AE60', alpha=0.7)
    ax1.set_xlabel('Inflation Rate (%)', fontsize=11)
    ax1.set_ylabel('PoC Increase (pp)', fontsize=11)
    ax1.set_title('PoC Sensitivity to Inflation', fontsize=13, fontweight='bold')
    ax1.set_xticks(x)
    ax1.set_xticklabels([f'{r:.0f}%' for r in rates])
    ax1.legend(fontsize=9)
    ax1.grid(axis='y', alpha=0.3)

    # Absolute PoC levels
    pi_pocs = [data['baseline']['deficit_prob']] + [s['deficit_prob'] for s in data['inflation_scenarios']]
    io_pocs = [io_data['baseline']['deficit_prob']] + [s['deficit_prob'] for s in io_data['inflation_scenarios']]
    rate_labels = ['Flat'] + [f'{r:.0f}%' for r in rates]

    ax2.plot(rate_labels, io_pocs, 'o-', label='IO (Unoptimised)', color='#C0392B', linewidth=2)
    ax2.plot(rate_labels, pi_pocs, 'o-', label='PI (Optimised)', color='#27AE60', linewidth=2)
    ax2.set_xlabel('Inflation Scenario', fontsize=11)
    ax2.set_ylabel('PoC at Year 30 (%)', fontsize=11)
    ax2.set_title('Absolute PoC Levels', fontsize=13, fontweight='bold')
    ax2.legend(fontsize=9)
    ax2.grid(alpha=0.3)

    fig.tight_layout()
    return fig_to_image(fig, width=170*mm, height=90*mm)


def chart_tail_risk(data):
    fig, ax = plt.subplots(figsize=(8, 4.5))
    baseline = data['baseline']
    scenarios = [baseline] + data['inflation_scenarios']
    labels = ['Flat'] + [f"{s['inflation_rate']*100:.0f}%" for s in data['inflation_scenarios']]
    p5_vals = [s['p5'] / 1000 for s in scenarios]
    bars = ax.bar(labels, p5_vals, color=COLOURS_MPL, alpha=0.85)
    ax.set_ylabel('P5 Surplus ($K)', fontsize=11)
    ax.set_title('5th Percentile Surplus (Tail Risk) — Year 30', fontsize=13, fontweight='bold')
    ax.grid(axis='y', alpha=0.3)
    ax.axhline(y=0, color='black', linewidth=0.8)
    for bar, val, raw in zip(bars, p5_vals, [s['p5'] for s in scenarios]):
        if raw >= 0:
            ax.text(bar.get_x() + bar.get_width()/2, val + 3,
                    f'${val:.0f}K', ha='center', va='bottom', fontsize=9, fontweight='bold')
        else:
            ax.text(bar.get_x() + bar.get_width()/2, val - 3,
                    f'-${abs(val):.0f}K', ha='center', va='top', fontsize=9, fontweight='bold', color='white')
    fig.tight_layout()
    return fig_to_image(fig, width=160*mm, height=85*mm)


def build_report(data, io_data=None):
    output_path = 'FutureProof_EPM_v14a_Inflation_Analysis_Optimised_Mar2025.pdf'
    doc = SimpleDocTemplate(output_path, pagesize=A4,
        leftMargin=20*mm, rightMargin=20*mm, topMargin=20*mm, bottomMargin=20*mm)

    styles = get_styles()
    story = []
    baseline = data['baseline']
    scenarios = data['inflation_scenarios']
    opt_params = data['optimisation_params']

    # ============================================================
    # TITLE PAGE
    # ============================================================
    story.append(Spacer(1, 30*mm))
    story.append(Paragraph('FutureProof EPM', styles['ReportTitle']))
    story.append(Paragraph('Inflation-Indexed Annuity<br/>Impact Analysis', styles['ReportTitle']))
    story.append(Spacer(1, 3*mm))
    story.append(Paragraph('Optimised Model (Principal &amp; Interest)', styles['ReportSubtitle']))
    story.append(Spacer(1, 5*mm))
    story.append(Paragraph('v14a Optimised — 50,000-Path Monte Carlo Simulation', styles['BodyText2']))
    story.append(Paragraph('March 2025', styles['BodyText2']))
    story.append(Paragraph('Confidential — For Internal Use Only', styles['SmallNote']))
    story.append(Spacer(1, 15*mm))

    summary_data = [
        ['Parameter', 'Optimised Value'],
        ['Model', 'v14a Optimised (PI)'],
        ['Mortgage Type', 'Principal & Interest (amortises to $0)'],
        ['Property Value', '$2,000,000'],
        ['Initial Mortgage', '$1,350,000'],
        ['Peak Mortgage (Year 10)', fmt_dollar(baseline['max_loan'])],
        ['Mortgage at Maturity', '$0'],
        ['Holiday Entry', f"{opt_params['holiday_entry']:.2f}x (vs 0.90x baseline)"],
        ['Profit Share', f"{opt_params['profit_share_pct']*100:.0f}% every {opt_params['profit_share_years']} years"],
        ['Baseline PoC (Year 30)', fmt_pct(baseline['deficit_prob'])],
        ['Inflation Rates Tested', '2.0%, 2.5%, 3.0%, 3.5%, 4.0%'],
    ]
    story.append(make_table(summary_data, col_widths=[55*mm, 115*mm]))

    story.append(PageBreak())

    # ============================================================
    # 1. EXECUTIVE SUMMARY
    # ============================================================
    story.append(Paragraph('1. Executive Summary', styles['SectionHead']))

    story.append(Paragraph(
        'This analysis examines the impact of inflation-indexing the EPM annuity payout using '
        'the <b>optimised Principal &amp; Interest model</b>. Unlike the interest-only baseline, '
        'this model amortises the mortgage to zero over 20 years (from Year 11 to Year 30), '
        'dramatically reducing PoC from ~14% to ~5%. The question is whether this structural '
        'improvement provides enough headroom to absorb inflation-indexed payouts.',
        styles['BodyText2']
    ))

    ref = next(s for s in scenarios if s['inflation_rate'] == 0.03)
    poc_delta = ref['deficit_prob'] - baseline['deficit_prob']
    surplus_delta = ref['mean_surplus'] - baseline['mean_surplus']
    extra_annuity = ref['total_annuity'] - baseline['total_annuity']

    story.append(Spacer(1, 3*mm))
    story.append(Paragraph('Key Findings', styles['SubSection']))

    findings = [
        f'The optimised PI model absorbs inflation indexing <b>significantly better</b> than the '
        f'IO model. At 3% inflation, PoC rises by only {fmt_pp(poc_delta)} (from '
        f'{fmt_pct(baseline["deficit_prob"])} to {fmt_pct(ref["deficit_prob"])}), compared with '
        f'+2.13pp in the IO model.',

        f'Even at 4% inflation, PoC remains at just {fmt_pct(scenarios[-1]["deficit_prob"])} — '
        f'well below the unoptimised IO baseline of 13.87% <i>without</i> inflation indexing.',

        f'Total annuity at 3% inflation increases by {fmt_dollar(extra_annuity)} '
        f'({extra_annuity/baseline["total_annuity"]*100:.1f}%), identical to the IO analysis. '
        f'But the surplus impact is smaller: {fmt_dollar(abs(surplus_delta))} vs $81K in IO.',

        f'The cost multiplier drops to ~1.3x (from ~2.2x in IO), because PI amortisation reduces '
        f'the mortgage balance faster, limiting the compounding of interest and margin costs.',

        f'P5 surplus shifts from {fmt_dollar(baseline["p5"])} (positive) to '
        f'{fmt_dollar(ref["p5"])} (negative) — the tail risk boundary is more sensitive, '
        f'but the absolute level remains far better than IO.',

        f'Insurance premium increases from {fmt_dollar(baseline["fair_premium_loaded"])} to '
        f'{fmt_dollar(ref["fair_premium_loaded"])} — a '
        f'{(ref["fair_premium_loaded"]/baseline["fair_premium_loaded"]-1)*100:.0f}% increase, '
        f'but still well below the IO model\'s {fmt_dollar(39541)} at the same inflation rate.',
    ]

    for f in findings:
        story.append(Paragraph(f'&bull; {f}', styles['BulletItem']))

    story.append(PageBreak())

    # ============================================================
    # 2. OPTIMISED MODEL STRUCTURE
    # ============================================================
    story.append(Paragraph('2. Optimised Model Structure', styles['SectionHead']))

    story.append(Paragraph(
        'The optimised model differs from the baseline in three key respects that collectively '
        'reduce PoC from ~14% to ~5%:',
        styles['BodyText2']
    ))

    opt_features = [
        '<b>Principal &amp; Interest Amortisation</b> — After the 10-year annuity period, the '
        'mortgage amortises linearly to $0 over the remaining 20 years. This eliminates the '
        'end-of-term balance that drives deficit risk in the IO model. Annual principal '
        f'repayment: {fmt_dollar(baseline["max_loan"] / 20)}/year from the investment account.',

        '<b>Higher Holiday Entry (1.05x vs 0.90x)</b> — The holiday mechanism triggers earlier, '
        'providing more protection when investment values decline. This increases holiday usage '
        'but prevents investment depletion in adverse scenarios.',

        '<b>More Frequent Profit Share (20% every 3 years vs 25% every 5 years)</b> — Smaller, '
        'more frequent profit extractions smooth the revenue stream while maintaining total '
        f'revenue: mean total profit share is {fmt_dollar(baseline["mean_profit_share"])}.',
    ]

    for feat in opt_features:
        story.append(Paragraph(f'&bull; {feat}', styles['BulletItem']))

    story.append(Spacer(1, 5*mm))
    story.append(Paragraph('Mortgage Amortisation Profile', styles['SubSection']))
    story.append(chart_mortgage_amortisation(data))

    story.append(Spacer(1, 3*mm))

    # Mortgage balance table
    mort_header = ['Year', 'Flat'] + [f'{s["inflation_rate"]*100:.0f}% Indexed' for s in scenarios]
    mort_rows = [mort_header]
    for yr in [0, 5, 10, 15, 20, 25, 30]:
        row = [f'Year {yr}', fmt_dollar(baseline['loan_schedule'][yr])]
        for s in scenarios:
            row.append(fmt_dollar(s['loan_schedule'][yr]))
        mort_rows.append(row)
    widths = [22*mm] + [28*mm] * (len(scenarios) + 1)
    story.append(make_table(mort_rows, col_widths=widths))

    story.append(PageBreak())

    # ============================================================
    # 3. ANNUITY SCHEDULE
    # ============================================================
    story.append(Paragraph('3. Annuity Payout Schedule', styles['SectionHead']))

    story.append(Paragraph(
        'The annuity payout schedule is identical to the IO analysis — the only difference is '
        'how the resulting mortgage balance is treated after Year 10.',
        styles['BodyText2']
    ))

    story.append(chart_annuity_schedule(data))
    story.append(Spacer(1, 5*mm))

    header = ['Year', 'Flat'] + [f'{s["inflation_rate"]*100:.0f}% Indexed' for s in scenarios]
    annuity_rows = [header]
    for yr in [1, 2, 3, 5, 7, 10]:
        row = [f'Year {yr}', fmt_dollar(baseline['annuity_schedule'][yr])]
        for s in scenarios:
            row.append(fmt_dollar(s['annuity_schedule'][yr]))
        annuity_rows.append(row)
    total_row = ['Total', fmt_dollar(baseline['total_annuity'])]
    for s in scenarios:
        total_row.append(fmt_dollar(s['total_annuity']))
    annuity_rows.append(total_row)
    extra_row = ['Extra vs Flat', '—']
    for s in scenarios:
        extra_row.append(fmt_dollar(s['total_annuity'] - baseline['total_annuity']))
    annuity_rows.append(extra_row)
    story.append(make_table(annuity_rows, col_widths=widths))

    story.append(PageBreak())

    # ============================================================
    # 4. RISK IMPACT
    # ============================================================
    story.append(Paragraph('4. Risk Impact Analysis', styles['SectionHead']))

    story.append(Paragraph('4.1 PoC Trajectory', styles['SubSection']))
    story.append(chart_poc_by_year(data))

    story.append(Paragraph(
        'The PoC curves show the hallmark of PI amortisation: a steep decline from Year 10 onwards '
        'as principal repayments reduce the mortgage balance. The inflation-indexed scenarios '
        'maintain the same shape but with a modest vertical offset. By Year 25, even the 4% '
        f'scenario ({fmt_pct(scenarios[-1]["deficit_by_year"][24])}) is below the flat IO baseline.',
        styles['BodyText2']
    ))

    story.append(Spacer(1, 3*mm))
    story.append(Paragraph('4.2 PoC by Year — All Scenarios', styles['SubSection']))

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
    # 5. SURPLUS DISTRIBUTION
    # ============================================================
    story.append(Paragraph('5. Surplus Distribution Impact', styles['SectionHead']))

    story.append(chart_impact_summary(data))
    story.append(Spacer(1, 5*mm))

    story.append(Paragraph('5.1 Key Metrics — All Scenarios (Year 30)', styles['SubSection']))

    metrics_header = ['Metric', 'Flat'] + [f'{s["inflation_rate"]*100:.0f}% Indexed' for s in scenarios]
    metrics_rows = [metrics_header]
    metric_defs = [
        ('PoC', 'deficit_prob', '%'), ('Mean Surplus', 'mean_surplus', '$'),
        ('Median Surplus', 'median_surplus', '$'), ('P1 Surplus', 'p1', '$'),
        ('P5 Surplus', 'p5', '$'), ('P10 Surplus', 'p10', '$'),
        ('P25 Surplus', 'p25', '$'), ('P75 Surplus', 'p75', '$'),
        ('P90 Surplus', 'p90', '$'), ('P95 Surplus', 'p95', '$'),
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
    story.append(Paragraph('5.2 Tail Risk — 5th Percentile Surplus', styles['SubSection']))
    story.append(chart_tail_risk(data))

    story.append(Paragraph(
        f'A critical observation: the flat PI baseline has a <b>positive</b> P5 surplus '
        f'({fmt_dollar(baseline["p5"])}), meaning 95% of paths end in surplus. Inflation indexing '
        f'at 3%+ pushes P5 negative, but the magnitude is modest relative to IO.',
        styles['BodyText2']
    ))

    story.append(PageBreak())

    # ============================================================
    # 6. COMPARISON: IO vs PI SENSITIVITY
    # ============================================================
    story.append(Paragraph('6. IO vs PI Model Comparison', styles['SectionHead']))

    if io_data:
        story.append(Paragraph(
            'The PI (optimised) model is substantially less sensitive to inflation indexing than '
            'the IO (unoptimised) model. This is because PI amortisation reduces the mortgage '
            'balance after Year 10, limiting the period over which higher balances compound costs.',
            styles['BodyText2']
        ))

        story.append(chart_comparison_io_vs_pi(data, io_data))
        story.append(Spacer(1, 5*mm))

        # Side-by-side comparison table
        comp_header = ['Metric', 'IO Flat', 'IO @ 3%', 'IO Δ', 'PI Flat', 'PI @ 3%', 'PI Δ']
        comp_rows = [comp_header]

        io_base = io_data['baseline']
        io_3 = next(s for s in io_data['inflation_scenarios'] if s['inflation_rate'] == 0.03)
        pi_base = baseline
        pi_3 = ref

        comp_metrics = [
            ('PoC (Yr 30)', 'deficit_prob', '%'),
            ('Mean Surplus', 'mean_surplus', '$'),
            ('P5 Surplus', 'p5', '$'),
            ('P10 Surplus', 'p10', '$'),
            ('Insurance (loaded)', 'fair_premium_loaded', '$'),
            ('Profit Share', 'mean_profit_share', '$'),
        ]

        for label, key, fmt in comp_metrics:
            if fmt == '%':
                row = [label,
                       fmt_pct(io_base[key]), fmt_pct(io_3[key]),
                       fmt_pp(io_3[key] - io_base[key]),
                       fmt_pct(pi_base[key]), fmt_pct(pi_3[key]),
                       fmt_pp(pi_3[key] - pi_base[key])]
            else:
                row = [label,
                       fmt_dollar(io_base[key]), fmt_dollar(io_3[key]),
                       fmt_dollar(io_3[key] - io_base[key]),
                       fmt_dollar(pi_base[key]), fmt_dollar(pi_3[key]),
                       fmt_dollar(pi_3[key] - pi_base[key])]
            comp_rows.append(row)

        story.append(make_table(comp_rows, col_widths=[30*mm, 25*mm, 25*mm, 22*mm, 25*mm, 25*mm, 22*mm]))

        story.append(Spacer(1, 5*mm))
        story.append(Paragraph(
            'The PI model reduces inflation sensitivity by approximately 60%: PoC increases by '
            f'+{poc_delta:.2f}pp vs +2.13pp in IO, and mean surplus declines by '
            f'{fmt_dollar(abs(surplus_delta))} vs $81K. This makes the optimised model a '
            f'strong candidate for offering inflation-indexed payouts as a product feature.',
            styles['BodyText2']
        ))
    else:
        story.append(Paragraph(
            'IO model results not available for comparison. Run the IO inflation analysis first.',
            styles['BodyText2']
        ))

    story.append(PageBreak())

    # ============================================================
    # 7. COST MULTIPLIER
    # ============================================================
    story.append(Paragraph('7. Cost Multiplier Analysis', styles['SectionHead']))

    story.append(Paragraph(
        'The cost multiplier measures how much mean surplus is lost per additional dollar of '
        'annuity paid. In the PI model, this is significantly lower than IO because the higher '
        'mortgage balance amortises away, limiting the compounding period.',
        styles['BodyText2']
    ))

    mult_header = ['Inflation', 'Extra Annuity', 'Surplus Loss', 'Multiplier', 'IO Multiplier']
    mult_rows = [mult_header]
    for i, s in enumerate(scenarios):
        extra = s['total_annuity'] - baseline['total_annuity']
        loss = baseline['mean_surplus'] - s['mean_surplus']
        multiplier = loss / extra if extra > 0 else 0
        io_mult = '—'
        if io_data:
            io_s = io_data['inflation_scenarios'][i]
            io_extra = io_s['total_annuity'] - io_data['baseline']['total_annuity']
            io_loss = io_data['baseline']['mean_surplus'] - io_s['mean_surplus']
            io_mult = f'{io_loss / io_extra:.2f}x' if io_extra > 0 else '—'
        mult_rows.append([
            f'{s["inflation_rate"]*100:.1f}%',
            fmt_dollar(extra),
            fmt_dollar(loss),
            f'{multiplier:.2f}x',
            io_mult,
        ])
    story.append(make_table(mult_rows, col_widths=[22*mm, 30*mm, 30*mm, 28*mm, 28*mm]))

    story.append(Spacer(1, 5*mm))
    story.append(Paragraph(
        'The PI cost multiplier of ~1.3x means that each additional $1 of inflation-indexed '
        'annuity reduces surplus by approximately $1.30 — much closer to a 1:1 relationship '
        'than the IO model\'s ~2.2x. The fundamental reason is that PI amortisation eliminates '
        'the mortgage balance by Year 30, so the higher balance from indexed payouts only '
        'compounds costs for ~20 years (the amortisation period) rather than the full 30.',
        styles['BodyText2']
    ))

    story.append(PageBreak())

    # ============================================================
    # 8. CONCLUSIONS
    # ============================================================
    story.append(Paragraph('8. Conclusions &amp; Recommendations', styles['SectionHead']))

    story.append(Paragraph(
        'The optimised PI model provides substantial headroom for inflation-indexed annuity '
        'payouts. The structural advantages of principal amortisation absorb the additional '
        'cost of indexed payouts with minimal impact on risk metrics.',
        styles['BodyText2']
    ))

    story.append(Spacer(1, 3*mm))
    story.append(Paragraph('Assessment', styles['SubSection']))

    assessments = [
        f'<b>2.0–2.5% Inflation</b> — PoC increases by +0.58pp to +0.72pp, remaining below '
        f'6%. P5 surplus moves slightly negative but P10 stays well positive. '
        f'<b>Highly recommended</b> — negligible risk impact with meaningful borrower benefit.',

        f'<b>3.0% Inflation</b> — PoC increases by +0.85pp to {fmt_pct(ref["deficit_prob"])}. '
        f'Mean surplus declines by {fmt_dollar(abs(surplus_delta))}. Insurance premium increases '
        f'by {fmt_dollar(ref["fair_premium_loaded"] - baseline["fair_premium_loaded"])}. '
        f'<b>Recommended</b> — comfortably within risk tolerance.',

        f'<b>3.5–4.0% Inflation</b> — PoC reaches {fmt_pct(scenarios[-1]["deficit_prob"])}. '
        f'Still well below the unoptimised IO baseline of 13.87%. P5 surplus of '
        f'{fmt_dollar(scenarios[-1]["p5"])} is the main concern. '
        f'<b>Acceptable</b> — but consider a slight reduction in initial annuity to offset.',
    ]

    for a in assessments:
        story.append(Paragraph(f'&bull; {a}', styles['BulletItem']))

    story.append(Spacer(1, 5*mm))
    story.append(Paragraph('Recommendation', styles['SubSection']))

    story.append(Paragraph(
        'The optimised PI model can comfortably support inflation-indexed payouts at 2.5–3.0% '
        'without any structural changes. At these rates, PoC remains under 6% (vs the IO model\'s '
        '16%), and all risk metrics stay within acceptable bounds. This represents a compelling '
        'product enhancement: borrowers receive inflation-protected income while the mortgage '
        'structure ensures the investment account can absorb the additional cost.',
        styles['KeyFinding']
    ))

    story.append(Spacer(1, 10*mm))

    story.append(Paragraph('Methodology', styles['SubSection']))
    story.append(Paragraph(
        'All scenarios use the v14a optimised parameters (PI amortisation, holiday entry 1.05, '
        'profit share 20%/3yr) with 50,000 Monte Carlo paths and identical random number '
        'generation (seed=42). The PI amortisation reduces the mortgage linearly from peak '
        '(Year 10) to $0 (Year 30), with principal repayments deducted from the investment '
        'account. All other mechanics (holiday, collar, GBM returns, OU cash rate) are identical.',
        styles['BodyText2']
    ))

    story.append(Spacer(1, 5*mm))
    story.append(Paragraph(
        'This report is confidential and intended for internal use only. '
        'FutureProof Financial — March 2025.',
        styles['SmallNote']
    ))

    doc.build(story)
    print(f"\nReport generated: {output_path}")
    return output_path


if __name__ == '__main__':
    with open('inflation_analysis_optimised_results.json') as f:
        data = json.load(f)

    # Try to load IO results for comparison
    io_data = None
    try:
        with open('inflation_analysis_results.json') as f:
            io_data = json.load(f)
        print("Loaded IO results for comparison")
    except FileNotFoundError:
        print("IO results not found — skipping comparison")

    build_report(data, io_data)
