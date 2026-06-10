#!/usr/bin/env python3
"""
Generate PDF report for EPM Scenario Analysis:
  1. Loan term mix — removing 15yr terms
  2. Top cover limit — P10 vs P20 vs P30
Styled to match generate_v14_reports.py
"""

import json
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
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
# COLOUR PALETTE (matching v10/v14 reports)
# ============================================================
DARK_NAVY = HexColor('#2C3E50')
TEAL = HexColor('#3498A8')
CORAL = HexColor('#C0392B')
LIGHT_GREY = HexColor('#F5F5F5')
MID_GREY = HexColor('#95A5A6')
WHITE = colors.white
HEADER_BG = HexColor('#2C3E50')
ROW_ALT = HexColor('#F8F9FA')

# Matplotlib hex strings
MPL = {
    'navy': '#2C3E50', 'teal': '#3498A8', 'coral': '#C0392B',
    'grey': '#95A5A6', 'green': '#27AE60', 'amber': '#F39C12',
    'purple': '#8E44AD', 'blue': '#2980B9',
}

# ============================================================
# DATA (from scenario_analysis.py results)
# ============================================================
TENURE_DATA = {
    15: {'pod': 27.09, 'mean': 493_646, 'median': 429_899, 'p10': -485_989, 'p20': -161_261, 'p30': 58_998},
    20: {'pod': 21.34, 'mean': 835_141, 'median': 704_805, 'p10': -416_871, 'p20': -38_632, 'p30': 226_770},
    25: {'pod': 17.27, 'mean': 1_232_227, 'median': 1_025_556, 'p10': -337_581, 'p20': 100_440, 'p30': 414_798},
    30: {'pod': 14.25, 'mean': 1_682_642, 'median': 1_376_590, 'p10': -237_888, 'p20': 260_824, 'p30': 641_935},
}

SCENARIO1 = {
    'baseline_pod': 19.99, 'test_pod': 17.62,
    'baseline_poc': 0.00, 'test_poc': 0.00,
    'baseline_mean': 1_060_914, 'test_mean': 1_250_003,
    'baseline_premium': 39_385, 'test_premium': 36_843,
}

# Full surplus distribution for 30yr (from monte_carlo_v14a)
SURPLUS_30 = {
    'p1': -1_479_144, 'p5': -684_942, 'p10': -237_888,
    'p20': 260_824, 'p25': 454_671, 'p30': 641_935,
    'p50': 1_376_590, 'p75': 2_590_196, 'p90': 4_021_088,
    'p95': 5_043_668, 'p99': 7_464_941,
}


# ============================================================
# STYLE HELPERS (matching v14 reports)
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
    return styles


def make_table(headers, rows, col_widths=None):
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


def highlight_box(text, styles, bg=HexColor('#EBF5FB'), border=TEAL):
    data = [[Paragraph(text, styles['BodyText2'])]]
    t = Table(data, colWidths=[150 * mm])
    t.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, -1), bg),
        ('BOX', (0, 0), (-1, -1), 1.5, border),
        ('TOPPADDING', (0, 0), (-1, -1), 12),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 12),
        ('LEFTPADDING', (0, 0), (-1, -1), 14),
        ('RIGHTPADDING', (0, 0), (-1, -1), 14),
    ]))
    return t


def fig_to_image(fig, width=160*mm, height=100*mm):
    buf = BytesIO()
    fig.savefig(buf, format='png', dpi=150, bbox_inches='tight',
                facecolor='white', edgecolor='none')
    plt.close(fig)
    buf.seek(0)
    return Image(buf, width=width, height=height)


def footer(canvas, doc, title, date='March 2025'):
    canvas.saveState()
    canvas.setFont('Helvetica', 8)
    canvas.setFillColor(MID_GREY)
    canvas.drawString(25*mm, 12*mm, f'FutureProof | {title} | {date}')
    canvas.drawRightString(A4[0] - 25*mm, 12*mm, f'Page {doc.page}')
    canvas.restoreState()


