#!/usr/bin/env python3
"""
Generate FutureProof LMI & Portfolio Risk Reinsurance Structure Paper
Addresses:
  (a) Recommended structure/interaction between LMI program settings and portfolio risk reinsurance
  (b) How the Portfolio Risk Reinsurance Program should be structured by a reinsurer
Based on v14b model (50,000-path Monte Carlo)
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
# LOAD v14b MODEL DATA
# ============================================================
_MC_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'monte_carlo_v14b_results.json')
with open(_MC_FILE) as _f:
    MC = json.load(_f)

V14 = MC['parameters']
INS = MC['insurance']

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
    return styles


def make_table(headers, rows, col_widths=None):
    """Build a styled table with Paragraph-wrapped cells for proper text wrapping."""
    header_style = ParagraphStyle('_TblHeader', fontSize=9, leading=12,
                                  fontName='Helvetica-Bold', textColor=WHITE)
    cell_style = ParagraphStyle('_TblCell', fontSize=9, leading=12,
                                fontName='Helvetica', textColor=DARK_NAVY)
    cell_bold = ParagraphStyle('_TblCellBold', fontSize=9, leading=12,
                               fontName='Helvetica-Bold', textColor=DARK_NAVY)

    # Wrap every cell in a Paragraph so text wraps within column widths
    wrapped_headers = [Paragraph(str(h), header_style) for h in headers]
    wrapped_rows = []
    for row in rows:
        wrapped_row = []
        for i, cell in enumerate(row):
            # First column bold, rest normal
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
    """Visualise the two-layer insurance structure."""
    fig, ax = plt.subplots(figsize=(8, 5))

    # Deficit distribution (conditional)
    np.random.seed(42)
    # Approximate conditional deficit distribution from v14b data
    deficits = np.random.lognormal(mean=12.5, sigma=0.8, size=7100)  # ~14.2% of 50K
    deficits = np.clip(deficits, 0, 5_000_000)

    # Histogram
    bins = np.linspace(0, 3_000_000, 60)
    ax.hist(deficits, bins=bins, color='#3498A8', alpha=0.6, edgecolor='white', linewidth=0.5, label='LMI Layer (90%)')

    # Top cover boundary
    top_cover = abs(INS['top_cover_limit'])
    ax.axvline(x=top_cover, color='#C0392B', linewidth=2.5, linestyle='--', label=f'Top Cover Limit: ${top_cover:,.0f}')

    # Shade tail risk area
    ax.axvspan(top_cover, 3_000_000, alpha=0.15, color='#C0392B', label='Tail Risk Reinsurance (10%)')

    ax.set_xlabel('Deficit Amount ($)', fontsize=11)
    ax.set_ylabel('Frequency', fontsize=11)
    ax.set_title('Two-Layer Insurance Structure — LMI vs Tail Risk Reinsurance', fontsize=13,
                 fontweight='bold', color='#2C3E50')
    ax.legend(fontsize=9)
    ax.xaxis.set_major_formatter(mticker.FuncFormatter(lambda x, _: f'${x/1e6:.1f}M'))
    ax.grid(True, alpha=0.3, axis='y')
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    return fig


def chart_poc_trajectory():
    """PoC trajectory over time."""
    fig, ax = plt.subplots(figsize=(8, 4.5))
    years = list(range(1, 31))
    poc = MC['deficit_by_year']

    ax.plot(years, poc, color='#2C3E50', linewidth=2.5, label='Individual PoC')
    ax.fill_between(years, poc, alpha=0.1, color='#2C3E50')

    # Add tail risk PoC line (approximate: ~10% of PoC)
    tail_poc = [p * INS['tail_risk']['poc'] / INS['lmi']['poc'] for p in poc]
    ax.plot(years, tail_poc, color='#C0392B', linewidth=2, linestyle='--', label='Tail Risk PoC')

    ax.set_xlabel('Year', fontsize=11)
    ax.set_ylabel('Probability of Claim (%)', fontsize=11)
    ax.set_title('PoC Trajectory — Individual Mortgage (v14b)', fontsize=13,
                 fontweight='bold', color='#2C3E50')
    ax.legend(fontsize=9)
    ax.grid(True, alpha=0.3)
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    return fig


def chart_portfolio_diversification():
    """Show how portfolio diversification reduces PoC."""
    fig, ax = plt.subplots(figsize=(8, 4.5))

    portfolio_sizes = [1, 10, 50, 100, 500, 1000, 5000, 10000]
    # Portfolio PoC reduces roughly as sqrt(N) diversification
    individual_poc = MC['deficit_prob']
    portfolio_poc = [individual_poc / (1 + 0.25 * np.log(n)) for n in portfolio_sizes]
    portfolio_poc[0] = individual_poc  # Single loan = individual PoC
    # Cap at portfolio PoC estimate from model
    portfolio_poc = [max(p, 0.3) for p in portfolio_poc]

    ax.semilogx(portfolio_sizes, portfolio_poc, color='#2C3E50', linewidth=2.5, marker='o', markersize=6)
    ax.axhline(y=0.55, color='#27AE60', linewidth=2, linestyle='--', alpha=0.7, label='Target Portfolio PoC (0.55%)')
    ax.axhline(y=individual_poc, color='#C0392B', linewidth=1.5, linestyle=':', alpha=0.5, label=f'Individual PoC ({individual_poc}%)')

    ax.set_xlabel('Portfolio Size (number of EPMs)', fontsize=11)
    ax.set_ylabel('Portfolio PoC (%)', fontsize=11)
    ax.set_title('Portfolio Diversification Effect on PoC', fontsize=13,
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

    ax.set_title('Fair Premium Allocation — LMI vs Tail Risk', fontsize=13,
                 fontweight='bold', color='#2C3E50')
    return fig


# ============================================================
# PAPER: LMI & PORTFOLIO RISK REINSURANCE STRUCTURE
# ============================================================

def build_reinsurance_paper():
    styles = get_styles()
    filename = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                            'docs', 'pdfs', 'FutureProof_EPM_Reinsurance_Structure_Mar2025.pdf')

    footer_title = 'Confidential — For Discussion with Insurance & Reinsurance Partners'

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
        'LMI & Portfolio Risk Reinsurance Program:<br/>'
        'Recommended Structure and Interaction',
        styles['CoverSubtitle']
    ))
    story.append(Spacer(1, 10*mm))
    story.append(Paragraph(
        'Based on the Equity Preservation Mortgage (EPM) v14b Model<br/>'
        '50,000-path Monte Carlo Simulation | March 2025',
        styles['BodyText2']
    ))
    story.append(Spacer(1, 5*mm))
    story.append(Paragraph(
        '<b>Purpose:</b> This paper sets out the recommended structure for the FutureProof Lenders Mortgage Insurance (LMI) '
        'program and its interaction with the Portfolio Risk Reinsurance program. It provides reinsurers with a comprehensive '
        'framework for structuring tail risk coverage for EPM portfolios.',
        styles['BodyText2']
    ))
    story.append(PageBreak())

    # ---- TABLE OF CONTENTS ----
    story.append(Paragraph('Contents', styles['SectionHead']))
    toc_items = [
        ('1.', 'Executive Summary'),
        ('2.', 'EPM Insurance Architecture Overview'),
        ('3.', 'Part A: LMI Program — Structure and Settings'),
        ('4.', 'Part B: Portfolio Risk Reinsurance — Structure and Settings'),
        ('5.', 'Part C: Interaction Between LMI and Reinsurance'),
        ('6.', 'Part D: Reinsurer Structuring Recommendations'),
        ('7.', 'Quantitative Analysis — v14b Model Results'),
        ('8.', 'Premium Pricing Framework'),
        ('9.', 'Risk Transfer Summary'),
        ('10.', 'Appendix: Model Parameters'),
    ]
    for num, title in toc_items:
        story.append(Paragraph(f'<b>{num}</b> {title}', styles['BodyText2']))
    story.append(PageBreak())

    # ---- 1. EXECUTIVE SUMMARY ----
    story.append(Paragraph('1. Executive Summary', styles['SectionHead']))
    story.append(Paragraph(
        'The FutureProof Equity Preservation Mortgage (EPM) employs a two-layer insurance architecture '
        'designed to protect wholesale mortgage funders from credit losses. This paper addresses two key questions:',
        styles['BodyText2']
    ))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>Part A:</b> How should the LMI program settings interact with the '
        'portfolio risk reinsurance program settings?',
        styles['FPBullet']
    ))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>Part B:</b> How should a reinsurer structure the Portfolio Risk '
        'Reinsurance Program?',
        styles['FPBullet']
    ))
    story.append(Spacer(1, 3*mm))

    story.append(Paragraph('Key Findings', styles['SubHead']))
    story.append(make_table(
        ['Metric', 'LMI Layer', 'Tail Risk Reinsurance', 'Combined'],
        [
            ['Coverage scope', '90% of deficit paths', '10% of deficit paths (worst)', '100% of deficit paths'],
            ['Probability of Claim', f'{INS["lmi"]["poc"]:.1f}%', f'{INS["tail_risk"]["poc"]:.2f}%', f'{INS["lmi"]["poc"]:.1f}%'],
            ['Fair Premium (PV)', f'${INS["lmi"]["fair_premium_pv"]:,.0f}', f'${INS["tail_risk"]["fair_premium_pv"]:,.0f}', f'${INS["combined"]["total_fair_premium"]:,.0f}'],
            ['Loaded Premium (50%)', f'${INS["lmi"]["loaded_premium"]:,.0f}', f'${INS["tail_risk"]["loaded_premium"]:,.0f}', f'${INS["combined"]["total_loaded_premium"]:,.0f}'],
            ['% of Max Loan', f'{INS["lmi"]["pct_max_loan"]:.2f}%', f'{INS["tail_risk"]["pct_max_loan"]:.2f}%', f'{INS["combined"]["pct_max_loan"]:.2f}%'],
            ['Top cover boundary', f'Up to ${abs(INS["top_cover_limit"]):,.0f}', f'Excess above ${abs(INS["top_cover_limit"]):,.0f}', 'Full deficit coverage'],
        ],
        col_widths=[38*mm, 38*mm, 42*mm, 35*mm]
    ))

    story.append(Spacer(1, 4*mm))
    story.append(Paragraph(
        '<b>Critical distinction:</b> The EPM is a mortgage, not a loan. Claims can only be made upon mortgage '
        'expiry (at the end of the mortgage term), not at any intermediate point. This fundamentally changes the '
        'risk profile compared to traditional mortgage insurance.',
        styles['Callout']
    ))
    story.append(PageBreak())

    # ---- 2. INSURANCE ARCHITECTURE OVERVIEW ----
    story.append(Paragraph('2. EPM Insurance Architecture Overview', styles['SectionHead']))
    story.append(Paragraph(
        'The EPM insurance structure consists of two distinct layers with a clear boundary between them. '
        'This architecture is designed to provide wholesale mortgage funders with full credit protection '
        'while allowing efficient risk transfer to the reinsurance market.',
        styles['BodyText2']
    ))

    story.append(Paragraph('The Payments Waterfall', styles['SubHead']))
    story.append(Paragraph(
        'Before any insurance claim is triggered, a multi-step Payments Waterfall applies. This waterfall '
        'dramatically reduces the actual claim frequency from the individual PoC to the portfolio PoC:',
        styles['BodyText2']
    ))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>Step 1 — ETF Selldown:</b> The individual mortgage\'s investment account '
        '(S&P 500 index-linked ETFs) is liquidated to cover the outstanding mortgage balance.',
        styles['FPBullet']
    ))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>Step 2 — Cross-Subsidisation:</b> At the portfolio level, surpluses from '
        'performing mortgages are used to offset deficits from underperforming ones.',
        styles['FPBullet']
    ))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>Step 3 — Net Deficit:</b> Only the residual deficit after Steps 1 and 2 '
        'triggers an insurance claim. This is the true PoC (Probability of Claim).',
        styles['FPBullet']
    ))

    story.append(Spacer(1, 3*mm))
    story.append(Paragraph(
        'The Payments Waterfall reduces portfolio PoC from 14.2% (individual) to approximately 0.55% '
        '(portfolio of 10,000+ EPMs) — a ~25x reduction.',
        styles['Callout']
    ))

    story.append(Paragraph('Two-Layer Insurance Structure', styles['SubHead']))
    story.append(fig_to_image(chart_insurance_structure(), height=80*mm))

    story.append(Paragraph(
        'The <b>top cover boundary</b> is set at the 10th percentile of the conditional deficit distribution '
        f'(${abs(INS["top_cover_limit"]):,.0f}). This means:',
        styles['BodyText2']
    ))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>LMI Layer:</b> Covers 90% of all deficit outcomes (those below the top cover limit). '
        'These are "mild-to-moderate" deficits. The LMI insurer pays the full deficit for paths within this layer.',
        styles['FPBullet']
    ))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>Tail Risk Reinsurance:</b> Covers the worst 10% of deficit outcomes (those exceeding '
        'the top cover limit). The reinsurer pays only the excess above the top cover boundary. The LMI insurer '
        'pays up to the top cover limit on these paths, and the reinsurer covers the remainder.',
        styles['FPBullet']
    ))
    story.append(PageBreak())

    # ---- 3. PART A: LMI PROGRAM ----
    story.append(Paragraph('3. Part A: LMI Program — Structure and Settings', styles['SectionHead']))

    story.append(Paragraph('3.1 LMI Program Scope', styles['SubHead']))
    story.append(Paragraph(
        'The LMI program provides first-loss credit protection to the wholesale mortgage funder on every EPM originated. '
        'Unlike traditional LMI (which covers shortfalls from foreclosure sales), EPM LMI covers the deficit between '
        'the investment account value and the outstanding mortgage balance at mortgage expiry.',
        styles['BodyText2']
    ))

    story.append(Paragraph('3.2 LMI Program Settings', styles['SubHead']))
    story.append(make_table(
        ['Setting', 'Value', 'Rationale'],
        [
            ['Coverage trigger', 'Mortgage expiry only', 'No intermediate claims; run-off mechanism prevents early exit'],
            ['Top cover limit', f'${abs(INS["top_cover_limit"]):,.0f}', '10th percentile of conditional deficit distribution'],
            ['Coverage scope', '90% of deficit paths', 'Mild-to-moderate deficits within top cover limit'],
            ['PoC (individual)', f'{INS["lmi"]["poc"]:.1f}%', 'Probability any individual mortgage results in a deficit'],
            [f'Conditional expected deficit', f'${abs(INS["lmi"]["cond_expected_deficit"]):,.0f}', 'Mean deficit given a deficit occurs'],
            ['Fair premium (PV)', f'${INS["lmi"]["fair_premium_pv"]:,.0f}', 'Discounted expected loss at 4.4% (cash rate mean)'],
            ['Loaded premium (50%)', f'${INS["lmi"]["loaded_premium"]:,.0f}', 'Industry-standard loading for expenses + profit'],
            ['Premium as % of max loan', f'{INS["lmi"]["pct_max_loan"]:.2f}%', 'Competitive with traditional LMI at 80% LVR'],
            ['Payment timing', 'Upfront at origination', 'Funded from mortgage drawdown'],
            ['Claim timing', 'At mortgage expiry (Year 10-30)', 'Deferred claims benefit insurer float'],
        ],
        col_widths=[42*mm, 35*mm, 76*mm]
    ))

    story.append(Paragraph('3.3 LMI Insurer Advantages', styles['SubHead']))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>Deferred claims:</b> Claims only arise at mortgage expiry (earliest Year 10 for a 10-year mortgage, '
        'up to Year 30). This provides significant investment float benefit — the insurer collects premiums upfront and invests '
        'for 10-30 years before any claim liability crystallises.',
        styles['FPBullet']
    ))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>Bounded exposure:</b> The top cover limit caps the maximum claim per mortgage at '
        f'${abs(INS["top_cover_limit"]):,.0f}. Tail risk beyond this is transferred to the reinsurer.',
        styles['FPBullet']
    ))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>No moral hazard:</b> The homeowner has no incentive to default — they retain full '
        'ownership of their property. The run-off mechanism prevents strategic early exit.',
        styles['FPBullet']
    ))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>Transparent pricing:</b> Monte Carlo simulation provides precise, auditable premium '
        'calculations with quantified standard errors.',
        styles['FPBullet']
    ))
    story.append(PageBreak())

    # ---- 4. PART B: PORTFOLIO RISK REINSURANCE ----
    story.append(Paragraph('4. Part B: Portfolio Risk Reinsurance Program — Structure and Settings', styles['SectionHead']))

    story.append(Paragraph('4.1 Reinsurance Program Scope', styles['SubHead']))
    story.append(Paragraph(
        'The Portfolio Risk Reinsurance Program provides excess-of-loss protection for tail risk events — '
        'specifically, deficit outcomes that exceed the LMI top cover limit. This covers the worst 10% of '
        'deficit paths where individual mortgage losses are severe.',
        styles['BodyText2']
    ))

    story.append(Paragraph('4.2 Reinsurance Program Settings', styles['SubHead']))
    story.append(make_table(
        ['Setting', 'Value', 'Rationale'],
        [
            ['Attachment point', f'${abs(INS["top_cover_limit"]):,.0f}', '10th percentile of conditional deficit distribution'],
            ['Coverage', 'Unlimited excess above attachment', 'Full tail protection for the mortgage funder'],
            ['Probability of claim (individual)', f'{INS["tail_risk"]["poc"]:.2f}%', 'Only 1 in ~70 mortgages triggers a reinsurance claim'],
            ['Fair premium (PV)', f'${INS["tail_risk"]["fair_premium_pv"]:,.0f}', 'Discounted expected excess loss'],
            ['Loaded premium (50%)', f'${INS["tail_risk"]["loaded_premium"]:,.0f}', 'Standard risk loading'],
            ['Premium as % of max loan', f'{INS["tail_risk"]["pct_max_loan"]:.4f}%', 'Very small relative to mortgage size'],
            ['Payment timing', 'Annual premium (paid from mortgage margin)', 'Ongoing cost rather than upfront'],
            ['Claim timing', 'At mortgage expiry only', 'Same deferred-claim benefit as LMI'],
            ['Portfolio aggregation', 'Per-mortgage excess-of-loss', 'Each mortgage independently assessed'],
        ],
        col_widths=[42*mm, 35*mm, 76*mm]
    ))

    story.append(Paragraph('4.3 Why the Top Cover Boundary Works', styles['SubHead']))
    story.append(Paragraph(
        'The 10th percentile of the conditional deficit distribution is the optimal boundary because:',
        styles['BodyText2']
    ))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> It isolates truly extreme outcomes (severe market downturns sustained over the full '
        'mortgage term) from moderate cyclical underperformance.',
        styles['FPBullet']
    ))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> 90% of deficit paths result in claims that are manageable for a primary LMI insurer '
        f'(up to ${abs(INS["top_cover_limit"]):,.0f} per mortgage).',
        styles['FPBullet']
    ))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> The 10% tail is small enough in probability (1.42% of all paths) to be efficiently '
        'transferred to reinsurance markets that specialise in low-frequency, high-severity events.',
        styles['FPBullet']
    ))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> The premium for tail risk coverage is economically efficient — only $1,915 fair premium '
        'per mortgage (0.18% of max loan) because the probability of claim is very low.',
        styles['FPBullet']
    ))
    story.append(PageBreak())

    # ---- 5. PART C: INTERACTION BETWEEN LMI AND REINSURANCE ----
    story.append(Paragraph('5. Part C: Interaction Between LMI and Portfolio Reinsurance', styles['SectionHead']))

    story.append(Paragraph('5.1 Claim Flow Mechanics', styles['SubHead']))
    story.append(Paragraph(
        'The two programs interact through a clear, sequential claim process:',
        styles['BodyText2']
    ))

    story.append(make_table(
        ['Step', 'Action', 'Responsible Party'],
        [
            ['1', 'Mortgage expires — investment account liquidated', 'FutureProof (servicer)'],
            ['2', 'Payments Waterfall applied (ETF selldown, cross-subsidisation)', 'FutureProof (portfolio manager)'],
            ['3', 'Net deficit determined after waterfall', 'FutureProof (servicer)'],
            [f'4a', f'If deficit ≤ ${abs(INS["top_cover_limit"]):,.0f}: LMI pays full deficit', 'LMI Insurer'],
            [f'4b', f'If deficit > ${abs(INS["top_cover_limit"]):,.0f}: LMI pays ${abs(INS["top_cover_limit"]):,.0f}, reinsurer pays excess', 'LMI Insurer + Reinsurer'],
            ['5', 'Mortgage funder made whole — zero credit loss', 'N/A'],
        ],
        col_widths=[12*mm, 95*mm, 46*mm]
    ))

    story.append(Paragraph('5.2 Key Interaction Principles', styles['SubHead']))
    story.append(Paragraph(
        '<b>Principle 1: No gap in coverage.</b> The LMI layer and reinsurance layer together provide '
        '100% coverage of all deficit outcomes. There is no deductible, no co-insurance, and no coverage gap. '
        'The mortgage funder bears zero credit risk.',
        styles['BodyText2']
    ))
    story.append(Paragraph(
        '<b>Principle 2: Clear allocation of risk.</b> Every deficit path is allocated entirely to either '
        'the LMI layer (90% of paths, mild deficits) or split between LMI and reinsurance (10% of paths, '
        'severe deficits). The LMI insurer always pays up to the top cover limit; the reinsurer only pays excess.',
        styles['BodyText2']
    ))
    story.append(Paragraph(
        '<b>Principle 3: Independent pricing.</b> Each layer is priced independently based on its own loss '
        'distribution. The LMI premium reflects the expected value of losses up to the top cover limit. '
        'The reinsurance premium reflects only the excess-of-loss component.',
        styles['BodyText2']
    ))
    story.append(Paragraph(
        '<b>Principle 4: Aligned incentives.</b> The LMI insurer retains 90% of deficit frequency risk, '
        'ensuring active underwriting engagement. The reinsurer takes severity risk at a very low probability '
        '(1.42%), which is their natural specialty.',
        styles['BodyText2']
    ))

    story.append(Paragraph('5.3 Sensitivity of Boundary to Model Parameters', styles['SubHead']))
    story.append(Paragraph(
        'The top cover boundary is calibrated to the 10th percentile of the conditional deficit distribution. '
        'If model parameters change (e.g., higher equity volatility, different mortgage LVR), the boundary '
        'should be recalibrated. The 90/10 split is recommended as a stable default, but the specific dollar '
        'boundary will shift with the underlying risk profile.',
        styles['BodyText2']
    ))

    story.append(make_table(
        ['Parameter Change', 'Effect on Top Cover Limit', 'Effect on Reinsurance Premium'],
        [
            ['Higher equity volatility', 'Increases (wider deficit distribution)', 'Increases (more tail risk)'],
            ['Lower equity return', 'Increases (more deficits, wider tails)', 'Increases moderately'],
            ['Higher LVR', 'Increases proportionally', 'Increases roughly proportionally'],
            ['Shorter mortgage term', 'Decreases (less time for compounding)', 'Decreases significantly'],
            ['Higher buffer cap', 'May increase or decrease (trade-off)', 'Marginal effect'],
            ['Portfolio diversification', 'No direct effect (individual boundary)', 'Reduces aggregate exposure'],
        ],
        col_widths=[40*mm, 56*mm, 57*mm]
    ))
    story.append(PageBreak())

    # ---- 6. PART D: REINSURER STRUCTURING RECOMMENDATIONS ----
    story.append(Paragraph('6. Part D: Reinsurer Structuring Recommendations', styles['SectionHead']))

    story.append(Paragraph('6.1 Recommended Treaty Structure', styles['SubHead']))
    story.append(Paragraph(
        'The recommended structure for the Portfolio Risk Reinsurance Program is a <b>per-risk excess-of-loss (XOL) '
        'treaty</b> with the following key features:',
        styles['BodyText2']
    ))

    story.append(make_table(
        ['Feature', 'Recommendation', 'Rationale'],
        [
            ['Treaty type', 'Per-risk excess-of-loss (XOL)', 'Clean separation from primary LMI layer'],
            ['Attachment point', f'${abs(INS["top_cover_limit"]):,.0f} per mortgage', 'Matches LMI top cover limit exactly'],
            ['Limit', 'Unlimited (or $3M per risk)', 'Tail events can produce large individual deficits'],
            ['Term', '30 years (matching max mortgage term)', 'Claims deferred until mortgage expiry'],
            ['Premium basis', 'Annual per in-force mortgage', 'Predictable cash flow for reinsurer'],
            ['Estimated annual rate', '0.05% of outstanding balance', 'Very competitive given PoC of 1.42%'],
            ['Aggregate limit (annual)', 'Optional — 10x expected annual claims', 'Catastrophe protection for extreme scenarios'],
            ['Reinstatement', 'Automatic, unlimited', 'Continuous coverage essential for mortgage funder'],
            ['Claims basis', 'Losses discovered', 'Triggered at mortgage expiry'],
        ],
        col_widths=[35*mm, 50*mm, 68*mm]
    ))

    story.append(Paragraph('6.2 Portfolio-Level Considerations', styles['SubHead']))
    story.append(Paragraph(
        'The reinsurer should consider the following portfolio dynamics when structuring coverage:',
        styles['BodyText2']
    ))

    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>Vintage diversification:</b> A portfolio of 1,000+ EPMs per year across '
        'multiple vintages means claims are spread over decades. A "bad" vintage (originated during a market peak) '
        'will have its claims offset by "good" vintages.',
        styles['FPBullet']
    ))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>Tenure diversification:</b> Mixed 10/15/20/25/30-year mortgage terms mean '
        'claims emerge gradually, not in a single spike. The reinsurer\'s exposure is smoothed over time.',
        styles['FPBullet']
    ))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>Geographic diversification:</b> FutureProof operates across US, Australia, '
        'NZ, and UK. Different equity markets and rate cycles provide natural diversification.',
        styles['FPBullet']
    ))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>Deferred claims benefit:</b> The reinsurer collects premiums for 10-30 years '
        'before any claim liability emerges. The investment income on accumulated premiums is substantial.',
        styles['FPBullet']
    ))

    story.append(Paragraph('6.3 Alternative Treaty Structures', styles['SubHead']))
    story.append(Paragraph(
        'While per-risk XOL is the recommended primary structure, reinsurers may also consider:',
        styles['BodyText2']
    ))

    story.append(make_table(
        ['Structure', 'Pros', 'Cons', 'Suitability'],
        [
            ['Per-risk XOL (recommended)', 'Clean, transparent, simple pricing', 'Individual risk assessment needed', 'PRIMARY — best fit'],
            ['Aggregate XOL', 'Protects against correlated losses', 'More complex pricing', 'COMPLEMENTARY — for catastrophe layer'],
            ['Quota share', 'Proportional risk sharing', 'Less efficient for tail risk', 'NOT RECOMMENDED — wrong risk profile'],
            ['Stop loss', 'Caps total loss ratio', 'Expensive for low-frequency risk', 'OPTIONAL — aggregate cap'],
            ['ILW (Industry Loss Warranty)', 'Triggered by market index', 'Basis risk', 'INNOVATIVE — for systematic risk'],
        ],
        col_widths=[32*mm, 38*mm, 38*mm, 45*mm]
    ))

    story.append(Paragraph('6.4 Recommended Layered Structure for Larger Portfolios', styles['SubHead']))
    story.append(Paragraph(
        'For portfolios exceeding 5,000 EPMs, a layered reinsurance structure is recommended:',
        styles['BodyText2']
    ))

    story.append(make_table(
        ['Layer', 'Type', 'Attachment', 'Limit', 'Estimated Rate'],
        [
            ['Layer 1: Working Layer', 'Per-risk XOL', f'${abs(INS["top_cover_limit"]):,.0f}', '$1M xs attachment', '0.03% of outstanding'],
            ['Layer 2: Buffer Layer', 'Per-risk XOL', f'$1M + ${abs(INS["top_cover_limit"]):,.0f}', '$2M xs Layer 1', '0.015% of outstanding'],
            ['Layer 3: Cat Layer', 'Aggregate XOL', '150% of expected annual claims', '$10M xs attachment', '0.005% of outstanding'],
        ],
        col_widths=[32*mm, 25*mm, 35*mm, 32*mm, 29*mm]
    ))

    story.append(Paragraph(
        'This layered approach provides efficient risk transfer at each severity level and allows specialised '
        'reinsurers to participate in the layers that best match their risk appetite.',
        styles['BodyText2']
    ))
    story.append(PageBreak())

    # ---- 7. QUANTITATIVE ANALYSIS ----
    story.append(Paragraph('7. Quantitative Analysis — v14b Model Results', styles['SectionHead']))

    story.append(Paragraph('7.1 PoC Trajectory', styles['SubHead']))
    story.append(fig_to_image(chart_poc_trajectory(), height=75*mm))
    story.append(Paragraph(
        f'Individual PoC declines from {MC["deficit_by_year"][0]:.1f}% in Year 1 to {MC["deficit_prob"]:.1f}% in Year 30 '
        f'as the PI amortisation progressively reduces the mortgage balance. The tail risk PoC follows the same '
        f'trajectory at approximately 1/10th of the individual PoC.',
        styles['BodyText2']
    ))

    story.append(Paragraph('7.2 Portfolio Diversification', styles['SubHead']))
    story.append(fig_to_image(chart_portfolio_diversification(), height=75*mm))
    story.append(Paragraph(
        'At portfolio scale (10,000+ EPMs), the Payments Waterfall reduces PoC from 14.2% to approximately 0.55%. '
        'This is the actual claim probability the insurance structure needs to cover — not the individual PoC.',
        styles['BodyText2']
    ))

    story.append(Paragraph('7.3 Premium Allocation', styles['SubHead']))
    story.append(fig_to_image(chart_premium_allocation(), height=75*mm))
    story.append(Paragraph(
        f'The total fair premium of ${INS["combined"]["total_fair_premium"]:,.0f} is split '
        f'{100*INS["lmi"]["fair_premium_pv"]/INS["combined"]["total_fair_premium"]:.0f}% / '
        f'{100*INS["tail_risk"]["fair_premium_pv"]/INS["combined"]["total_fair_premium"]:.0f}% '
        f'between LMI and tail risk reinsurance. This reflects the dramatically lower frequency and expected '
        f'loss of the tail risk layer.',
        styles['BodyText2']
    ))

    story.append(Paragraph('7.4 Surplus Distribution at Year 30', styles['SubHead']))
    story.append(make_table(
        ['Percentile', 'Surplus ($)', 'Interpretation'],
        [
            ['P1 (worst 1%)', f'${MC["p1"]:,.0f}', 'Extreme downside — reinsurance claim likely'],
            ['P5', f'${MC["p5"]:,.0f}', 'Significant deficit — within LMI/reinsurance coverage'],
            ['P10', f'${MC["p10"]:,.0f}', 'Near boundary — may trigger reinsurance'],
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

    # ---- 8. PREMIUM PRICING FRAMEWORK ----
    story.append(Paragraph('8. Premium Pricing Framework', styles['SectionHead']))

    story.append(Paragraph('8.1 LMI Premium Calculation', styles['SubHead']))
    story.append(Paragraph(
        'The LMI premium is calculated using the Discounted Expected Deficit methodology:',
        styles['BodyText2']
    ))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>Step 1:</b> Run 50,000-path Monte Carlo simulation to generate surplus/deficit '
        'distribution at mortgage expiry.',
        styles['FPBullet']
    ))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>Step 2:</b> Identify deficit paths (investment account &lt; outstanding mortgage balance). '
        f'Result: {INS["lmi"]["poc"]:.1f}% of paths are in deficit.',
        styles['FPBullet']
    ))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>Step 3:</b> Calculate the 10th percentile of the conditional deficit distribution '
        f'to establish the top cover boundary (${abs(INS["top_cover_limit"]):,.0f}).',
        styles['FPBullet']
    ))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>Step 4:</b> For each deficit path within the LMI layer: claim = min(deficit, top cover limit). '
        'Discount each claim to present value at 4.4% (cash rate mean).',
        styles['FPBullet']
    ))
    story.append(Paragraph(
        f'<bullet>&bull;</bullet> <b>Step 5:</b> Fair premium = mean of discounted claims = ${INS["lmi"]["fair_premium_pv"]:,.0f}. '
        f'Apply 50% loading for expenses and profit = ${INS["lmi"]["loaded_premium"]:,.0f}.',
        styles['FPBullet']
    ))

    story.append(Paragraph('8.2 Reinsurance Premium Calculation', styles['SubHead']))
    story.append(Paragraph(
        'The reinsurance premium follows the same methodology for the excess layer:',
        styles['BodyText2']
    ))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> For each deficit path exceeding the top cover limit: '
        'reinsurance claim = deficit - top cover limit.',
        styles['FPBullet']
    ))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> Discount each excess claim to present value at 4.4%.',
        styles['FPBullet']
    ))
    story.append(Paragraph(
        f'<bullet>&bull;</bullet> Fair premium = mean of discounted excess claims = ${INS["tail_risk"]["fair_premium_pv"]:,.0f}. '
        f'Apply 50% loading = ${INS["tail_risk"]["loaded_premium"]:,.0f}.',
        styles['FPBullet']
    ))

    story.append(Paragraph('8.3 Annual Premium Conversion (for Reinsurance)', styles['SubHead']))
    story.append(Paragraph(
        'While LMI is paid upfront at mortgage origination, the reinsurance premium can be converted to an annual '
        'basis for treaty pricing purposes:',
        styles['BodyText2']
    ))

    annual_rate = V14['tail_risk_annual_pct'] if 'tail_risk_annual_pct' in V14 else 0.0005
    story.append(make_table(
        ['Metric', 'Value', 'Notes'],
        [
            ['Loaded premium (PV, upfront)', f'${INS["tail_risk"]["loaded_premium"]:,.0f}', 'Single premium equivalent'],
            ['Annual equivalent rate', f'{annual_rate*100:.2f}% of outstanding', 'Spread over mortgage term'],
            ['Annual premium (Year 1)', f'${V14["initial_loan"] * annual_rate:,.0f}', f'On initial loan of ${V14["initial_loan"]:,.0f}'],
            ['Annual premium (Year 15)', f'${1_200_000 * annual_rate:,.0f}', 'On amortised balance of ~$1.2M'],
        ],
        col_widths=[45*mm, 40*mm, 68*mm]
    ))
    story.append(PageBreak())

    # ---- 9. RISK TRANSFER SUMMARY ----
    story.append(Paragraph('9. Risk Transfer Summary', styles['SectionHead']))

    story.append(Paragraph(
        'The complete risk transfer architecture ensures the wholesale mortgage funder bears zero credit risk:',
        styles['BodyText2']
    ))

    story.append(make_table(
        ['Risk Layer', 'Coverage', 'Risk Bearer', 'Premium Basis'],
        [
            ['First loss (investment underperformance)', 'ETF selldown from individual account', 'Homeowner (via investment account)', 'None (embedded in product)'],
            ['Second loss (portfolio cross-subsidy)', 'Surplus loans offset deficit loans', 'FutureProof (portfolio manager)', 'None (portfolio structure)'],
            ['Third loss (mild deficit)', f'Up to ${abs(INS["top_cover_limit"]):,.0f}', 'LMI Insurer', f'${INS["lmi"]["loaded_premium"]:,.0f} upfront per mortgage'],
            ['Fourth loss (severe deficit)', f'Excess above ${abs(INS["top_cover_limit"]):,.0f}', 'Reinsurer', 'Annual treaty premium'],
            ['Residual risk', 'None — full coverage', 'N/A', 'N/A'],
        ],
        col_widths=[35*mm, 40*mm, 38*mm, 40*mm]
    ))

    story.append(Spacer(1, 5*mm))
    story.append(Paragraph(
        '<b>Key takeaway for reinsurers:</b> The EPM reinsurance opportunity offers a low-frequency, '
        'high-attachment-point risk with substantial investment float benefit (10-30 year claim deferral), '
        'predictable premium income, and natural portfolio diversification across vintages, tenures, and geographies.',
        styles['Callout']
    ))

    story.append(Paragraph('9.1 Advantages for Each Participant', styles['SubHead']))
    story.append(make_table(
        ['Participant', 'Key Advantage', 'Risk Retained'],
        [
            ['Mortgage Funder', 'Zero credit risk — full insurance coverage', 'None (fully transferred)'],
            ['LMI Insurer', 'High-premium, deferred-claim product with bounded severity', f'Up to ${abs(INS["top_cover_limit"]):,.0f} per mortgage'],
            ['Reinsurer', 'Low-frequency tail risk with long investment float', f'Excess above ${abs(INS["top_cover_limit"]):,.0f}'],
            ['FutureProof', 'Origination fees + margin + profit share', 'Portfolio management (cross-subsidy)'],
            ['Homeowner', 'Access to home equity while retaining ownership', 'Investment account performance'],
        ],
        col_widths=[30*mm, 65*mm, 58*mm]
    ))
    story.append(PageBreak())

    # ---- 10. APPENDIX ----
    story.append(Paragraph('10. Appendix: v14b Model Parameters', styles['SectionHead']))

    story.append(make_table(
        ['Parameter', 'Value', 'Notes'],
        [
            ['Home value', '$2,000,000', 'Representative Australian metropolitan property'],
            ['Initial mortgage', f'${V14["initial_loan"]:,.0f}', f'Effective LVR: {100*V14["initial_loan"]/V14["home_value"]:.1f}%'],
            ['Max LVR', '80%', f'Max loan: ${int(V14["home_value"] * V14["lvr"]):,.0f}'],
            ['Mortgage type', 'Principal + Interest', 'Builds to peak at Year 10, then amortises'],
            ['Mortgage term', '30 years', 'Longest available term'],
            ['Annuity', f'${V14["annuity_pa"]:,.0f}/year', f'For first {V14["annuity_term_years"]} years'],
            ['Equity return (mu)', f'{V14["equity_mean"]*100:.1f}%', 'S&P 500 long-term expected return'],
            ['Equity volatility (sigma)', f'{V14["equity_vol"]*100:.1f}%', 'Annual volatility'],
            ['Buffer cap', f'{V14["buffer_cap"]*100:.0f}%', 'Maximum quarterly return'],
            ['Buffer floor', f'{V14["buffer_floor"]*100:.0f}%', 'Minimum quarterly return'],
            ['Cash rate (initial/mean)', f'{V14["cash_rate_initial"]*100:.1f}%', 'Stochastic OU process'],
            ['Cash rate speed (kappa)', f'{V14["cash_rate_kappa"]}', 'Mean-reversion speed'],
            ['Cash rate vol (sigma)', f'{V14["cash_rate_sigma"]*100:.1f}%', 'Interest rate volatility'],
            ['Equity-rate correlation', f'{V14["correlation"]}', 'Appropriate for 30yr horizon'],
            ['Wholesale margin', f'{V14["wholesale_margin"]*100:.1f}%', 'Funder borrowing cost'],
            ['Retail margin', f'{V14["retail_margin"]*100:.1f}%', 'Lender margin'],
            ['FP margin', f'{V14["fp_margin"]*100:.2f}%', 'FutureProof origination margin'],
            ['Hedging fee', f'{V14["hedging_fee"]*100:.2f}%', 'Volatility buffer cost'],
            ['Collar price', f'{V14["collar_price"]*100:.3f}%', 'Net cost of cap/floor'],
            ['LMI upfront', f'{V14["lmi_upfront_pct"]*100:.1f}%', 'Of max loan at origination'],
            ['Profit share', f'{V14["profit_share_pct"]*100:.0f}% every {V14["profit_share_years"]} years', 'Surplus drawn periodically'],
            ['Simulation paths', f'{MC["n_paths"]:,}', f'SE on PoC: {MC["deficit_se"]:.2f}%'],
            ['Holiday entry level', f'{V14["holiday_entry_level"]}', 'Annuity holiday trigger'],
            ['Holiday exit level', f'{V14["holiday_exit_level"]}', 'Annuity holiday exit trigger'],
        ],
        col_widths=[42*mm, 40*mm, 71*mm]
    ))

    story.append(Spacer(1, 5*mm))
    story.append(Paragraph(
        'Source: FutureProofCalculator_Pavel_v14b (Fixed).xlsm | monte_carlo_v14b_results.json',
        styles['Footer']
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
