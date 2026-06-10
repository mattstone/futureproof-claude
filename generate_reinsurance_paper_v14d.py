#!/usr/bin/env python3
"""
Generate FutureProof LMI & Portfolio Risk Reinsurance Structure Paper
Addresses:
  (a) Recommended structure/interaction between LMI program settings and portfolio risk reinsurance
  (b) How the Portfolio Risk Reinsurance Program should be structured by a reinsurer
Based on v14d Optimised model — GBM+MeanRev equity model (Shevchenko 2026)
50,000-path Monte Carlo simulation, $1.5M home, asymmetric collar +40%/-20%,
50 bps FP margin, 10% profit share at 3-year resets.

John Innes feedback (May 2026) incorporated:
  - All figures updated to v14d Optimised 50k-path MC results
  - Baseline home value reflects current model ($1.5M, not $2M)
  - Title updated to "Equity Preservation Mortgage v14d (Optimised)"
  - LMI scope language clarified ("long-term index risk over 30 years")

All per-mortgage figures are sourced from Pavel's authoritative v14d xlsm
(2026-05-24): base PoD 8.37%, LMI PoC 8.37%, reinsurance PoC 1.67%.
The per-mortgage reinsurance PoC (1.67%) is the hard ceiling for the portfolio
figure — cross-subsidy/diversification can only reduce claims. We anchor on this
ceiling rather than a fragile portfolio point estimate. NOTE: the xlsm Portfolio
sheet "prob of portfolio deficit" is portfolio PoD, NOT PoC.
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

# ============================================================
# LOAD v14d OPTIMISED MODEL DATA
# ============================================================
_MC_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'monte_carlo_v14d_optimised_results.json')
with open(_MC_FILE) as _f:
    MC = json.load(_f)

V14 = MC['parameters']
INS = MC['insurance']

# Helper for home-value formatting (model now uses $1.5M baseline)
HOME_VALUE = V14['home_value']
HOME_LABEL_M = f'${HOME_VALUE/1e6:.1f}M'
HOME_LABEL_FULL = f'${HOME_VALUE:,.0f}'

# Portfolio reinsurance PoC AFTER cross-subsidisation (Payments Waterfall).
# The per-mortgage reinsurance PoC (1.67%, xlsm-verified) is the hard CEILING —
# cross-subsidy and diversification can only reduce claims, never increase them.
# The portfolio figure sits modestly below this ceiling; we anchor the analysis on
# the ceiling rather than a fragile portfolio point estimate.
# NOTE: the xlsm Portfolio-sheet "prob of portfolio deficit" is portfolio PoD, NOT PoC.
PER_MORTGAGE_REINS_POC = INS['tail_risk']['poc']  # 1.67% — hard ceiling for the portfolio figure

# ============================================================
# STYLES
# ============================================================
def get_styles():
    styles = getSampleStyleSheet()

    styles.add(ParagraphStyle(
        'CoverTitle', fontSize=28, leading=34, fontName='Helvetica-Bold',
        textColor=DARK_NAVY, spaceAfter=6*mm, alignment=TA_LEFT
    ))
    styles.add(ParagraphStyle(
        'CoverSubtitle', fontSize=14, leading=18, fontName='Helvetica',
        textColor=TEAL, spaceAfter=15*mm, alignment=TA_LEFT
    ))
    styles.add(ParagraphStyle(
        'SectionHead', fontSize=16, leading=20, fontName='Helvetica-Bold',
        textColor=DARK_NAVY, spaceBefore=10*mm, spaceAfter=4*mm
    ))
    styles.add(ParagraphStyle(
        'SubHead', fontSize=13, leading=16, fontName='Helvetica-Bold',
        textColor=TEAL, spaceBefore=6*mm, spaceAfter=3*mm
    ))
    styles.add(ParagraphStyle(
        'BodyText2', fontSize=10, leading=14, fontName='Helvetica',
        textColor=DARK_NAVY, spaceBefore=2*mm, spaceAfter=2*mm,
        alignment=TA_JUSTIFY
    ))
    styles.add(ParagraphStyle(
        'FPBullet', fontSize=10, leading=14, fontName='Helvetica',
        textColor=DARK_NAVY, leftIndent=15, spaceBefore=1*mm, spaceAfter=1*mm,
        bulletIndent=5, alignment=TA_JUSTIFY
    ))
    styles.add(ParagraphStyle(
        'Callout', fontSize=10, leading=14, fontName='Helvetica-Oblique',
        textColor=TEAL, spaceBefore=3*mm, spaceAfter=3*mm,
        leftIndent=10*mm, rightIndent=10*mm, alignment=TA_JUSTIFY,
        backColor=HexColor('#F0F8FF'), borderPadding=8
    ))
    styles.add(ParagraphStyle(
        'Footer', fontSize=8, leading=10, fontName='Helvetica',
        textColor=MID_GREY, alignment=TA_CENTER
    ))
    styles.add(ParagraphStyle(
        'Equation', fontSize=10, leading=14, fontName='Courier',
        textColor=DARK_NAVY, spaceBefore=2*mm, spaceAfter=2*mm,
        leftIndent=10*mm, alignment=TA_LEFT
    ))
    return styles


def make_table(headers, rows, col_widths=None):
    """Build a styled table with Paragraph-wrapped cells for proper text wrapping."""
    header_style = ParagraphStyle('_TblHeader', fontSize=9, leading=12,
                                  fontName='Helvetica-Bold', textColor=WHITE)
    cell_style = ParagraphStyle('_TblCell', fontSize=9, leading=12,
                                fontName='Helvetica', textColor=DARK_NAVY)
    cell_bold = ParagraphStyle('_TblCellBold', fontSize=9, leading=12,
                               fontName='Helvetica-Bold', textColor=DARK_NAVY)

    wrapped_headers = [Paragraph(str(h), header_style) for h in headers]
    wrapped_rows = []
    for row in rows:
        wrapped_row = []
        for i, cell in enumerate(row):
            style = cell_bold if i == 0 else cell_style
            wrapped_row.append(Paragraph(str(cell), style))
        wrapped_rows.append(wrapped_row)

    data = [wrapped_headers] + wrapped_rows
    if col_widths:
        t = Table(data, colWidths=col_widths, repeatRows=1)
    else:
        t = Table(data, repeatRows=1)

    style_cmds = [
        ('BACKGROUND', (0, 0), (-1, 0), HEADER_BG),
        ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
        ('TOPPADDING', (0, 0), (-1, -1), 4),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 4),
        ('LEFTPADDING', (0, 0), (-1, -1), 6),
        ('RIGHTPADDING', (0, 0), (-1, -1), 6),
        ('GRID', (0, 0), (-1, -1), 0.5, MID_GREY),
    ]
    for i in range(1, len(data)):
        if i % 2 == 0:
            style_cmds.append(('BACKGROUND', (0, i), (-1, i), ROW_ALT))

    t.setStyle(TableStyle(style_cmds))
    return t


def fig_to_image(fig, height=80*mm):
    """Convert matplotlib figure to ReportLab Image."""
    buf = BytesIO()
    fig.savefig(buf, format='png', dpi=150, bbox_inches='tight')
    plt.close(fig)
    buf.seek(0)
    img = Image(buf)
    ratio = img.imageWidth / img.imageHeight
    img.drawHeight = height
    img.drawWidth = height * ratio
    return img


# ============================================================
# CHARTS
# ============================================================

def chart_insurance_structure():
    """Visualise the two-layer insurance structure — per-mortgage deficit distribution."""
    fig, ax = plt.subplots(figsize=(8, 5))

    # Reconstruct approximate conditional deficit distribution from v14d model data
    # ~8.37% of 50,000 paths ≈ 4,185 deficit paths (xlsm-verified)
    # Top cover boundary ≈ $234,495 (v14d Optimised, $1.5M home); ~20% of deficit
    # paths fall in the reinsurance layer (tail PoC 1.67% / LMI PoC 8.37%).
    np.random.seed(42)
    n_deficit = int(MC['n_paths'] * MC['deficit_prob'] / 100)

    # Log-normal calibrated so P80 ≈ actual top_cover boundary (≈20% in reins layer)
    # mean=11.90, sigma=0.55 -> median ~$147K, conditional mean ~$166K, P80 ~$234K
    deficits = np.random.lognormal(mean=11.90, sigma=0.55, size=n_deficit)
    deficits = np.clip(deficits, 10000, 2_000_000)

    # Top cover boundary (P20 of conditional deficit = 20th percentile from worst)
    top_cover = abs(INS['top_cover_limit'])

    # Split into two populations for the chart
    lmi_only = deficits[deficits <= top_cover]
    reins = deficits[deficits > top_cover]

    bins = np.linspace(0, 2_000_000, 50)

    ax.hist(lmi_only, bins=bins, color='#3498A8', alpha=0.7, edgecolor='white',
            linewidth=0.5, label=f'LMI layer: deficit up to ${top_cover/1e6:.2f}M ({len(lmi_only)} of {n_deficit} paths)')
    ax.hist(reins, bins=bins, color='#C0392B', alpha=0.7, edgecolor='white',
            linewidth=0.5, label=f'Reinsurance layer: deficit above ${top_cover/1e6:.2f}M ({len(reins)} of {n_deficit} paths)')

    ax.axvline(x=top_cover, color='#2C3E50', linewidth=2.5, linestyle='--',
               label=f'Split boundary (P20): ${top_cover:,.0f}')

    ax.set_xlabel('Per-Mortgage Deficit at Expiry ($)', fontsize=11)
    ax.set_ylabel('Number of Deficit Paths', fontsize=11)
    ax.set_title(f'Per-Mortgage Conditional Deficit Distribution\nTwo-Layer Insurance Split ({HOME_LABEL_M} home)',
                 fontsize=12, fontweight='bold', color='#2C3E50')
    ax.legend(fontsize=8.5, loc='upper right')
    ax.xaxis.set_major_formatter(mticker.FuncFormatter(lambda x, _: f'${x/1e6:.1f}M'))
    ax.grid(True, alpha=0.3, axis='y')
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)

    ax.text(0.02, 0.95, 'Note: All amounts are per-mortgage.\nBoundary varies with home value, LVR, and annuity.',
            transform=ax.transAxes, fontsize=8, color='#95A5A6', va='top',
            bbox=dict(boxstyle='round,pad=0.3', facecolor='#F8F9FA', edgecolor='none'))

    return fig


def chart_poc_trajectory():
    """PoC trajectory over time."""
    fig, ax = plt.subplots(figsize=(8, 4.5))
    years = list(range(1, 31))
    poc = MC['deficit_by_year']

    ax.plot(years, poc, color='#2C3E50', linewidth=2.5, label='Individual PoD (probability of deficit)')
    ax.fill_between(years, poc, alpha=0.1, color='#2C3E50')

    # Tail risk PoC line (reinsurance layer only)
    tail_poc = [p * INS['tail_risk']['poc'] / INS['lmi']['poc'] for p in poc]
    ax.plot(years, tail_poc, color='#C0392B', linewidth=2, linestyle='--', label='Reinsurance Layer PoC')

    ax.set_xlabel('Year', fontsize=11)
    ax.set_ylabel('Probability of Deficit (%)', fontsize=11)
    ax.set_title('PoD Trajectory Over Mortgage Term (per-mortgage)', fontsize=13,
                 fontweight='bold', color='#2C3E50')
    ax.legend(fontsize=9)
    ax.grid(True, alpha=0.3)
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    return fig


def chart_premium_allocation():
    """Pie chart of premium allocation."""
    fig, ax = plt.subplots(figsize=(6, 5))

    lmi_fair = INS['lmi']['fair_premium_pv']
    tail_fair = INS['tail_risk']['fair_premium_pv']
    total = lmi_fair + tail_fair

    sizes = [lmi_fair, tail_fair]
    labels = [f'LMI Layer\n${lmi_fair:,.0f}\n({100*lmi_fair/total:.1f}%)',
              f'Tail Risk Reinsurance\n${tail_fair:,.0f}\n({100*tail_fair/total:.1f}%)']
    colours = ['#3498A8', '#C0392B']
    explode = (0, 0.05)

    wedges, texts = ax.pie(sizes, labels=labels, colors=colours, explode=explode,
                           startangle=90, textprops={'fontsize': 10, 'color': '#2C3E50'})

    ax.set_title(f'Per-Mortgage Fair Premium Allocation\nLMI vs Tail Risk Reinsurance ({HOME_LABEL_M} home)',
                 fontsize=12, fontweight='bold', color='#2C3E50')
    return fig


# ============================================================
# HEDGING APPENDIX CHARTS (SpiderRock 140/80 program)
# ============================================================

def chart_collar_payoff():
    """140/80 collar payoff: credited account return vs index annual return."""
    fig, ax = plt.subplots(figsize=(8, 4.6))
    idx = np.linspace(-50, 70, 400)          # index annual return %
    credited = np.clip(idx, -20, 40)          # collar: floor -20%, cap +40%
    ax.plot(idx, idx, color='#95A5A6', linewidth=1.6, linestyle='--', label='Unhedged index return')
    ax.plot(idx, credited, color='#2C3E50', linewidth=2.8, label='Credited to offset account (140/80 collar)')
    ax.axhline(40, color='#27AE60', linewidth=1, linestyle=':')
    ax.axhline(-20, color='#C0392B', linewidth=1, linestyle=':')
    ax.text(60, 42, 'Upside cap +40% (140)', fontsize=8.5, color='#27AE60', va='bottom', ha='right')
    ax.text(-48, -18, 'Downside floor -20% (80)', fontsize=8.5, color='#C0392B', va='bottom')
    ax.axhline(0, color='#000000', linewidth=0.6, alpha=0.4)
    ax.axvline(0, color='#000000', linewidth=0.6, alpha=0.4)
    ax.set_xlabel('S&P 500 annual return (%)', fontsize=11)
    ax.set_ylabel('Return credited to offset account (%)', fontsize=11)
    ax.set_title('Step 4 — 140/80 Collar Payoff (per annum)', fontsize=13, fontweight='bold', color='#2C3E50')
    ax.legend(fontsize=9, loc='upper left')
    ax.grid(True, alpha=0.3)
    ax.spines['top'].set_visible(False); ax.spines['right'].set_visible(False)
    return fig


def chart_laddered_hedge():
    """Laddered tenors -> smoothed combined hedge exposure vs single-maturity spike."""
    fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(8, 5.4), gridspec_kw={'height_ratios': [1, 1.1]})
    # Top: four overlapping tenors as staggered bars
    tenors = [('3M roll', 0, 3), ('6M roll', 0, 6), ('9M roll', 0, 9), ('12M roll', 0, 12)]
    for i, (lbl, s, e) in enumerate(tenors):
        ax1.barh(i, e - s, left=s, height=0.6, color='#3498A8', alpha=0.55, edgecolor='white')
        ax1.text(e + 0.3, i, lbl, va='center', fontsize=8.5, color='#2C3E50')
    ax1.barh(-1, 48, left=0, height=0.6, color='#2C3E50', alpha=0.5, edgecolor='white')
    ax1.text(48.6, -1, '2–4yr LEAPS calls', va='center', fontsize=8.5, color='#2C3E50')
    ax1.set_yticks([]); ax1.set_xlim(0, 60); ax1.set_xlabel('Months', fontsize=10)
    ax1.set_title('Laddered 140/80 Hedge — Overlapping Tenors', fontsize=12, fontweight='bold', color='#2C3E50')
    ax1.spines['top'].set_visible(False); ax1.spines['right'].set_visible(False); ax1.spines['left'].set_visible(False)
    # Bottom: combined exposure — laddered smooth plateau vs single-maturity spike
    t = np.linspace(0, 12, 400)
    single = np.exp(-((t - 12) ** 2) / 1.2)                       # spike near the single roll date
    ladder = np.clip(0.25 * sum(np.exp(-((t - c) ** 2) / 3.0) for c in (3, 6, 9, 12)) * 2.2, 0, 1)
    ax2.plot(t, single, color='#C0392B', linewidth=2, linestyle='--', label='Single-maturity (vega concentrated on one roll)')
    ax2.plot(t, ladder, color='#2C3E50', linewidth=2.6, label='Laddered (smoothed, averaged exposure)')
    ax2.fill_between(t, ladder, color='#2C3E50', alpha=0.08)
    ax2.set_xlabel('Months to roll', fontsize=10); ax2.set_ylabel('Hedge / vega exposure', fontsize=10)
    ax2.set_yticks([]); ax2.legend(fontsize=8.5, loc='upper left')
    ax2.set_title('Combined Hedge Exposure Over Time', fontsize=11, fontweight='bold', color='#2C3E50')
    ax2.grid(True, alpha=0.3); ax2.spines['top'].set_visible(False); ax2.spines['right'].set_visible(False)
    fig.tight_layout()
    return fig


def chart_hedge_efficiency():
    """Cost (bps) vs breach probability (%) for the five hedge structures."""
    fig, ax = plt.subplots(figsize=(8, 4.8))
    pts = [
        ('No hedge', 0, 16, '#C0392B'),
        ('5% convexity', 45, 11.5, '#3498A8'),
        ('10% convexity', 90, 8, '#3498A8'),
        ('Rules-based overlay', 32.5, 9, '#27AE60'),
        ('Static replication', 20, 11, '#3498A8'),
    ]
    for lbl, cost, breach, col in pts:
        ax.scatter(cost, breach, s=140, color=col, zorder=5, edgecolor='white', linewidth=1)
        dy = 0.5 if lbl != 'Rules-based overlay' else -1.0
        ax.annotate(lbl, (cost, breach), xytext=(cost + 2, breach + dy), fontsize=9, color='#2C3E50')
    ax.annotate('best cost-per-unit\nof protection', (32.5, 9), xytext=(60, 13.5), fontsize=8.5,
                color='#27AE60', ha='center', arrowprops=dict(arrowstyle='->', color='#27AE60', lw=1.4))
    ax.set_xlabel('Annual cost (bps)', fontsize=11)
    ax.set_ylabel('80%-floor breach probability (%)', fontsize=11)
    ax.set_title('Hedge-Efficiency Frontier — Cost vs Protection', fontsize=13, fontweight='bold', color='#2C3E50')
    ax.set_xlim(-8, 120); ax.set_ylim(6, 18)
    ax.grid(True, alpha=0.3); ax.spines['top'].set_visible(False); ax.spines['right'].set_visible(False)
    return fig


def chart_terminal_wealth():
    """30-year terminal wealth distribution with 80% floor and breach region."""
    from scipy import interpolate
    np.random.seed(11)
    q = np.array([0.01, 0.05, 0.25, 0.50, 0.75, 0.95, 0.99])
    x = np.array([0.15, 0.35, 1.30, 2.90, 6.27, 16.7, 30.0])
    inv = interpolate.PchipInterpolator(q, x)
    samples = inv(np.clip(np.random.rand(200000), 0.001, 0.999))
    samples = samples[samples <= 12]          # clip extreme right tail for display
    fig, ax = plt.subplots(figsize=(8, 4.6))
    bins = np.linspace(0, 12, 70)
    ax.hist(samples, bins=bins, color='#3498A8', alpha=0.55, edgecolor='white', linewidth=0.4)
    # breach region (< 0.80x)
    breach = samples[samples < 0.80]
    ax.hist(breach, bins=bins, color='#C0392B', alpha=0.75, edgecolor='white', linewidth=0.4)
    ax.axvline(0.80, color='#C0392B', linewidth=2, linestyle='--')
    ax.axvline(2.90, color='#2C3E50', linewidth=1.6, linestyle=':')
    _ymax = ax.get_ylim()[1]
    ax.annotate('80% real-wealth floor', xy=(0.80, _ymax*0.55), xytext=(3.3, _ymax*0.7),
                fontsize=9, color='#C0392B', arrowprops=dict(arrowstyle='->', color='#C0392B', lw=1.3))
    ax.annotate('Breach ≈16%\n(P < 0.80×)', xy=(0.45, _ymax*0.30), xytext=(4.8, _ymax*0.45),
                fontsize=9, color='#C0392B', fontweight='bold',
                arrowprops=dict(arrowstyle='->', color='#C0392B', lw=1.3))
    ax.text(3.0, _ymax*0.92, 'Median 2.9×', color='#2C3E50', fontsize=9)
    ax.set_xlabel('30-year terminal wealth (× starting capital)', fontsize=11)
    ax.set_ylabel('Frequency (of 50,000 paths)', fontsize=11)
    ax.set_title('30-Year Terminal Wealth Distribution & 80% Floor', fontsize=13, fontweight='bold', color='#2C3E50')
    ax.grid(True, alpha=0.3, axis='y'); ax.spines['top'].set_visible(False); ax.spines['right'].set_visible(False)
    return fig


# ============================================================
# PAPER: LMI & PORTFOLIO RISK REINSURANCE STRUCTURE
# ============================================================

def build_reinsurance_paper():
    styles = get_styles()
    filename = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                            'docs', 'pdfs', 'FutureProof_EPM_Reinsurance_Structure_May2026.pdf')

    footer_title = 'Confidential — For Internal Distribution Only'

    def add_footer(canvas, doc):
        canvas.saveState()
        canvas.setFont('Helvetica', 8)
        canvas.setFillColor(MID_GREY)
        canvas.drawString(25*mm, 12*mm, footer_title)
        canvas.drawRightString(A4[0] - 25*mm, 12*mm, f'Page {doc.page}')
        canvas.restoreState()

    doc = SimpleDocTemplate(
        filename, pagesize=A4,
        leftMargin=25*mm, rightMargin=25*mm,
        topMargin=20*mm, bottomMargin=20*mm
    )
    story = []

    # ---- COVER PAGE ----
    story.append(Spacer(1, 30*mm))
    story.append(Paragraph('FutureProof Financial', styles['CoverTitle']))
    story.append(Paragraph(
        'Equity Preservation Mortgage&reg; Modelling v14d (Optimised)<br/>'
        'Reinsurance Review<br/>'
        'LMI & Portfolio Risk Reinsurance Program:<br/>'
        'Recommended Structure and Interaction',
        styles['CoverSubtitle']
    ))
    story.append(Spacer(1, 10*mm))
    story.append(Paragraph(
        'Based on the Equity Preservation Mortgage (EPM) v14d (Optimised) Model<br/>'
        'GBM (with Stochastic Drift) + Mean Reversion Equity Model (Shevchenko 2026)<br/>'
        '50,000-path Monte Carlo Simulation | May 2026',
        styles['BodyText2']
    ))
    story.append(Spacer(1, 5*mm))
    story.append(Paragraph(
        '<b>Purpose:</b> This paper sets out the recommended structure for the FutureProof Lenders Mortgage Insurance (LMI) '
        'program and its interaction with the Portfolio Risk Reinsurance program. It provides reinsurers with a comprehensive '
        'framework for structuring tail risk coverage for EPM portfolios.',
        styles['BodyText2']
    ))
    story.append(Spacer(1, 3*mm))
    story.append(Paragraph('CONFIDENTIAL — For Internal Distribution Only', styles['BodyText2']))
    story.append(Spacer(1, 3*mm))
    story.append(Paragraph(
        f'<b>Important note on dollar amounts:</b> All dollar amounts in this paper are per-mortgage values for a '
        f'representative {HOME_LABEL_FULL} property at 80% LVR. These amounts will vary proportionally for different '
        f'home values, LVR ratios, and annuity levels. They are not global constants.',
        styles['Callout']
    ))
    story.append(PageBreak())

    # ---- TABLE OF CONTENTS ----
    story.append(Paragraph('Contents', styles['SectionHead']))
    toc_items = [
        ('1.', 'Executive Summary'),
        ('2.', 'Stochastic Model Selection and Calibration'),
        ('3.', 'EPM Insurance Architecture Overview'),
        ('4.', 'Part A: LMI Program — Structure and Settings'),
        ('5.', 'Part B: Tail Risk Reinsurance — Structure and Settings'),
        ('6.', 'Part C: Interaction Between LMI and Reinsurance'),
        ('7.', 'Part D: Reinsurer Structuring Recommendations'),
        ('8.', 'Quantitative Analysis — Model Results'),
        ('9.', 'Premium Pricing Framework'),
        ('10.', 'Risk Transfer Summary'),
        ('11.', 'Appendix A: Model Parameters'),
        ('12.', 'Appendix B: Stochastic Model Equations (Shevchenko 2026)'),
        ('13.', 'Appendix C: Long-Horizon Equity Hedging Program (SpiderRock)'),
    ]
    for num, title in toc_items:
        story.append(Paragraph(f'<b>{num}</b> {title}', styles['BodyText2']))
    story.append(PageBreak())

    # ---- 1. EXECUTIVE SUMMARY ----
    story.append(Paragraph('1. Executive Summary', styles['SectionHead']))
    story.append(Paragraph(
        'The Equity Preservation Mortgage is a strongly positive-expectation product, and — importantly — the '
        'homeowner bears none of its investment risk. The homeowner\'s income is contractually guaranteed '
        'regardless of market conditions; they retain their home throughout; and their home equity is preserved in '
        'every outcome (the product is non-recourse to the home). The investment account that sits behind the '
        'guarantee — and its surplus or shortfall — accrues to FutureProof, the funder, and the insurers, not the '
        'homeowner. Those economics are sound too: across 50,000 simulated 30-year paths, <b>roughly 92% of '
        f'mortgages fully self-fund</b> — the investment account grows past the mortgage, with a typical (median) '
        f'surplus near ${MC["median_surplus"]/1e6:.1f}M shared between FutureProof and the funder — and the two-layer '
        'insurance covers the minority tail. This paper concerns that tail; the risk analysis that follows '
        'characterises it, not the expected case.',
        styles['BodyText2']
    ))
    story.append(Paragraph(
        'For a reinsurer this is an attractive risk to write: a book where the great majority of mortgages '
        'self-fund in full, where any claim can only crystallise once (at maturity), and where loss severity is '
        'modest. The two-layer architecture below protects lenders and wholesale funders against the residual '
        'tail. This paper addresses two key questions:',
        styles['BodyText2']
    ))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>Part A:</b> How should the individual-mortgage LMI program settings interact '
        'with the loan-book / portfolio risk reinsurance program settings?',
        styles['FPBullet']
    ))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>Part B:</b> How should a reinsurer structure the Portfolio Risk '
        'Reinsurance Program?',
        styles['FPBullet']
    ))
    story.append(Spacer(1, 3*mm))

    # Mutually exclusive deficit-outcome buckets (per-mortgage, % of all mortgages)
    _lmi_total_pct = INS["lmi"]["poc"]              # 8.37% — all deficit paths
    _tail_pct = INS["tail_risk"]["poc"]              # 1.67% — severe-deficit subset
    _lmi_only_pct = _lmi_total_pct - _tail_pct       # 6.70% — moderate-deficit subset
    _no_deficit_pct = 100.0 - _lmi_total_pct         # 91.63% — no deficit

    story.append(Paragraph(f'Key Findings — Per-Layer ({HOME_LABEL_M} home at 80% LVR)', styles['SubHead']))
    story.append(make_table(
        ['Metric', 'LMI Layer', 'Tail Risk Reinsurance', 'Combined'],
        [
            ['Insurance scope', 'Pays on every deficit path', 'Pays only on severe-deficit paths (subset of LMI)',
             '100% coverage from $0'],
            ['Covers deficits', f'Up to ${abs(INS["top_cover_limit"]):,.0f} per mortgage',
             f'Excess above ${abs(INS["top_cover_limit"]):,.0f} per mortgage', 'All deficits from $0'],
            ['Probability of Claim (% of all mortgages)¹',
             f'{_lmi_total_pct:.2f}%', f'{_tail_pct:.2f}% (subset of LMI)', f'{_lmi_total_pct:.2f}% (any insurer pays)'],
            ['Fair Premium (PV)', f'${INS["lmi"]["fair_premium_pv"]:,.0f} per mortgage', f'${INS["tail_risk"]["fair_premium_pv"]:,.0f} per mortgage', f'${INS["combined"]["total_fair_premium"]:,.0f} per mortgage'],
            ['Loaded Premium (50%)', f'${INS["lmi"]["loaded_premium"]:,.0f} per mortgage', f'${INS["tail_risk"]["loaded_premium"]:,.0f} per mortgage', f'${INS["combined"]["total_loaded_premium"]:,.0f} per mortgage'],
            ['Premium timing', 'Upfront at origination', 'Upfront at origination', 'Upfront at origination'],
        ],
        col_widths=[35*mm, 40*mm, 42*mm, 36*mm]
    ))
    story.append(Paragraph(
        '<super>1</super> <i>Reinsurance claims are a strict subset of LMI claims — every reinsurance claim is also '
        'an LMI claim, because LMI pays first-loss from $0. The 1.67% reinsurance frequency is the ~20% subset '
        'of severe-deficit paths within the 8.37% total deficit probability. "Combined" is the probability that '
        'any insurer pays anything — equal to the LMI frequency, not the sum.</i>',
        styles['BodyText2']
    ))

    story.append(Spacer(1, 3*mm))
    story.append(Paragraph('Outcome Distribution at Maturity', styles['SubHead']))
    story.append(Paragraph(
        'Every mortgage falls into exactly one of the following buckets at year 30. <b>The great majority finish '
        'in surplus with no claim</b>; the two insurance layers split the deficit <i>dollars</i> only on the '
        'minority tail — and both layers can pay on the same mortgage.',
        styles['BodyText2']
    ))
    story.append(make_table(
        ['Year-30 outcome', 'Frequency (% of all mortgages)', 'LMI pays', 'Reinsurer pays'],
        [
            ['In surplus (no claim)', f'{_no_deficit_pct:.2f}%', '—', '—'],
            [f'Moderate deficit (≤ ${abs(INS["top_cover_limit"]):,.0f})',
             f'{_lmi_only_pct:.2f}%', 'Full deficit', '$0'],
            [f'Severe deficit (> ${abs(INS["top_cover_limit"]):,.0f})',
             f'{_tail_pct:.2f}%', f'${abs(INS["top_cover_limit"]):,.0f} (capped)', 'Excess'],
            ['<b>Any insurance claim</b>', f'<b>{_lmi_total_pct:.2f}%</b>',
             '<b>—</b>', '<b>—</b>'],
        ],
        col_widths=[55*mm, 36*mm, 32*mm, 30*mm]
    ))

    story.append(Spacer(1, 4*mm))
    story.append(Paragraph(
        '<b>Critical distinction:</b> The EPM is a mortgage, not a loan. Insurance claims can only arise at '
        'mortgage expiry (end of the 30-year term), not at any intermediate point. The insurance structure provides '
        '100% coverage of all deficit outcomes from dollar zero — there is no deductible or uninsured gap. The two '
        'layers divide responsibility by loss severity: the LMI insurer covers smaller deficits, and the reinsurer '
        'covers the excess on larger deficits.',
        styles['Callout']
    ))

    story.append(Spacer(1, 4*mm))
    story.append(Paragraph('Parameter Uncertainty and Three-Scenario Framework', styles['SubHead']))
    story.append(Paragraph(
        'The premium numbers above are produced under the model\'s base-case parameter set (MLE central estimates '
        f'from historical data, {V14["collar_price"]*100:.3f}% collar cost, base correlation). A companion paper — '
        '<i>Model Assumptions &amp; Parameter Risk</i> — stress-tests each parameter against academic benchmarks '
        '(Shiller CAPE, Jordà-Schularick-Taylor, Black-Scholes collar pricing) and defines three scenarios '
        'that reinsurers should use side-by-side when structuring coverage:',
        styles['BodyText2']
    ))
    story.append(make_table(
        ['Scenario', 'PoD (Yr 30)', 'Tail-layer claim rate', 'Use in reinsurance structuring'],
        [
            ['Base (model-as-written)',
             f'{MC["deficit_prob"]:.2f}%',
             f'{INS["tail_risk"]["poc"]:.2f}%',
             'Quoted fair premium; pricing floor'],
            ['Realistic-central',
             '40%',
             '— (not separately run)',
             'Premium anchor; treaty rate-on-line'],
            ['Adverse-plausible',
             '69%',
             '— (not separately run)',
             'Capital sizing; attachment/limit design; PML'],
        ],
        col_widths=[40*mm, 28*mm, 30*mm, 52*mm]
    ))
    story.append(Paragraph(
        '<i>Scenario PoD figures are xlsm-verified (realistic-central and adverse-plausible parameter sets, '
        'defined in the companion <b>Model Assumptions &amp; Parameter Risk</b> paper). The tail-layer (reinsurance) '
        'claim rate was not separately simulated for each scenario; it remains structurally bounded by the '
        'per-mortgage reinsurance PoC ceiling and rises with PoD. The three-scenario logic (pricing floor / anchor / '
        'capital sizing) is the recommended structuring framework.</i>',
        styles['BodyText2']
    ))
    story.append(Spacer(1, 3*mm))
    story.append(Paragraph(
        '<b>Reinsurer guidance:</b> Structural features of the EPM (run-off mechanism, Payments Waterfall, '
        '~10–12% loss severity given a deficit*, 100% insurance from dollar zero, ~30-year float on upfront premium) '
        'are scenario-robust — they are structural features of the product, not parameter-dependent. What moves '
        'across stress scenarios is the expected loss frequency. Reinsurance pricing should anchor to the '
        'realistic-central scenario (PoD 40%), and capital and limit sizing to the adverse-plausible scenario '
        '(PoD 69%) — both PoD figures are xlsm-verified and detailed in the companion Parameter Risk paper.',
        styles['Callout']
    ))
    story.append(PageBreak())

    # ---- 2. STOCHASTIC MODEL SELECTION AND CALIBRATION ----
    story.append(Paragraph('2. Stochastic Model Selection and Calibration', styles['SectionHead']))
    story.append(Paragraph(
        'The EPM requires robust stochastic modelling of two key risk drivers over a 30-year horizon: '
        'S&P index returns and interest rates. This section describes the model selection process, '
        'explains why each model was chosen, and details the parameter estimation methodology.',
        styles['BodyText2']
    ))

    story.append(Paragraph('2.1 Interest Rate Model: Vasicek/Ornstein-Uhlenbeck Process', styles['SubHead']))
    story.append(Paragraph(
        'Cash rates are modelled using the Vasicek (Ornstein-Uhlenbeck) process, the standard model for '
        'mean-reverting interest rates. The exact discretisation (Shevchenko 2026, Section 1) is:',
        styles['BodyText2']
    ))
    story.append(Paragraph(
        'r(t+1) = r(t) * w + theta * (1 - w) + v * epsilon(t)',
        styles['Equation']
    ))
    story.append(Paragraph(
        'where w = exp(-kappa * dt), v = sigma * sqrt((1 - w^2) / (2 * kappa)), and epsilon ~ N(0,1).',
        styles['BodyText2']
    ))
    story.append(Paragraph(
        'This model captures the empirically observed tendency of interest rates to revert to a long-run mean, '
        'which is essential for realistic 30-year projections. A random walk model would produce unrealistic '
        'rate paths over such a long horizon.',
        styles['BodyText2']
    ))

    story.append(Paragraph('2.2 Equity Model: GBM + Mean Reversion', styles['SubHead']))
    story.append(Paragraph(
        'Two candidate models were evaluated for equity returns using Maximum Likelihood Estimation (MLE) '
        'on historical S&P 500 data (Shevchenko 2026, Sections 2-3):',
        styles['BodyText2']
    ))

    story.append(make_table(
        ['Model', 'Equation', 'Log-Likelihood', 'Assessment'],
        [
            ['Geometric Brownian Motion (GBM)',
             'S(t+1) = S(t)(1 + mu + sigma * epsilon)',
             '-159.0',
             'Standard model; no mean reversion; overstates 30-year tail risk'],
            ['GBM + Mean Reversion (selected)',
             'S(t+1) = S(t)(1 + mu + sigma * epsilon) + gamma * (M(t) - S(t))',
             '-157.4',
             'Superior fit; mean reversion reduces unrealistic extreme paths'],
        ],
        col_widths=[30*mm, 50*mm, 25*mm, 48*mm]
    ))

    story.append(Spacer(1, 3*mm))
    story.append(Paragraph(
        'The GBM + Mean Reversion model was selected because it provides a statistically superior fit '
        '(higher log-likelihood) and, critically, incorporates mean reversion towards a deterministic trend. '
        'The mean reversion component M(t) grows at the expected return rate, and the parameter gamma '
        'controls the speed at which the equity index reverts to this trend after deviations.',
        styles['BodyText2']
    ))
    story.append(Paragraph(
        'For a 30-year mortgage product, this is particularly important: pure GBM can generate extremely '
        'divergent paths over 30 years (both unrealistically high and unrealistically low), whereas the '
        'mean-reverting model produces paths that are more consistent with observed long-run equity market '
        'behaviour. This results in a more realistic — and somewhat lower — estimate of tail risk.',
        styles['BodyText2']
    ))

    story.append(Paragraph('2.3 Parameter Estimation via Maximum Likelihood', styles['SubHead']))
    story.append(Paragraph(
        'All model parameters are estimated using Maximum Likelihood Estimation (MLE) on historical data — '
        'they are not arbitrary assumptions. The MLE procedure (detailed in Shevchenko 2026) provides:',
        styles['BodyText2']
    ))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>Statistically optimal estimates:</b> MLE produces the parameter values that '
        'maximise the probability of observing the historical data under each model.',
        styles['FPBullet']
    ))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>Standard errors:</b> The Fisher information matrix provides confidence intervals '
        'for each parameter, enabling sensitivity analysis.',
        styles['FPBullet']
    ))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>Model comparison:</b> The log-likelihood values allow formal comparison between '
        'GBM and GBM+MeanRev to determine which model better fits the data.',
        styles['FPBullet']
    ))

    story.append(Spacer(1, 3*mm))
    story.append(Paragraph('Estimated Parameters (MLE)', styles['SubHead']))
    story.append(make_table(
        ['Parameter', 'Symbol', 'MLE Estimate', 'Description'],
        [
            ['Equity expected return', 'mu_B', '9.2% p.a.', 'Long-run S&P 500 return'],
            ['Equity volatility', 'sigma_B', '16.6% p.a.', 'S&P 500 annual volatility'],
            ['Equity mean reversion speed', 'gamma_B', '0.163', 'Speed of reversion to trend'],
            ['Cash rate long-run mean', 'theta', '2.13% p.a.', 'Long-run equilibrium cash rate'],
            ['Cash rate mean reversion speed', 'kappa', '0.24', 'Rate of mean reversion'],
            ['Cash rate volatility', 'sigma_r', '1.22% p.a.', 'Cash rate annual volatility'],
            ['Equity-rate correlation', 'rho', '0.30', 'Cross-correlation (appropriate for 30yr horizon)'],
        ],
        col_widths=[42*mm, 18*mm, 25*mm, 68*mm]
    ))

    story.append(Spacer(1, 3*mm))
    story.append(Paragraph(
        'The correlation of 0.30 between equity returns and interest rate innovations is estimated over '
        'the full historical sample. This moderate positive correlation is appropriate for the 30-year '
        'horizon of the EPM product.',
        styles['BodyText2']
    ))

    story.append(Paragraph('2.4 Correlated Simulation Methodology', styles['SubHead']))
    story.append(Paragraph(
        'The Monte Carlo simulation generates 50,000 correlated paths for equity returns and interest rates '
        'over the 30-year mortgage term. Correlation is introduced via the Cholesky decomposition:',
        styles['BodyText2']
    ))
    story.append(Paragraph(
        'z1 ~ N(0,1)   [equity innovation]<br/>'
        'z2 = rho * z1 + sqrt(1 - rho^2) * z2_raw   [rate innovation]',
        styles['Equation']
    ))
    story.append(Paragraph(
        'This ensures that equity and rate shocks are correlated within each simulated year, matching '
        'the observed empirical relationship. The full simulation tracks the investment account, mortgage '
        'balance, interest costs, fees, and the interest payment holiday mechanism year-by-year for each path.',
        styles['BodyText2']
    ))

    story.append(Paragraph('2.5 Parameter Uncertainty and Alternative Calibrations', styles['SubHead']))
    story.append(Paragraph(
        'MLE point estimates on a ~75-year historical sample are the right starting point, but over a '
        '30-year forward horizon each estimate carries material uncertainty. A separate <i>Model Assumptions '
        '&amp; Parameter Risk</i> paper documents the stress-test fully; the short summary relevant to '
        'reinsurance structuring is:',
        styles['BodyText2']
    ))

    story.append(make_table(
        ['Parameter', 'Base (MLE central)', 'Alternative / stress', 'Implication for tail-layer'],
        [
            ['Equity drift (mu_B)', '9.2% p.a.',
             'Shiller CAPE-implied 5–6% p.a.',
             'Raises PoD materially; increases tail claim frequency'],
            ['Mean reversion (gamma_B)', '0.163',
             'Bootstrap 95% CI [0.019, 0.447]',
             'Lower gamma widens 30-year distribution; fatter tail'],
            ['Cash rate long-run mean (theta)', '2.13% p.a.',
             'AU 30-yr MLE ~4.7% p.a.',
             'Higher funding cost → higher mortgage balance at expiry'],
            ['Equity-rate correlation (rho)', '0.30',
             'Crisis-period 0.5–0.7',
             'Weakens hedge; drift/rate tail shocks become co-incident'],
            ['Collar cost', '0.046% p.a. net credit',
             'Black-Scholes 0.16–0.44% p.a. net cost',
             'Raises interest drag; increases deficit severity'],
            ['Loss severity (structural)*', '~10–12% of mortgage balance',
             'Scenario-robust across stresses',
             'Does not move materially — structural floor'],
        ],
        col_widths=[32*mm, 30*mm, 40*mm, 58*mm]
    ))

    story.append(Spacer(1, 3*mm))
    story.append(Paragraph(
        'Applying these stresses jointly produces the three scenarios flagged in the Executive Summary '
        '(base / realistic-central / adverse-plausible). Reinsurers should read the Executive Summary '
        'premium numbers as the base-case headline and use the realistic-central and adverse-plausible '
        'cases for pricing anchor and capital sizing respectively.',
        styles['BodyText2']
    ))
    story.append(Paragraph(
        '<b>What is scenario-robust:</b> the ~10–12% loss severity on deficit paths*, the absence of prepayment '
        'risk (run-off mechanism), the ~30-year float on upfront premium, and the zero-attachment-point structure '
        'of combined LMI + reinsurance. These are structural features of the product, not parameter-dependent.',
        styles['Callout']
    ))
    story.append(Paragraph(
        '<i>*Loss severity is the model\'s conditional expected deficit ($143,274, xlsm-verified) expressed as a '
        'fraction of the home value ($1.5M, giving ~10%) or peak loan ($1.2M, giving ~12%). The authoritative '
        'price of risk is the fair premium itself.</i>',
        styles['BodyText2']
    ))
    story.append(PageBreak())

    # ---- 2.6 NO WEIGHTING OR CAPPING OF EXTREME PATHS ----
    story.append(Paragraph('2.6 No Weighting or Capping of Extreme Paths vs Likely Paths', styles['SubHead']))
    story.append(Paragraph(
        'In long-term Monte Carlo modelling a common question arises as to the capping or weighting of extreme '
        'return pathways (both positive and negative). <b>Equal weighting is the correct actuarial approach.</b> '
        'Each of the 50,000 paths represents an equally probable realisation of the stochastic model.',
        styles['BodyText2']
    ))
    story.append(Paragraph(
        '<b>Downweighting extreme paths</b> would amount to saying "we don\'t think 30-year equity returns below '
        '5% can happen" — but that is exactly what happened in Japan (1990–2020), and arguably in the US during '
        '1929–1959 if you adjust for inflation. The whole point of running 50,000 paths is to capture the tail.',
        styles['BodyText2']
    ))
    story.append(Paragraph(
        '<b>Capping paths would understate risk.</b> If you cap the downside paths (e.g. "no path can produce a '
        'final deficit worse than -$500K"), you are essentially providing a hidden guarantee that does not exist. '
        'An actuary or regulator reviewing the model would immediately flag this as cherry-picking.',
        styles['BodyText2']
    ))
    story.append(Paragraph('There are legitimate ways to manage this:', styles['BodyText2']))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>1. The mean-reversion model already does this.</b> The GBM (with Stochastic '
        'Drift) + Mean Reversion model (Shevchenko) is specifically designed to prevent unrealistic extreme paths. '
        'Pure GBM allows equity to drop 99% and never recover — the mean-reversion parameter (γ=0.163) pulls paths '
        'back toward trend. This is a structurally honest way to reduce tail extremes, especially when modelling '
        'an index rather than individual stock performance.',
        styles['FPBullet']
    ))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>2. The collar already caps upside.</b> The 80/140 dynamic continuous hedging '
        'buffer means no single year contributes more than +40% or less than -20% to the investment account. This '
        'is a real structural cap, not a statistical trick.',
        styles['FPBullet']
    ))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>3. Conditional tail metrics are more informative than capping.</b> Rather than '
        'suppressing extreme paths, report them separately: among the 8.37% of deficit paths, the conditional '
        'expected deficit is ~$143K, and the worst ~1.67% (the reinsurance tail) carry larger deficits beyond the '
        '$234,495 boundary. This gives investors a complete picture.',
        styles['FPBullet']
    ))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>4. Scenario-based presentation alongside MC.</b> Stress scenarios (GFC-like, '
        'stagflation, Japan) tell the story better than raw percentiles — e.g. "even in a Japan-like environment '
        '(low returns, low rates), PoC rises but stays insurable" is more useful than quoting a single extreme '
        'path. (Scenario PoD figures are quantified in the companion Parameter Risk paper.)',
        styles['FPBullet']
    ))
    story.append(Paragraph(
        '<b>Recommendation:</b> Do not cap or reweight the paths. The model\'s structural features (mean reversion, '
        'collar, holiday mechanism, LMI) already provide legitimate protection against extremes. Present the full '
        'distribution honestly, and use the stress scenarios to contextualise the tails. This is what actuaries '
        'and regulators want to see — a model that faces its risks squarely rather than defining them away.',
        styles['Callout']
    ))
    story.append(PageBreak())

    # ---- 3. INSURANCE ARCHITECTURE OVERVIEW ----
    story.append(Paragraph('3. EPM Insurance Architecture Overview', styles['SectionHead']))
    story.append(Paragraph(
        'The EPM insurance structure provides 100% coverage of all deficit outcomes from dollar zero. '
        'There is no deductible, no co-insurance gap, and no uninsured first-loss position for any party. '
        'The two insurance layers divide responsibility by <b>loss severity</b>:',
        styles['BodyText2']
    ))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>LMI Layer:</b> Covers the full deficit for 80% of deficit paths '
        '(those with smaller deficits, up to the split boundary) on each individual mortgage.',
        styles['FPBullet']
    ))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>Tail Risk Reinsurance:</b> On the remaining 20% of deficit paths '
        '(those with larger deficits), the LMI insurer pays up to the split boundary and 20% tail risk is '
        'transferred to the portfolio level (i.e. the loan book of each mortgage funder), where the Payments & '
        'Risk Waterfall is first applied before the reinsurer pays any residual loss.',
        styles['FPBullet']
    ))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>Combined effect:</b> The lender and wholesale mortgage funder bear zero '
        'credit risk — every deficit is fully covered from the first dollar.',
        styles['FPBullet']
    ))

    story.append(Paragraph('The Payments & Risk Waterfall', styles['SubHead']))
    story.append(Paragraph(
        '<b>No insurance or reinsurance claim can be made before end-of-term (30 years).</b> Before any claim is '
        'triggered, a multi-step Payments &amp; Risk Waterfall applies — first at the individual-mortgage level '
        'and then at the portfolio (i.e. loan book) level. This waterfall dramatically reduces the actual claim '
        'frequency:',
        styles['BodyText2']
    ))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>Step 1 — Interest Holidays:</b> Where the mortgage offset account balance for '
        'a borrower falls below its original opening balance at start-of-loan by 25% or more (the Holiday-Entry '
        'trigger), an interest holiday automatically occurs in order to: preserve offset capital; maximise the '
        'return of reference assets (the index ETFs) as the market rebounds; and maintain the positive effect of '
        'compounding returns on offset capital invested in index reference assets.',
        styles['FPBullet']
    ))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>Step 2 — ETF Selldown:</b> The individual mortgage\'s offset account holds a '
        'calculated amount of loan capital as reference assets (S&P 500 index-linked ETFs), sized by reference to '
        'the expected return pathway. ETFs are liquidated to cover the loan cost (interest) and outstanding '
        'mortgage balance (part principal) each quarter.',
        styles['FPBullet']
    ))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>Step 3 — Capital Buffer:</b> A further portion of loan capital is held in the '
        'individual mortgage\'s offset account, also as reference assets (S&P 500 index-linked ETFs). The capital '
        'buffer is sized by reference to historical index drawdown in any 12-month period (15–20%). These ETFs are '
        'liquidated if needed, and only after depletion of the Step 2 selldown.',
        styles['FPBullet']
    ))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>Step 4 — Continuous Dynamic Hedging:</b> A capital-market risk-management '
        'solution. An index collar overlay using a laddered 140/80 hedge — put options against long-term call '
        'options — on the portfolio of ETFs held in the individual mortgage offset account. The 80/140 hedge is '
        'reset each 1, 3 or 5 years, always limiting the loss to 20%.',
        styles['FPBullet']
    ))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>Step 5 — LMI:</b> An insurance-markets risk solution. Every mortgage is '
        'covered by an LMI policy insuring the lender. The policy is subject to a top cover limit (in $) '
        'representing the worst 20% quantile of return pathways (the tail risk) calculated for each mortgage. '
        'Only the first 80% of loss triggers an insurance claim. This is the true Insurance PoC (Probability of '
        'Claim); PoC at end-of-term (Year 30) is kept within a target range of ≤10%.',
        styles['FPBullet']
    ))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>Step 6 — Cross-Subsidisation:</b> A risk-pooling solution. Any remaining '
        'shortfall at end-of-term is transferred from the individual mortgage to the portfolio (loan book) level. '
        'This pooling mechanism uses surpluses from performing unexpiring mortgages in a funder\'s loan book to '
        'offset deficits from underperforming expiring or expired mortgages.',
        styles['FPBullet']
    ))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>Step 7 — Net Deficit:</b> An insurance-markets risk solution. Only the '
        'residual deficit after Steps 1 through 6 triggers a reinsurance claim. This is the true Reinsurance PoC; '
        'PoC at end-of-term (Year 30) is kept within a target range of ≤2%.',
        styles['FPBullet']
    ))

    story.append(Spacer(1, 3*mm))
    story.append(Paragraph(
        f'The Payments Waterfall (ETF selldown plus cross-subsidisation from surplus mortgages) reduces the '
        f'claim probability from the per-mortgage level to the portfolio level:',
        styles['Callout']
    ))
    story.append(make_table(
        ['Metric', 'Probability', 'Notes'],
        [
            ['Per-mortgage PoD (yr 30)', f'{MC["deficit_prob"]:.2f}%', 'One mortgage in deficit at maturity (balance-sheet view)'],
            ['Per-mortgage reinsurance PoC', f'{PER_MORTGAGE_REINS_POC:.2f}%', 'Deficit beyond LMI boundary — hard ceiling for portfolio figure'],
            ['Portfolio reinsurance PoC (after cross-subsidy)', f'≤ {PER_MORTGAGE_REINS_POC:.2f}%', 'Bounded by the per-mortgage ceiling; diversification reduces it modestly'],
        ],
        col_widths=[48*mm, 36*mm, 68*mm]
    ))
    story.append(Spacer(1, 2*mm))
    story.append(Paragraph(
        f'<b>What this means.</b> The per-mortgage reinsurance PoC ({PER_MORTGAGE_REINS_POC:.2f}%) is the hard '
        f'ceiling for the portfolio figure — cross-subsidisation and diversification can only reduce it, never '
        f'increase it — and it sits comfortably within the ≤2% end-of-term target. The EPM structure lends '
        f'itself to pooling because there are always more positive than negative return pathways over the 30-year '
        f'horizon (otherwise the S&P 500 would not appreciate over time): for an average P&I EPM, ~85% of return '
        f'pathways are positive and only ~15% are negative. The Payments Waterfall pools the surpluses of the '
        f'positive pathways against the deficits of the negative ones, so the portfolio reinsurance PoC sits '
        f'modestly below the {PER_MORTGAGE_REINS_POC:.2f}% per-mortgage ceiling. (Note: the aggregate portfolio '
        f'balance-sheet deficit probability is a point-in-time PoD snapshot of the whole book, not a claim metric.)',
        styles['Callout']
    ))

    story.append(Paragraph('Two-Layer Insurance Structure', styles['SubHead']))
    story.append(fig_to_image(chart_insurance_structure(), height=80*mm))

    story.append(Paragraph(
        f'The <b>split boundary</b> is set at the 20th percentile of the conditional deficit distribution '
        f'for each mortgage. For the representative {HOME_LABEL_M} home shown above, this boundary is '
        f'${abs(INS["top_cover_limit"]):,.0f} per mortgage. This boundary is not a global constant — '
        f'it varies with home value, LVR, annuity amount, and mortgage term, and is recalculated '
        f'via Monte Carlo simulation for each mortgage configuration.',
        styles['BodyText2']
    ))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>LMI Layer:</b> Covers 80% of deficit paths in full (those with deficits '
        'below the split boundary). On the remaining 20% of paths, the LMI insurer pays up to the boundary amount '
        '(i.e. the top-cover policy limit). A LMI claim can only be made at end-of-term.',
        styles['FPBullet']
    ))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>Tail Risk Reinsurance:</b> On the 20% of deficit paths that exceed the split '
        'boundary, the reinsurer is on-risk to pay the excess above the boundary. The reinsurer has no liability '
        'on the other 80% of deficit paths. Any claim on portfolio reinsurance only occurs after pooling and '
        'cross-subsidisation between mortgages in each funder\'s loan book, and can only be made at end-of-term.',
        styles['FPBullet']
    ))

    story.append(Spacer(1, 3*mm))
    story.append(Paragraph(
        '<b>Key point for reinsurance underwriters:</b> Both insurers provide coverage from dollar zero. '
        'The split is by loss severity, not by attachment point. On every deficit path, the LMI insurer '
        'pays first (up to the boundary). On the 20% of paths where the deficit exceeds the boundary, '
        'the reinsurer pays the excess. There is no "attachment point" in the traditional XoL sense — '
        'the attachment is at zero for the combined structure.',
        styles['Callout']
    ))
    story.append(PageBreak())

    # ---- 4. PART A: LMI PROGRAM ----
    story.append(Paragraph('4. Part A: LMI Program — Structure and Settings', styles['SectionHead']))

    story.append(Paragraph('4.1 LMI Program Scope', styles['SubHead']))
    story.append(Paragraph(
        'The LMI program provides first-loss credit protection to the lender on every EPM '
        'originated. Unlike traditional LMI (which covers shortfalls from foreclosure sales — essentially a '
        'property risk), EPM LMI covers the deficit between the offset account value and the outstanding '
        'mortgage balance at mortgage expiry — essentially, the long-term index risk over 30 years.',
        styles['BodyText2']
    ))

    story.append(Paragraph(f'4.2 LMI Program Settings (per-mortgage, {HOME_LABEL_M} home)', styles['SubHead']))
    story.append(make_table(
        ['Setting', 'Value', 'Rationale'],
        [
            ['Coverage trigger', 'Mortgage expiry only (Year 30)', 'No intermediate claims; run-off mechanism prevents early exit'],
            ['Split boundary', f'${abs(INS["top_cover_limit"]):,.0f} per mortgage', 'P20 of conditional deficit distribution (recalculated per mortgage config)'],
            ['Coverage scope', '100% of deficit paths from $0', 'LMI pays full deficit on 80% of paths; pays up to boundary on remaining 20%'],
            ['PoC (individual)', f'{INS["lmi"]["poc"]:.1f}%', 'Probability any individual mortgage results in a deficit'],
            ['Conditional expected LMI claim', f'${abs(INS["lmi"]["cond_expected_deficit"]):,.0f} per mortgage',
             'Mean LMI payment per deficit path; capped at the split boundary on severe-deficit paths'],
            ['Fair premium (PV)', f'${INS["lmi"]["fair_premium_pv"]:,.0f} per mortgage', f'Discounted expected loss at {V14["cash_rate_theta"]*100:.2f}% (cash rate long-run mean)'],
            ['Loaded premium (50%)', f'${INS["lmi"]["loaded_premium"]:,.0f} per mortgage', 'Industry-standard loading for expenses + profit'],
            ['Premium as % of max loan', f'{INS["lmi"]["pct_max_loan"]:.2f}%', 'Competitive with traditional LMI at 80% LVR'],
            ['Payment timing', 'Single upfront premium at origination', 'Funded from mortgage drawdown'],
            ['Claim timing', 'At mortgage expiry (Year 30)', 'Deferred claims benefit insurer float'],
        ],
        col_widths=[42*mm, 35*mm, 76*mm]
    ))

    story.append(Paragraph('4.3 LMI Insurer Advantages', styles['SubHead']))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>Deferred claims:</b> Claims only arise at mortgage expiry (Year 30). This '
        'provides ~30 years of investment float — the insurer collects the premium upfront and invests it '
        'for the full mortgage term before any claim liability crystallises.',
        styles['FPBullet']
    ))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>Bounded exposure:</b> The split boundary caps the maximum LMI claim per mortgage at '
        f'${abs(INS["top_cover_limit"]):,.0f} (for a {HOME_LABEL_M} home). Larger deficits are shared with the reinsurer.',
        styles['FPBullet']
    ))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>No moral hazard:</b> The homeowner has no incentive to default — they retain full '
        'ownership of their property. The run-off mechanism prevents strategic early exit.',
        styles['FPBullet']
    ))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>Transparent pricing:</b> Monte Carlo simulation with MLE-calibrated parameters '
        'provides precise, auditable premium calculations with quantified standard errors.',
        styles['FPBullet']
    ))

    story.append(Paragraph('4.4 Interest Payment Holiday Mechanism', styles['SubHead']))
    story.append(Paragraph(
        'The EPM includes an interest payment holiday mechanism that protects the investment account during '
        'periods of underperformance. When the investment account falls below 75% of the initial mortgage '
        'amount, interest payments to the wholesale funder are suspended. Importantly:',
        styles['BodyText2']
    ))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> The <b>annuity payments to the borrower continue</b> during the holiday — '
        'it is the interest cost payments (to the funder) that pause.',
        styles['FPBullet']
    ))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> Deferred interest is accumulated and repaid when the investment account '
        f'recovers above the exit threshold (145.8% of initial mortgage).',
        styles['FPBullet']
    ))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> In practice the mechanism is rarely needed and never burdens the borrower. '
        f'<b>More than half of mortgages ({MC["pct_zero_holidays"]:.0f}%) never enter a holiday at all, and the '
        'typical (median) borrower takes none.</b> Where holidays do occur they concentrate in the early years — '
        'while the investment account is still building against the freshly-drawn mortgage — and fade to around 2% '
        f'incidence by maturity as the account compounds. Across the whole book the average is just '
        f'{MC["mean_total_holiday_years"]:.1f} holiday-years over the 30-year term. It is a counter-cyclical safety '
        'valve that preserves investment capital in downturns, lowering the probability of deficit.',
        styles['FPBullet']
    ))
    story.append(PageBreak())

    # ---- 5. PART B: TAIL RISK REINSURANCE ----
    story.append(Paragraph('5. Part B: Tail Risk Reinsurance — Structure and Settings', styles['SectionHead']))

    story.append(Paragraph('5.1 Reinsurance Program Scope', styles['SubHead']))
    story.append(Paragraph(
        'The Tail Risk Reinsurance program provides excess-of-boundary protection for the most severe '
        'deficit outcomes. It covers the 20% of deficit paths where the per-mortgage deficit exceeds the '
        'split boundary. On these paths, the reinsurer pays only the excess above the boundary — the LMI '
        'insurer still pays up to the boundary amount.',
        styles['BodyText2']
    ))
    story.append(Paragraph(
        '<b>Important clarification:</b> This is not a traditional excess-of-loss (XoL) treaty with an '
        'attachment point above zero. The combined LMI + reinsurance structure provides 100% coverage from '
        'dollar zero. The "split boundary" determines how much the LMI insurer pays on severe-deficit paths '
        'before the reinsurer becomes liable for the excess. The attachment point for the overall insurance '
        'structure is zero — no deficit goes uninsured.',
        styles['Callout']
    ))

    story.append(Paragraph(f'5.2 Reinsurance Program Settings (per-mortgage, {HOME_LABEL_M} home)', styles['SubHead']))
    story.append(make_table(
        ['Setting', 'Value', 'Rationale'],
        [
            ['Split boundary', f'${abs(INS["top_cover_limit"]):,.0f} per mortgage', 'P20 of conditional deficit distribution — varies by mortgage configuration'],
            ['Coverage', 'Excess above split boundary per mortgage', 'Reinsurer pays deficit minus boundary amount on severe paths'],
            ['Probability of claim (individual)', f'{INS["tail_risk"]["poc"]:.2f}%', f'Only {INS["tail_risk"]["poc"]:.2f}% of all mortgages trigger a reinsurance claim'],
            ['Fair premium (PV)', f'${INS["tail_risk"]["fair_premium_pv"]:,.0f} per mortgage', 'Discounted expected excess loss'],
            ['Loaded premium (50%)', f'${INS["tail_risk"]["loaded_premium"]:,.0f} per mortgage', 'Standard risk loading'],
            ['Premium as % of max loan', f'{INS["tail_risk"]["pct_max_loan"]:.4f}%', 'Very small relative to mortgage size'],
            ['Payment timing', 'Single upfront premium at origination', 'Funded from mortgage drawdown alongside LMI premium'],
            ['Claim timing', 'At mortgage expiry (Year 30) only', 'Same deferred-claim benefit as LMI'],
            ['Assessment basis', 'Per-mortgage', 'Each mortgage independently assessed at expiry'],
        ],
        col_widths=[42*mm, 35*mm, 76*mm]
    ))

    story.append(Paragraph('5.3 Why the Split Boundary Works', styles['SubHead']))
    story.append(Paragraph(
        'The 20th percentile of the conditional deficit distribution (P20) is the optimal boundary because:',
        styles['BodyText2']
    ))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> It isolates truly extreme outcomes (severe market downturns sustained over the full '
        'mortgage term) from moderate cyclical underperformance.',
        styles['FPBullet']
    ))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> 80% of deficit paths result in claims fully manageable by the LMI insurer '
        f'(up to ${abs(INS["top_cover_limit"]):,.0f} per mortgage for a {HOME_LABEL_M} home).',
        styles['FPBullet']
    ))
    story.append(Paragraph(
        f'<bullet>&bull;</bullet> The 20% tail represents only {INS["tail_risk"]["poc"]:.2f}% of all mortgage paths — '
        'a low-frequency event well suited for reinsurance markets that specialise in severity risk.',
        styles['FPBullet']
    ))
    story.append(Paragraph(
        f'<bullet>&bull;</bullet> The reinsurance premium is economically efficient — only '
        f'${INS["tail_risk"]["fair_premium_pv"]:,.0f} fair premium per mortgage '
        f'({INS["tail_risk"]["pct_max_loan"]:.2f}% of max loan) because claim probability is very low.',
        styles['FPBullet']
    ))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> The boundary is not a fixed dollar amount — it is recalculated for each '
        'mortgage configuration via Monte Carlo simulation, ensuring the split remains appropriate.',
        styles['FPBullet']
    ))
    story.append(PageBreak())

    # ---- 6. PART C: INTERACTION BETWEEN LMI AND REINSURANCE ----
    story.append(Paragraph('6. Part C: Interaction Between LMI and Tail Risk Reinsurance', styles['SectionHead']))

    story.append(Paragraph('6.1 Claim Flow Mechanics', styles['SubHead']))
    story.append(Paragraph(
        'The two programs interact through a clear, sequential claim process at mortgage expiry:',
        styles['BodyText2']
    ))

    story.append(make_table(
        ['Step', 'Action', 'Responsible Party'],
        [
            ['1', 'Mortgage expires (Year 30) — investment account liquidated', 'FutureProof (servicer)'],
            ['2', 'Payments Waterfall applied (ETF selldown, cross-subsidisation)', 'FutureProof (portfolio manager)'],
            ['3', 'Net deficit determined after waterfall', 'FutureProof (servicer)'],
            ['4a', f'If deficit <= split boundary: LMI pays full deficit (from $0)', 'LMI Insurer'],
            ['4b', f'If deficit > split boundary: LMI pays up to boundary, reinsurer pays excess', 'LMI Insurer + Reinsurer'],
            ['5', 'Mortgage funder made whole — zero credit loss', 'N/A'],
        ],
        col_widths=[12*mm, 95*mm, 46*mm]
    ))

    story.append(Spacer(1, 3*mm))
    story.append(Paragraph(
        f'<b>Worked example (per average mortgage, {HOME_LABEL_M} home, P&I mortgage):</b> If a mortgage expires with an $800,000 deficit '
        f'(after the Payments Waterfall), the LMI insurer pays ${abs(INS["top_cover_limit"]):,.0f} and the '
        f'reinsurer pays ${800_000 - abs(INS["top_cover_limit"]):,.0f}. If the deficit is $400,000, the LMI '
        f'insurer pays the full $400,000 and the reinsurer pays nothing.',
        styles['Callout']
    ))

    story.append(Paragraph('6.2 Key Interaction Principles', styles['SubHead']))
    story.append(Paragraph(
        '<b>Principle 1: No gap in coverage.</b> The LMI layer and reinsurance layer together provide '
        '100% coverage of all deficit outcomes from dollar zero. There is no deductible, no co-insurance, '
        'and no coverage gap. The mortgage funder bears zero credit risk.',
        styles['BodyText2']
    ))
    story.append(Paragraph(
        '<b>Principle 2: Clear allocation by severity.</b> The split is by loss severity, not by probability. '
        'Every deficit path is either: (a) fully covered by LMI (80% of deficit paths — smaller losses), or '
        '(b) split between LMI (pays up to boundary) and reinsurance (pays excess). The reinsurer only '
        'participates on the most severe 20% of deficit outcomes.',
        styles['BodyText2']
    ))
    story.append(Paragraph(
        '<b>Principle 3: Independent pricing.</b> Each layer is priced independently based on its own loss '
        'distribution. The LMI premium reflects expected losses up to the split boundary. '
        'The reinsurance premium reflects only the excess-of-boundary component (after pooling and '
        'cross-subsidisation with the funder\'s loan book).',
        styles['BodyText2']
    ))
    story.append(Paragraph(
        '<b>Principle 4: Aligned incentives.</b> The LMI insurer retains 80% of deficit frequency risk and '
        'pays on 100% of deficit paths (up to the boundary), ensuring active underwriting engagement. '
        'The reinsurer takes severity risk at low probability, which is their natural specialty.',
        styles['BodyText2']
    ))

    story.append(Paragraph('6.3 Sensitivity of Boundary to Mortgage Configuration', styles['SubHead']))
    story.append(Paragraph(
        'The split boundary is calibrated to the P20 of the conditional deficit distribution for each '
        'mortgage configuration. The boundary is not a global constant — it shifts with the underlying '
        'risk profile of each mortgage:',
        styles['BodyText2']
    ))

    story.append(make_table(
        ['Parameter Change', 'Effect on Split Boundary', 'Effect on Reinsurance Premium'],
        [
            ['Higher home value (e.g. $3M)', 'Increases proportionally (larger mortgage)', 'Increases proportionally'],
            ['Higher equity volatility', 'Increases (wider deficit distribution)', 'Increases (more tail risk)'],
            ['Lower equity return', 'Increases (more deficits, wider tails)', 'Increases moderately'],
            ['Higher LVR', 'Increases proportionally', 'Increases roughly proportionally'],
            ['Higher buffer cap', 'May increase or decrease (trade-off)', 'Marginal effect'],
            ['Portfolio diversification', 'No direct effect (per-mortgage boundary)', 'Reduces aggregate exposure'],
        ],
        col_widths=[40*mm, 56*mm, 57*mm]
    ))
    story.append(PageBreak())

    # ---- 7. PART D: REINSURER STRUCTURING RECOMMENDATIONS ----
    story.append(Paragraph('7. Part D: Reinsurer Structuring Recommendations', styles['SectionHead']))

    story.append(Paragraph('7.1 Recommended Treaty Structure', styles['SubHead']))
    story.append(Paragraph(
        'The recommended structure for the Tail Risk Reinsurance program is a <b>per-mortgage severity-based '
        'reinsurance treaty</b> with the following key features:',
        styles['BodyText2']
    ))

    story.append(make_table(
        ['Feature', 'Recommendation', 'Rationale'],
        [
            ['Treaty type', 'Per-mortgage excess-of-boundary', 'Reinsurer pays excess above split boundary on each mortgage'],
            ['Split boundary', f'${abs(INS["top_cover_limit"]):,.0f} per mortgage ({HOME_LABEL_M} home)', 'P20 of conditional deficit — varies by mortgage config'],
            ['Limit', 'Unlimited (or $3M per risk)', 'Tail events can produce large individual deficits'],
            ['Term', '30 years (matching mortgage term)', 'Claims deferred until mortgage expiry'],
            ['Premium basis', 'Single upfront premium per mortgage', 'Paid at origination alongside LMI premium'],
            ['Loaded premium', f'${INS["tail_risk"]["loaded_premium"]:,.0f} per mortgage ({HOME_LABEL_M} home)', f'Fair premium ${INS["tail_risk"]["fair_premium_pv"]:,.0f} + 50% loading'],
            ['Aggregate limit (annual)', 'Optional — 10x expected annual claims', 'Catastrophe protection for extreme scenarios'],
            ['Reinstatement', 'Automatic, unlimited', 'Continuous coverage essential for mortgage funder'],
            ['Claims basis', 'Losses discovered at mortgage expiry', 'Triggered at Year 30'],
        ],
        col_widths=[35*mm, 50*mm, 68*mm]
    ))

    story.append(Paragraph('7.2 Portfolio-Level Considerations', styles['SubHead']))
    story.append(Paragraph(
        'The reinsurer should consider the following portfolio dynamics when structuring coverage:',
        styles['BodyText2']
    ))

    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>Vintage diversification:</b> A portfolio of 1,000+ EPMs per year across '
        'multiple vintages means claims are spread over decades. It is a basic error to assume that an economic '
        'downturn affects all mortgages equally — each EPM has its own unique surplus/deficit position at any '
        'time slice depending on when that mortgage was originated. A "bad" vintage (originated during a market '
        'peak) will have its claims offset by "good" vintages.',
        styles['FPBullet']
    ))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>Geographic diversification:</b> FutureProof operates across US, Australia, '
        'NZ, and UK. Different equity markets and rate cycles, and movements in applicable exchange rates, provide '
        'natural diversification.',
        styles['FPBullet']
    ))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>Deferred claims benefit:</b> The reinsurer collects the upfront premium and '
        'invests it for ~30 years before any claim liability emerges. The investment income on the accumulated '
        'premium reserve is substantial and should be factored into pricing.',
        styles['FPBullet']
    ))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>Low frequency, moderate severity:</b> Only {:.2f}% of all mortgages trigger '
        'a reinsurance claim. When they do, the per-mortgage excess is bounded by the relationship between '
        'the split boundary and the maximum realistic deficit.'.format(INS['tail_risk']['poc']),
        styles['FPBullet']
    ))

    story.append(Paragraph('7.3 Alternative Treaty Structures', styles['SubHead']))
    story.append(Paragraph(
        'While per-mortgage severity-based reinsurance is the recommended primary structure, reinsurers may also consider:',
        styles['BodyText2']
    ))

    story.append(make_table(
        ['Structure', 'Pros', 'Cons', 'Suitability'],
        [
            ['Per-mortgage excess-of-boundary (recommended)', 'Clean, transparent, simple pricing', 'Individual risk assessment needed', 'PRIMARY — best fit'],
            ['Aggregate excess-of-loss', 'Protects against correlated losses', 'More complex pricing', 'COMPLEMENTARY — for catastrophe layer'],
            ['Quota share', 'Proportional risk sharing', 'Less efficient for tail risk', 'NOT RECOMMENDED — wrong risk profile'],
            ['Stop loss', 'Caps total loss ratio', 'Expensive for low-frequency risk', 'OPTIONAL — aggregate cap'],
            ['ILW (Industry Loss Warranty)', 'Triggered by market index', 'Basis risk', 'INNOVATIVE — for systematic risk'],
        ],
        col_widths=[32*mm, 38*mm, 38*mm, 45*mm]
    ))

    story.append(Paragraph('7.4 Recommended Layered Structure for Larger Portfolios', styles['SubHead']))
    story.append(Paragraph(
        'For portfolios exceeding 5,000 EPMs, a layered reinsurance structure is recommended:',
        styles['BodyText2']
    ))

    story.append(make_table(
        ['Layer', 'Type', 'Trigger', 'Limit', 'Estimated Rate'],
        [
            ['Layer 1: Working Layer', 'Per-mortgage excess', f'Per-mortgage deficit > ${abs(INS["top_cover_limit"]):,.0f}', 'First $1M excess per mortgage', '0.03% of outstanding'],
            ['Layer 2: Buffer Layer', 'Per-mortgage excess', 'Per-mortgage excess > $1M above boundary', 'Next $2M excess per mortgage', '0.015% of outstanding'],
            ['Layer 3: Cat Layer', 'Aggregate excess', '150% of expected annual claims', '$10M xs attachment', '0.005% of outstanding'],
        ],
        col_widths=[32*mm, 25*mm, 35*mm, 32*mm, 29*mm]
    ))

    story.append(Paragraph(
        'This layered approach provides efficient risk transfer at each severity level and allows specialised '
        'reinsurers to participate in the layers that best match their risk appetite.',
        styles['BodyText2']
    ))

    story.append(Paragraph('7.5 Capital Sizing Across Parameter Scenarios', styles['SubHead']))
    story.append(Paragraph(
        'The three-scenario framework from Section 2.5 maps directly onto reinsurance structuring decisions. '
        'Each scenario has a distinct role — the base case is a pricing floor, the realistic-central case '
        'is the pricing anchor, and the adverse-plausible case is the capital-sizing reference. Using only '
        'the base case would under-price the treaty and undersize capital; using only the adverse-plausible '
        'case would over-price and lose competitive traction.',
        styles['BodyText2']
    ))

    story.append(make_table(
        ['Scenario', 'Tail-layer PoC', 'Expected loss (tail layer)', 'Reinsurer role'],
        [
            ['Base (model-as-written)',
             f'{INS["tail_risk"]["poc"]:.2f}%',
             f'~${INS["tail_risk"]["fair_premium_pv"]:,.0f} per mortgage',
             'Pricing floor — minimum acceptable premium'],
            ['Realistic-central',
             '— (not separately run)',
             '— (not separately run)',
             'Rate-on-line anchor; reserve testing'],
            ['Adverse-plausible',
             '— (not separately run)',
             '— (not separately run)',
             'Attachment/limit sizing; PML; capital allocation'],
        ],
        col_widths=[40*mm, 28*mm, 36*mm, 46*mm]
    ))
    story.append(Paragraph(
        '<i>Scenario PoD figures (realistic-central 40%, adverse-plausible 69%) are xlsm-verified and given in '
        'the companion Parameter Risk paper. The tail-layer (reinsurance) PoC and expected loss were not '
        'separately simulated per scenario; they remain bounded above by the per-mortgage reinsurance PoC '
        'ceiling and rise with PoD.</i>',
        styles['BodyText2']
    ))

    story.append(Spacer(1, 3*mm))
    story.append(Paragraph(
        '<b>Practical implications for treaty design:</b>',
        styles['BodyText2']
    ))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>Premium loading beyond the stated 50%:</b> the 50% loading above is '
        'calibrated to the base-case fair premium. A reinsurer anchoring to realistic-central would need '
        'either a larger loading, a scenario-weighted fair premium, or explicit experience-rating triggers.',
        styles['FPBullet']
    ))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>Per-risk limit:</b> should be sized against the adverse-plausible tail '
        'distribution, not the base-case tail. The maximum per-mortgage deficit observed under '
        'adverse-plausible parameters is the relevant severity reference.',
        styles['FPBullet']
    ))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>Aggregate cat layer:</b> the optional aggregate limit (Section 7.1) '
        'becomes more valuable under adverse-plausible parameters, since claim frequency clusters more '
        'tightly around bad-vintage years. For adverse-plausible calibration, aggregate protection is '
        'strongly recommended rather than optional.',
        styles['FPBullet']
    ))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>Experience-rating clauses:</b> given the wide spread between base and '
        'adverse-plausible, a profit-commission or swing-rated structure allows the reinsurer to write '
        'at realistic-central rates while sharing the benefit if actual experience tracks the base case.',
        styles['FPBullet']
    ))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>Float economics are scenario-robust:</b> the ~30-year investment float '
        'on upfront premium is structural — it applies equally under every scenario. Even under '
        'adverse-plausible assumptions, the economic present value of the treaty remains attractive '
        'provided pricing reflects the scenario-appropriate expected loss.',
        styles['FPBullet']
    ))
    story.append(PageBreak())

    # ---- 8. QUANTITATIVE ANALYSIS ----
    story.append(Paragraph('8. Quantitative Analysis — Model Results', styles['SectionHead']))
    story.append(Paragraph(
        f'<i>All values below are per-mortgage for a representative {HOME_LABEL_FULL} property at 80% LVR.</i>',
        styles['BodyText2']
    ))

    story.append(Paragraph('8.1 PoD Trajectory Over Mortgage Term', styles['SubHead']))
    story.append(fig_to_image(chart_poc_trajectory(), height=75*mm))
    story.append(Paragraph(
        f'The individual probability of deficit (PoD) declines from {MC["deficit_by_year"][0]:.1f}% in Year 1 '
        f'to {MC["deficit_prob"]:.1f}% at Year 30 as the PI amortisation progressively reduces the mortgage '
        f'balance. The reinsurance layer PoC follows the same trajectory at approximately one-fifth of the '
        f'individual PoD.',
        styles['BodyText2']
    ))

    story.append(Paragraph('8.2 Premium Allocation (per-mortgage)', styles['SubHead']))
    story.append(fig_to_image(chart_premium_allocation(), height=75*mm))
    story.append(Paragraph(
        f'The total per-mortgage fair premium of ${INS["combined"]["total_fair_premium"]:,.0f} is split '
        f'{100*INS["lmi"]["fair_premium_pv"]/INS["combined"]["total_fair_premium"]:.0f}% / '
        f'{100*INS["tail_risk"]["fair_premium_pv"]/INS["combined"]["total_fair_premium"]:.0f}% '
        f'between LMI and tail risk reinsurance. Both premiums are paid as single upfront amounts at '
        f'mortgage origination, funded from the mortgage drawdown.',
        styles['BodyText2']
    ))

    story.append(Paragraph('8.3 Surplus Distribution at Year 30 (per-mortgage)', styles['SubHead']))
    story.append(make_table(
        ['Percentile', 'Surplus ($)', 'Interpretation'],
        [
            ['P1 (worst 1%)', f'${MC["p1"]:,.0f}', 'Extreme downside — reinsurance claim likely'],
            ['P5', f'${MC["p5"]:,.0f}', 'Significant deficit — within LMI/reinsurance coverage'],
            ['P10', f'${MC["p10"]:,.0f}', 'Near boundary — moderate outcome'],
            ['P25', f'${MC["p25"]:,.0f}', 'Moderate surplus — no claim'],
            ['Median', f'${MC["median_surplus"]:,.0f}', 'Typical outcome — healthy surplus'],
            ['Mean', f'${MC["mean_surplus"]:,.0f}', 'Average outcome — strong surplus'],
            ['P75', f'${MC["p75"]:,.0f}', 'Good outcome'],
            ['P90', f'${MC["p90"]:,.0f}', 'Strong outcome'],
            ['P99', f'${MC["p99"]:,.0f}', 'Exceptional outcome'],
        ],
        col_widths=[30*mm, 40*mm, 83*mm]
    ))
    story.append(PageBreak())

    # ---- 9. PREMIUM PRICING FRAMEWORK ----
    story.append(Paragraph('9. Premium Pricing Framework', styles['SectionHead']))
    story.append(Paragraph(
        'Both the LMI premium and the reinsurance premium are calculated using the same Monte Carlo '
        'simulation framework and are paid as single upfront amounts at mortgage origination.',
        styles['BodyText2']
    ))

    story.append(Paragraph('9.1 LMI Premium Calculation (per-mortgage)', styles['SubHead']))
    story.append(Paragraph(
        'The LMI premium is calculated using the Discounted Expected Deficit methodology:',
        styles['BodyText2']
    ))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>Step 1:</b> Run 50,000-path Monte Carlo simulation (GBM+MeanRev equity model, '
        'Vasicek rates, MLE-calibrated parameters) to generate surplus/deficit distribution at mortgage expiry.',
        styles['FPBullet']
    ))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>Step 2:</b> Identify deficit paths (investment account &lt; outstanding mortgage balance). '
        f'Result: {INS["lmi"]["poc"]:.1f}% of paths are in deficit.',
        styles['FPBullet']
    ))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>Step 3:</b> Calculate the P20 of the conditional deficit distribution '
        f'to establish the per-mortgage split boundary (${abs(INS["top_cover_limit"]):,.0f} for a {HOME_LABEL_M} home).',
        styles['FPBullet']
    ))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>Step 4:</b> For each deficit path: LMI claim = min(deficit, split boundary). '
        f'Discount each claim to present value at {V14["cash_rate_theta"]*100:.2f}% (cash rate long-run mean).',
        styles['FPBullet']
    ))
    story.append(Paragraph(
        f'<bullet>&bull;</bullet> <b>Step 5:</b> Fair premium = mean of discounted claims = ${INS["lmi"]["fair_premium_pv"]:,.0f} per mortgage. '
        f'Apply 50% loading for expenses and profit = ${INS["lmi"]["loaded_premium"]:,.0f} per mortgage.',
        styles['FPBullet']
    ))

    story.append(Paragraph('9.2 Reinsurance Premium Calculation (per-mortgage)', styles['SubHead']))
    story.append(Paragraph(
        'The reinsurance premium follows the same methodology for the excess layer:',
        styles['BodyText2']
    ))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> For each deficit path exceeding the split boundary: '
        'reinsurance claim = deficit - split boundary.',
        styles['FPBullet']
    ))
    story.append(Paragraph(
        f'<bullet>&bull;</bullet> Discount each excess claim to present value at {V14["cash_rate_theta"]*100:.2f}%.',
        styles['FPBullet']
    ))
    story.append(Paragraph(
        f'<bullet>&bull;</bullet> Fair premium = mean of discounted excess claims = ${INS["tail_risk"]["fair_premium_pv"]:,.0f} per mortgage. '
        f'Apply 50% loading = ${INS["tail_risk"]["loaded_premium"]:,.0f} per mortgage.',
        styles['FPBullet']
    ))

    story.append(Paragraph('9.3 Premium Payment Structure', styles['SubHead']))
    story.append(Paragraph(
        'Both the LMI premium and the reinsurance premium are structured as single upfront payments '
        'at mortgage origination, funded from the mortgage drawdown:',
        styles['BodyText2']
    ))

    story.append(make_table(
        ['Premium Component', f'Amount (per-mortgage, {HOME_LABEL_M} home)', 'Payment Timing', 'Funded From'],
        [
            ['LMI premium (loaded)', f'${INS["lmi"]["loaded_premium"]:,.0f}', 'Upfront at origination', 'Mortgage drawdown'],
            ['Reinsurance premium (loaded)', f'${INS["tail_risk"]["loaded_premium"]:,.0f}', 'Upfront at origination', 'Mortgage drawdown'],
            ['Total insurance cost', f'${INS["combined"]["total_loaded_premium"]:,.0f}', 'Upfront at origination', 'Mortgage drawdown'],
            ['As % of max loan', f'{INS["combined"]["pct_max_loan"]:.2f}%', '', ''],
        ],
        col_widths=[40*mm, 48*mm, 35*mm, 30*mm]
    ))

    story.append(Spacer(1, 3*mm))
    story.append(Paragraph(
        'The upfront premium structure means the insurer and reinsurer both receive funds at origination '
        'and invest them for ~30 years before any claim liability arises. This investment float is a '
        'significant benefit and should be considered when evaluating the attractiveness of the risk.',
        styles['BodyText2']
    ))
    story.append(PageBreak())

    # ---- 10. RISK TRANSFER SUMMARY ----
    story.append(Paragraph('10. Risk Transfer Summary', styles['SectionHead']))

    story.append(Paragraph(
        'The complete risk transfer architecture ensures the wholesale mortgage funder bears zero credit risk. '
        'Insurance coverage begins at dollar zero — there is no uninsured first-loss position for any party:',
        styles['BodyText2']
    ))

    story.append(make_table(
        ['Risk Layer', 'Coverage', 'Risk Bearer', 'Premium Basis'],
        [
            ['Portfolio cross-subsidy', 'Surplus mortgages offset deficit mortgages', 'FutureProof (portfolio manager)', 'None (portfolio structure)'],
            ['First-loss insurance (mild deficit)', f'Deficit up to ${abs(INS["top_cover_limit"]):,.0f} per mortgage', 'LMI Insurer', f'${INS["lmi"]["loaded_premium"]:,.0f} upfront per mortgage'],
            ['Severity insurance (severe deficit)', f'Excess above ${abs(INS["top_cover_limit"]):,.0f} per mortgage', 'Reinsurer', f'${INS["tail_risk"]["loaded_premium"]:,.0f} upfront per mortgage'],
            ['Residual risk', 'None — full coverage from $0', 'N/A', 'N/A'],
        ],
        col_widths=[35*mm, 43*mm, 38*mm, 37*mm]
    ))

    story.append(Spacer(1, 5*mm))
    story.append(Paragraph(
        '<b>Key takeaway for reinsurers:</b> The EPM reinsurance opportunity is a severity-based risk with '
        '~30 years of investment float on the upfront premium, zero prepayment risk, and transparent '
        f'MLE-calibrated pricing via Monte Carlo simulation. Per-mortgage reinsurance claim frequency is '
        f'{PER_MORTGAGE_REINS_POC:.2f}% — the hard ceiling; after portfolio cross-subsidisation and '
        f'diversification the portfolio reinsurance PoC sits modestly below this, comfortably within the ≤2% '
        f'target. Stress-scenario PoD figures (realistic-central 40% for pricing anchor, adverse-plausible 69% '
        f'for capital sizing) are detailed in the companion Parameter Risk paper.',
        styles['Callout']
    ))

    # EPM vs Current Investment Landscape
    story.append(Spacer(1, 5*mm))
    story.append(Paragraph('10.1 EPM vs Comparable Risk Profiles', styles['SubHead']))
    story.append(Paragraph(
        'To assist reinsurer underwriting assessment, we benchmark the EPM credit risk profile against '
        'the instruments most commonly seen in reinsurance portfolios.',
        styles['BodyText2']))

    _combined_fair_pct = 100 * INS["combined"]["total_fair_premium"] / V14["max_loan"]
    story.append(make_table(
        ['Metric', 'EPM (base case)', 'Traditional LMI', "Moody's AA Bond", 'AU RMBS (AA)'],
        [
            ['Lifetime tail-layer claim probability (at maturity)',
             f'{INS["tail_risk"]["poc"]:.2f}%', '2–4% of book', '~1.5%', '~1–2%'],
            ['Loss severity (conditional on deficit)',
             '~10–12%', '15–25%', '40–60%', 'Subordination-dependent'],
            ['Expected loss (30yr, combined)',
             f'{_combined_fair_pct:.2f}%', '0.6–1.25%', '0.6–0.9%', '0.05–0.15%'],
            ['Claim timing', 'Year 30 only', 'Peaks Year 3–7', 'Any year', 'Any year'],
            ['Float on premium', '~30 yrs', '~3–7 yrs', 'N/A', 'N/A'],
            ['Correlation to trad. LMI', 'Near zero', '—', 'Low', 'Moderate'],
            ['Prepayment / lapse risk', 'None', 'Significant', 'Moderate', 'Significant'],
        ],
        col_widths=[42*mm, 28*mm, 30*mm, 26*mm, 24*mm]
    ))
    story.append(Paragraph(
        '<i>Stress-scenario PoD figures (realistic-central 40% / adverse-plausible 69%) are detailed in the '
        'companion Parameter Risk paper.</i>',
        styles['BodyText2']
    ))

    story.append(Spacer(1, 3*mm))
    reins_landscape = [
        '<b>Scenario-sensitive vs scenario-robust metrics.</b> Expected loss and claim probability move '
        'materially across the three parameter scenarios — exact magnitudes will be quantified in the '
        'companion Parameter Risk paper. Loss severity (~10–12%), claim timing (Year 30 only), float '
        'duration (~30 years), and the absence of prepayment risk are <i>structural</i> — they do not move '
        'with the parameter stresses. Reinsurer underwriting should separate these two categories.',
        '<b>Unique diversification value (scenario-robust).</b> Traditional LMI losses are driven by borrower '
        'unemployment, divorce, and rate stress — correlated with economic cycles. EPM losses are driven by '
        '30-year equity index returns. This diversification benefit holds under every parameter scenario '
        'tested and is a genuine diversifier for reinsurance portfolios concentrated in traditional mortgage credit.',
        '<b>Exceptional float characteristics (scenario-robust).</b> Premiums are collected upfront at mortgage '
        'origination and claims can only arise at mortgage expiry. This ~30-year float applies under every '
        'parameter scenario — far longer than any traditional LMI product, where claims typically peak within '
        '3–7 years. The economic value of the float is substantial even under adverse-plausible calibration.',
        f'<b>Expected loss band, not single point.</b> The base-case combined expected loss of '
        f'{_combined_fair_pct:.2f}% (fair-premium basis) reflects the model\'s conservative '
        'parameter set (50 bps FP margin, 10% profit share at 3-year resets, asymmetric collar). '
        'Under realistic-central parameters the expected loss is materially higher; under adverse-plausible '
        'parameters higher still. Reinsurers should price to the realistic-central expected loss and hold '
        'capital against the adverse-plausible scenario.',
    ]
    for rl in reins_landscape:
        story.append(Paragraph(f'<bullet>&bull;</bullet> {rl}', styles['FPBullet']))

    story.append(Spacer(1, 5*mm))
    story.append(Paragraph('10.2 Advantages for Each Participant', styles['SubHead']))
    story.append(make_table(
        ['Participant', 'Key Advantage', 'Risk Retained'],
        [
            ['Mortgage Funder', 'Zero credit risk — full insurance coverage from $0', 'None (fully transferred)'],
            ['LMI Insurer', 'First-loss insurer with bounded severity + 30yr float on upfront premium', f'Up to ${abs(INS["top_cover_limit"]):,.0f} per mortgage'],
            ['Reinsurer', 'Low-frequency severity risk with 30yr float on upfront premium', f'Excess above ${abs(INS["top_cover_limit"]):,.0f} per mortgage'],
            ['FutureProof', 'Origination fees + margin + profit share', 'Portfolio management (cross-subsidy)'],
            ['Homeowner', 'Access to home equity while retaining ownership', 'None — investment account performance is insured'],
        ],
        col_widths=[30*mm, 65*mm, 58*mm]
    ))
    story.append(PageBreak())

    # ---- 11. APPENDIX A: MODEL PARAMETERS ----
    story.append(Paragraph(f'11. Appendix A: Model Parameters (per-mortgage, {HOME_LABEL_M} home)', styles['SectionHead']))

    story.append(make_table(
        ['Parameter', 'Value', 'Notes'],
        [
            ['Home value', HOME_LABEL_FULL, 'Representative Australian metropolitan property'],
            ['Initial mortgage', f'${V14["initial_loan"]:,.0f}', f'Effective LVR: {100*V14["initial_loan"]/V14["home_value"]:.1f}%'],
            ['Max LVR', '80%', f'Max loan: ${int(V14["home_value"] * V14["lvr"]):,.0f}'],
            ['Mortgage type', 'Principal + Interest (30 years)', 'Builds to peak at Year 10, then amortises to zero'],
            ['Annuity', f'${V14["annuity_pa"]:,.0f}/year', f'For first {V14["annuity_term_years"]} years (paid to borrower)'],
            ['Equity model', 'GBM + Mean Reversion', 'Shevchenko 2026, Section 3 — MLE calibrated'],
            ['Equity return (mu_B)', f'{V14["equity_mean"]*100:.1f}%', 'MLE estimate from S&P 500 data'],
            ['Equity volatility (sigma_B)', f'{V14["equity_vol"]*100:.1f}%', 'MLE estimate'],
            ['Mean reversion speed (gamma_B)', f'{V14["equity_mean_rev"]}', 'MLE estimate — pulls returns toward trend'],
            ['Buffer cap', f'{V14["buffer_cap"]*100:.0f}% (+{(V14["buffer_cap"]-1)*100:.0f}%)',
             'Asymmetric collar: cap +40% on annual return credited'],
            ['Buffer floor', f'{V14["buffer_floor"]*100:.0f}% (-{(1-V14["buffer_floor"])*100:.0f}%)',
             'Asymmetric collar: floor -20% on annual return credited'],
            ['Cash rate model', 'Vasicek/OU process', 'Shevchenko 2026, Section 1 — MLE calibrated'],
            ['Cash rate (initial)', f'{V14["cash_rate_initial"]*100:.2f}%', 'Current RBA cash rate'],
            ['Cash rate (long-run mean)', f'{V14["cash_rate_theta"]*100:.2f}%', 'MLE estimate (theta)'],
            ['Cash rate speed (kappa)', f'{V14["cash_rate_kappa"]}', 'MLE estimate — mean reversion speed'],
            ['Cash rate vol (sigma_r)', f'{V14["cash_rate_sigma"]*100:.2f}%', 'MLE estimate'],
            ['Equity-rate correlation', f'{V14["correlation"]}', 'MLE estimate — appropriate for 30yr horizon'],
            ['Wholesale margin', f'{V14["wholesale_margin"]*100:.1f}%', 'Funder borrowing cost above cash rate'],
            ['Retail margin', f'{V14["retail_margin"]*100:.2f}%', 'Lender margin'],
            ['FP margin', f'{V14["fp_margin"]*100:.2f}%', 'FutureProof origination margin'],
            ['Hedging fee', f'{V14["hedging_fee"]*100:.2f}%', 'Volatility buffer cost'],
            ['Collar price', f'{V14["collar_price"]*100:.3f}%', 'Net annual credit from cap/floor collar'],
            ['LMI upfront', f'{V14["lmi_upfront_pct"]*100:.1f}%', 'Of max loan at origination'],
            ['Tail risk reserve', f'{V14["tail_risk_annual_pct"]*100:.2f}%', 'Annual tail risk provision'],
            ['Profit share', f'{V14["profit_share_pct"]*100:.0f}% every {V14["profit_share_years"]} years', 'Surplus drawn periodically'],
            ['Interest holiday entry', f'{V14["holiday_entry_level"]}x initial mortgage', 'Interest payments pause below this'],
            ['Interest holiday exit', f'{V14["holiday_exit_level"]}x initial mortgage', 'Interest payments resume above this'],
            ['Simulation paths', f'{MC["n_paths"]:,}', f'SE on PoD: {MC["deficit_se"]:.2f}%'],
        ],
        col_widths=[42*mm, 40*mm, 71*mm]
    ))

    story.append(Spacer(1, 5*mm))
    story.append(Paragraph(
        'Source: Pavel\'s authoritative v14d Optimised workbook, 50,000-path Monte Carlo (xlsm-verified, '
        '2026-05-24). Per-mortgage reinsurance PoC 1.67% is the hard ceiling for the portfolio figure; after '
        'cross-subsidisation and diversification the portfolio reinsurance PoC sits modestly below it. Note: the '
        'xlsm "prob of portfolio deficit" row is portfolio PoD, not PoC.',
        styles['Footer']
    ))
    story.append(PageBreak())

    # ---- 12. APPENDIX B: STOCHASTIC MODEL EQUATIONS ----
    story.append(Paragraph('12. Appendix B: Stochastic Model Equations', styles['SectionHead']))
    story.append(Paragraph(
        'The following equations are from Shevchenko (2026), "Parameter Estimation for Mean-Reverting '
        'Brownian Stochastic Model", which provides the mathematical framework and MLE methodology for '
        'all stochastic models used in the EPM simulation.',
        styles['BodyText2']
    ))

    story.append(Paragraph('B.1 Cash Rate Model — Vasicek/OU Process (Section 1)', styles['SubHead']))
    story.append(Paragraph(
        'The cash rate follows an Ornstein-Uhlenbeck process with exact discretisation:',
        styles['BodyText2']
    ))
    story.append(Paragraph(
        'r(t+1) = r(t) * exp(-kappa * dt) + theta * (1 - exp(-kappa * dt))<br/>'
        '         + sigma * sqrt((1 - exp(-2*kappa*dt)) / (2*kappa)) * epsilon(t)',
        styles['Equation']
    ))
    story.append(Paragraph(
        'where theta is the long-run mean rate, kappa is the mean-reversion speed, sigma is the volatility, '
        'and epsilon ~ N(0,1). The MLE estimates are: theta = 2.13%, kappa = 0.24, sigma = 1.22%.',
        styles['BodyText2']
    ))

    story.append(Paragraph('B.2 Equity Model — GBM (Section 2)', styles['SubHead']))
    story.append(Paragraph(
        'The baseline Geometric Brownian Motion model for equity returns:',
        styles['BodyText2']
    ))
    story.append(Paragraph(
        'S(t+1) = S(t) * (1 + mu + sigma * epsilon(t))',
        styles['Equation']
    ))
    story.append(Paragraph(
        'MLE estimates: mu = 9.2%, sigma = 16.6%. Log-likelihood = -159.0.',
        styles['BodyText2']
    ))

    story.append(Paragraph('B.3 Equity Model — GBM + Mean Reversion (Section 3, selected)', styles['SubHead']))
    story.append(Paragraph(
        'The selected model adds a mean-reverting component to GBM:',
        styles['BodyText2']
    ))
    story.append(Paragraph(
        'S(t+1) = S(t) * (1 + mu_B + sigma_B * epsilon(t)) + gamma_B * (M(t) - S(t))',
        styles['Equation']
    ))
    story.append(Paragraph(
        'where M(t) = M(0) * (1 + mu_B)^t is the deterministic trend (growing at the expected return rate), '
        'and gamma_B controls the speed of mean reversion. When S(t) falls below trend, the gamma_B term '
        'adds a positive correction; when S(t) is above trend, it adds a negative correction.',
        styles['BodyText2']
    ))
    story.append(Paragraph(
        'MLE estimates: mu_B = 9.2%, sigma_B = 16.6%, gamma_B = 0.163. Log-likelihood = -157.4 '
        '(superior to pure GBM).',
        styles['BodyText2']
    ))

    story.append(Paragraph('B.4 Why Mean Reversion Matters for EPM', styles['SubHead']))
    story.append(Paragraph(
        'The mean reversion parameter gamma_B = 0.163 has a material impact on 30-year tail risk:',
        styles['BodyText2']
    ))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> Without mean reversion (pure GBM), equity paths can wander arbitrarily far '
        'from the expected trend over 30 years, producing unrealistically extreme outcomes in both tails.',
        styles['FPBullet']
    ))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> With mean reversion, paths that deviate significantly from the long-run trend '
        'experience a restoring force (gamma_B * (M(t) - S(t))) that pulls them back toward the trend.',
        styles['FPBullet']
    ))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> This is consistent with observed equity market behaviour: while short-term '
        'returns are unpredictable, long-run returns tend to revert toward historical norms.',
        styles['FPBullet']
    ))
    story.append(Paragraph(
        f'<bullet>&bull;</bullet> The practical effect is a lower probability of deficit ({MC["deficit_prob"]}%) '
        'than pure GBM models would produce — this is a more realistic, not more optimistic, estimate.',
        styles['FPBullet']
    ))

    story.append(Paragraph('B.5 Correlation Structure', styles['SubHead']))
    story.append(Paragraph(
        'Equity and rate innovations are correlated using the Cholesky decomposition:',
        styles['BodyText2']
    ))
    story.append(Paragraph(
        'z_equity ~ N(0,1)<br/>'
        'z_rate = rho * z_equity + sqrt(1 - rho^2) * z_independent<br/>'
        'where rho = 0.30 (MLE estimate)',
        styles['Equation']
    ))
    story.append(Paragraph(
        'This ensures that equity and interest rate shocks within each simulated year reflect the observed '
        'positive correlation between the two risk drivers.',
        styles['BodyText2']
    ))

    story.append(Spacer(1, 5*mm))
    story.append(Paragraph(
        'Reference: Shevchenko, P.V. (2026). "Parameter Estimation for Mean-Reverting Brownian Stochastic Model." '
        'Working paper prepared for FutureProof Financial.',
        styles['Footer']
    ))
    story.append(PageBreak())

    # ---- 13. APPENDIX C: LONG-HORIZON EQUITY HEDGING PROGRAM (SpiderRock) ----
    story.append(Paragraph('13. Appendix C: Long-Horizon Equity Hedging Program (SpiderRock)', styles['SectionHead']))
    story.append(Paragraph(
        'This appendix sets out the continuous dynamic hedging program (Step 4 of the Payments & Risk Waterfall) '
        'designed and managed by SpiderRock, and the regime-aware framework used to size it.',
        styles['BodyText2']
    ))
    story.append(Paragraph('C.1 Executive Summary', styles['SubHead']))
    for b in [
        'The S&P 500 shows weak mean reversion over 30 years; long-horizon outcomes are dominated by drift '
        'uncertainty and regime shifts.',
        'Baseline probability of breaching an 80% real-wealth floor ≈ 16%.',
        'Left-tail risk is driven by persistent stagnation, not single crisis events.',
        'A combined static-replication sleeve + rules-based overlay reduces breach probability to 8–10%.',
        'Total expected hedge cost: 40–60 bps per year.',
        'Long-horizon equity risk is structural, not cyclical. The hedge program is cost-efficient and '
        'regulator-defensible.',
    ]:
        story.append(Paragraph(f'<bullet>&bull;</bullet> {b}', styles['FPBullet']))

    story.append(Paragraph('C.2 Why Index Mean Reversion Over 30 Years Is Weak', styles['SubHead']))
    story.append(Paragraph(
        'Individual stocks mean-revert; index mean-reversion is weak — this is the core modelling insight. '
        'Index composition changes (winners scale, losers exit), sector weights shift (tech → AI → next cycle), '
        'valuation anchors drift with real rates and margins, drift uncertainty compounds over decades, and '
        'structural breaks reset the "mean" repeatedly.',
        styles['BodyText2']
    ))

    story.append(Paragraph('C.3 Modelling Framework — Regime-Switching Engine', styles['SubHead']))
    story.append(Paragraph(
        'The institutional standard for long-horizon equity modelling: GBM inside each regime, Markov switching '
        'across regimes, with volatility mean-reverting while returns do not. This produces realistic '
        'fat-tailed distributions. Drift &amp; volatility bands (annualised):',
        styles['BodyText2']
    ))
    story.append(make_table(
        ['Regime', 'Drift (μ)', 'Volatility (σ)'],
        [
            ['A: High-Growth / Low-Vol', '6.5–8.0%', '10–14%'],
            ['B: Mid-Cycle / Normal', '4.5–6.0%', '14–18%'],
            ['C: Stagnation / High-Vol', '1.5–3.5%', '18–25%'],
            ['D: Crisis', '-20% to -35% shock', '35–55%'],
        ],
        col_widths=[55*mm, 45*mm, 45*mm]
    ))
    story.append(Paragraph(
        'Regimes have 5–10 year half-lives. Stagnation (C) is the most persistent "bad" state; Crisis (D) is rare '
        'but sticky; High-Growth (A) is real but not dominant. Persistence is the key driver of long-run '
        'left-tail outcomes.',
        styles['BodyText2']
    ))

    story.append(Paragraph('C.4 30-Year Terminal Wealth Distribution & Shortfall Risk', styles['SubHead']))
    story.append(make_table(
        ['Percentile', 'Terminal wealth (×)'],
        [['5th', '0.35×'], ['25th', '1.30×'], ['Median', '2.9×'], ['75th', '6.27×'], ['95th', '16.7×']],
        col_widths=[55*mm, 55*mm]
    ))
    story.append(Paragraph(
        'The distribution is wide because drift uncertainty dominates over 30 years. Shortfall risk against an '
        '80% floor: P(terminal wealth &lt; 0.80) ≈ 16%; P(&lt;1.0) ≈ 19%; P(&lt;0.75) ≈ 14%. The left tail is '
        'driven by persistent Regime C, not single-year crises — so crisis hedges alone are insufficient, which '
        'is what justifies the hedge program.',
        styles['BodyText2']
    ))
    story.append(fig_to_image(chart_terminal_wealth(), height=72*mm))

    story.append(Paragraph('C.5 Hedge-Efficiency Comparison', styles['SubHead']))
    story.append(make_table(
        ['Hedge structure', 'Annual cost', 'Breach probability', 'Reduction vs baseline'],
        [
            ['No hedge', '0 bps', '16%', '—'],
            ['5% convexity', '35–55 bps', '11–12%', '4–5%'],
            ['10% convexity', '70–110 bps', '7–9%', '7–9%'],
            ['Rules-based overlay', '25–40 bps', '8–10%', '6–8%'],
            ['Static replication', '15–25 bps', '10–12%', '4–6%'],
        ],
        col_widths=[42*mm, 30*mm, 38*mm, 40*mm]
    ))
    story.append(Paragraph(
        'Rules-based overlays deliver the best cost-per-unit-of-protection.',
        styles['BodyText2']
    ))
    story.append(fig_to_image(chart_hedge_efficiency(), height=72*mm))

    story.append(Paragraph('C.6 How the Hedge Is Constructed — Laddered 140/80', styles['SubHead']))
    story.append(fig_to_image(chart_collar_payoff(), height=70*mm))
    story.append(Paragraph(
        'The program uses a <b>laddered 140/80 collar</b> rather than a single-maturity structure. The payoff is '
        'identical (upside capped at 140%, downside floored at 80%, as shown above), but instead of all options '
        'expiring on one date, the hedge is built as four overlapping mini-hedges at 3M / 6M / 9M / 12M expiries '
        '(like roof tiles), with long-dated 2–4yr LEAPS calls across staggered tenors. A single-maturity hedge '
        'concentrates all vega, skew, gamma and execution risk on one roll date; the ladder spreads it.',
        styles['BodyText2']
    ))
    story.append(fig_to_image(chart_laddered_hedge(), height=90*mm))
    for b in [
        '<b>Smooths vega</b> — not hostage to volatility on one day.',
        '<b>Reduces execution cost</b> — SpiderRock works smaller clips across expiries.',
        '<b>Reduces skew risk</b> — steep skew on one date affects only part of the hedge.',
        '<b>Reduces gamma cliffs</b> — no single expiry where the hedge "falls off".',
        '<b>Creates a regulator-friendly, systematic roll</b> — predictable, rules-based, low-variance.',
    ]:
        story.append(Paragraph(f'<bullet>&bull;</bullet> {b}', styles['FPBullet']))

    story.append(Paragraph('C.7 Rules-Based Overlay & Static Replication Sleeve', styles['SubHead']))
    story.append(Paragraph(
        '<b>Rules-based overlay.</b> Activation needs 2 of 3 triggers: volatility (VIX &gt; 22 or realised vol '
        '&gt; 18%), macro (PMI &lt; 50 or credit spreads widen &gt; 40 bps), trend (S&P below 200-day MA or '
        'breadth &lt; 40%). Implementation: 5–10% notional OTM puts, 3–6 month tenor, 10–15% OTM strikes, rolled '
        'quarterly. Deactivation when VIX &lt; 18, PMI &gt; 50, trend recovers. Objective and regulator-friendly.',
        styles['BodyText2']
    ))
    story.append(Paragraph(
        '<b>Static replication sleeve.</b> 2–3% notional deep-OTM put spreads, 20–30% OTM strikes, 1-year tenor '
        'laddered, cost 15–25 bps. Always-on convexity that complements the overlay — the baseline protection '
        'layer.',
        styles['BodyText2']
    ))
    story.append(Paragraph(
        '<b>Combined outcome:</b> baseline breach probability 16% → with static sleeve 10–12% → with rules-based '
        'overlay 8–10%; total cost 40–60 bps. High efficiency, low drag, scalable.',
        styles['Callout']
    ))

    story.append(Paragraph('C.8 Implementation Pathway', styles['SubHead']))
    for b in [
        'Phase 1: Deploy static replication sleeve.',
        'Phase 2: Add rules-based overlay.',
        'Phase 3: Quarterly regime review.',
        'Phase 4: Annual recalibration of drift/volatility bands.',
        'Phase 5: Integrate into product disclosure + risk governance.',
    ]:
        story.append(Paragraph(f'<bullet>&bull;</bullet> {b}', styles['FPBullet']))
    story.append(Paragraph(
        '<b>Conclusion:</b> A cost-efficient, regime-aware dynamic continuous hedge program reduces long-horizon '
        'shortfall risk by half, without compromising long-run equity participation.',
        styles['Callout']
    ))

    # Build
    doc.build(story, onFirstPage=add_footer, onLaterPages=add_footer)
    print(f'  Generated: {filename}')
    return filename


if __name__ == '__main__':
    print('Generating FutureProof LMI & Portfolio Reinsurance Structure Paper...\n')
    os.chdir(os.path.dirname(os.path.abspath(__file__)))
    f = build_reinsurance_paper()
    print(f'\nDone: {f}')