def title_page(story, styles, main_title, report_name, subtitle, confidential_text, date='March 2025'):
    story.append(Spacer(1, 60*mm))
    story.append(Paragraph('Futureproof', styles['ReportTitle']))
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
# CHARTS
# ============================================================
def chart_pod_by_tenure():
    """Bar chart showing PoD declining with longer tenures."""
    tenures = [15, 20, 25, 30]
    pods = [TENURE_DATA[t]['pod'] for t in tenures]
    means = [TENURE_DATA[t]['mean'] / 1000 for t in tenures]

    fig, ax1 = plt.subplots(figsize=(8, 4.5))
    bar_colors = [MPL['coral'], MPL['amber'], MPL['teal'], MPL['green']]

    bars = ax1.bar([f'{t}yr' for t in tenures], pods, color=bar_colors, width=0.5, alpha=0.85)
    for bar, pod in zip(bars, pods):
        ax1.text(bar.get_x() + bar.get_width() / 2, bar.get_height() + 0.5,
                 f'{pod:.1f}%', ha='center', fontsize=11, fontweight='bold', color=MPL['navy'])

    ax1.set_ylabel('PoD at Maturity (%)', fontsize=11)
    ax1.set_title('Probability of Deficit by Loan Tenure', fontsize=13, fontweight='bold', color=MPL['navy'])
    ax1.spines['top'].set_visible(False)
    ax1.spines['right'].set_visible(False)
    ax1.set_ylim(0, 35)
    ax1.grid(axis='y', alpha=0.3)

    # Overlay mean surplus as line on secondary axis
    ax2 = ax1.twinx()
    ax2.plot([f'{t}yr' for t in tenures], means, color=MPL['purple'], linewidth=2.5,
             marker='o', markersize=8, label='Mean Surplus')
    for i, (t, m) in enumerate(zip(tenures, means)):
        ax2.annotate(f'${m:,.0f}K', (i, m), textcoords="offset points",
                     xytext=(0, 12), ha='center', fontsize=9, color=MPL['purple'], fontweight='bold')
    ax2.set_ylabel('Mean Surplus ($K)', fontsize=11, color=MPL['purple'])
    ax2.spines['top'].set_visible(False)
    ax2.set_ylim(0, 2200)

    return fig


def chart_mix_comparison():
    """Side-by-side bar chart comparing baseline vs no-15yr mix."""
    metrics = ['Wtd PoD (%)', 'Mean Surplus ($K)', 'LMI Premium ($K)']
    baseline_vals = [SCENARIO1['baseline_pod'], SCENARIO1['baseline_mean'] / 1000, SCENARIO1['baseline_premium'] / 1000]
    test_vals = [SCENARIO1['test_pod'], SCENARIO1['test_mean'] / 1000, SCENARIO1['test_premium'] / 1000]

    fig, axes = plt.subplots(1, 3, figsize=(10, 4))

    for i, (ax, label, b, t) in enumerate(zip(axes, metrics, baseline_vals, test_vals)):
        bars = ax.bar(['Baseline\n25/25/25/25', 'No 15yr\n0/33/33/33'], [b, t],
                      color=[MPL['grey'], MPL['teal']], width=0.5, alpha=0.85)
        for bar, val in zip(bars, [b, t]):
            fmt = f'{val:.1f}%' if 'PoD' in label else f'${val:,.0f}K'
            ax.text(bar.get_x() + bar.get_width() / 2, bar.get_height() + max(b, t) * 0.02,
                    fmt, ha='center', fontsize=10, fontweight='bold', color=MPL['navy'])
        ax.set_title(label, fontsize=11, fontweight='bold', color=MPL['navy'])
        ax.spines['top'].set_visible(False)
        ax.spines['right'].set_visible(False)
        ax.grid(axis='y', alpha=0.3)
        if 'PoD' in label or 'Premium' in label:
            if t < b:
                bars[1].set_edgecolor(MPL['green'])
                bars[1].set_linewidth(2)

    return fig


