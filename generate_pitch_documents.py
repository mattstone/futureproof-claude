#!/usr/bin/env python3
"""
Generate two FutureProof pitch documents:
  1. VC Seed Round Pitch Deck (PDF)
  2. Wholesale Funder Investment Memorandum (PDF)

Honest, data-driven, built from actual platform metrics.
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
    PageBreak, Image, KeepTogether, HRFlowable
)
from reportlab.lib.colors import HexColor
from io import BytesIO
from datetime import date

# ============================================================
# COLOUR PALETTE
# ============================================================
DARK_NAVY = HexColor('#1a1a2e')
NAVY = HexColor('#16213e')
TEAL = HexColor('#0f3460')
ACCENT_BLUE = HexColor('#3b82f6')
ACCENT_GREEN = HexColor('#10b981')
ACCENT_PURPLE = HexColor('#8b5cf6')
CORAL = HexColor('#ef4444')
AMBER = HexColor('#f59e0b')
LIGHT_GREY = HexColor('#f8fafc')
MID_GREY = HexColor('#94a3b8')
DARK_TEXT = HexColor('#0f172a')
WHITE = colors.white
HEADER_BG = HexColor('#1e293b')
ROW_ALT = HexColor('#f1f5f9')

TODAY = date.today().strftime('%B %Y')

# ============================================================
# MODEL DATA
# ============================================================
EPM = {
    'home_value': 2_000_000,
    'initial_loan': 1_350_000,
    'max_lvr': 80,
    'effective_lvr': 67.5,
    'tenure': 30,
    'annuity': 25_000,
    'annuity_term': 10,
    'annuity_rates': {10: 1.50, 15: 1.37, 20: 1.25, 25: 1.15, 30: 1.05},
    'wholesale_margin': 2.0,
    'retail_margin': 0.70,
    'fp_margin': 0.25,
    'hedging_fee': 0.25,
    'total_cost': 3.20,
    'investment_return': 10.0,
    'investment_vol': 10.0,
    'nsim': 50_000,
    'pod_yr30': 13.87,
    'poc_yr30': 0.55,
    'mean_surplus': 1_690_289,
    'median_surplus': 1_376_802,
    'p5': -653_596,
    'p10': -211_973,
    'p25': 457_103,
    'p75': 2_615_818,
    'p90': 4_017_354,
    'p95': 5_029_172,
    'p99': 7_318_739,
    'ins_fair_premium': 21_953,
    'ins_loaded': 32_929,
    'cond_deficit': -592_400,
    'profit_share_means': [36_021, 71_376, 139_569, 220_625, 315_689],
}

# Optimised model metrics
OPT = {
    'pod_yr30': 4.4,
    'mean_surplus': 3_826_343,
    'fp_total_revenue': 1_895_620,
    'fp_profit_share': 1_765_860,
    'fp_margin_income': 129_760,
    'funder_surplus': 1_926_767,
    'sharpe_ratio': 1.134,
}

# ============================================================
# STYLE HELPERS
# ============================================================

def get_styles():
    styles = getSampleStyleSheet()
    styles.add(ParagraphStyle(
        'DocTitle', parent=styles['Title'],
        fontSize=28, textColor=WHITE, spaceAfter=4*mm,
        alignment=TA_LEFT, fontName='Helvetica-Bold', leading=34
    ))
    styles.add(ParagraphStyle(
        'DocSubtitle', parent=styles['Normal'],
        fontSize=14, textColor=HexColor('#93c5fd'), spaceAfter=4*mm,
        alignment=TA_LEFT, fontName='Helvetica'
    ))
    styles.add(ParagraphStyle(
        'Confidential', parent=styles['Normal'],
        fontSize=10, textColor=CORAL, spaceAfter=6*mm,
        alignment=TA_LEFT, fontName='Helvetica-Oblique'
    ))
    styles.add(ParagraphStyle(
        'SectionHead', parent=styles['Heading1'],
        fontSize=20, textColor=DARK_NAVY, spaceBefore=10*mm,
        spaceAfter=5*mm, fontName='Helvetica-Bold'
    ))
    styles.add(ParagraphStyle(
        'SubHead', parent=styles['Heading2'],
        fontSize=14, textColor=ACCENT_BLUE, spaceBefore=6*mm,
        spaceAfter=3*mm, fontName='Helvetica-Bold'
    ))
    styles.add(ParagraphStyle(
        'SubHead2', parent=styles['Heading3'],
        fontSize=12, textColor=TEAL, spaceBefore=4*mm,
        spaceAfter=2*mm, fontName='Helvetica-Bold'
    ))
    styles.add(ParagraphStyle(
        'Body', parent=styles['Normal'],
        fontSize=10, textColor=DARK_TEXT, spaceAfter=3*mm,
        alignment=TA_JUSTIFY, fontName='Helvetica', leading=14
    ))
    styles.add(ParagraphStyle(
        'BodyBold', parent=styles['Normal'],
        fontSize=10, textColor=DARK_TEXT, spaceAfter=3*mm,
        alignment=TA_JUSTIFY, fontName='Helvetica-Bold', leading=14
    ))
    styles.add(ParagraphStyle(
        'BulletCustom', parent=styles['Normal'],
        fontSize=10, textColor=DARK_TEXT, spaceAfter=2*mm,
        fontName='Helvetica', leading=13, leftIndent=15,
        bulletIndent=5, bulletFontName='Helvetica', bulletFontSize=10
    ))
    styles.add(ParagraphStyle(
        'BulletBold', parent=styles['Normal'],
        fontSize=10, textColor=DARK_TEXT, spaceAfter=2*mm,
        fontName='Helvetica-Bold', leading=13, leftIndent=15,
        bulletIndent=5, bulletFontName='Helvetica-Bold', bulletFontSize=10
    ))
    styles.add(ParagraphStyle(
        'SmallNote', parent=styles['Normal'],
        fontSize=8, textColor=MID_GREY, spaceAfter=2*mm,
        fontName='Helvetica-Oblique'
    ))
    styles.add(ParagraphStyle(
        'KPI_Value', parent=styles['Normal'],
        fontSize=22, textColor=ACCENT_BLUE, spaceAfter=1*mm,
        fontName='Helvetica-Bold', alignment=TA_CENTER
    ))
    styles.add(ParagraphStyle(
        'KPI_Label', parent=styles['Normal'],
        fontSize=9, textColor=MID_GREY, spaceAfter=0,
        fontName='Helvetica', alignment=TA_CENTER
    ))
    styles.add(ParagraphStyle(
        'PageNumber', parent=styles['Normal'],
        fontSize=8, textColor=MID_GREY,
        fontName='Helvetica', alignment=TA_CENTER
    ))
    return styles


def make_table(headers, rows, col_widths=None, highlight_last=False):
    header_style = ParagraphStyle('_h', fontName='Helvetica-Bold', fontSize=9,
                                   textColor=WHITE, leading=11, alignment=TA_LEFT)
    hdr_c = ParagraphStyle('_hc', fontName='Helvetica-Bold', fontSize=9,
                            textColor=WHITE, leading=11, alignment=TA_CENTER)
    cell_s = ParagraphStyle('_cs', fontName='Helvetica', fontSize=9,
                             textColor=DARK_TEXT, leading=11)
    cell_c = ParagraphStyle('_cc', fontName='Helvetica', fontSize=9,
                             textColor=DARK_TEXT, leading=11, alignment=TA_CENTER)
    cell_b = ParagraphStyle('_cb', fontName='Helvetica-Bold', fontSize=9,
                             textColor=DARK_TEXT, leading=11, alignment=TA_CENTER)

    wrapped_h = [Paragraph(str(h), header_style if i == 0 else hdr_c)
                 for i, h in enumerate(headers)]
    wrapped_rows = []
    for ri, row in enumerate(rows):
        is_last = (ri == len(rows) - 1) and highlight_last
        wr = []
        for ci, cell in enumerate(row):
            st = cell_b if is_last else (cell_s if ci == 0 else cell_c)
            wr.append(Paragraph(str(cell), st))
        wrapped_rows.append(wr)

    data = [wrapped_h] + wrapped_rows
    style_cmds = [
        ('BACKGROUND', (0, 0), (-1, 0), HEADER_BG),
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ('GRID', (0, 0), (-1, -1), 0.5, MID_GREY),
        ('ROWBACKGROUNDS', (0, 1), (-1, -1), [WHITE, ROW_ALT]),
        ('TOPPADDING', (0, 0), (-1, -1), 5),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 5),
        ('LEFTPADDING', (0, 0), (-1, -1), 6),
        ('RIGHTPADDING', (0, 0), (-1, -1), 6),
    ]
    if highlight_last:
        style_cmds.append(('BACKGROUND', (0, -1), (-1, -1), HexColor('#e0f2fe')))

    t = Table(data, colWidths=col_widths, repeatRows=1)
    t.setStyle(TableStyle(style_cmds))
    return t


def cover_page(story, styles, title, subtitle, confidential=True):
    """Dark cover page using a table background."""
    cover_data = [['']]
    cover_style = TableStyle([
        ('BACKGROUND', (0, 0), (-1, -1), DARK_NAVY),
        ('TOPPADDING', (0, 0), (-1, -1), 60),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 40),
        ('LEFTPADDING', (0, 0), (-1, -1), 25),
        ('RIGHTPADDING', (0, 0), (-1, -1), 25),
    ])

    cover_content = []
    cover_content.append(Spacer(1, 30*mm))
    cover_content.append(Paragraph('FUTUREPROOF FINANCIAL', ParagraphStyle(
        '_cover_brand', fontName='Helvetica-Bold', fontSize=12,
        textColor=HexColor('#60a5fa'), spaceAfter=8*mm, leading=14
    )))
    cover_content.append(Paragraph(title, styles['DocTitle']))
    cover_content.append(Spacer(1, 3*mm))
    cover_content.append(Paragraph(subtitle, styles['DocSubtitle']))
    cover_content.append(Spacer(1, 8*mm))
    if confidential:
        cover_content.append(Paragraph(
            'CONFIDENTIAL &amp; PROPRIETARY', styles['Confidential']))
    cover_content.append(Spacer(1, 4*mm))
    cover_content.append(Paragraph(TODAY, ParagraphStyle(
        '_cover_date', fontName='Helvetica', fontSize=11,
        textColor=HexColor('#cbd5e1'), leading=14
    )))
    cover_content.append(Spacer(1, 6*mm))
    cover_content.append(Paragraph(
        'www.futureprooffinancial.co', ParagraphStyle(
        '_cover_url', fontName='Helvetica', fontSize=10,
        textColor=HexColor('#93c5fd'), leading=13
    )))

    # Build cover as a full-width coloured table
    w, h = A4
    page_w = w - 50  # approx margins
    cover_cell = [cover_content]
    cover_tbl = Table([[cover_cell]], colWidths=[page_w])
    cover_tbl.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, -1), DARK_NAVY),
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
        ('TOPPADDING', (0, 0), (-1, -1), 0),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 0),
        ('LEFTPADDING', (0, 0), (-1, -1), 20),
        ('RIGHTPADDING', (0, 0), (-1, -1), 20),
    ]))

    story.append(cover_tbl)
    story.append(PageBreak())


def kpi_strip(items, styles):
    """Create a row of KPI cards as a table."""
    vals = []
    labels = []
    for val, label in items:
        vals.append(Paragraph(str(val), styles['KPI_Value']))
        labels.append(Paragraph(str(label), styles['KPI_Label']))

    data = [vals, labels]
    n = len(items)
    w, _ = A4
    col_w = (w - 50) / n
    t = Table(data, colWidths=[col_w]*n)
    t.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, -1), HexColor('#f0f9ff')),
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ('ALIGN', (0, 0), (-1, -1), 'CENTER'),
        ('TOPPADDING', (0, 0), (-1, 0), 12),
        ('BOTTOMPADDING', (0, -1), (-1, -1), 12),
        ('BOX', (0, 0), (-1, -1), 0.5, HexColor('#dbeafe')),
        ('LINEAFTER', (0, 0), (-2, -1), 0.5, HexColor('#dbeafe')),
        ('ROUNDEDCORNERS', [6, 6, 6, 6]),
    ]))
    return t


def highlight_box(text, styles, bg=HexColor('#f0fdf4'), border=HexColor('#86efac')):
    """Coloured callout box."""
    inner = Paragraph(text, styles['Body'])
    data = [[inner]]
    t = Table(data, colWidths=[A4[0] - 50])
    t.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, -1), bg),
        ('BOX', (0, 0), (-1, -1), 1, border),
        ('TOPPADDING', (0, 0), (-1, -1), 10),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 10),
        ('LEFTPADDING', (0, 0), (-1, -1), 12),
        ('RIGHTPADDING', (0, 0), (-1, -1), 12),
        ('ROUNDEDCORNERS', [4, 4, 4, 4]),
    ]))
    return t


def make_chart_image(fig, dpi=150):
    buf = BytesIO()
    fig.savefig(buf, format='png', dpi=dpi, bbox_inches='tight',
                facecolor='white', edgecolor='none')
    plt.close(fig)
    buf.seek(0)
    return Image(buf, width=160*mm, height=90*mm)


def make_chart_image_small(fig, dpi=150):
    buf = BytesIO()
    fig.savefig(buf, format='png', dpi=dpi, bbox_inches='tight',
                facecolor='white', edgecolor='none')
    plt.close(fig)
    buf.seek(0)
    return Image(buf, width=75*mm, height=55*mm)


# ============================================================
# CHART GENERATORS
# ============================================================

def chart_surplus_fan():
    """Surplus distribution fan chart over 30 years."""
    years = list(range(1, 31))
    mean_s = [
        -22952, -17213, -8484, 3706, 18487, -1641, 21185, 48798, 82280,
        121232, 112540, 182342, 257458, 338650, 426685, 368971, 460610,
        556400, 660609, 773800, 655190, 766480, 889047, 1021272,
        1165690, 980751, 1120775, 1275877, 1446209, 1690289
    ]
    p10 = [
        -188608, -255497, -310187, -360194, -405131, -443630, -479464,
        -512855, -537838, -566643, -559491, -549041, -539232, -527013,
        -519452, -504322, -488146, -471468, -461416, -446516, -434542,
        -419002, -403605, -390288, -370077, -362865, -343266, -323108,
        -302340, -211973
    ]
    p90 = [
        117619, 221672, 299138, 380056, 463634, 435039, 531839, 633784,
        743505, 862688, 790482, 941012, 1101273, 1278566, 1475291,
        1281166, 1481495, 1687520, 1924231, 2171315, 1861699, 2105685,
        2380449, 2660260, 2976792, 2536957, 2835768, 3165575, 3537541,
        4017354
    ]

    fig, ax = plt.subplots(figsize=(10, 5))
    ax.fill_between(years, [v/1e6 for v in p10], [v/1e6 for v in p90],
                     alpha=0.15, color='#3b82f6', label='P10–P90 range')
    ax.plot(years, [v/1e6 for v in mean_s], color='#3b82f6', linewidth=2.5,
            label='Mean surplus')
    ax.axhline(y=0, color='#94a3b8', linestyle='--', linewidth=0.8)
    ax.set_xlabel('Year', fontsize=10, color='#475569')
    ax.set_ylabel('Surplus ($M)', fontsize=10, color='#475569')
    ax.set_title('Surplus Distribution — 50,000 Monte Carlo Paths', fontsize=12,
                 fontweight='bold', color='#0f172a')
    ax.legend(fontsize=9, loc='upper left')
    ax.yaxis.set_major_formatter(mticker.FormatStrFormatter('$%.1fM'))
    ax.grid(axis='y', alpha=0.2)
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    return fig


def chart_revenue_waterfall():
    """Revenue waterfall per mortgage over 30 years."""
    categories = ['FP Margin\n(0.25% p.a.)', 'Profit Share\nYr 5-25',
                  'Maturity Split\n(50/50)', 'Total FP\nRevenue']
    # Approximate 30yr revenue per $1.35M mortgage
    fp_margin_30yr = 1_350_000 * 0.0025 * 30  # ~$101,250
    profit_share_total = sum(EPM['profit_share_means'])  # ~$783k
    maturity_split = EPM['mean_surplus'] * 0.5  # ~$845k
    total = fp_margin_30yr + profit_share_total + maturity_split

    values = [fp_margin_30yr/1000, profit_share_total/1000,
              maturity_split/1000, total/1000]
    fig, ax = plt.subplots(figsize=(10, 5))
    bar_colors = ['#3b82f6', '#8b5cf6', '#10b981', '#0f172a']
    bars = ax.bar(categories, values, color=bar_colors, width=0.55, edgecolor='white')
    for bar, val in zip(bars, values):
        ax.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 15,
                f'${val:,.0f}k', ha='center', fontsize=10, fontweight='bold',
                color='#0f172a')
    ax.set_ylabel('Revenue ($k)', fontsize=10, color='#475569')
    ax.set_title('Revenue Per Mortgage — 30-Year Lifetime', fontsize=12,
                 fontweight='bold', color='#0f172a')
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    ax.grid(axis='y', alpha=0.2)
    return fig


def chart_profit_share_bars():
    """Profit share growth every 5 years."""
    years = ['Year 5', 'Year 10', 'Year 15', 'Year 20', 'Year 25']
    values = [v/1000 for v in EPM['profit_share_means']]
    fig, ax = plt.subplots(figsize=(10, 5))
    bar_colors = ['#8b5cf6'] * 5
    alphas = [0.5, 0.6, 0.7, 0.8, 0.9]
    for i, (y, v, a) in enumerate(zip(years, values, alphas)):
        ax.bar(y, v, color=bar_colors[i], alpha=a, width=0.5, edgecolor='white')
        ax.text(i, v + 3, f'${v:,.0f}k', ha='center', fontsize=10,
                fontweight='bold', color='#0f172a')
    ax.set_ylabel('Mean Profit Share ($k)', fontsize=10, color='#475569')
    ax.set_title('Profit Share Distributions — Every 5 Years', fontsize=12,
                 fontweight='bold', color='#0f172a')
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    ax.grid(axis='y', alpha=0.2)
    return fig


def chart_pod_decline():
    """PoD declining over time."""
    years = list(range(1, 31))
    pod = [
        53.15, 52.73, 51.39, 50.54, 49.51, 50.08, 48.76, 47.19, 45.9, 44.15,
        41.96, 39.2, 36.43, 33.82, 31.6, 30.26, 28.47, 26.8, 25.25, 23.92,
        23.14, 22.07, 21.2, 20.21, 19.24, 18.63, 18.0, 17.07, 16.36, 13.87
    ]
    poc = [
        None, None, None, None, None, None, None, None, None, None,
        None, None, None, None,
        1.60, 1.52, 1.40, 1.29, 1.20, 1.12,
        1.07, 1.01, 0.95, 0.90, 0.84,
        0.81, 0.77, 0.72, 0.68, 0.55
    ]

    fig, ax = plt.subplots(figsize=(10, 5))
    ax.plot(years, pod, color='#f59e0b', linewidth=2, label='PoD (balance sheet)',
            marker='', linestyle='-')
    poc_years = [y for y, p in zip(years, poc) if p is not None]
    poc_vals = [p for p in poc if p is not None]
    ax.plot(poc_years, poc_vals, color='#10b981', linewidth=2.5,
            label='PoC (actual claim risk)', marker='o', markersize=4)
    ax.fill_between(poc_years, poc_vals, alpha=0.1, color='#10b981')
    ax.set_xlabel('Year', fontsize=10, color='#475569')
    ax.set_ylabel('Probability (%)', fontsize=10, color='#475569')
    ax.set_title('Risk Profile — PoD vs PoC Over Time', fontsize=12,
                 fontweight='bold', color='#0f172a')
    ax.legend(fontsize=9)
    ax.grid(axis='y', alpha=0.2)
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    return fig


def chart_market_sizing():
    """TAM/SAM/SOM market sizing."""
    fig, ax = plt.subplots(figsize=(6, 4))
    sizes = [500, 120, 15]
    labels = ['TAM\n$500B', 'SAM\n$120B', 'SOM\n$15B']
    bar_colors = ['#e0e7ff', '#bfdbfe', '#3b82f6']
    for i, (s, l, c) in enumerate(zip(sizes, labels, bar_colors)):
        circle = plt.Circle((0.5, 0.5), 0.45 - i*0.13, color=c, alpha=0.7)
        ax.add_patch(circle)
    ax.text(0.5, 0.82, 'TAM: $500B+', ha='center', fontsize=12,
            fontweight='bold', color='#1e293b')
    ax.text(0.5, 0.5, 'SAM: $120B', ha='center', fontsize=11,
            fontweight='bold', color='#1e3a5f')
    ax.text(0.5, 0.25, 'SOM: $15B', ha='center', fontsize=10,
            fontweight='bold', color='white')
    ax.set_xlim(-0.1, 1.1)
    ax.set_ylim(-0.1, 1.1)
    ax.set_aspect('equal')
    ax.axis('off')
    ax.set_title('Addressable Market', fontsize=12, fontweight='bold', color='#0f172a')
    return fig


def chart_funder_returns():
    """Funder return projection chart."""
    years = [5, 10, 15, 20, 25, 30]
    # Funder gets: interest spread + 50% maturity surplus
    # Interest: ~4.5% on $1.35M = $60.75k/yr cumulative
    interest_cum = [60.75 * y for y in years]
    # Mean surplus at these years (approximate from MC data)
    surplus_at_yr = [18.5, 121.2, 426.7, 773.8, 1165.7, 1690.3]
    funder_share = [s * 0.5 for s in surplus_at_yr]  # 50% at maturity only
    total_return = [i + (f if y == 30 else 0) for i, f, y in zip(interest_cum, funder_share, years)]

    fig, ax = plt.subplots(figsize=(10, 5))
    ax.bar(years, interest_cum, label='Cumulative Interest', color='#3b82f6',
           alpha=0.7, width=3, edgecolor='white')
    # Show maturity bonus at year 30
    ax.bar([30], [funder_share[-1]], bottom=[interest_cum[-1]],
           label='50% Surplus (Maturity)', color='#10b981', alpha=0.8,
           width=3, edgecolor='white')
    ax.set_xlabel('Year', fontsize=10, color='#475569')
    ax.set_ylabel('Funder Returns ($k)', fontsize=10, color='#475569')
    ax.set_title('Wholesale Funder Return Profile — $1.35M Deployment', fontsize=12,
                 fontweight='bold', color='#0f172a')
    ax.legend(fontsize=9)
    ax.grid(axis='y', alpha=0.2)
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    ax.yaxis.set_major_formatter(mticker.FormatStrFormatter('$%.0fk'))
    return fig


# ============================================================
# DOCUMENT 1: VC SEED PITCH
# ============================================================

def generate_vc_pitch():
    filename = 'FutureProof_VC_Seed_Pitch_Mar2025.pdf'
    doc = SimpleDocTemplate(
        filename, pagesize=A4,
        leftMargin=25*mm, rightMargin=25*mm,
        topMargin=20*mm, bottomMargin=20*mm
    )
    styles = get_styles()
    story = []

    # ── Cover ────────────────────────────────────
    cover_page(story, styles,
               'Seed Investment<br/>Memorandum',
               'Equity Preservation Mortgage Platform<br/>Multi-Jurisdiction Financial Infrastructure')

    # ── Executive Summary ────────────────────────
    story.append(Paragraph('1. Executive Summary', styles['SectionHead']))
    story.append(Paragraph(
        'FutureProof Financial is building the infrastructure layer for <b>Equity Preservation Mortgages (EPM)</b> '
        '— a new asset class that enables homeowners to receive guaranteed monthly income from their property '
        'equity without selling, downsizing, or taking on compounding debt. The mortgage proceeds are invested '
        'in a professionally managed investment portfolio (BlackRock volatility-controlled ETFs with SpiderRock '
        'dynamic hedging), and the homeowner receives a guaranteed annuity for the term of their choice.',
        styles['Body']))

    story.append(Paragraph(
        'Unlike reverse mortgages — which erode equity through compounding interest — EPM preserves 100% of '
        'the homeowner\'s equity position through a No Negative Equity Guarantee (NNEG). The customer retains '
        'full ownership of their home and their equity is protected by an eight-layer risk framework validated '
        'through 50,000-path Monte Carlo simulation.',
        styles['Body']))

    story.append(highlight_box(
        '<b>What we have built:</b> A production-deployed, multi-jurisdiction platform (AU, NZ, UK, US) with '
        'complete origination workflow, AI-powered operations, 79 data models, real-time dashboards, and Monte Carlo '
        'validated pricing. The platform is live at futureprooffinancial.co with full regulatory compliance '
        'framework across four jurisdictions.',
        styles))

    story.append(Spacer(1, 4*mm))

    story.append(kpi_strip([
        ('4', 'Jurisdictions'),
        ('79', 'Data Models'),
        ('605', 'Passing Tests'),
        ('50K', 'MC Paths'),
    ], styles))

    story.append(Spacer(1, 6*mm))

    # ── The Problem ──────────────────────────────
    story.append(Paragraph('2. The Problem', styles['SectionHead']))
    story.append(Paragraph(
        '<b>$11.6 trillion in untapped home equity</b> exists across the US, UK, Australia, and New Zealand. '
        'Homeowners — particularly retirees — are asset-rich but cash-poor. Current solutions are inadequate:',
        styles['Body']))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>Reverse mortgages</b> — compound interest erodes equity; negative perception; '
        'high fees; limited to seniors 62+ (US). The US reverse mortgage market has declined 70% from its 2009 peak.',
        styles['BulletCustom']))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>Home equity loans/HELOCs</b> — require monthly repayments; '
        'borrower must service the debt; interest rate risk on variable products.',
        styles['BulletCustom']))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>Downsizing</b> — emotional cost; transaction costs 6-8% of property value; '
        'disrupts social connections and community.',
        styles['BulletCustom']))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>Sale-leaseback</b> — homeowner loses ownership; regulatory scrutiny; '
        'tenant risk.',
        styles['BulletCustom']))
    story.append(Paragraph(
        'None of these options offer guaranteed income while preserving 100% equity. '
        'The EPM fills this gap as a genuinely new financial product.',
        styles['Body']))

    # ── The Solution ─────────────────────────────
    story.append(Paragraph('3. The Solution: Equity Preservation Mortgage', styles['SectionHead']))
    story.append(Paragraph(
        'The EPM is an index-linked mortgage where the loan proceeds are invested in a diversified portfolio '
        'rather than drawn down. The investment returns fund a guaranteed annuity to the homeowner, while '
        'the mortgage balance is repaid from the investment account at maturity or property sale.',
        styles['Body']))

    story.append(Paragraph('How It Works', styles['SubHead']))
    story.append(make_table(
        ['Step', 'Action', 'Example ($2M Property)'],
        [
            ['1', 'Homeowner takes EPM at up to 80% LTV', '$1,350,000 loan (67.5% effective)'],
            ['2', 'Proceeds managed by BlackRock & SpiderRock', 'Volatility-controlled ETFs + dynamic hedging (±20% collar)'],
            ['3', 'Guaranteed monthly income paid', '$2,500/mo (10yr term) = 1.5% p.a.'],
            ['4', 'Investment grows over time', 'Mean: $1.69M surplus at Year 30'],
            ['5', 'Mortgage repaid at sale/maturity', 'Equity 100% preserved by NNEG'],
        ],
        col_widths=[15*mm, 55*mm, 75*mm]
    ))
    story.append(Spacer(1, 4*mm))
    story.append(Paragraph(
        'The annuity is funded by the expected investment returns, not by drawing down the loan principal. '
        'After the annuity period ends, the investment continues to compound. At maturity, the mortgage is '
        'repaid from the investment account. Any surplus is shared between FutureProof and the wholesale funder.',
        styles['Body']))

    # Annuity rates table
    story.append(Paragraph('Guaranteed Annuity Rates', styles['SubHead']))
    story.append(make_table(
        ['Term', 'Annual Rate', 'Monthly Income ($2M Property)', 'Annual Income'],
        [
            ['10 years', '1.50%', '$2,500', '$30,000'],
            ['15 years', '1.37%', '$2,283', '$27,400'],
            ['20 years', '1.25%', '$2,083', '$25,000'],
            ['25 years', '1.15%', '$1,917', '$23,000'],
            ['30 years', '1.05%', '$1,750', '$21,000'],
        ],
        col_widths=[25*mm, 25*mm, 50*mm, 40*mm]
    ))
    story.append(Spacer(1, 2*mm))
    story.append(Paragraph(
        'Note: Income rates are conservative (1.05–1.50% of property value p.a.) because the '
        'underlying investment portfolio targets 10% mean annual returns. The large spread between '
        'investment returns and income payout creates the surplus that funds the business model.',
        styles['SmallNote']))

    story.append(PageBreak())

    # ── Market Opportunity ───────────────────────
    story.append(Paragraph('4. Market Opportunity', styles['SectionHead']))
    story.append(Paragraph(
        'FutureProof targets four markets simultaneously — enabled by our multi-jurisdiction platform. '
        'Each market has specific regulatory requirements that our platform handles natively:',
        styles['Body']))
    story.append(make_table(
        ['Market', 'Regulator', 'Min Property', 'Min Age', 'Est. Addressable Equity'],
        [
            ['United States', 'CFPB / NMLS', '$500,000', '62', '$8.0T'],
            ['Australia', 'ASIC / AFSL', 'A$500,000', '55', '$1.8T'],
            ['United Kingdom', 'FCA', '£300,000', '55', '$1.3T'],
            ['New Zealand', 'FMA / FAP', 'NZ$500,000', '60', '$0.5T'],
        ],
        col_widths=[28*mm, 28*mm, 28*mm, 20*mm, 40*mm],
        highlight_last=False
    ))
    story.append(Spacer(1, 4*mm))
    story.append(Paragraph(
        '<b>Total Addressable Market:</b> $11.6T in home equity across target demographics. '
        'Even at 0.1% penetration, that represents $11.6B in AUM — generating approximately '
        '$29M in annual management fees alone, before profit share.',
        styles['Body']))

    # ── Revenue Model ────────────────────────────
    story.append(Paragraph('5. Revenue Model', styles['SectionHead']))
    story.append(Paragraph(
        'FutureProof generates revenue from <b>three distinct streams</b>, creating a compounding business model '
        'where revenue grows with both AUM and investment performance:',
        styles['Body']))

    story.append(Paragraph('Stream 1: Annual Management Fee (0.25% of AUM)', styles['SubHead']))
    story.append(Paragraph(
        'Recurring annual revenue of 0.25% of all assets under management. This is collected regardless of '
        'investment performance and scales linearly with origination volume.',
        styles['Body']))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> Per mortgage ($1.35M): <b>$3,375 per year</b>, ~$101,250 over 30 years',
        styles['BulletCustom']))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> At $1B AUM: <b>$2.5M per year</b> in recurring management fees',
        styles['BulletCustom']))

    story.append(Paragraph('Stream 2: Profit Share (25% Every 5 Years)', styles['SubHead']))
    story.append(Paragraph(
        'Every 5 years, 25% of the investment surplus above the loan baseline is realised as profit. '
        'This captures the upside from long-term equity market growth:',
        styles['Body']))
    story.append(make_table(
        ['Year', 'Mean Profit Share', 'Cumulative'],
        [
            ['Year 5', '$36,021', '$36,021'],
            ['Year 10', '$71,376', '$107,397'],
            ['Year 15', '$139,569', '$246,966'],
            ['Year 20', '$220,625', '$467,591'],
            ['Year 25', '$315,689', '$783,280'],
        ],
        col_widths=[30*mm, 40*mm, 40*mm],
        highlight_last=True
    ))
    story.append(Spacer(1, 2*mm))
    story.append(Paragraph(
        'Source: 50,000-path Monte Carlo simulation, v14a baseline parameters.',
        styles['SmallNote']))

    story.append(Paragraph('Stream 3: Maturity Surplus Split (50/50)', styles['SubHead']))
    story.append(Paragraph(
        'At loan maturity (Year 30), the remaining surplus after mortgage repayment is split 50/50 between '
        'FutureProof and the wholesale funder. Mean surplus at Year 30 is <b>$1,690,289</b>, with FutureProof\'s '
        'share averaging <b>~$845,000 per mortgage</b>.',
        styles['Body']))

    story.append(Spacer(1, 4*mm))
    story.append(make_chart_image(chart_revenue_waterfall()))
    story.append(Spacer(1, 2*mm))

    story.append(highlight_box(
        '<b>Total 30-Year Revenue Per Mortgage:</b> ~$1.73M<br/>'
        'Management fees: ~$101k | Profit share: ~$783k | Maturity split: ~$845k<br/>'
        'This represents approximately <b>128% return on the $1.35M loan originated</b>.',
        styles, bg=HexColor('#eff6ff'), border=HexColor('#93c5fd')))

    story.append(PageBreak())

    # ── Unit Economics ───────────────────────────
    story.append(Paragraph('6. Unit Economics &amp; Scaling', styles['SectionHead']))
    story.append(Paragraph(
        'The platform\'s economics improve dramatically with scale due to fixed cost leverage '
        'and the compounding nature of AUM-based revenue:',
        styles['Body']))
    story.append(make_table(
        ['Metric', '10 Mortgages', '100 Mortgages', '1,000 Mortgages'],
        [
            ['AUM', '$13.5M', '$135M', '$1.35B'],
            ['Annual Mgmt Fee', '$33,750', '$337,500', '$3,375,000'],
            ['5-Year Profit Share', '$360k', '$3.6M', '$36M'],
            ['Annual Revenue (Yr 5)', '~$106k', '~$1.06M', '~$10.6M'],
            ['Est. Operating Cost', '~$500k', '~$800k', '~$2M'],
            ['Est. Margin (Yr 5+)', 'Negative', '~25%', '~80%+'],
        ],
        col_widths=[35*mm, 35*mm, 35*mm, 35*mm]
    ))
    story.append(Spacer(1, 3*mm))
    story.append(Paragraph(
        'The management fee provides baseline recurring revenue from day one. The profit share — '
        'which dwarfs the management fee — begins at Year 5 and grows exponentially. This creates '
        'a business with <b>high initial capital efficiency requirements</b> but extraordinary long-term margins.',
        styles['Body']))

    story.append(Paragraph('Honest Assessment', styles['SubHead']))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>Revenue timing:</b> Profit share revenue is back-loaded (first realisation at Year 5). '
        'The management fee alone does not cover operating costs at low AUM. We need to reach ~100 active '
        'mortgages before the management fee stream becomes meaningful.',
        styles['BulletCustom']))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>Capital dependency:</b> Growth is gated by wholesale funder capital availability. '
        'Each mortgage requires ~$1.35M in capital deployment. Scaling to 1,000 mortgages requires $1.35B in '
        'funder commitments.',
        styles['BulletCustom']))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>Regulatory complexity:</b> Each jurisdiction requires specific licensing (AFSL, FCA Auth, '
        'NMLS, FAP). While the platform handles compliance programmatically, obtaining licences takes 6-18 months per market.',
        styles['BulletCustom']))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>Market education:</b> EPM is a new product category. Customer acquisition will require '
        'education spend to explain how it differs from reverse mortgages. We expect higher CAC initially.',
        styles['BulletCustom']))

    # ── Risk Framework ───────────────────────────
    story.append(Paragraph('7. Risk Framework — Eight-Layer Defence', styles['SectionHead']))
    story.append(Paragraph(
        'The EPM product is protected by an eight-layer defence system. Each layer reduces the probability '
        'that an insurance claim is ever made. The key distinction is between <b>PoD</b> (Probability of Deficit — '
        'a balance sheet snapshot) and <b>PoC</b> (Probability of Claim — actual insurance loss on an expiring loan). '
        'Only PoC matters for pricing:',
        styles['Body']))

    story.append(make_table(
        ['Layer', 'Defence Mechanism', 'Purpose'],
        [
            ['0', 'Mortgage Offset Account Capital', 'Pre-funded prudential buffer (~30%)'],
            ['1', 'Prudential Capital Buffer', 'Vintage diversification across cohorts'],
            ['2', 'BlackRock Volatility Control', 'Adaptive equity/cash allocation'],
            ['3', 'SpiderRock Dynamic Hedging', '±20% collar on annual returns'],
            ['4', 'Lender\'s Mortgage Insurance (LMI)', '90% loss coverage on claims'],
            ['5', 'Interest Holidays', 'Compound recovery during downturns'],
            ['6', 'Payments Waterfall', 'Cross-subsidisation from surplus loans'],
            ['7', 'Portfolio Reinsurance', 'Tail risk transfer (worst 10%)'],
        ],
        col_widths=[12*mm, 55*mm, 75*mm]
    ))
    story.append(Spacer(1, 3*mm))

    story.append(Paragraph(
        '<b>Net effect:</b> Individual PoD of 13.87% at Year 30 reduces to portfolio PoC of just <b>0.55%</b> '
        'after the Payments Waterfall. This means that in a diversified portfolio of EPM mortgages, fewer than '
        '1 in 200 expiring loans results in an actual insurance claim.',
        styles['Body']))

    story.append(Spacer(1, 3*mm))
    story.append(make_chart_image(chart_pod_decline()))

    story.append(PageBreak())

    # ── Technology Platform ──────────────────────
    story.append(Paragraph('8. What We\'ve Built', styles['SectionHead']))
    story.append(Paragraph(
        'FutureProof is not a pitch deck — it\'s a <b>production-deployed platform</b>. We have built the core '
        'technology stack required to originate, manage, and service EPM mortgages across four jurisdictions, '
        'with remaining integration and compliance work funded from this raise:',
        styles['Body']))

    story.append(Paragraph('Platform Architecture', styles['SubHead']))
    story.append(make_table(
        ['Component', 'Status', 'Details'],
        [
            ['Multi-Jurisdiction Origination', 'Production', '4 regions, 8-step application workflow, auto-checklists'],
            ['Financial Calculation Engine', 'Production', 'Actuarial models, MC-validated pricing, real-time quotes'],
            ['Contract Lifecycle Management', 'Production', 'Funding allocation, investment tracking, payment processing'],
            ['AI Agent Operations', 'Production', '5 specialist agents (Ava, Marcus, Claire, Sam, Diana)'],
            ['Compliance Framework', 'Production', 'KYC/AML per jurisdiction, audit logging, Paper Trail'],
            ['Email Workflow Automation', 'Production', 'Visual builder, triggers, conditional logic'],
            ['Webhook Integration System', 'Production', 'Event-driven, HMAC-signed, retry logic'],
            ['Stakeholder Portals', 'Production', '5 portals: Borrower, Lender, Funder, Broker, Admin'],
            ['Legal Document Management', 'Production', '24 templates (6 types x 4 regions), versioning'],
            ['Real-Time Dashboards', 'Production', '4 dashboards: Main, Financial, Risk, Business'],
            ['Monte Carlo Risk Engine', 'Production', '50K-path simulation'],
            ['External API Integration', 'Mocked', 'CoreLogic, payments, identity — interfaces ready'],
        ],
        col_widths=[48*mm, 22*mm, 75*mm]
    ))
    story.append(Spacer(1, 3*mm))

    story.append(Paragraph('Technology Stack', styles['SubHead']))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>Backend:</b> Ruby on Rails 8.1.2, Ruby 3.4.8, PostgreSQL — chosen for rapid iteration and proven reliability in financial services',
        styles['BulletCustom']))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>Frontend:</b> Stimulus.js (Hotwire), custom Apple HIG design system — no framework dependencies',
        styles['BulletCustom']))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>Security:</b> AES-256 encryption at rest, TLS 1.3, RBAC, MFA, CSP, CSRF, Brakeman auditing',
        styles['BulletCustom']))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>Testing:</b> 605 tests, 2,991 assertions, 0 failures — integration, unit, service, and controller coverage',
        styles['BulletCustom']))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>Infrastructure:</b> Docker/Kamal deployment on Fly.io, Solid Queue/Cache/Cable',
        styles['BulletCustom']))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>Risk Engine:</b> Python Monte Carlo with NumPy, validated against spreadsheet models',
        styles['BulletCustom']))

    # ── Competitive Advantage ────────────────────
    story.append(Paragraph('9. Competitive Advantages', styles['SectionHead']))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>First-mover in EPM infrastructure:</b> No existing platform supports the full EPM lifecycle. '
        'Reverse mortgage platforms (e.g., Finance of America, Longbridge) cannot pivot — their business model requires '
        'equity erosion. We are building the category.',
        styles['BulletCustom']))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>Multi-jurisdiction from day one:</b> Four-market regulatory compliance baked into the platform '
        'architecture, not bolted on. Regional configuration drives everything: currencies, regulators, tax treatment, '
        'minimum ages, LTV limits.',
        styles['BulletCustom']))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>Monte Carlo validated pricing:</b> Every quote is backed by 50,000-path simulation. '
        'Competitors in adjacent spaces (reverse mortgages, equity release) use actuarial tables with limited '
        'stochastic modelling. Our risk framework is transparent and auditable.',
        styles['BulletCustom']))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>AI-native operations:</b> Five specialist AI agents handle onboarding, loan analysis, '
        'legal compliance, customer support, and operations monitoring. This reduces human headcount requirements '
        'by an estimated 60-80% compared to traditional mortgage servicing.',
        styles['BulletCustom']))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>Platform, not product:</b> We are building the infrastructure for the EPM asset class. '
        'Lenders, funders, and brokers all operate through our platform. This creates network effects as more '
        'participants join.',
        styles['BulletCustom']))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>Eight-layer risk framework:</b> Portfolio PoC of 0.55% (vs individual PoD of 13.87%) '
        'makes EPM one of the safest structured mortgage products available. This is the key to attracting '
        'institutional wholesale capital.',
        styles['BulletCustom']))

    story.append(PageBreak())

    # ── Team & Use of Funds ──────────────────────
    story.append(Paragraph('10. Use of Funds', styles['SectionHead']))
    story.append(Paragraph(
        'We are raising <b>$5M at a $20M pre-money valuation</b> (20% dilution) to fund the path from '
        'production platform to first live mortgages. This valuation is supported by our DCF model (Section 11), '
        'which projects $42M enterprise value at a 25% discount rate — offering significant upside at entry:',
        styles['Body']))
    story.append(make_table(
        ['Category', 'Allocation', 'Purpose'],
        [
            ['Regulatory Licensing', '25%', 'AFSL (AU), FCA Auth (UK), NMLS (US), FAP (NZ) — legal & compliance costs'],
            ['Platform Completion', '20%', 'Engineering team to complete external integrations (CoreLogic, payments, identity, e-signatures), borrower portal, and production hardening'],
            ['External Integrations', '10%', 'CoreLogic, payment gateway, identity verification, e-signatures — live API connections & licensing'],
            ['First Mortgages', '15%', 'Seed capital contribution to first 5-10 mortgages (alongside wholesale funder capital)'],
            ['Team', '20%', 'Engineers, compliance officer, operations lead, business development'],
            ['Working Capital', '10%', 'Infrastructure, insurance, professional services'],
        ],
        col_widths=[35*mm, 20*mm, 90*mm]
    ))
    story.append(Spacer(1, 4*mm))

    story.append(Paragraph('Milestones', styles['SubHead']))
    story.append(make_table(
        ['Timeline', 'Milestone', 'Key Metric'],
        [
            ['Month 1-6', 'Platform completion, regulatory applications, external APIs live', 'All 4 licence applications filed'],
            ['Month 6-12', 'First jurisdiction licensed, first mortgages originated', '24 live mortgages, $32M AUM'],
            ['Month 12-18', 'Second jurisdiction, wholesale funder partnerships', '84+ mortgages, $113M+ AUM'],
            ['Month 18-24', 'All four jurisdictions active, 10+/month origination', '200+ mortgages, $275M+ AUM'],
        ],
        col_widths=[25*mm, 55*mm, 60*mm]
    ))

    story.append(PageBreak())

    # ── DCF / Business Model ─────────────────────
    story.append(Paragraph('11. Business Model &amp; DCF Valuation', styles['SectionHead']))
    story.append(Paragraph(
        'The following 10-year financial model projects FutureProof\'s revenue, costs, and free cash flow '
        'based on conservative origination assumptions. All three revenue streams are modelled independently:',
        styles['Body']))

    # --- DCF Model Assumptions ---
    avg_mortgage = 1_350_000  # average loan size
    fp_margin_rate = 0.0025   # 0.25% annual management fee
    profit_share_per_yr = 36_021  # mean profit share per mortgage per extraction (Yr 5 figure, grows)
    # Origination ramp: mortgages originated per year (informed by market research)
    # Yr1: 2/mo, Yr2: 5/mo, Yr3: 10/mo, scaling to ~125/mo by Yr10 across 4 jurisdictions
    originations = [24, 60, 120, 240, 400, 600, 800, 1000, 1200, 1500]
    # Cumulative active mortgages (no maturities in first 10 years — min 10yr term)
    cumulative = []
    total = 0
    for o in originations:
        total += o
        cumulative.append(total)
    # AUM each year
    aum = [c * avg_mortgage for c in cumulative]

    # Revenue streams per year
    mgmt_fee = [a * fp_margin_rate for a in aum]
    # Profit share: only begins Yr 5 after origination. In year N, mortgages originated in year N-5 or earlier generate profit share
    # Simplified: mortgages aged 5+ years generate profit share. Mean per mortgage ~$36K at Yr5, growing ~$7K/yr
    profit_share = []
    for yr in range(10):
        ps = 0
        for orig_yr in range(yr + 1):
            age = yr - orig_yr
            if age >= 5:
                # Profit share grows with age: Yr5=$36K, Yr10=$71K (from EPM data)
                ps_per = 36_021 + (age - 5) * 7_071  # linear interpolation
                ps += originations[orig_yr] * ps_per
        profit_share.append(ps)

    # Origination fees (0.5% of loan at origination — one-time)
    orig_fee_rate = 0.005
    orig_fees = [originations[yr] * avg_mortgage * orig_fee_rate for yr in range(10)]

    total_revenue = [mgmt_fee[yr] + profit_share[yr] + orig_fees[yr] for yr in range(10)]

    # Operating costs (realistic scaling for higher volume)
    # Base: $800K Yr1 (small team + platform completion), scaling with headcount, compliance, and infrastructure
    opex_base = [800, 1200, 2000, 3000, 4500, 6000, 7500, 9000, 10500, 12000]  # $K
    opex = [x * 1000 for x in opex_base]

    # Free cash flow
    fcf = [total_revenue[yr] - opex[yr] for yr in range(10)]

    # DCF calculation
    discount_rate = 0.25  # 25% — typical seed-stage VC discount rate
    terminal_growth = 0.03  # 3% terminal growth
    # Terminal value on Year 10 FCF
    terminal_value = fcf[9] * (1 + terminal_growth) / (discount_rate - terminal_growth)
    pv_fcfs = [fcf[yr] / (1 + discount_rate) ** (yr + 1) for yr in range(10)]
    pv_terminal = terminal_value / (1 + discount_rate) ** 10
    npv = sum(pv_fcfs) + pv_terminal

    story.append(Paragraph('Key Assumptions', styles['SubHead']))
    story.append(make_table(
        ['Assumption', 'Value', 'Rationale'],
        [
            ['Average mortgage size', f'${avg_mortgage/1e6:.2f}M', 'Based on $2M property at 67.5% effective LVR'],
            ['Origination ramp', '24 → 1,500/yr over 10 years', '2/mo → 125/mo across 4 jurisdictions (market research backed)'],
            ['Management fee', '0.25% of AUM p.a.', 'Recurring — collected regardless of performance'],
            ['Profit share', 'From Year 5 per mortgage', 'Mean $36K at Yr 5, growing to $71K at Yr 10'],
            ['Origination fee', '0.5% of loan', 'One-time fee at mortgage origination'],
            ['Discount rate', '25%', 'Standard seed-stage VC hurdle rate'],
            ['Terminal growth', '3%', 'Long-term GDP-linked growth assumption'],
        ],
        col_widths=[35*mm, 35*mm, 75*mm]
    ))

    story.append(Spacer(1, 4*mm))
    story.append(Paragraph('10-Year Financial Projections ($000s)', styles['SubHead']))

    dcf_rows = []
    for yr in range(10):
        dcf_rows.append([
            f'{yr + 1}',
            f'{originations[yr]:,}',
            f'{cumulative[yr]:,}',
            f'${aum[yr]/1e6:,.0f}M',
            f'${mgmt_fee[yr]/1000:,.0f}',
            f'${profit_share[yr]/1000:,.0f}',
            f'${orig_fees[yr]/1000:,.0f}',
            f'${total_revenue[yr]/1000:,.0f}',
            f'${opex[yr]/1000:,.0f}',
            f'${fcf[yr]/1000:,.0f}',
        ])

    story.append(make_table(
        ['Year', 'New', 'Total', 'AUM', 'Mgmt\nFee', 'Profit\nShare', 'Orig\nFee', 'Total\nRev', 'Opex', 'FCF'],
        dcf_rows,
        col_widths=[13*mm, 11*mm, 12*mm, 15*mm, 14*mm, 14*mm, 14*mm, 14*mm, 13*mm, 14*mm]
    ))

    story.append(Spacer(1, 4*mm))

    # DCF chart — Revenue vs Opex vs FCF
    def chart_dcf():
        years_x = list(range(1, 11))
        rev_k = [total_revenue[yr]/1000 for yr in range(10)]
        opex_k = [opex[yr]/1000 for yr in range(10)]
        fcf_k = [fcf[yr]/1000 for yr in range(10)]

        fig, ax = plt.subplots(figsize=(10, 5))
        ax.bar([x - 0.2 for x in years_x], rev_k, 0.35, color='#10b981', label='Revenue', alpha=0.85)
        ax.bar([x + 0.2 for x in years_x], opex_k, 0.35, color='#ef4444', label='Opex', alpha=0.65)
        ax.plot(years_x, fcf_k, color='#3b82f6', linewidth=2.5, marker='o', markersize=6, label='Free Cash Flow')
        ax.axhline(y=0, color='#94a3b8', linewidth=0.8, linestyle='--')
        ax.set_xlabel('Year', fontsize=10, color='#475569')
        ax.set_ylabel('$000s', fontsize=10, color='#475569')
        ax.set_title('10-Year Financial Projection — Revenue, Opex & FCF', fontsize=12,
                     fontweight='bold', color='#0f172a')
        ax.legend(fontsize=9)
        ax.spines['top'].set_visible(False)
        ax.spines['right'].set_visible(False)
        ax.grid(axis='y', alpha=0.2)
        ax.set_xticks(years_x)
        return fig

    story.append(make_chart_image(chart_dcf()))

    story.append(Spacer(1, 4*mm))
    story.append(Paragraph('DCF Valuation Summary', styles['SubHead']))
    story.append(make_table(
        ['Metric', 'Value'],
        [
            ['Sum of PV(FCF) Years 1-10', f'${sum(pv_fcfs)/1e6:,.1f}M'],
            ['Terminal Value (Year 10)', f'${terminal_value/1e6:,.1f}M'],
            ['PV of Terminal Value', f'${pv_terminal/1e6:,.1f}M'],
            ['Enterprise Value (NPV)', f'${npv/1e6:,.1f}M'],
            ['Year 10 AUM', f'${aum[9]/1e9:,.2f}B'],
            ['Year 10 Revenue', f'${total_revenue[9]/1e6:,.1f}M'],
            ['Year 10 FCF', f'${fcf[9]/1e6:,.1f}M'],
            ['Year 10 FCF Margin', f'{fcf[9]/total_revenue[9]*100:.0f}%'],
            ['Breakeven Year', f'Year {next(yr+1 for yr in range(10) if fcf[yr] > 0)}'],
        ],
        col_widths=[45*mm, 45*mm]
    ))

    story.append(Spacer(1, 3*mm))
    story.append(Paragraph(
        '<b>Note:</b> This model excludes maturity surplus splits (Year 10-30 revenue), which represent the largest '
        'revenue stream long-term. At maturity, FutureProof receives 50% of surplus — a mean of $845K per mortgage. '
        'Including maturities would significantly increase the terminal value. The model also assumes no geographic '
        'expansion beyond the initial four jurisdictions.',
        styles['SmallNote']))

    story.append(Spacer(1, 3*mm))
    story.append(Paragraph('Sensitivity Analysis', styles['SubHead']))
    # Sensitivity on discount rate and origination pace
    sens_rows = []
    for dr_label, dr in [('20%', 0.20), ('25% (base)', 0.25), ('30%', 0.30)]:
        for pace_label, pace_mult in [('Conservative (base)', 1.0), ('Moderate (1.5x)', 1.5), ('Aggressive (2x)', 2.0)]:
            adj_fcf = [f * pace_mult for f in fcf]
            adj_tv = adj_fcf[9] * (1 + terminal_growth) / (dr - terminal_growth)
            adj_pv = sum(adj_fcf[yr] / (1 + dr) ** (yr + 1) for yr in range(10)) + adj_tv / (1 + dr) ** 10
            sens_rows.append([dr_label, pace_label, f'${adj_pv/1e6:,.0f}M'])

    story.append(make_table(
        ['Discount Rate', 'Origination Pace', 'Enterprise Value'],
        sens_rows,
        col_widths=[30*mm, 45*mm, 35*mm]
    ))

    story.append(PageBreak())

    # ── Monte Carlo Validation ───────────────────
    story.append(Paragraph('12. Monte Carlo Validation', styles['SectionHead']))
    story.append(Paragraph(
        'All financial projections in this document are derived from a <b>50,000-path Monte Carlo simulation</b> '
        'using Geometric Brownian Motion for equity returns and an Ornstein-Uhlenbeck process for interest rates. '
        'The simulation captures the full complexity of the EPM product including hedging collars, interest holidays, '
        'profit share extractions, and loan wind-up mechanics.',
        styles['Body']))

    story.append(Spacer(1, 3*mm))
    story.append(make_chart_image(chart_surplus_fan()))
    story.append(Spacer(1, 3*mm))
    story.append(make_chart_image(chart_profit_share_bars()))

    story.append(Spacer(1, 4*mm))
    story.append(Paragraph('Key Simulation Results (Year 30)', styles['SubHead']))
    story.append(make_table(
        ['Metric', 'Value', 'Interpretation'],
        [
            ['Mean Surplus', '$1,690,289', 'Average outcome across all 50K paths'],
            ['Median Surplus', '$1,376,802', '50th percentile — half of paths above this'],
            ['P10 Surplus', '-$211,973', '10% of paths below this (modest deficit)'],
            ['P90 Surplus', '$4,017,354', '10% of paths above this (strong upside)'],
            ['PoD (Year 30)', '13.87%', 'Probability investment < loan balance'],
            ['PoC (Portfolio)', '0.55%', 'Actual claim probability after waterfall'],
            ['Fair Insurance Premium', '$21,953', 'PV of expected insurance loss'],
            ['Conditional Deficit', '-$592,400', 'Average deficit given shortfall occurs'],
        ],
        col_widths=[35*mm, 30*mm, 80*mm]
    ))
    story.append(Spacer(1, 2*mm))
    story.append(Paragraph(
        'Parameters: Equity return 10% (GBM, vol 10%); Cash rate 4.4% (OU, kappa=0.8, sigma=1.5%); '
        'Correlation 0.069; Collar ±20%; 30-year horizon; $2M property, 67.5% effective LVR.',
        styles['SmallNote']))

    story.append(PageBreak())

    # ── Closing ──────────────────────────────────
    story.append(Paragraph('13. Why Now', styles['SectionHead']))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>Demographic tailwind:</b> 10,000 baby boomers turn 65 every day in the US alone. '
        'Australia\'s retirement population will double by 2060. The demand for equity release without downsizing '
        'is structural and growing.',
        styles['BulletCustom']))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>Interest rate normalisation:</b> Higher-for-longer rates have increased mortgage costs, '
        'making the EPM\'s guaranteed-income model more attractive relative to new debt. The spread between '
        'investment returns (10% mean) and cost of capital (3.2%) supports the product at current rate levels.',
        styles['BulletCustom']))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>AI cost reduction:</b> The operational cost of mortgage servicing has historically '
        'prevented innovation in this space. AI-native operations reduce the cost structure by 60-80%, making '
        'the EPM viable at scale.',
        styles['BulletCustom']))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>Regulatory openness:</b> Post-GFC regulatory frameworks in all four target markets '
        'have created pathways for innovative mortgage products, provided they meet consumer protection standards. '
        'The EPM\'s equity preservation feature and NNEG guarantee align with regulatory intent.',
        styles['BulletCustom']))

    story.append(Spacer(1, 8*mm))
    story.append(highlight_box(
        '<b>FutureProof Financial</b><br/><br/>'
        'We have built the platform. The financial model is validated. The risk framework is robust. '
        'We are raising $5M to complete the platform, secure licensing, and originate first mortgages — '
        'targeting breakeven by Year 4 and $66M revenue by Year 10.<br/><br/>'
        '<b>Contact:</b> hello@futureprooffinancial.co<br/>'
        '<b>Platform:</b> www.futureprooffinancial.co',
        styles, bg=HexColor('#f8fafc'), border=HexColor('#e2e8f0')))

    story.append(Spacer(1, 8*mm))
    story.append(Paragraph(
        'This document is confidential and intended solely for the recipient. Financial projections are based on '
        'Monte Carlo simulation and do not guarantee future performance. Past performance of underlying indices '
        'is not indicative of future results. All figures in USD unless otherwise stated.',
        styles['SmallNote']))

    doc.build(story)
    print(f"  Generated: {filename}")
    return filename


# ============================================================
# DOCUMENT 2: WHOLESALE FUNDER MEMORANDUM
# ============================================================

def generate_funder_memo():
    filename = 'FutureProof_Wholesale_Funder_Memorandum_Mar2025.pdf'
    doc = SimpleDocTemplate(
        filename, pagesize=A4,
        leftMargin=25*mm, rightMargin=25*mm,
        topMargin=20*mm, bottomMargin=20*mm
    )
    styles = get_styles()
    story = []

    # ── Cover ────────────────────────────────────
    cover_page(story, styles,
               'Wholesale Funder<br/>Investment Memorandum',
               'Equity Preservation Mortgage — Capital Deployment Opportunity<br/>'
               'Secured Lending with Performance Upside')

    # ── Executive Summary ────────────────────────
    story.append(Paragraph('1. Executive Summary', styles['SectionHead']))
    story.append(Paragraph(
        'FutureProof Financial invites wholesale capital providers to participate in the origination of '
        '<b>Equity Preservation Mortgages (EPM)</b> — a secured lending product backed by residential property '
        'with investment-linked performance upside.',
        styles['Body']))
    story.append(Paragraph(
        'Unlike traditional mortgage lending where the funder\'s return is limited to the interest spread, '
        'EPM wholesale funders receive <b>both</b> a contractual interest rate (benchmark + margin) <b>and</b> '
        'a 50% share of the investment surplus at loan maturity. This creates a return profile that combines '
        'the safety of secured property lending with the upside of equity market participation.',
        styles['Body']))

    story.append(highlight_box(
        '<b>Investment Proposition:</b> Deploy capital into first-lien residential mortgages at up to 80% LTV. '
        'Receive contractual interest payments throughout the loan term, plus 50% of the investment surplus at maturity. '
        'Mean surplus at Year 30 is $1,690,289 — funder\'s share averaging $845,000 per mortgage on $1.35M deployed.',
        styles))

    story.append(Spacer(1, 4*mm))
    story.append(kpi_strip([
        ('80%', 'Max LTV'),
        ('$1.69M', 'Mean Surplus'),
        ('0.55%', 'Portfolio PoC'),
        ('50/50', 'Surplus Split'),
    ], styles))
    story.append(Spacer(1, 6*mm))

    # ── Product Overview ─────────────────────────
    story.append(Paragraph('2. Product Overview', styles['SectionHead']))
    story.append(Paragraph(
        'The Equity Preservation Mortgage is a first-lien residential mortgage where the loan proceeds are '
        'invested in a diversified portfolio rather than consumed by the borrower. The homeowner receives '
        'guaranteed monthly income (funded by investment returns), and the mortgage is repaid from the '
        'investment account at maturity or property sale.',
        styles['Body']))

    story.append(Paragraph('Key Product Features', styles['SubHead']))
    story.append(make_table(
        ['Feature', 'Specification'],
        [
            ['Security', 'First-lien registered mortgage over residential property'],
            ['Maximum LTV', '80% (effective LTV typically 67.5% at origination)'],
            ['Loan Terms', '10, 15, 20, 25, or 30 years'],
            ['Investment Portfolio', 'BlackRock volatility-controlled ETFs + SpiderRock dynamic hedging (±20% collar)'],
            ['Borrower Income', '1.05–1.50% of property value p.a. (guaranteed)'],
            ['No Negative Equity Guarantee', '100% — borrower equity always preserved'],
            ['Property Types', 'Primary residences, $500K+ (varies by jurisdiction)'],
            ['Jurisdictions', 'Australia, New Zealand, United Kingdom, United States'],
        ],
        col_widths=[42*mm, 103*mm]
    ))

    story.append(Spacer(1, 4*mm))
    story.append(Paragraph('How Funder Capital Is Used', styles['SubHead']))
    story.append(Paragraph(
        'When a borrower is approved for an EPM, the wholesale funder\'s capital is deployed as follows:',
        styles['Body']))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>Loan origination:</b> Capital funds the mortgage (up to 80% LTV of property value)',
        styles['BulletCustom']))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>Investment:</b> Loan proceeds immediately invested in the designated portfolio',
        styles['BulletCustom']))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>Annuity payments:</b> Monthly income paid to borrower from investment returns',
        styles['BulletCustom']))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>Funder interest:</b> Wholesale interest (benchmark + margin) accrued and capitalised',
        styles['BulletCustom']))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>Maturity:</b> Investment account liquidated, mortgage repaid, surplus split 50/50',
        styles['BulletCustom']))

    # ── Funder Return Profile ────────────────────
    story.append(PageBreak())
    story.append(Paragraph('3. Return Profile', styles['SectionHead']))
    story.append(Paragraph(
        'Wholesale funders receive returns through <b>two channels</b>:',
        styles['Body']))

    story.append(Paragraph('Channel 1: Contractual Interest', styles['SubHead']))
    story.append(Paragraph(
        'A fixed spread above the applicable benchmark rate, accrued over the loan term:',
        styles['Body']))
    story.append(make_table(
        ['Component', 'Typical Rate', 'Annual on $1.35M', '30-Year Total'],
        [
            ['Benchmark Rate', '4.00%', '$54,000', '$1,620,000'],
            ['Margin', '0.50%', '$6,750', '$202,500'],
            ['Total Interest', '4.50%', '$60,750', '$1,822,500'],
        ],
        col_widths=[35*mm, 25*mm, 35*mm, 35*mm],
        highlight_last=True
    ))
    story.append(Spacer(1, 2*mm))
    story.append(Paragraph(
        'Note: Interest is capitalised (not paid from investment proceeds). The funder receives '
        'interest payments from the investment account at scheduled intervals or at maturity.',
        styles['SmallNote']))

    story.append(Paragraph('Channel 2: Surplus Share at Maturity', styles['SubHead']))
    story.append(Paragraph(
        'At loan maturity, after the mortgage balance and all accrued costs are repaid from the investment '
        'account, the remaining surplus is split <b>50/50 between FutureProof and the wholesale funder</b>.',
        styles['Body']))
    story.append(make_table(
        ['Metric', 'Value'],
        [
            ['Mean Investment at Year 30', '$1,599,221 (after wind-up)'],
            ['Mean Surplus (after all costs)', '$1,690,289'],
            ['Funder\'s 50% Share', '~$845,000'],
            ['Median Surplus', '$1,376,802'],
            ['P90 Surplus (upside)', '$4,017,354 → Funder share ~$2.0M'],
            ['P10 Surplus (downside)', '-$211,973 → Covered by insurance layers'],
        ],
        col_widths=[45*mm, 100*mm]
    ))

    story.append(Spacer(1, 4*mm))
    story.append(make_chart_image(chart_funder_returns()))
    story.append(Spacer(1, 2*mm))

    story.append(highlight_box(
        '<b>Combined Return (Mean):</b> On a $1.35M deployment over 30 years, the funder receives '
        '~$1.82M in interest plus ~$845K in surplus share = <b>~$2.67M total return</b> on $1.35M deployed capital. '
        'This represents a blended annualised return of approximately <b>7-8% p.a.</b> — significantly above '
        'traditional secured lending rates.',
        styles, bg=HexColor('#f0fdf4'), border=HexColor('#86efac')))

    # ── Risk Framework ───────────────────────────
    story.append(PageBreak())
    story.append(Paragraph('4. Risk Framework &amp; Capital Protection', styles['SectionHead']))
    story.append(Paragraph(
        'The wholesale funder\'s capital is protected by multiple layers of risk mitigation, validated through '
        '50,000-path Monte Carlo simulation:',
        styles['Body']))

    story.append(Paragraph('Eight-Layer Defence System', styles['SubHead']))
    story.append(make_table(
        ['Layer', 'Mechanism', 'Effect on Funder Risk'],
        [
            ['0', 'Mortgage Offset Account', 'Pre-funded ~30% prudential buffer absorbs early-period losses'],
            ['1', 'Prudential Capital Buffer', 'Vintage diversification — mixed cohorts reduce crash exposure'],
            ['2', 'Volatility Control (BlackRock)', 'Dynamic equity/cash allocation limits drawdown severity'],
            ['3', 'Dynamic Hedging (SpiderRock)', '±20% collar — caps annual loss at 20% per year'],
            ['4', 'Lender\'s Mortgage Insurance', '90% of any deficit at expiry covered by LMI'],
            ['5', 'Interest Holidays', 'Compound recovery during downturns — no forced selling'],
            ['6', 'Payments Waterfall', 'Cross-subsidise from surplus loans before any claim'],
            ['7', 'Portfolio Reinsurance', 'Tail risk (worst 10%) transferred to reinsurer'],
        ],
        col_widths=[12*mm, 42*mm, 90*mm]
    ))

    story.append(Spacer(1, 4*mm))
    story.append(Paragraph('Key Risk Metrics', styles['SubHead']))
    story.append(make_table(
        ['Metric', 'Individual Loan', 'Portfolio Level', 'Significance'],
        [
            ['PoD (Year 30)', '13.87%', '—', 'Balance sheet snapshot — NOT claim risk'],
            ['PoC (Year 30)', '—', '0.55%', 'ACTUAL claim probability after waterfall'],
            ['Conditional Deficit', '-$592,400', '—', 'Average deficit IF shortfall occurs'],
            ['LMI Coverage', '90%', '90%', 'Insurer covers 90% of any deficit'],
            ['Net Funder Exposure', '—', '<0.06%', 'After LMI + reinsurance'],
            ['Fair Insurance Cost', '$21,953', '—', 'PV of expected loss (1.6% of loan)'],
        ],
        col_widths=[30*mm, 28*mm, 28*mm, 55*mm]
    ))

    story.append(Spacer(1, 3*mm))
    story.append(Paragraph(
        '<b>The critical insight:</b> PoD (13.87%) is a balance sheet metric — it measures how often the investment '
        'account is below the loan balance at a point in time. <b>PoC (0.55%)</b> is the metric that matters for '
        'funders — it measures how often an actual insurance claim occurs on an expiring loan, after the Payments '
        'Waterfall has cross-subsidised from surplus loans in the portfolio.',
        styles['Body']))

    story.append(Spacer(1, 3*mm))
    story.append(make_chart_image(chart_pod_decline()))

    # ── Surplus Distribution ─────────────────────
    story.append(PageBreak())
    story.append(Paragraph('5. Surplus Distribution Analysis', styles['SectionHead']))
    story.append(Paragraph(
        'The following table shows the distribution of surplus outcomes across 50,000 simulated paths. '
        'The funder receives 50% of the surplus at maturity (Year 30):',
        styles['Body']))

    story.append(make_table(
        ['Percentile', 'Surplus', 'Funder 50% Share', 'Outcome'],
        [
            ['P1 (Worst 1%)', '-$1,467,735', 'Covered by LMI/Reinsurance', 'Insurance claim'],
            ['P5', '-$653,596', 'Covered by LMI/Reinsurance', 'Insurance claim'],
            ['P10', '-$211,973', 'Covered by LMI/Reinsurance', 'Insurance claim'],
            ['P25', '$457,103', '$228,552', 'Modest surplus'],
            ['Median (P50)', '$1,376,802', '$688,401', 'Typical outcome'],
            ['Mean', '$1,690,289', '$845,145', 'Expected outcome'],
            ['P75', '$2,615,818', '$1,307,909', 'Strong performance'],
            ['P90', '$4,017,354', '$2,008,677', 'Very strong performance'],
            ['P95', '$5,029,172', '$2,514,586', 'Excellent performance'],
            ['P99 (Best 1%)', '$7,318,739', '$3,659,370', 'Exceptional performance'],
        ],
        col_widths=[28*mm, 30*mm, 40*mm, 42*mm]
    ))
    story.append(Spacer(1, 2*mm))
    story.append(Paragraph(
        '86.13% of all simulated paths end in surplus. In deficit scenarios (13.87% of paths), '
        'the Payments Waterfall and insurance layers protect the funder from loss.',
        styles['SmallNote']))

    story.append(Spacer(1, 4*mm))
    story.append(make_chart_image(chart_surplus_fan()))

    # ── Pool Structure ───────────────────────────
    story.append(PageBreak())
    story.append(Paragraph('6. Funder Pool Structure', styles['SectionHead']))
    story.append(Paragraph(
        'Wholesale funders deploy capital through <b>Funder Pools</b> — ring-fenced capital allocations '
        'managed through the FutureProof platform:',
        styles['Body']))

    story.append(Paragraph('Pool Management Features', styles['SubHead']))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>Real-time dashboard:</b> Track capital deployment, utilisation rates, contract performance, '
        'and P&L across all pools',
        styles['BulletCustom']))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>Multi-currency support:</b> AUD, USD, GBP, NZD — deploy capital in your preferred currency',
        styles['BulletCustom']))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>Lender assignment:</b> Choose which lenders can access your capital pools',
        styles['BulletCustom']))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>Benchmark + margin pricing:</b> Set your own benchmark rate and margin for each pool',
        styles['BulletCustom']))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>Allocation tracking:</b> Per-contract capital allocation with real-time utilisation monitoring',
        styles['BulletCustom']))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>Webhook notifications:</b> Automated event notifications (contract signed, distribution processed, etc.)',
        styles['BulletCustom']))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>Audit trail:</b> Complete version history and change tracking on all pool operations',
        styles['BulletCustom']))

    story.append(Spacer(1, 4*mm))
    story.append(Paragraph('Example Pool Configuration', styles['SubHead']))
    story.append(make_table(
        ['Parameter', 'Example Value'],
        [
            ['Pool Name', 'APAC Growth Pool - 2025'],
            ['Committed Capital', '$50,000,000'],
            ['Benchmark Rate', '4.00% (linked to 10yr govt bond)'],
            ['Margin', '0.50%'],
            ['Effective Rate', '4.50%'],
            ['Target Utilisation', '80-90%'],
            ['Eligible Regions', 'Australia, New Zealand'],
            ['Min Property Value', '$750,000'],
            ['Max Single Exposure', '$3,000,000'],
        ],
        col_widths=[40*mm, 105*mm]
    ))

    # ── Cost Structure ───────────────────────────
    story.append(Spacer(1, 6*mm))
    story.append(Paragraph('7. Cost Structure Transparency', styles['SectionHead']))
    story.append(Paragraph(
        'The EPM has a total annual variable cost of 3.20% applied to the loan balance. This is fully transparent '
        'and embedded in the Monte Carlo simulation:',
        styles['Body']))
    story.append(make_table(
        ['Cost Component', 'Annual Rate', 'Purpose', 'Paid To'],
        [
            ['Wholesale Margin', '2.00%', 'Cost of funds spread', 'Wholesale Funder'],
            ['Retail Margin', '0.70%', 'Lender NIM', 'Lender'],
            ['FP Management Fee', '0.25%', 'Platform operation', 'FutureProof'],
            ['Hedging / Rebalancing', '0.25%', 'Investment protection', 'Investment Manager'],
            ['Total Variable Cost', '3.20%', '', ''],
        ],
        col_widths=[35*mm, 22*mm, 40*mm, 40*mm],
        highlight_last=True
    ))
    story.append(Spacer(1, 2*mm))
    story.append(Paragraph(
        'Additionally, upfront costs of 1.6% (LMI) + 0.1% (reinsurance) are deducted from the loan at origination. '
        'All costs are modelled in the Monte Carlo simulation — the surplus figures presented already account for '
        'the full cost structure.',
        styles['SmallNote']))

    # ── Insurance & Sensitivity ──────────────────
    story.append(PageBreak())
    story.append(Paragraph('8. Insurance &amp; Sensitivity Analysis', styles['SectionHead']))

    story.append(Paragraph('Insurance Pricing', styles['SubHead']))
    story.append(Paragraph(
        'Lender\'s Mortgage Insurance (LMI) is priced using the Monte Carlo simulated expected loss:',
        styles['Body']))
    story.append(make_table(
        ['Metric', 'Value', 'Notes'],
        [
            ['Fair Premium (PV)', '$21,953', 'Discounted at 4.75% (30yr T-bond)'],
            ['Loaded Premium (1.5x)', '$32,929', 'Standard insurer loading'],
            ['Premium as % of Loan', '1.6%', 'Deducted at origination'],
            ['Conditional Expected Deficit', '-$592,400', 'Average loss IF deficit occurs'],
            ['LMI Coverage', '90%', '90% of deficit covered'],
            ['Reinsurance (Tail Risk)', '0.1%', 'Worst 10% quantile transferred'],
        ],
        col_widths=[42*mm, 28*mm, 75*mm]
    ))

    story.append(Spacer(1, 4*mm))
    story.append(Paragraph('Parameter Sensitivity', styles['SubHead']))
    story.append(Paragraph(
        'The following table shows how key outcomes vary across different property values, LTV ratios, '
        'and annuity levels (based on 10,000-path simulation per scenario):',
        styles['Body']))
    story.append(make_table(
        ['Scenario', 'Loan', 'PoD (Yr 30)', 'Mean Surplus', 'Funder Share'],
        [
            ['$2M / 60% LVR / $20K ann.', '$1.2M', '12.46%', '$1,552k', '$776k'],
            ['$2M / 80% LVR / $25K ann.', '$1.6M', '13.87%', '$1,690k', '$845k'],
            ['$2.5M / 70% LVR / $20K ann.', '$1.75M', '9.50%', '$2,371k', '$1,186k'],
            ['$3M / 80% LVR / $15K ann.', '$2.4M', '6.97%', '$3,635k', '$1,818k'],
            ['$3M / 80% LVR / $20K ann.', '$2.4M', '7.80%', '$3,537k', '$1,769k'],
        ],
        col_widths=[42*mm, 22*mm, 22*mm, 28*mm, 28*mm]
    ))
    story.append(Spacer(1, 2*mm))
    story.append(Paragraph(
        'Larger properties with lower annuity-to-loan ratios produce the best risk-adjusted outcomes. '
        'The optimal configuration (from fine optimisation analysis) achieves PoD of 4.4% and mean surplus of $3.83M.',
        styles['SmallNote']))

    # ── Interest Holiday Mechanism ───────────────
    story.append(Spacer(1, 6*mm))
    story.append(Paragraph('9. Interest Holiday Mechanism', styles['SubHead']))
    story.append(Paragraph(
        'When the investment account falls below 90% of the initial loan amount, the contract enters an '
        '<b>interest holiday</b>. During this period, no interest is charged to the investment account, allowing '
        'compound growth to recover the position. Interest resumes when the account exceeds 145.8% of the initial loan.',
        styles['Body']))
    story.append(make_table(
        ['Holiday Metric', 'Value'],
        [
            ['Paths with zero holidays', '48.3% (24,162 of 50,000)'],
            ['Mean holidays per loan', '4.62 years (of 30)'],
            ['Peak holiday incidence', 'Year 6: 34.1% of paths on holiday'],
            ['Holiday by Year 30', '7.4% of paths still on holiday'],
            ['Median holidays', '4 years'],
            ['P95 holidays', '16 years'],
        ],
        col_widths=[42*mm, 103*mm]
    ))
    story.append(Spacer(1, 2*mm))
    story.append(Paragraph(
        'The holiday mechanism is a key risk management feature — it prevents forced selling of investments '
        'during market downturns and allows compound growth to naturally restore the surplus position. '
        'Nearly half of all paths require zero holidays.',
        styles['Body']))

    # ── Platform & Compliance ────────────────────
    story.append(PageBreak())
    story.append(Paragraph('10. Platform &amp; Compliance', styles['SectionHead']))
    story.append(Paragraph(
        'The FutureProof platform provides wholesale funders with complete visibility into their capital '
        'deployment through a dedicated portal:',
        styles['Body']))

    story.append(Paragraph('Funder Portal Features', styles['SubHead']))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>Capital deployment dashboard:</b> Real-time view of all pools, contracts, and utilisation',
        styles['BulletCustom']))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>Per-contract P&L:</b> Investment return, cost of capital, and net P&L for each funded mortgage',
        styles['BulletCustom']))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>Risk monitoring:</b> Individual and portfolio risk metrics, holiday status, performance alerts',
        styles['BulletCustom']))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>Distribution tracking:</b> All borrower payments, profit share distributions, and maturity events',
        styles['BulletCustom']))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>Compliance reporting:</b> KYC/AML status, audit logs, regulatory documentation per jurisdiction',
        styles['BulletCustom']))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>Webhook integration:</b> Automated notifications for contract events, distributions, and alerts',
        styles['BulletCustom']))

    story.append(Spacer(1, 4*mm))
    story.append(Paragraph('Regulatory Framework', styles['SubHead']))
    story.append(make_table(
        ['Jurisdiction', 'Regulator', 'Licence Required', 'Consumer Protection'],
        [
            ['Australia', 'ASIC', 'AFSL', 'NCCPA, Corporations Act 2001'],
            ['New Zealand', 'FMA', 'FAP Licence', 'FMCA 2013, AML/CFT Act 2009'],
            ['United Kingdom', 'FCA', 'FCA Authorisation', 'MCD, Consumer Rights Act 2015'],
            ['United States', 'CFPB', 'NMLS', 'TILA, RESPA, Dodd-Frank'],
        ],
        col_widths=[28*mm, 20*mm, 30*mm, 65*mm]
    ))

    # ── Next Steps ───────────────────────────────
    story.append(Spacer(1, 8*mm))
    story.append(Paragraph('11. Next Steps', styles['SectionHead']))
    story.append(Paragraph(
        'We invite qualified wholesale capital providers to explore a partnership with FutureProof Financial. '
        'The engagement process is straightforward:',
        styles['Body']))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>Step 1:</b> Platform demonstration — review the funder portal, dashboards, and risk analytics',
        styles['BulletCustom']))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>Step 2:</b> Pool structuring — define pool parameters (size, rate, regions, eligibility)',
        styles['BulletCustom']))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>Step 3:</b> Legal documentation — wholesale funder agreement (jurisdiction-specific, already templated)',
        styles['BulletCustom']))
    story.append(Paragraph(
        '<bullet>&bull;</bullet> <b>Step 4:</b> Capital deployment — fund the pool and begin origination',
        styles['BulletCustom']))

    story.append(Spacer(1, 8*mm))
    story.append(highlight_box(
        '<b>FutureProof Financial</b><br/><br/>'
        'Secured lending with investment upside. Eight-layer risk protection. '
        'Monte Carlo validated. Multi-jurisdiction platform.<br/><br/>'
        '<b>Contact:</b> hello@futureprooffinancial.co<br/>'
        '<b>Platform:</b> www.futureprooffinancial.co',
        styles, bg=HexColor('#f8fafc'), border=HexColor('#e2e8f0')))

    story.append(Spacer(1, 8*mm))
    story.append(Paragraph(
        'This document is confidential and intended solely for qualified wholesale capital providers. '
        'Financial projections are based on 50,000-path Monte Carlo simulation and do not guarantee future '
        'performance. Past performance of underlying indices is not indicative of future results. '
        'All figures in USD unless otherwise stated. Surplus figures account for all cost structures.',
        styles['SmallNote']))

    doc.build(story)
    print(f"  Generated: {filename}")
    return filename


# ============================================================
# MAIN
# ============================================================

if __name__ == '__main__':
    print("Generating FutureProof Pitch Documents...")
    print("=" * 50)
    vc = generate_vc_pitch()
    funder = generate_funder_memo()
    print("=" * 50)
    print("Done! Generated files:")
    print(f"  1. {vc}")
    print(f"  2. {funder}")
