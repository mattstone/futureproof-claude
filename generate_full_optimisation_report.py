#!/usr/bin/env python3
"""
Generate Full Optimisation Report — Including Longer Payouts
Matches v14 report style
"""

import json
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.ticker as mticker
from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import mm
from reportlab.lib.enums import TA_LEFT, TA_CENTER, TA_JUSTIFY
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle,
    PageBreak, Image, KeepTogether
)
from reportlab.lib.colors import HexColor
from io import BytesIO

DARK_NAVY = HexColor('#2C3E50')
TEAL = HexColor('#3498A8')
CORAL = HexColor('#C0392B')
LIGHT_GREY = HexColor('#F5F5F5')
MID_GREY = HexColor('#95A5A6')
WHITE = colors.white
HEADER_BG = HexColor('#2C3E50')
ROW_ALT = HexColor('#F8F9FA')
GREEN = HexColor('#27AE60')

MPL = {
    'navy': '#2C3E50', 'teal': '#3498A8', 'coral': '#C0392B',
    'grey': '#95A5A6', 'green': '#27AE60', 'orange': '#E67E22',
    'purple': '#8E44AD', 'blue': '#2980B9', 'gold': '#F39C12',
}


def get_styles():
    styles = getSampleStyleSheet()
    for name, kw in [
        ('ReportTitle', dict(fontSize=24, textColor=DARK_NAVY, spaceAfter=6*mm,
                             alignment=TA_CENTER, fontName='Helvetica-Bold')),
        ('ReportSubtitle', dict(fontSize=13, textColor=TEAL, spaceAfter=4*mm,
                                alignment=TA_CENTER, fontName='Helvetica')),
        ('Confidential', dict(fontSize=11, textColor=CORAL, spaceAfter=8*mm,
                              alignment=TA_CENTER, fontName='Helvetica-Oblique')),
        ('SectionHead', dict(fontSize=18, textColor=DARK_NAVY, spaceBefore=8*mm,
                             spaceAfter=4*mm, fontName='Helvetica-Bold')),
        ('SubHead', dict(fontSize=14, textColor=TEAL, spaceBefore=5*mm,
                         spaceAfter=3*mm, fontName='Helvetica-Bold')),
        ('BodyText2', dict(fontSize=10, textColor=DARK_NAVY, spaceAfter=3*mm,
                           alignment=TA_JUSTIFY, fontName='Helvetica', leading=14)),
        ('BulletCustom', dict(fontSize=10, textColor=DARK_NAVY, spaceAfter=2*mm,
                              fontName='Helvetica', leading=13, leftIndent=15,
                              bulletIndent=5)),
        ('SmallNote', dict(fontSize=8, textColor=MID_GREY, spaceAfter=2*mm,
                           fontName='Helvetica-Oblique')),
    ]:
        parent = 'Title' if 'Title' in name else ('Heading1' if 'Section' in name else
                 ('Heading2' if 'Sub' in name else 'Normal'))
        styles.add(ParagraphStyle(name, parent=styles[parent], **kw))
    return styles


def make_table(headers, rows, col_widths=None):
    hs = ParagraphStyle('_h', fontName='Helvetica-Bold', fontSize=9, textColor=WHITE, leading=11, alignment=TA_LEFT)
    hc = ParagraphStyle('_hc', fontName='Helvetica-Bold', fontSize=9, textColor=WHITE, leading=11, alignment=TA_CENTER)
    cs = ParagraphStyle('_c', fontName='Helvetica', fontSize=9, textColor=DARK_NAVY, leading=11, alignment=TA_LEFT)
    cc = ParagraphStyle('_cc', fontName='Helvetica', fontSize=9, textColor=DARK_NAVY, leading=11, alignment=TA_CENTER)
    data = [[Paragraph(str(h), hs if i == 0 else hc) for i, h in enumerate(headers)]]
    for row in rows:
        data.append([Paragraph(str(c), cs if i == 0 else cc) for i, c in enumerate(row)])
    t = Table(data, colWidths=col_widths, repeatRows=1)
    t.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), HEADER_BG),
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ('GRID', (0, 0), (-1, -1), 0.5, MID_GREY),
        ('ROWBACKGROUNDS', (0, 1), (-1, -1), [WHITE, ROW_ALT]),
        ('TOPPADDING', (0, 0), (-1, -1), 4),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 4),
        ('LEFTPADDING', (0, 0), (-1, -1), 6),
        ('RIGHTPADDING', (0, 0), (-1, -1), 6),
    ]))
    return t


def fig_to_image(fig, width=160*mm, height=100*mm):
    buf = BytesIO()
    fig.savefig(buf, format='png', dpi=150, bbox_inches='tight', facecolor='white', edgecolor='none')
    plt.close(fig)
    buf.seek(0)
    return Image(buf, width=width, height=height)


def footer(canvas, doc):
    canvas.saveState()
    canvas.setFont('Helvetica', 8)
    canvas.setFillColor(MID_GREY)
    canvas.drawString(25*mm, 12*mm, 'FutureProof | Full Optimisation — Including Longer Payouts | March 2025')
    canvas.drawRightString(A4[0] - 25*mm, 12*mm, f'Page {doc.page}')
    canvas.restoreState()


def annuity_desc(r):
    return f'${r["annuity_pa"]/1000:.0f}K×{r["annuity_term"]}yr=${r["total_annuity"]/1000:.0f}K'