def chart_surplus_distribution():
    """Horizontal bar chart showing 30yr surplus percentile distribution."""
    labels = ['P1', 'P5', 'P10', 'P20', 'P25', 'P30', 'P50\n(Median)', 'P75', 'P90', 'P95', 'P99']
    keys = ['p1', 'p5', 'p10', 'p20', 'p25', 'p30', 'p50', 'p75', 'p90', 'p95', 'p99']
    values = [SURPLUS_30[k] / 1000 for k in keys]

    fig, ax = plt.subplots(figsize=(8, 4.5))
    bar_colors = [MPL['coral'] if v < 0 else MPL['teal'] for v in values]

    bars = ax.barh(labels, values, color=bar_colors, height=0.6, alpha=0.8)
    ax.axvline(x=0, color=MPL['navy'], linewidth=1.5, linestyle='-')

    for bar, val in zip(bars, values):
        ha = 'left' if val >= 0 else 'right'
        ax.text(val + (80 if val >= 0 else -80), bar.get_y() + bar.get_height() / 2,
                f'${val:,.0f}K', ha=ha, va='center', fontsize=9, fontweight='bold', color=MPL['navy'])

    ax.set_xlabel('Surplus ($K)', fontsize=11)
    ax.set_title('30-Year Surplus Distribution — Deficit Zone vs Surplus Zone', fontsize=13,
                 fontweight='bold', color=MPL['navy'])
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    ax.grid(axis='x', alpha=0.3)

    ax.axvspan(ax.get_xlim()[0], 0, alpha=0.05, color='red')
    ax.text(-200, 10.2, 'DEFICIT ZONE', fontsize=9, color=MPL['coral'], fontweight='bold', ha='center')
    ax.text(2000, 10.2, 'SURPLUS ZONE', fontsize=9, color=MPL['teal'], fontweight='bold', ha='center')

    return fig


def chart_top_cover():
    """Chart showing top cover scenarios and their insurance implications."""
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(10, 4.5))

    # Left: Percentile thresholds
    pcts = ['P10', 'P20', 'P30']
    thresholds = [SURPLUS_30['p10'] / 1000, SURPLUS_30['p20'] / 1000, SURPLUS_30['p30'] / 1000]
    bar_colors = [MPL['coral'], MPL['teal'], MPL['green']]

    bars = ax1.bar(pcts, thresholds, color=bar_colors, width=0.4, alpha=0.85)
    ax1.axhline(y=0, color=MPL['navy'], linewidth=1.5, linestyle='-')
    for bar, val in zip(bars, thresholds):
        y_off = -20 if val < 0 else 20
        ax1.text(bar.get_x() + bar.get_width() / 2, val + y_off,
                 f'${val:,.0f}K', ha='center', fontsize=10, fontweight='bold', color=MPL['navy'])
    ax1.set_ylabel('Surplus ($K)', fontsize=11)
    ax1.set_title('Percentile Threshold Values\n(30yr tenure)', fontsize=11, fontweight='bold', color=MPL['navy'])
    ax1.spines['top'].set_visible(False)
    ax1.spines['right'].set_visible(False)
    ax1.grid(axis='y', alpha=0.3)

    # Right: Coverage layer distribution
    deficit_pct = 14.25
    categories = ['P10\n(-$238K)', 'P20\n(+$261K)', 'P30\n(+$642K)']

    ax2.bar(categories, [4.25, 14.25, 14.25], color=MPL['coral'], alpha=0.7, label='Reinsurance layer')
    ax2.bar(categories, [10.0, 0, 0], bottom=[4.25, 14.25, 14.25],
            color=MPL['amber'], alpha=0.7, label='LMI covers')
    ax2.bar(categories, [85.75, 85.75, 85.75], bottom=[14.25, 14.25, 14.25],
            color=MPL['teal'], alpha=0.3, label='In surplus')

    ax2.set_ylabel('% of Paths', fontsize=11)
    ax2.set_title('Coverage Layer Distribution\nby Top Cover Threshold', fontsize=11, fontweight='bold', color=MPL['navy'])
    ax2.legend(fontsize=8, loc='upper right')
    ax2.spines['top'].set_visible(False)
    ax2.spines['right'].set_visible(False)
    ax2.set_ylim(0, 105)

    return fig