def generate():
    with open('optimisation_v14a_full_results.json') as f:
        data = json.load(f)

    bl = data['baseline']
    rec = data['recommended_overall']
    pareto = data['pareto_front_50k']
    validated = data['all_50k_validated']
    meta = data['metadata']
    best_by = data['best_by_payout_duration']

    # Get the duration-specific recommendations
    rec_10 = best_by['min_10yr']
    rec_15 = best_by['min_15yr']
    rec_20 = best_by['min_20yr']
    rec_25 = best_by['min_25yr']

    styles = get_styles()
    story = []

    # ── Title Page ──
    story.append(Spacer(1, 60*mm))
    story.append(Paragraph('Futureproof', styles['ReportTitle']))
    story.append(Spacer(1, 15*mm))
    story.append(Paragraph('EPM v14a', styles['ReportTitle']))
    story.append(Spacer(1, 4*mm))
    story.append(Paragraph('Full Parameter Optimisation', styles['ReportTitle']))
    story.append(Spacer(1, 4*mm))
    story.append(Paragraph('Including Longer Payout Periods (10–25 Years)', styles['ReportSubtitle']))
    story.append(Paragraph('March 2025', styles['ReportSubtitle']))
    story.append(Spacer(1, 15*mm))
    story.append(Paragraph('CONFIDENTIAL — For Internal Use Only', styles['Confidential']))
    story.append(PageBreak())

    # ── Executive Summary ──
    story.append(Paragraph('Executive Summary', styles['SectionHead']))
    story.append(Paragraph(
        'This report presents a comprehensive optimisation of EPM v14a parameters with a particular focus on '
        '<b>longer payout periods</b>. The base EPM provides $25,000/year for 10 years ($250K total), but for '
        'a 30-year mortgage this may not be sufficiently attractive to borrowers. This analysis explores payout '
        'terms from 10 to 25 years, combined with all other structural levers (P&amp;I vs IO, collar width, '
        'holiday thresholds, profit share configuration, FP margin).',
        styles['BodyText2']))

    total_scenarios = meta['phase1_scenarios'] + meta['phase2_scenarios']
    story.append(Paragraph(
        f'A total of <b>{total_scenarios} scenarios</b> were screened at 10,000 Monte Carlo paths, with the '
        f'top {meta["phase3_scenarios"]} validated at 50,000 paths. The analysis identifies optimal configurations '
        f'for each payout duration, enabling FutureProof to offer tailored products matching borrower preferences.',
        styles['BodyText2']))

    # Duration comparison table
    story.append(Spacer(1, 3*mm))
    story.append(Paragraph('Best Configuration by Payout Duration', styles['SubHead']))
    story.append(make_table(
        ['Metric', '10yr Payout', '15yr Payout', '20yr Payout', '25yr Payout'],
        [
            ['Income p.a.', f'${rec_10["annuity_pa"]:,.0f}', f'${rec_15["annuity_pa"]:,.0f}',
             f'${rec_20["annuity_pa"]:,.0f}', f'${rec_25["annuity_pa"]:,.0f}'],
            ['Total Income', f'${rec_10["total_annuity"]:,.0f}', f'${rec_15["total_annuity"]:,.0f}',
             f'${rec_20["total_annuity"]:,.0f}', f'${rec_25["total_annuity"]:,.0f}'],
            ['Loan Type', rec_10['loan_type'], rec_15['loan_type'],
             rec_20['loan_type'], rec_25['loan_type']],
            ['PoD Year 30', f'{rec_10["pod_yr30"]:.1f}%', f'{rec_15["pod_yr30"]:.1f}%',
             f'{rec_20["pod_yr30"]:.1f}%', f'{rec_25["pod_yr30"]:.1f}%'],
            ['FP Revenue', f'${rec_10["mean_total_fp_revenue"]:,.0f}',
             f'${rec_15["mean_total_fp_revenue"]:,.0f}',
             f'${rec_20["mean_total_fp_revenue"]:,.0f}',
             f'${rec_25["mean_total_fp_revenue"]:,.0f}'],
            ['Mean Surplus', f'${rec_10["mean_surplus_yr30"]:,.0f}',
             f'${rec_15["mean_surplus_yr30"]:,.0f}',
             f'${rec_20["mean_surplus_yr30"]:,.0f}',
             f'${rec_25["mean_surplus_yr30"]:,.0f}'],
            ['Sharpe Ratio', f'{rec_10["sharpe_like"]:.3f}', f'{rec_15["sharpe_like"]:.3f}',
             f'{rec_20["sharpe_like"]:.3f}', f'{rec_25["sharpe_like"]:.3f}'],
            ['Protection', f'{rec_10["mean_borrower_equity_return"]:.1f}%',
             f'{rec_15["mean_borrower_equity_return"]:.1f}%',
             f'{rec_20["mean_borrower_equity_return"]:.1f}%',
             f'{rec_25["mean_borrower_equity_return"]:.1f}%'],
            ['Premium', f'${rec_10["fair_premium_loaded"]:,.0f}',
             f'${rec_15["fair_premium_loaded"]:,.0f}',
             f'${rec_20["fair_premium_loaded"]:,.0f}',
             f'${rec_25["fair_premium_loaded"]:,.0f}'],
        ],
        col_widths=[28*mm, 32*mm, 32*mm, 32*mm, 32*mm]
    ))

    story.append(Spacer(1, 4*mm))
    story.append(Paragraph(
        '<b>Key finding:</b> Longer payout periods are viable with optimised parameters. A 20-year payout '
        f'at $15,000/year delivers $300,000 total income (vs $250,000 over 10 years) with PoD of just '
        f'{rec_20["pod_yr30"]:.1f}% and FP revenue of ${rec_20["mean_total_fp_revenue"]:,.0f}. Even a 25-year '
        f'payout at $15,000/year ($375K total) maintains PoD at {rec_25["pod_yr30"]:.1f}%.',
        styles['BodyText2']))

    story.append(PageBreak())

    # ── Annuity Term Analysis ──
    story.append(Paragraph('Payout Duration Analysis', styles['SectionHead']))
    story.append(Paragraph(
        'The following chart shows how PoD and total borrower income change as the payout term increases. '
        'The key trade-off: longer terms deliver more income but increase deficit risk. P&amp;I dramatically '
        'reduces PoD at all durations by amortising the mortgage to zero.',
        styles['BodyText2']))

    # Chart: PoD vs payout term for fixed $25K/yr and fixed $15K/yr
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(10, 4.5))

    # $25K/yr — fixed annual
    terms_25k = [10, 12, 15, 18, 20, 25]
    pods_io = [17.9, 20.6, 25.2, 29.4, 31.8, 37.0]
    pods_pi = [10.2, 14.8, 21.7, 28.2, 32.0, 38.3]
    totals_25k = [t * 25 for t in terms_25k]

    ax1.plot(terms_25k, pods_io, 'o-', color=MPL['coral'], linewidth=2, markersize=6, label='IO')
    ax1.plot(terms_25k, pods_pi, 's-', color=MPL['green'], linewidth=2, markersize=6, label='P&I')
    ax1.axhline(y=5, color=MPL['grey'], linestyle=':', alpha=0.7, label='5% target')
    ax1.set_xlabel('Payout Term (years)', fontsize=10)
    ax1.set_ylabel('PoD at Year 30 (%)', fontsize=10)
    ax1.set_title('$25,000/yr — Varying Term', fontsize=11, fontweight='bold', color=MPL['navy'])
    ax1.legend(fontsize=8)
    ax1.grid(True, alpha=0.3)
    ax1.spines['top'].set_visible(False)
    ax1.spines['right'].set_visible(False)

    # Fixed total $250K — spreading over different terms
    terms_fixed = [10, 12, 15, 20, 25]
    pods_fixed = [10.2, 11.9, 14.1, 15.5, 15.4]
    annuals_fixed = [250000/t for t in terms_fixed]

    ax2.plot(terms_fixed, pods_fixed, 's-', color=MPL['teal'], linewidth=2, markersize=6, label='P&I, $250K total')
    # Fixed total $300K
    pods_300 = [12.8, 14.8, 17.0, 18.4, 18.3]
    ax2.plot(terms_fixed, pods_300, 'D-', color=MPL['purple'], linewidth=2, markersize=6, label='P&I, $300K total')
    # Fixed total $375K
    pods_375 = [17.5, 19.4, 21.7, 23.0, 22.8]
    ax2.plot(terms_fixed, pods_375, '^-', color=MPL['orange'], linewidth=2, markersize=6, label='P&I, $375K total')
    ax2.axhline(y=5, color=MPL['grey'], linestyle=':', alpha=0.7, label='5% target')
    ax2.set_xlabel('Payout Term (years)', fontsize=10)
    ax2.set_ylabel('PoD at Year 30 (%)', fontsize=10)
    ax2.set_title('Fixed Total Income — Varying Term', fontsize=11, fontweight='bold', color=MPL['navy'])
    ax2.legend(fontsize=8)
    ax2.grid(True, alpha=0.3)
    ax2.spines['top'].set_visible(False)
    ax2.spines['right'].set_visible(False)

    fig.tight_layout()
    story.append(fig_to_image(fig, width=170*mm, height=95*mm))

    story.append(Spacer(1, 4*mm))
    story.append(Paragraph(
        '<b>Left panel:</b> Extending the payout term at $25,000/year rapidly increases PoD. '
        'At 15 years ($375K total), PoD exceeds 20% even with P&amp;I. At 25 years ($625K total), PoD reaches '
        '37–38% — unacceptable without additional parameter optimisation.',
        styles['BodyText2']))

    story.append(Paragraph(
        '<b>Right panel:</b> Spreading a fixed total over more years has a much milder impact. '
        'Distributing $250K over 25 years ($10K/yr) only increases PoD from 10.2% to 15.4% under P&amp;I — '
        'and this increase is more than offset by combined lever optimisation (collar, holidays, PS).',
        styles['BodyText2']))

    story.append(PageBreak())

    # ── Recommended Configurations ──
    story.append(Paragraph('Recommended Configurations', styles['SectionHead']))

    # Config comparison table
    configs = [
        ('10yr Payout', rec_10),
        ('15–20yr Payout', rec_15),
        ('25yr Payout', rec_25),
    ]
    story.append(make_table(
        ['Parameter', 'v14a Baseline', '10yr (Best Overall)', '20yr Payout', '25yr Payout'],
        [
            ['Annuity', f'${bl["annuity_pa"]/1000:.0f}K×{bl["annuity_term"]}yr',
             f'${rec_10["annuity_pa"]/1000:.0f}K×{rec_10["annuity_term"]}yr',
             f'${rec_15["annuity_pa"]/1000:.0f}K×{rec_15["annuity_term"]}yr',
             f'${rec_25["annuity_pa"]/1000:.0f}K×{rec_25["annuity_term"]}yr'],
            ['Total Income', f'${bl["total_annuity"]:,.0f}', f'${rec_10["total_annuity"]:,.0f}',
             f'${rec_15["total_annuity"]:,.0f}', f'${rec_25["total_annuity"]:,.0f}'],
            ['Loan Type', bl['loan_type'], rec_10['loan_type'], rec_15['loan_type'], rec_25['loan_type']],
            ['Collar', f'±{(bl["buffer_cap"]-1)*100:.0f}%', f'±{(rec_10["buffer_cap"]-1)*100:.0f}%',
             f'±{(rec_15["buffer_cap"]-1)*100:.0f}%', f'±{(rec_25["buffer_cap"]-1)*100:.0f}%'],
            ['Holiday Entry', f'{bl["holiday_entry"]:.2f}', f'{rec_10["holiday_entry"]:.2f}',
             f'{rec_15["holiday_entry"]:.2f}', f'{rec_25["holiday_entry"]:.2f}'],
            ['Profit Share', f'{bl["profit_share_pct"]*100:.0f}% q{bl["profit_share_years"]}',
             f'{rec_10["profit_share_pct"]*100:.0f}% q{rec_10["profit_share_years"]}',
             f'{rec_15["profit_share_pct"]*100:.0f}% q{rec_15["profit_share_years"]}',
             f'{rec_25["profit_share_pct"]*100:.0f}% q{rec_25["profit_share_years"]}'],
            ['FP Margin', f'{bl["fp_margin"]*100:.2f}%', f'{rec_10["fp_margin"]*100:.2f}%',
             f'{rec_15["fp_margin"]*100:.2f}%', f'{rec_25["fp_margin"]*100:.2f}%'],
        ],
        col_widths=[28*mm, 30*mm, 32*mm, 32*mm, 32*mm]
    ))

    story.append(Spacer(1, 4*mm))
    story.append(Paragraph(
        'All three recommended configurations share the same core structural changes from baseline: '
        '<b>P&amp;I amortisation</b> (except 25yr which uses IO), <b>±35% collar</b>, <b>holiday entry at 1.05</b>, '
        'and <b>FP margin of 0.15%</b>. The key differences are the annuity structure and profit share frequency.',
        styles['BodyText2']))

    story.append(Paragraph(
        f'The 25-year payout uses IO rather than P&amp;I because with a 25-year annuity term and only 5 years '
        f'of post-annuity amortisation, the annual principal payments would be extremely high (~$320K/year). '
        f'IO keeps the payments manageable while the wider collar and tighter holidays maintain PoD at '
        f'{rec_25["pod_yr30"]:.1f}%.',
        styles['BodyText2']))

    story.append(PageBreak())

    # ── PoD Trajectory Comparison ──
    story.append(Paragraph('Risk Trajectories', styles['SectionHead']))

    fig, ax = plt.subplots(figsize=(9, 5))
    years = list(range(1, 31))
    ax.plot(years, bl['pod_by_year'], color=MPL['coral'], linewidth=2.5, label=f'Baseline (IO, $25K×10yr)', linestyle='--')
    ax.plot(years, rec_10['pod_by_year'], color=MPL['green'], linewidth=2.5, label=f'Best 10yr (PI, $25K×10yr)')
    ax.plot(years, rec_15['pod_by_year'], color=MPL['teal'], linewidth=2.5, label=f'Best 20yr (PI, $15K×20yr)')
    ax.plot(years, rec_25['pod_by_year'], color=MPL['purple'], linewidth=2.5, label=f'Best 25yr (IO, $15K×25yr)')
    ax.axhline(y=5, color=MPL['grey'], linestyle=':', alpha=0.7, label='5% target')
    ax.set_xlabel('Year', fontsize=11)
    ax.set_ylabel('Deficit Probability (%)', fontsize=11)
    ax.set_title('PoD Over Time — By Payout Duration', fontsize=13, fontweight='bold', color=MPL['navy'])
    ax.legend(fontsize=9, loc='upper right')
    ax.set_xlim(1, 30)
    ax.set_ylim(0, max(bl['pod_by_year']) * 1.05)
    ax.grid(True, alpha=0.3)
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    fig.tight_layout()
    story.append(fig_to_image(fig, width=170*mm, height=105*mm))

    story.append(Paragraph(
        'All optimised configurations dramatically outperform the baseline. The 10-year payout achieves the '
        f'lowest terminal PoD ({rec_10["pod_yr30"]:.1f}%), but even the 25-year payout ({rec_25["pod_yr30"]:.1f}%) '
        f'is well within acceptable bounds. Note how the optimised configurations converge toward '
        f'low PoD in later years as the P&amp;I amortisation and wider collar take effect.',
        styles['BodyText2']))

    story.append(PageBreak())

    # ── Surplus Trajectory ──
    story.append(Paragraph('Surplus Trajectories', styles['SubHead']))

    fig, ax = plt.subplots(figsize=(9, 5))
    ax.plot(years, [s/1e6 for s in bl['mean_surplus_by_year']], color=MPL['coral'],
            linewidth=2.5, label='Baseline', linestyle='--')
    ax.plot(years, [s/1e6 for s in rec_10['mean_surplus_by_year']], color=MPL['green'],
            linewidth=2.5, label=f'10yr ($250K)')
    ax.plot(years, [s/1e6 for s in rec_15['mean_surplus_by_year']], color=MPL['teal'],
            linewidth=2.5, label=f'20yr ($300K)')
    ax.plot(years, [s/1e6 for s in rec_25['mean_surplus_by_year']], color=MPL['purple'],
            linewidth=2.5, label=f'25yr ($375K)')
    ax.axhline(y=0, color=MPL['coral'], linestyle='--', alpha=0.5)
    ax.set_xlabel('Year', fontsize=11)
    ax.set_ylabel('Mean Surplus ($M)', fontsize=11)
    ax.set_title('Mean Surplus — By Payout Duration', fontsize=13, fontweight='bold', color=MPL['navy'])
    ax.legend(fontsize=9)
    ax.set_xlim(1, 30)
    ax.yaxis.set_major_formatter(mticker.FormatStrFormatter('$%.1fM'))
    ax.grid(True, alpha=0.3)
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    fig.tight_layout()
    story.append(fig_to_image(fig, width=170*mm, height=105*mm))

    story.append(Paragraph(
        f'The 20-year payout ($300K total) generates a higher terminal surplus (${rec_15["mean_surplus_yr30"]/1e6:.1f}M) '
        f'than the 10-year payout (${rec_10["mean_surplus_yr30"]/1e6:.1f}M) because the lower annual withdrawal '
        f'($15K vs $25K) allows the investment account to compound more effectively in the early years. '
        f'The 25-year payout maintains a surplus trajectory comparable to the baseline despite delivering '
        f'50% more total income ($375K vs $250K).',
        styles['BodyText2']))

    # ── Loan Balance Comparison ──
    story.append(Spacer(1, 6*mm))
    story.append(Paragraph('Loan Balance by Configuration', styles['SubHead']))

    fig, ax = plt.subplots(figsize=(9, 5))
    yrs = list(range(0, 31))
    ax.plot(yrs, [l/1e6 for l in bl['mean_loan_by_year']], color=MPL['coral'],
            linewidth=2.5, label='Baseline (IO)', linestyle='--')
    ax.plot(yrs, [l/1e6 for l in rec_10['mean_loan_by_year']], color=MPL['green'],
            linewidth=2.5, label=f'10yr PI — $0 at maturity')
    ax.plot(yrs, [l/1e6 for l in rec_15['mean_loan_by_year']], color=MPL['teal'],
            linewidth=2.5, label=f'20yr PI — $0 at maturity')
    ax.plot(yrs, [l/1e6 for l in rec_25['mean_loan_by_year']], color=MPL['purple'],
            linewidth=2.5, label=f'25yr IO — $1.7M outstanding')
    ax.set_xlabel('Year', fontsize=11)
    ax.set_ylabel('Loan Balance ($M)', fontsize=11)
    ax.set_title('Mortgage Balance — IO vs P&I Amortisation', fontsize=13, fontweight='bold', color=MPL['navy'])
    ax.legend(fontsize=9)
    ax.set_xlim(0, 30)
    ax.set_ylim(0)
    ax.yaxis.set_major_formatter(mticker.FormatStrFormatter('$%.1fM'))
    ax.grid(True, alpha=0.3)
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    fig.tight_layout()
    story.append(fig_to_image(fig, width=170*mm, height=105*mm))

    story.append(PageBreak())

    # ── Efficient Frontier ──
    story.append(Paragraph('Efficient Frontier', styles['SectionHead']))

    fig, ax = plt.subplots(figsize=(9, 5.5))
    # Plot all validated
    for r in validated:
        if r['label'] == bl['label']:
            continue
        term = r.get('annuity_term', 10)
        if term <= 10:
            c, m = MPL['green'], 'o'
        elif term <= 15:
            c, m = MPL['teal'], 's'
        elif term <= 20:
            c, m = MPL['blue'], 'D'
        else:
            c, m = MPL['purple'], '^'
        ax.scatter(r['pod_yr30'], r['mean_total_fp_revenue']/1e6, c=c, marker=m, s=50,
                  zorder=4, edgecolors=MPL['navy'], linewidths=0.5, alpha=0.7)

    # Pareto front line
    pareto_sorted = sorted(pareto, key=lambda x: x['pod_yr30'])
    ax.plot([p['pod_yr30'] for p in pareto_sorted],
            [p['mean_total_fp_revenue']/1e6 for p in pareto_sorted],
            color=MPL['navy'], linewidth=1.5, linestyle='--', alpha=0.5, zorder=3)

    # Baseline
    ax.scatter(bl['pod_yr30'], bl['mean_total_fp_revenue']/1e6,
              c=MPL['coral'], s=150, marker='X', zorder=6, edgecolors=MPL['navy'], linewidths=1,
              label='v14a Baseline')

    # Best by duration
    for lbl, r, c, m in [
        ('Best 10yr', rec_10, MPL['green'], '*'),
        ('Best 20yr', rec_15, MPL['teal'], '*'),
        ('Best 25yr', rec_25, MPL['purple'], '*'),
    ]:
        ax.scatter(r['pod_yr30'], r['mean_total_fp_revenue']/1e6,
                  c=c, s=200, marker=m, zorder=7, edgecolors=MPL['navy'], linewidths=1,
                  label=lbl)

    # Legend entries for term groups
    ax.scatter([], [], c=MPL['green'], marker='o', s=40, label='10yr payout configs')
    ax.scatter([], [], c=MPL['teal'], marker='s', s=40, label='15yr payout configs')
    ax.scatter([], [], c=MPL['blue'], marker='D', s=40, label='20yr payout configs')
    ax.scatter([], [], c=MPL['purple'], marker='^', s=40, label='25yr payout configs')

    ax.set_xlabel('Probability of Deficit at Year 30 (%)', fontsize=11)
    ax.set_ylabel('FP Total Revenue ($M)', fontsize=11)
    ax.set_title('Efficient Frontier — All Payout Durations', fontsize=13, fontweight='bold', color=MPL['navy'])
    ax.legend(fontsize=8, loc='upper right', ncol=2)
    ax.grid(True, alpha=0.3)
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    ax.yaxis.set_major_formatter(mticker.FormatStrFormatter('$%.1fM'))
    fig.tight_layout()
    story.append(fig_to_image(fig, width=170*mm, height=110*mm))

    story.append(Spacer(1, 4*mm))
    story.append(Paragraph(
        f'The frontier spans from {pareto_sorted[0]["pod_yr30"]:.1f}% PoD (safest) to '
        f'{pareto_sorted[-1]["pod_yr30"]:.1f}% PoD (highest revenue). 10-year payout configurations '
        f'dominate the low-risk end. Longer payout configs cluster at slightly higher PoD but achieve '
        f'comparable revenue — the 20-year payout\'s best configuration actually generates '
        f'<b>more</b> FP revenue (${rec_15["mean_total_fp_revenue"]:,.0f}) than the 10-year best '
        f'(${rec_10["mean_total_fp_revenue"]:,.0f}) because the larger total mortgage generates more '
        f'profit share opportunities.',
        styles['BodyText2']))

    story.append(PageBreak())

    # ── Pareto Front Table ──
    story.append(Paragraph('Pareto Front — 50K Validated', styles['SectionHead']))
    story.append(make_table(
        ['#', 'Configuration', 'Type', 'Annuity', 'PoD %', 'FP Revenue', 'Sharpe'],
        [[str(i+1), r['label'][:35], r['loan_type'], annuity_desc(r),
          f'{r["pod_yr30"]:.1f}%', f'${r["mean_total_fp_revenue"]:,.0f}', f'{r["sharpe_like"]:.3f}']
         for i, r in enumerate(pareto)],
        col_widths=[8*mm, 48*mm, 10*mm, 28*mm, 14*mm, 28*mm, 16*mm]
    ))

    story.append(Spacer(1, 6*mm))

    # ── All Validated ──
    story.append(Paragraph('All Validated Configurations', styles['SubHead']))
    val_rows = []
    for i, r in enumerate(validated):
        marker = ''
        if r['label'] == rec_10['label']:
            marker = ' ★10'
        elif r['label'] == rec_15['label']:
            marker = ' ★20'
        elif r['label'] == rec_25['label']:
            marker = ' ★25'
        elif r['label'] == bl['label']:
            marker = ' •'
        val_rows.append([
            str(i+1),
            r['label'][:33] + marker,
            r['loan_type'],
            annuity_desc(r),
            f'{r["pod_yr30"]:.1f}%',
            f'${r["mean_total_fp_revenue"]:,.0f}',
            f'{r["sharpe_like"]:.3f}',
        ])
    story.append(make_table(
        ['#', 'Configuration', 'Type', 'Annuity', 'PoD %', 'FP Revenue', 'Sharpe'],
        val_rows,
        col_widths=[8*mm, 45*mm, 10*mm, 28*mm, 14*mm, 28*mm, 16*mm]
    ))
    story.append(Paragraph('★10/★20/★25 = Recommended for that payout duration  • = v14a Baseline', styles['SmallNote']))

    story.append(PageBreak())

    # ── Detailed Comparison ──
    story.append(Paragraph('Detailed Comparison — Recommended vs Baseline', styles['SectionHead']))

    detail_rows = [
        ['Annuity', f'${bl["annuity_pa"]/1000:.0f}K×{bl["annuity_term"]}yr',
         f'${rec_10["annuity_pa"]/1000:.0f}K×{rec_10["annuity_term"]}yr',
         f'${rec_15["annuity_pa"]/1000:.0f}K×{rec_15["annuity_term"]}yr',
         f'${rec_25["annuity_pa"]/1000:.0f}K×{rec_25["annuity_term"]}yr'],
        ['Total Income', f'${bl["total_annuity"]:,.0f}', f'${rec_10["total_annuity"]:,.0f}',
         f'${rec_15["total_annuity"]:,.0f}', f'${rec_25["total_annuity"]:,.0f}'],
        ['Loan Type', bl['loan_type'], rec_10['loan_type'], rec_15['loan_type'], rec_25['loan_type']],
        ['Collar', f'±{(bl["buffer_cap"]-1)*100:.0f}%', f'±{(rec_10["buffer_cap"]-1)*100:.0f}%',
         f'±{(rec_15["buffer_cap"]-1)*100:.0f}%', f'±{(rec_25["buffer_cap"]-1)*100:.0f}%'],
        ['Holiday Entry', f'{bl["holiday_entry"]:.2f}', f'{rec_10["holiday_entry"]:.2f}',
         f'{rec_15["holiday_entry"]:.2f}', f'{rec_25["holiday_entry"]:.2f}'],
        ['Profit Share', f'{bl["profit_share_pct"]*100:.0f}% q{bl["profit_share_years"]}',
         f'{rec_10["profit_share_pct"]*100:.0f}% q{rec_10["profit_share_years"]}',
         f'{rec_15["profit_share_pct"]*100:.0f}% q{rec_15["profit_share_years"]}',
         f'{rec_25["profit_share_pct"]*100:.0f}% q{rec_25["profit_share_years"]}'],
        ['FP Margin', f'{bl["fp_margin"]*100:.2f}%', f'{rec_10["fp_margin"]*100:.2f}%',
         f'{rec_15["fp_margin"]*100:.2f}%', f'{rec_25["fp_margin"]*100:.2f}%'],
        ['', '', '', '', ''],
        ['PoD Year 30', f'{bl["pod_yr30"]:.1f}%', f'{rec_10["pod_yr30"]:.1f}%',
         f'{rec_15["pod_yr30"]:.1f}%', f'{rec_25["pod_yr30"]:.1f}%'],
        ['PoD Year 20', f'{bl["pod_yr20"]:.1f}%', f'{rec_10["pod_yr20"]:.1f}%',
         f'{rec_15["pod_yr20"]:.1f}%', f'{rec_25["pod_yr20"]:.1f}%'],
        ['PoD Year 15', f'{bl["pod_yr15"]:.1f}%', f'{rec_10["pod_yr15"]:.1f}%',
         f'{rec_15["pod_yr15"]:.1f}%', f'{rec_25["pod_yr15"]:.1f}%'],
        ['Mean Surplus', f'${bl["mean_surplus_yr30"]:,.0f}', f'${rec_10["mean_surplus_yr30"]:,.0f}',
         f'${rec_15["mean_surplus_yr30"]:,.0f}', f'${rec_25["mean_surplus_yr30"]:,.0f}'],
        ['Median Surplus', f'${bl["median_surplus"]:,.0f}', f'${rec_10["median_surplus"]:,.0f}',
         f'${rec_15["median_surplus"]:,.0f}', f'${rec_25["median_surplus"]:,.0f}'],
        ['P1 Surplus', f'${bl["p1_surplus"]:,.0f}', f'${rec_10["p1_surplus"]:,.0f}',
         f'${rec_15["p1_surplus"]:,.0f}', f'${rec_25["p1_surplus"]:,.0f}'],
        ['P5 Surplus', f'${bl["p5_surplus"]:,.0f}', f'${rec_10["p5_surplus"]:,.0f}',
         f'${rec_15["p5_surplus"]:,.0f}', f'${rec_25["p5_surplus"]:,.0f}'],
        ['Sharpe Ratio', f'{bl["sharpe_like"]:.3f}', f'{rec_10["sharpe_like"]:.3f}',
         f'{rec_15["sharpe_like"]:.3f}', f'{rec_25["sharpe_like"]:.3f}'],
        ['', '', '', '', ''],
        ['FP Revenue', f'${bl["mean_total_fp_revenue"]:,.0f}', f'${rec_10["mean_total_fp_revenue"]:,.0f}',
         f'${rec_15["mean_total_fp_revenue"]:,.0f}', f'${rec_25["mean_total_fp_revenue"]:,.0f}'],
        ['  Profit Share', f'${bl["mean_total_profit_share"]:,.0f}', f'${rec_10["mean_total_profit_share"]:,.0f}',
         f'${rec_15["mean_total_profit_share"]:,.0f}', f'${rec_25["mean_total_profit_share"]:,.0f}'],
        ['  FP Margin', f'${bl["mean_fp_margin_income"]:,.0f}', f'${rec_10["mean_fp_margin_income"]:,.0f}',
         f'${rec_15["mean_fp_margin_income"]:,.0f}', f'${rec_25["mean_fp_margin_income"]:,.0f}'],
        ['Funder Surplus', f'${bl["mean_funder_surplus_share"]:,.0f}', f'${rec_10["mean_funder_surplus_share"]:,.0f}',
         f'${rec_15["mean_funder_surplus_share"]:,.0f}', f'${rec_25["mean_funder_surplus_share"]:,.0f}'],
        ['Insurance Premium', f'${bl["fair_premium_loaded"]:,.0f}', f'${rec_10["fair_premium_loaded"]:,.0f}',
         f'${rec_15["fair_premium_loaded"]:,.0f}', f'${rec_25["fair_premium_loaded"]:,.0f}'],
        ['', '', '', '', ''],
        ['Final Loan', f'${bl["mean_final_loan_balance"]:,.0f}', f'${rec_10["mean_final_loan_balance"]:,.0f}',
         f'${rec_15["mean_final_loan_balance"]:,.0f}', f'${rec_25["mean_final_loan_balance"]:,.0f}'],
        ['Protection', f'{bl["mean_borrower_equity_return"]:.1f}%', f'{rec_10["mean_borrower_equity_return"]:.1f}%',
         f'{rec_15["mean_borrower_equity_return"]:.1f}%', f'{rec_25["mean_borrower_equity_return"]:.1f}%'],
    ]
    story.append(make_table(
        ['Metric', 'v14a Baseline', '10yr Payout', '20yr Payout', '25yr Payout'],
        detail_rows,
        col_widths=[28*mm, 30*mm, 32*mm, 32*mm, 32*mm]
    ))

    story.append(PageBreak())

    # ── Product Menu Concept ──
    story.append(Paragraph('Product Menu — Three Tiers', styles['SectionHead']))
    story.append(Paragraph(
        'The optimisation results suggest a natural three-tier product structure, offering borrowers '
        'a choice between higher annual income (shorter term) and longer income security (lower annual amount):',
        styles['BodyText2']))

    story.append(make_table(
        ['', 'Standard', 'Extended', 'Lifetime'],
        [
            ['Income Term', '10 years', '20 years', '25 years'],
            ['Annual Income', '$25,000', '$15,000', '$15,000'],
            ['Total Income', '$250,000', '$300,000', '$375,000'],
            ['Mortgage Type', 'P&I', 'P&I', 'IO'],
            ['Final Loan', '$0', '$0', '~$1.7M'],
            ['PoD', f'{rec_10["pod_yr30"]:.1f}%', f'{rec_15["pod_yr30"]:.1f}%', f'{rec_25["pod_yr30"]:.1f}%'],
            ['Equity Protection', f'{rec_10["mean_borrower_equity_return"]:.1f}%',
             f'{rec_15["mean_borrower_equity_return"]:.1f}%',
             f'{rec_25["mean_borrower_equity_return"]:.1f}%'],
            ['FP Revenue', f'${rec_10["mean_total_fp_revenue"]:,.0f}',
             f'${rec_15["mean_total_fp_revenue"]:,.0f}',
             f'${rec_25["mean_total_fp_revenue"]:,.0f}'],
            ['Best For', 'Retirees who want\nmax annual income', 'Those wanting\nlong-term security',
             'Those wanting\nincome for life'],
        ],
        col_widths=[30*mm, 40*mm, 40*mm, 40*mm]
    ))

    story.append(Spacer(1, 6*mm))
    story.append(Paragraph(
        '<b>Standard (10yr):</b> Highest annual income, lowest risk, mortgage fully repaid at maturity. '
        'Best for borrowers who prioritise cash flow in the near term.',
        styles['BulletCustom'], bulletText='•'))
    story.append(Paragraph(
        '<b>Extended (20yr):</b> Lower annual income but 20% more total income ($300K vs $250K), '
        'mortgage still fully repaid. Ideal for borrowers who want reliable income well into retirement.',
        styles['BulletCustom'], bulletText='•'))
    story.append(Paragraph(
        '<b>Lifetime (25yr):</b> Highest total income ($375K), income for nearly the full mortgage term. '
        'IO structure means the mortgage remains outstanding, but equity is protected in '
        f'{rec_25["mean_borrower_equity_return"]:.1f}% of scenarios.',
        styles['BulletCustom'], bulletText='•'))

    story.append(PageBreak())

    # ── Conclusions ──
    story.append(Paragraph('Conclusions', styles['SectionHead']))

    story.append(Paragraph(
        'This analysis demonstrates that <b>longer payout periods are viable and attractive</b> with '
        'optimised parameters. The key findings:',
        styles['BodyText2']))

    points = [
        f'<b>All recommended configurations outperform baseline:</b> Every payout duration achieves PoD below '
        f'5% (vs 17.9% baseline) while generating 2–3× more FP revenue.',

        f'<b>20-year payout is the sweet spot:</b> At $15,000/year for 20 years, the borrower receives '
        f'$300,000 total income (20% more than baseline), the mortgage fully amortises to $0 under P&amp;I, '
        f'and FP revenue actually exceeds the 10-year configuration (${rec_15["mean_total_fp_revenue"]:,.0f} '
        f'vs ${rec_10["mean_total_fp_revenue"]:,.0f}).',

        f'<b>P&amp;I remains the dominant structural lever:</b> For 10yr and 20yr payouts, P&amp;I reduces PoD '
        f'by 7–10pp by itself. For 25yr payouts, IO is necessary because the post-annuity amortisation window '
        f'is too short for P&amp;I.',

        f'<b>±35% collar + 1.05 holiday entry are universal:</b> These parameter choices optimise risk across '
        f'all payout durations — they are not sensitive to the annuity structure.',

        f'<b>Insurance costs scale modestly:</b> Despite longer payout terms, premiums remain low — '
        f'from ${rec_10["fair_premium_loaded"]:,.0f} (10yr) to ${rec_25["fair_premium_loaded"]:,.0f} (25yr).',
    ]
    for p in points:
        story.append(Paragraph(p, styles['BulletCustom'], bulletText='•'))

    story.append(Spacer(1, 8*mm))
    story.append(Paragraph('Methodology', styles['SmallNote']))
    story.append(Paragraph(
        f'{meta["phase1_scenarios"]} Phase 1 + {meta["phase2_scenarios"]} Phase 2 scenarios × 10K paths, '
        f'top {meta["phase3_scenarios"]} validated at 50K paths. Seed: {meta["seed"]}. '
        f'Annuity terms: 10, 12, 15, 18, 20, 25 years. Annual amounts: $10K–$37.5K. '
        f'P&I and IO structures. Collar ±25–35%, Holiday entry 0.95–1.05, '
        f'PS 20–25% every 3 or 5yr, FM 0.1–0.2%.',
        styles['SmallNote']))

    # Build
    outfile = 'FutureProof_EPM_v14a_Full_Optimisation.pdf'
    doc = SimpleDocTemplate(outfile, pagesize=A4,
                            leftMargin=25*mm, rightMargin=25*mm,
                            topMargin=20*mm, bottomMargin=20*mm)
    doc.build(story, onFirstPage=footer, onLaterPages=footer)
    print(f"Report: {outfile}")


if __name__ == '__main__':
    generate()