# ============================================================
# GENERATE PDF
# ============================================================
def generate():
    filename = 'FutureProof_EPM_Scenario_Analysis_Mar2025.pdf'
    footer_title = 'EPM Scenario Analysis'
    doc = SimpleDocTemplate(filename, pagesize=A4,
                            leftMargin=25*mm, rightMargin=25*mm,
                            topMargin=20*mm, bottomMargin=20*mm)
    styles = get_styles()
    story = []

    # ── Cover Page (matching v14 reports) ──────────────────
    title_page(story, styles,
               main_title='EPM v14a',
               report_name='Scenario Analysis',
               subtitle='Loan Term Mix & Top Cover Limit — 50,000-Path Monte Carlo',
               confidential_text='CONFIDENTIAL — For Internal Use Only',
               date='March 2025')

    # ── Executive Summary ─────────────────────────────
    story.append(Paragraph('Executive Summary', styles['SectionHead']))
    story.append(Paragraph(
        'This report analyses two portfolio-level parameter changes to the FutureProof EPM model, '
        'using independent 50,000-path Monte Carlo simulations for each loan tenure (15, 20, 25, and 30 years). '
        'All simulations use v14a parameters with identical market assumptions.',
        styles['BodyText2']))

    story.append(Spacer(1, 3*mm))
    story.append(highlight_box(
        '<b>Scenario 1 — Loan Term Mix:</b> Removing 15-year terms and redistributing equally across 20, 25, '
        'and 30-year tenures reduces weighted portfolio PoD by <b>2.4 percentage points</b> (from 20.0% to 17.6%) '
        'and increases mean surplus by <b>$189K per mortgage</b>.<br/><br/>'
        '<b>Scenario 2 — Top Cover Limit:</b> Only the worst ~14% of paths are in deficit at Year 30. '
        'The P20 and P30 thresholds are already in surplus territory (+$261K and +$642K respectively), '
        'meaning a wider top cover beyond P10 would not engage LMI — the deficit is concentrated in the '
        'worst 14.25% of outcomes.',
        styles, bg=HexColor('#E8F8F5'), border=TEAL))

    story.append(Spacer(1, 4*mm))
    story.append(Paragraph('Model Parameters', styles['SubHead']))
    story.append(make_table(
        ['Parameter', 'Value', 'Notes'],
        [
            ['Property Value', '$2,000,000', 'Reference property'],
            ['LVR / Effective LVR', '80% / 67.5%', 'Initial loan $1,350,000'],
            ['Annuity', '$25,000 p.a.', '10-year annuity term'],
            ['Equity Return', '10% (vol 10%)', 'GBM, hedged ±20% collar'],
            ['Cost of Capital', '3.20%', 'Wholesale + retail + hedging + FP margin'],
            ['Profit Share', '25% every 5yr', 'Extracted from surplus, not at maturity'],
            ['Simulation Paths', '50,000 per tenure', 'Seed-controlled for reproducibility'],
        ],
        col_widths=[35*mm, 30*mm, 80*mm]
    ))

    story.append(PageBreak())

    # ── Individual Tenure Results ──────────────────────
    story.append(Paragraph('1. Individual Tenure Analysis', styles['SectionHead']))
    story.append(Paragraph(
        'Before comparing portfolio mixes, it is important to understand how each loan tenure performs '
        'individually. The key insight: <b>longer tenures consistently produce lower PoD and higher surplus</b>. '
        'This is because the investment has more time to compound past the cost burden.',
        styles['BodyText2']))

    story.append(Spacer(1, 3*mm))
    story.append(fig_to_image(chart_pod_by_tenure()))

    story.append(Spacer(1, 4*mm))
    story.append(Paragraph('Detailed Tenure Comparison', styles['SubHead']))
    story.append(make_table(
        ['Metric', '15yr', '20yr', '25yr', '30yr'],
        [
            ['PoD at Maturity', '27.09%', '21.34%', '17.27%', '14.25%'],
            ['Mean Surplus', f'${TENURE_DATA[15]["mean"]:,.0f}', f'${TENURE_DATA[20]["mean"]:,.0f}',
             f'${TENURE_DATA[25]["mean"]:,.0f}', f'${TENURE_DATA[30]["mean"]:,.0f}'],
            ['Median Surplus', f'${TENURE_DATA[15]["median"]:,.0f}', f'${TENURE_DATA[20]["median"]:,.0f}',
             f'${TENURE_DATA[25]["median"]:,.0f}', f'${TENURE_DATA[30]["median"]:,.0f}'],
            ['P10 (Worst 10%)', f'${TENURE_DATA[15]["p10"]:,.0f}', f'${TENURE_DATA[20]["p10"]:,.0f}',
             f'${TENURE_DATA[25]["p10"]:,.0f}', f'${TENURE_DATA[30]["p10"]:,.0f}'],
            ['P20', f'${TENURE_DATA[15]["p20"]:,.0f}', f'${TENURE_DATA[20]["p20"]:,.0f}',
             f'${TENURE_DATA[25]["p20"]:,.0f}', f'${TENURE_DATA[30]["p20"]:,.0f}'],
            ['P30', f'${TENURE_DATA[15]["p30"]:,.0f}', f'${TENURE_DATA[20]["p30"]:,.0f}',
             f'${TENURE_DATA[25]["p30"]:,.0f}', f'${TENURE_DATA[30]["p30"]:,.0f}'],
        ],
        col_widths=[30*mm, 30*mm, 30*mm, 30*mm, 30*mm]
    ))

    story.append(Spacer(1, 3*mm))
    story.append(Paragraph(
        '<b>Key observation:</b> PoD declines almost linearly with tenure — each additional 5 years of loan '
        'term reduces PoD by approximately 4-5 percentage points. The 15yr tenure has nearly <b>double</b> the '
        'PoD of the 30yr tenure (27.1% vs 14.3%). This is because shorter tenures have less compounding time '
        'for the investment to overcome the cost drag (3.20% p.a.) and generate surplus.',
        styles['BodyText2']))

    story.append(PageBreak())

    # ── Scenario 1: Loan Term Mix ─────────────────────
    story.append(Paragraph('2. Scenario 1 — Removing 15-Year Terms', styles['SectionHead']))

    story.append(Paragraph(
        'The current portfolio worksheet assumes an equal 25% allocation to each of 15, 20, 25, and 30-year '
        'loan terms. This scenario tests the impact of eliminating 15-year terms entirely and redistributing '
        'the allocation equally across the remaining three tenures.',
        styles['BodyText2']))

    story.append(Spacer(1, 3*mm))
    story.append(make_table(
        ['Tenure', 'Baseline Weight', 'Test Weight', 'PoD at Maturity'],
        [
            ['15 years', '25%', '0%', '27.09%'],
            ['20 years', '25%', '33.3%', '21.34%'],
            ['25 years', '25%', '33.3%', '17.27%'],
            ['30 years', '25%', '33.3%', '14.25%'],
        ],
        col_widths=[30*mm, 30*mm, 30*mm, 35*mm]
    ))

    story.append(Spacer(1, 4*mm))
    story.append(fig_to_image(chart_mix_comparison()))

    story.append(Spacer(1, 4*mm))
    story.append(Paragraph('Portfolio Impact', styles['SubHead']))
    story.append(make_table(
        ['Metric', 'Baseline (25/25/25/25)', 'No 15yr (0/33/33/33)', 'Change'],
        [
            ['Weighted PoD', '19.99%', '17.62%', '-2.37%'],
            ['Portfolio PoC (Waterfall)', '0.00%', '0.00%', 'No change'],
            ['Mean Surplus', f'${SCENARIO1["baseline_mean"]:,.0f}', f'${SCENARIO1["test_mean"]:,.0f}',
             f'+${SCENARIO1["test_mean"] - SCENARIO1["baseline_mean"]:,.0f}'],
            ['Loaded Premium', f'${SCENARIO1["baseline_premium"]:,.0f}', f'${SCENARIO1["test_premium"]:,.0f}',
             f'-${SCENARIO1["baseline_premium"] - SCENARIO1["test_premium"]:,.0f}'],
        ],
        col_widths=[35*mm, 38*mm, 38*mm, 30*mm]
    ))

    story.append(Spacer(1, 4*mm))
    story.append(highlight_box(
        '<b>Conclusion — Scenario 1:</b> Removing 15-year terms improves every metric. Weighted PoD drops '
        'by 2.4 percentage points, mean surplus increases by $189K, and the insurance premium decreases by '
        '$2,543 per mortgage. The intuition is confirmed: longer loan terms allow more compounding time, '
        'which more than compensates for the additional cost accrual. Portfolio PoC remains at 0.00% in both '
        'scenarios — the Payments Waterfall effectively eliminates residual claims at the portfolio level.',
        styles, bg=HexColor('#E8F8F5'), border=TEAL))

    story.append(Spacer(1, 3*mm))
    story.append(Paragraph(
        '<b>Recommendation:</b> Consider restricting the minimum loan term to 20 years. This improves the '
        'risk profile with no adverse effect on the homeowner proposition — borrowers choosing shorter terms '
        'are likely less suited to the EPM product in any case, as they have shorter liquidity needs that '
        'conventional equity release products may serve better.',
        styles['BodyText2']))

    story.append(PageBreak())

    # ── Scenario 2: Top Cover Limit ───────────────────
    story.append(Paragraph('3. Scenario 2 — Top Cover Limit (LMI Threshold)', styles['SectionHead']))

    story.append(Paragraph(
        'The current model sets the LMI top cover limit at the <b>worst 10% quantile (P10)</b> — the insurer '
        'covers losses up to the P10 threshold, and any excess goes to the reinsurance layer. This scenario '
        'tests what happens if we widen the top cover to P20 or P30.',
        styles['BodyText2']))

    story.append(Spacer(1, 3*mm))
    story.append(Paragraph('Surplus Distribution at Year 30', styles['SubHead']))
    story.append(fig_to_image(chart_surplus_distribution()))

    story.append(Spacer(1, 3*mm))
    story.append(Paragraph(
        'The chart above reveals the critical insight: <b>the P20 and P30 thresholds are already in surplus '
        'territory</b>. At Year 30, only 14.25% of paths are in deficit. The percentile thresholds are:',
        styles['BodyText2']))

    story.append(make_table(
        ['Percentile', 'Surplus Value', 'In Deficit?', 'Implication'],
        [
            ['P10 (worst 10%)', f'${SURPLUS_30["p10"]:,.0f}', 'Yes', 'LMI covers losses up to this amount'],
            ['P20 (worst 20%)', f'${SURPLUS_30["p20"]:,.0f}', 'No — surplus', 'No LMI engagement at this threshold'],
            ['P30 (worst 30%)', f'${SURPLUS_30["p30"]:,.0f}', 'No — surplus', 'No LMI engagement at this threshold'],
        ],
        col_widths=[28*mm, 30*mm, 28*mm, 55*mm]
    ))

    story.append(Spacer(1, 4*mm))
    story.append(Paragraph('Insurance Layer Analysis (30yr tenure)', styles['SubHead']))

    story.append(fig_to_image(chart_top_cover()))

    story.append(Spacer(1, 4*mm))
    story.append(make_table(
        ['Top Cover', 'Threshold Value', 'LMI Premium (1.5x)', 'Reinsurance Premium', 'Paths Exceeding Cover'],
        [
            ['P10 (baseline)', f'${abs(SURPLUS_30["p10"]):,.0f}', '$11,463', '$22,740', '10.00% (5,000 paths)'],
            ['P20', '$0 (surplus)', '$0', '$34,203', '14.25% (all deficit paths)'],
            ['P30', '$0 (surplus)', '$0', '$34,203', '14.25% (all deficit paths)'],
        ],
        col_widths=[25*mm, 28*mm, 28*mm, 30*mm, 35*mm]
    ))

    story.append(Spacer(1, 4*mm))
    story.append(highlight_box(
        '<b>Conclusion — Scenario 2:</b> Widening the top cover beyond P10 has <b>no practical effect</b> '
        'because the P20 and P30 thresholds are already in surplus. The deficit is concentrated in the worst '
        '14.25% of paths, and the P10 threshold (-$237,888) already captures the boundary between manageable '
        'and tail losses.<br/><br/>'
        'With P10 top cover: LMI absorbs losses for the 4.25% of paths between P10 and zero (premium: $11,463), '
        'while the 10% of paths below P10 are covered by the reinsurance layer ($22,740). Moving to P20/P30 '
        'would shift the entire cost burden to reinsurance ($34,203) with no LMI layer at all — effectively '
        'eliminating the primary insurance tier.',
        styles, bg=HexColor('#EBF5FB'), border=TEAL))

    story.append(Spacer(1, 3*mm))
    story.append(Paragraph(
        '<b>Recommendation:</b> The P10 top cover is well-positioned. It creates a natural split between '
        'LMI (covering moderate deficits) and reinsurance (covering tail risk). Widening to P20 or P30 '
        'would not improve the risk profile — it would simply remove the LMI layer entirely and place '
        'all risk into the reinsurance tier, which is typically more expensive per dollar of coverage.',
        styles['BodyText2']))

    story.append(PageBreak())

    # ── Portfolio PoC Discussion ──────────────────────
    story.append(Paragraph('4. Portfolio PoC & The Payments Waterfall', styles['SectionHead']))

    story.append(Paragraph(
        'In both scenarios, the Portfolio PoC (Probability of Claim) simulated via the Payments Waterfall '
        'was <b>0.00%</b>. This requires explanation.',
        styles['BodyText2']))

    story.append(Paragraph(
        'The Payments Waterfall operates by cross-subsidising deficit mortgages from surplus mortgages within '
        'the same portfolio. In a diversified 100-loan portfolio with vintage, tenure, and market entry point '
        'diversification, the surplus loans overwhelmingly compensate for the deficit loans:',
        styles['BodyText2']))

    story.append(Spacer(1, 3*mm))
    story.append(make_table(
        ['Portfolio Metric', 'Value', 'Significance'],
        [
            ['Mean surplus per loan', '$1,060,914', 'Average across all tenures (baseline mix)'],
            ['Deficit probability', '~20%', 'Weighted average of individual tenures'],
            ['Surplus-to-deficit ratio', '~4:1', '80% of loans in surplus vs 20% in deficit'],
            ['Mean surplus of surplus loans', '~$1.5M', 'Ample buffer to cover deficit loans'],
            ['Mean deficit of deficit loans', '~$470K', 'Much smaller than surplus available'],
            ['Portfolio PoC', '0.00%', 'No net portfolio deficit in 50K simulations'],
        ],
        col_widths=[38*mm, 30*mm, 75*mm]
    ))

    story.append(Spacer(1, 3*mm))
    story.append(Paragraph(
        'The 4:1 surplus-to-deficit ratio means that even in the worst portfolio simulations, the surplus '
        'loans generate enough cross-subsidisation to cover all deficit loans. This is why the Payments '
        'Waterfall is the <b>single most powerful risk mitigation mechanism</b> in the EPM framework — it '
        'reduces the effective claim rate from ~20% (individual PoD) to 0% (portfolio PoC).',
        styles['BodyText2']))

    story.append(Spacer(1, 6*mm))

    # ── Key Takeaways ─────────────────────────────────
    story.append(Paragraph('5. Key Takeaways', styles['SectionHead']))

    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>Longer loan terms are unambiguously better:</b> Each additional 5 years of '
        'tenure reduces PoD by ~4-5 percentage points and increases mean surplus by ~$300K. The 15yr tenure '
        'is the weakest performer at 27.09% PoD.',
        styles['BulletCustom']))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>Removing 15yr terms improves every metric:</b> PoD drops 2.4pp, surplus '
        'rises $189K, insurance premium falls $2,543. There is no trade-off — the improvement is costless.',
        styles['BulletCustom']))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>The P10 top cover is correctly positioned:</b> P20 and P30 are already '
        'in surplus, so widening the top cover has no practical effect. The deficit is concentrated in the '
        'worst 14.25% of paths — P10 captures the meaningful boundary.',
        styles['BulletCustom']))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>Portfolio diversification eliminates claims:</b> The Payments Waterfall '
        'produces 0% PoC across all tested scenarios. The surplus-to-deficit ratio (~4:1) provides a '
        'substantial buffer against even correlated downturns.',
        styles['BulletCustom']))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>Insurance primarily covers tail risk:</b> At P10, the LMI layer covers '
        'only $11,463 per mortgage (0.72% of max loan). The reinsurance layer handles the extreme tail at '
        '$22,740. Combined insurance cost is $34,203 — approximately 2.1% of the max loan.',
        styles['BulletCustom']))

    story.append(Spacer(1, 8*mm))
    story.append(Paragraph(
        'This document is confidential and intended solely for the recipient. All results are derived from '
        'Monte Carlo simulation and do not guarantee future performance. Parameters based on v14a model '
        '(March 2025). Simulation: 50,000 paths per tenure, seed-controlled for reproducibility.',
        styles['SmallNote']))

    # Build PDF with footer
    doc.build(story, onFirstPage=lambda c, d: footer(c, d, footer_title),
              onLaterPages=lambda c, d: footer(c, d, footer_title))
    print(f'  Generated: {filename}')
    return filename


if __name__ == '__main__':
    generate()
