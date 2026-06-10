#!/usr/bin/env python3
"""
Generate Phase 2 Optimisation Report — Income Preserved
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
    'purple': '#8E44AD', 'blue': '#2980B9',
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
    canvas.drawString(25*mm, 12*mm, 'FutureProof | Phase 2 Optimisation — Income Preserved | March 2025')
    canvas.drawRightString(A4[0] - 25*mm, 12*mm, f'Page {doc.page}')
    canvas.restoreState()


def generate():
    with open('optimisation_v14a_phase2_results.json') as f:
        data = json.load(f)

    bl = data['baseline']
    rec = data['recommended']
    pareto = data['pareto_front_50k']
    validated = data['all_50k_validated']
    meta = data['metadata']

    styles = get_styles()
    story = []

    # ── Title Page ──
    story.append(Spacer(1, 60*mm))
    story.append(Paragraph('Futureproof', styles['ReportTitle']))
    story.append(Spacer(1, 15*mm))
    story.append(Paragraph('EPM v14a', styles['ReportTitle']))
    story.append(Spacer(1, 4*mm))
    story.append(Paragraph('Parameter Optimisation — Phase 2', styles['ReportTitle']))
    story.append(Spacer(1, 4*mm))
    story.append(Paragraph('Borrower Income Preserved at $250,000', styles['ReportSubtitle']))
    story.append(Paragraph('March 2025', styles['ReportSubtitle']))
    story.append(Spacer(1, 15*mm))
    story.append(Paragraph('CONFIDENTIAL — For Internal Use Only', styles['Confidential']))
    story.append(PageBreak())

    # ── Executive Summary ──
    story.append(Paragraph('Executive Summary', styles['SectionHead']))
    story.append(Paragraph(
        'This Phase 2 optimisation holds the borrower\'s income <b>fixed at $250,000</b> '
        '($25,000/year for 10 years) and optimises all other parameters: loan type (P&amp;I vs IO), '
        'collar width, holiday thresholds, profit share percentage and frequency, and FP margin. '
        f'A total of <b>{meta["phase1_scenarios"] + meta["phase2_scenarios"]} scenarios</b> were tested '
        f'with the top {meta["phase3_scenarios"]} validated at 50,000 Monte Carlo paths.',
        styles['BodyText2']))

    story.append(Paragraph(
        f'The recommended configuration reduces PoD from <b>{bl["pod_yr30"]:.1f}%</b> to '
        f'<b>{rec["pod_yr30"]:.1f}%</b> (−{bl["pod_yr30"] - rec["pod_yr30"]:.1f}pp) while increasing '
        f'FP revenue by <b>+{(rec["mean_total_fp_revenue"]/bl["mean_total_fp_revenue"] - 1)*100:.0f}%</b> '
        f'from ${bl["mean_total_fp_revenue"]:,.0f} to ${rec["mean_total_fp_revenue"]:,.0f}. '
        f'The borrower receives the same $250,000 annuity income, but under P&amp;I the mortgage '
        f'amortises to $0 at maturity (vs $1.6M outstanding under IO).',
        styles['BodyText2']))

    # Summary table
    story.append(Spacer(1, 3*mm))
    story.append(make_table(
        ['Metric', 'v14a Baseline', 'Recommended', 'Change'],
        [
            ['Borrower Income', '$250,000', '$250,000', 'UNCHANGED'],
            ['PoD Year 30', f'{bl["pod_yr30"]:.1f}%', f'{rec["pod_yr30"]:.1f}%',
             f'{rec["pod_yr30"] - bl["pod_yr30"]:+.1f}pp'],
            ['Mean Surplus', f'${bl["mean_surplus_yr30"]:,.0f}', f'${rec["mean_surplus_yr30"]:,.0f}',
             f'+{(rec["mean_surplus_yr30"]/bl["mean_surplus_yr30"] - 1)*100:.0f}%'],
            ['FP Revenue', f'${bl["mean_total_fp_revenue"]:,.0f}', f'${rec["mean_total_fp_revenue"]:,.0f}',
             f'+{(rec["mean_total_fp_revenue"]/bl["mean_total_fp_revenue"] - 1)*100:.0f}%'],
            ['Sharpe Ratio', f'{bl["sharpe_like"]:.3f}', f'{rec["sharpe_like"]:.3f}',
             f'+{(rec["sharpe_like"]/bl["sharpe_like"] - 1)*100:.0f}%'],
            ['Insurance Premium', f'${bl["fair_premium_loaded"]:,.0f}', f'${rec["fair_premium_loaded"]:,.0f}',
             f'{(rec["fair_premium_loaded"]/bl["fair_premium_loaded"] - 1)*100:+.0f}%'],
            ['Equity Protection', f'{bl["mean_borrower_equity_return"]:.1f}%',
             f'{rec["mean_borrower_equity_return"]:.1f}%',
             f'+{rec["mean_borrower_equity_return"] - bl["mean_borrower_equity_return"]:.1f}pp'],
            ['Final Loan Balance', f'${bl["mean_final_loan_balance"]:,.0f}',
             f'${rec["mean_final_loan_balance"]:,.0f}', 'Fully amortised'],
        ],
        col_widths=[42*mm, 38*mm, 38*mm, 32*mm]
    ))

    story.append(PageBreak())

    # ── Recommended Configuration ──
    story.append(Paragraph('Recommended Configuration', styles['SectionHead']))
    story.append(make_table(
        ['Parameter', 'v14a Baseline', 'Recommended', 'Rationale'],
        [
            ['Loan Type', bl['loan_type'], rec['loan_type'],
             'Amortises to $0, eliminates tail risk'],
            ['Collar Width', f'±{(bl["buffer_cap"]-1)*100:.0f}%', f'±{(rec["buffer_cap"]-1)*100:.0f}%',
             'Captures more equity upside'],
            ['Holiday Entry', f'{bl["holiday_entry"]:.2f}', f'{rec["holiday_entry"]:.2f}',
             'More aggressive capital preservation'],
            ['Profit Share', f'{bl["profit_share_pct"]*100:.0f}% every {bl["profit_share_years"]}yr',
             f'{rec["profit_share_pct"]*100:.0f}% every {rec["profit_share_years"]}yr',
             'More frequent extraction, higher revenue'],
            ['FP Margin', f'{bl["fp_margin"]*100:.2f}%', f'{rec["fp_margin"]*100:.2f}%',
             'Lower margin, better risk metrics'],
            ['Annuity', '$25K/yr × 10yr', '$25K/yr × 10yr', 'UNCHANGED'],
        ],
        col_widths=[30*mm, 35*mm, 35*mm, 55*mm]
    ))

    story.append(Spacer(1, 6*mm))
    story.append(Paragraph(
        '<b>Key changes from v14a baseline:</b> Three structural changes (P&amp;I, wider collar, '
        'higher holiday entry) plus two tuning changes (3-year PS frequency, lower FP margin). '
        'These work synergistically — P&amp;I reduces the loan balance over time, making the wider collar '
        'and tighter holidays even more effective at preventing deficits.',
        styles['BodyText2']))

    # ── PoD Trajectory ──
    story.append(Spacer(1, 4*mm))
    story.append(Paragraph('Risk Trajectory', styles['SubHead']))

    fig, ax = plt.subplots(figsize=(8, 4.5))
    years = list(range(1, 31))
    ax.plot(years, bl['pod_by_year'], color=MPL['coral'], linewidth=2.5, label='v14a Baseline (IO)')
    ax.plot(years, rec['pod_by_year'], color=MPL['green'], linewidth=2.5, label=f'Recommended (PI)')
    ax.axhline(y=5, color=MPL['grey'], linestyle=':', alpha=0.7, label='5% target')
    ax.set_xlabel('Year', fontsize=11)
    ax.set_ylabel('Deficit Probability (%)', fontsize=11)
    ax.set_title('PoD Over Time — Income Preserved at $250,000', fontsize=13, fontweight='bold', color=MPL['navy'])
    ax.legend(fontsize=9)
    ax.set_xlim(1, 30)
    ax.set_ylim(0, max(bl['pod_by_year']) * 1.05)
    ax.grid(True, alpha=0.3)
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    fig.tight_layout()
    story.append(fig_to_image(fig, width=165*mm, height=100*mm))

    story.append(PageBreak())

    # ── Surplus Trajectory ──
    story.append(Paragraph('Surplus Trajectory', styles['SubHead']))

    fig, ax = plt.subplots(figsize=(8, 4.5))
    ax.plot(years, [s/1e6 for s in bl['mean_surplus_by_year']], color=MPL['coral'], linewidth=2.5, label='v14a Baseline')
    ax.plot(years, [s/1e6 for s in rec['mean_surplus_by_year']], color=MPL['green'], linewidth=2.5, label='Recommended')
    ax.axhline(y=0, color=MPL['coral'], linestyle='--', alpha=0.5)
    ax.set_xlabel('Year', fontsize=11)
    ax.set_ylabel('Mean Surplus ($M)', fontsize=11)
    ax.set_title('Mean Surplus — Income Preserved at $250,000', fontsize=13, fontweight='bold', color=MPL['navy'])
    ax.legend(fontsize=9)
    ax.set_xlim(1, 30)
    ax.yaxis.set_major_formatter(mticker.FormatStrFormatter('$%.1fM'))
    ax.grid(True, alpha=0.3)
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    fig.tight_layout()
    story.append(fig_to_image(fig, width=165*mm, height=100*mm))

    # ── Loan Balance ──
    story.append(Spacer(1, 6*mm))
    story.append(Paragraph('Loan Balance: IO vs P&I', styles['SubHead']))

    fig, ax = plt.subplots(figsize=(8, 4.5))
    yrs = list(range(0, 31))
    ax.plot(yrs, [l/1e6 for l in bl['mean_loan_by_year']], color=MPL['coral'], linewidth=2.5, label='Baseline (IO)')
    ax.plot(yrs, [l/1e6 for l in rec['mean_loan_by_year']], color=MPL['green'], linewidth=2.5, label='Recommended (PI)')
    ax.set_xlabel('Year', fontsize=11)
    ax.set_ylabel('Loan Balance ($M)', fontsize=11)
    ax.set_title('Loan Balance — Same $250K Income, Different Amortisation', fontsize=13, fontweight='bold', color=MPL['navy'])
    ax.legend(fontsize=9)
    ax.set_xlim(0, 30)
    ax.set_ylim(0, 1.8)
    ax.yaxis.set_major_formatter(mticker.FormatStrFormatter('$%.1fM'))
    ax.grid(True, alpha=0.3)
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    fig.tight_layout()
    story.append(fig_to_image(fig, width=165*mm, height=100*mm))

    story.append(Paragraph(
        'Both configurations provide the same $250,000 annuity income over 10 years. '
        'Under IO, the $1.6M loan remains outstanding at maturity. Under P&amp;I, the loan amortises '
        'to zero over the remaining 20 years. This fundamental structural change means the investment account '
        'must fund ~$80,000/year in principal repayments after year 10, but the declining loan balance '
        'dramatically reduces interest costs and deficit probability.',
        styles['BodyText2']))

    story.append(PageBreak())

    # ── Efficient Frontier ──
    story.append(Paragraph('Efficient Frontier', styles['SectionHead']))

    fig, ax = plt.subplots(figsize=(9, 5.5))
    pods = [r['pod_yr30'] for r in pareto]
    revs = [r['mean_total_fp_revenue']/1e6 for r in pareto]
    labels = [r['label'] for r in pareto]
    pi_mask = ['PI' in r['loan_type'] for r in pareto]

    for i, (pod, rev, lbl, is_pi) in enumerate(zip(pods, revs, labels, pi_mask)):
        c = MPL['green'] if is_pi else MPL['teal']
        ax.scatter(pod, rev, c=c, s=80, zorder=5, edgecolors=MPL['navy'], linewidths=0.5)
        if i < 7:
            short = lbl[:30]
            ax.annotate(short, (pod, rev), textcoords="offset points",
                       xytext=(8, 5), fontsize=7, color=MPL['navy'])

    ax.scatter(bl['pod_yr30'], bl['mean_total_fp_revenue']/1e6,
              c=MPL['coral'], s=150, marker='s', zorder=6, edgecolors=MPL['navy'], linewidths=1,
              label='v14a Baseline')
    ax.scatter(rec['pod_yr30'], rec['mean_total_fp_revenue']/1e6,
              c=MPL['green'], s=200, marker='*', zorder=7, edgecolors=MPL['navy'], linewidths=1,
              label='Recommended')
    ax.scatter([], [], c=MPL['green'], s=60, label='P&I configurations')
    ax.scatter([], [], c=MPL['teal'], s=60, label='IO configurations')

    ax.set_xlabel('Probability of Deficit at Year 30 (%)', fontsize=11)
    ax.set_ylabel('FP Total Revenue ($M)', fontsize=11)
    ax.set_title('Efficient Frontier — Income Preserved', fontsize=13, fontweight='bold', color=MPL['navy'])
    ax.legend(fontsize=9, loc='upper right')
    ax.grid(True, alpha=0.3)
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    ax.yaxis.set_major_formatter(mticker.FormatStrFormatter('$%.1fM'))
    fig.tight_layout()
    story.append(fig_to_image(fig, width=170*mm, height=105*mm))

    story.append(Spacer(1, 4*mm))
    story.append(Paragraph(
        f'The Pareto front contains {len(pareto)} non-dominated scenarios. '
        f'All P&amp;I configurations dominate their IO equivalents — for any IO scenario on the front, '
        f'there exists a P&amp;I scenario with both lower PoD and comparable revenue. '
        f'The front spans from {pareto[0]["pod_yr30"]:.1f}% PoD (safest, PI) to '
        f'{pareto[-1]["pod_yr30"]:.1f}% (highest revenue, IO).',
        styles['BodyText2']))

    story.append(make_table(
        ['#', 'Configuration', 'Type', 'PoD %', 'FP Revenue', 'Sharpe'],
        [[str(i+1), r['label'][:40], r['loan_type'], f'{r["pod_yr30"]:.1f}%',
          f'${r["mean_total_fp_revenue"]:,.0f}', f'{r["sharpe_like"]:.3f}']
         for i, r in enumerate(pareto)],
        col_widths=[8*mm, 60*mm, 12*mm, 15*mm, 30*mm, 18*mm]
    ))

    story.append(PageBreak())

    # ── All Validated ──
    story.append(Paragraph('All Validated Configurations', styles['SectionHead']))
    story.append(Paragraph(
        f'Top {min(len(validated), 22)} configurations ranked by composite score:',
        styles['BodyText2']))

    val_rows = []
    for i, r in enumerate(validated):
        marker = ' ★' if r['label'] == rec['label'] else ''
        marker = marker or (' •' if 'BASELINE' in r['label'] else '')
        val_rows.append([
            str(i+1),
            r['label'][:38] + marker,
            r['loan_type'],
            f'{r["pod_yr30"]:.1f}%',
            f'${r["mean_total_fp_revenue"]:,.0f}',
            f'{r["sharpe_like"]:.3f}',
            f'${r["mean_surplus_yr30"]:,.0f}',
        ])
    story.append(make_table(
        ['#', 'Configuration', 'Type', 'PoD %', 'FP Revenue', 'Sharpe', 'Mean Surplus'],
        val_rows,
        col_widths=[8*mm, 55*mm, 12*mm, 15*mm, 28*mm, 16*mm, 30*mm]
    ))
    story.append(Paragraph('★ = Recommended  • = v14a Baseline', styles['SmallNote']))

    story.append(PageBreak())

    # ── Detailed Comparison ──
    story.append(Paragraph('Detailed Comparison', styles['SectionHead']))
    story.append(make_table(
        ['Metric', 'v14a Baseline', 'Recommended'],
        [
            ['Loan Type', bl['loan_type'], rec['loan_type']],
            ['Collar', f'±{(bl["buffer_cap"]-1)*100:.0f}%', f'±{(rec["buffer_cap"]-1)*100:.0f}%'],
            ['Holiday Entry', f'{bl["holiday_entry"]:.2f}', f'{rec["holiday_entry"]:.2f}'],
            ['Profit Share', f'{bl["profit_share_pct"]*100:.0f}% q{bl["profit_share_years"]}',
             f'{rec["profit_share_pct"]*100:.0f}% q{rec["profit_share_years"]}'],
            ['FP Margin', f'{bl["fp_margin"]*100:.2f}%', f'{rec["fp_margin"]*100:.2f}%'],
            ['', '', ''],
            ['PoD Year 30', f'{bl["pod_yr30"]:.1f}%', f'{rec["pod_yr30"]:.1f}%'],
            ['PoD Year 20', f'{bl["pod_yr20"]:.1f}%', f'{rec["pod_yr20"]:.1f}%'],
            ['PoD Year 15', f'{bl["pod_yr15"]:.1f}%', f'{rec["pod_yr15"]:.1f}%'],
            ['PoD Year 10', f'{bl["pod_yr10"]:.1f}%', f'{rec["pod_yr10"]:.1f}%'],
            ['Mean Surplus', f'${bl["mean_surplus_yr30"]:,.0f}', f'${rec["mean_surplus_yr30"]:,.0f}'],
            ['Median Surplus', f'${bl["median_surplus"]:,.0f}', f'${rec["median_surplus"]:,.0f}'],
            ['P1 Surplus', f'${bl["p1_surplus"]:,.0f}', f'${rec["p1_surplus"]:,.0f}'],
            ['P5 Surplus', f'${bl["p5_surplus"]:,.0f}', f'${rec["p5_surplus"]:,.0f}'],
            ['P10 Surplus', f'${bl["p10_surplus"]:,.0f}', f'${rec["p10_surplus"]:,.0f}'],
            ['P25 Surplus', f'${bl["p25_surplus"]:,.0f}', f'${rec["p25_surplus"]:,.0f}'],
            ['P75 Surplus', f'${bl["p75_surplus"]:,.0f}', f'${rec["p75_surplus"]:,.0f}'],
            ['P90 Surplus', f'${bl["p90_surplus"]:,.0f}', f'${rec["p90_surplus"]:,.0f}'],
            ['Std Deviation', f'${bl["std_surplus"]:,.0f}', f'${rec["std_surplus"]:,.0f}'],
            ['Sharpe Ratio', f'{bl["sharpe_like"]:.3f}', f'{rec["sharpe_like"]:.3f}'],
            ['', '', ''],
            ['FP Revenue', f'${bl["mean_total_fp_revenue"]:,.0f}', f'${rec["mean_total_fp_revenue"]:,.0f}'],
            ['  Profit Share', f'${bl["mean_total_profit_share"]:,.0f}', f'${rec["mean_total_profit_share"]:,.0f}'],
            ['  FP Margin', f'${bl["mean_fp_margin_income"]:,.0f}', f'${rec["mean_fp_margin_income"]:,.0f}'],
            ['Funder Surplus', f'${bl["mean_funder_surplus_share"]:,.0f}', f'${rec["mean_funder_surplus_share"]:,.0f}'],
            ['Insurance Premium', f'${bl["fair_premium_loaded"]:,.0f}', f'${rec["fair_premium_loaded"]:,.0f}'],
            ['Cond. Exp. Deficit', f'${bl["cond_expected_deficit"]:,.0f}', f'${rec["cond_expected_deficit"]:,.0f}'],
            ['', '', ''],
            ['Final Loan Balance', f'${bl["mean_final_loan_balance"]:,.0f}', f'${rec["mean_final_loan_balance"]:,.0f}'],
            ['Borrower Protection', f'{bl["mean_borrower_equity_return"]:.1f}%',
             f'{rec["mean_borrower_equity_return"]:.1f}%'],
        ],
        col_widths=[50*mm, 50*mm, 50*mm]
    ))

    story.append(PageBreak())

    # ── Conclusions ──
    story.append(Paragraph('Conclusions', styles['SectionHead']))

    story.append(Paragraph(
        'With borrower income held constant at $250,000, the optimisation identifies a configuration '
        'that dramatically improves all risk and revenue metrics:',
        styles['BodyText2']))

    points = [
        f'<b>PoD reduction:</b> From {bl["pod_yr30"]:.1f}% to {rec["pod_yr30"]:.1f}% '
        f'(−{bl["pod_yr30"] - rec["pod_yr30"]:.1f}pp). The borrower\'s equity is protected in '
        f'{rec["mean_borrower_equity_return"]:.1f}% of scenarios vs {bl["mean_borrower_equity_return"]:.1f}%.',

        f'<b>Revenue increase:</b> FP total revenue rises from ${bl["mean_total_fp_revenue"]:,.0f} to '
        f'${rec["mean_total_fp_revenue"]:,.0f} (+{(rec["mean_total_fp_revenue"]/bl["mean_total_fp_revenue"] - 1)*100:.0f}%). '
        f'The 3-year profit share frequency generates more cumulative profit share '
        f'(${rec["mean_total_profit_share"]:,.0f} vs ${bl["mean_total_profit_share"]:,.0f}).',

        f'<b>Insurance premium:</b> Drops {(1 - rec["fair_premium_loaded"]/bl["fair_premium_loaded"])*100:.0f}% '
        f'from ${bl["fair_premium_loaded"]:,.0f} to ${rec["fair_premium_loaded"]:,.0f}, '
        f'making the product dramatically cheaper to insure.',

        f'<b>Loan amortisation:</b> Under P&amp;I, the mortgage fully amortises to $0 at maturity. '
        f'The borrower receives the same $250,000 income but owns their home outright at the end of the term, '
        f'vs $1.6M outstanding under IO.',

        f'<b>Funder benefit:</b> Funder surplus share increases from ${bl["mean_funder_surplus_share"]:,.0f} to '
        f'${rec["mean_funder_surplus_share"]:,.0f} (+{(rec["mean_funder_surplus_share"]/bl["mean_funder_surplus_share"] - 1)*100:.0f}%), '
        f'making the product more attractive to wholesale funders.',
    ]
    for p in points:
        story.append(Paragraph(p, styles['BulletCustom'], bulletText='•'))

    story.append(Spacer(1, 6*mm))
    story.append(Paragraph('Implementation', styles['SubHead']))
    story.append(make_table(
        ['#', 'Change', 'Impact', 'Notes'],
        [
            ['1', 'Switch to P&I', '−7.4pp PoD', 'Structural — amortises to $0'],
            ['2', 'Collar ±35%', '−8.5pp PoD', 'Near-zero collar cost'],
            ['3', 'Holiday entry 1.05', '−9.7pp PoD', 'Parameter change only'],
            ['4', 'PS 25% every 3yr', '+$183K FP rev', 'More frequent cash flow'],
            ['5', 'FP margin 0.15%', '−1.1pp PoD', 'Lower recurring fee'],
        ],
        col_widths=[8*mm, 40*mm, 30*mm, 60*mm]
    ))

    story.append(Spacer(1, 8*mm))
    story.append(Paragraph('Methodology', styles['SmallNote']))
    story.append(Paragraph(
        f'{meta["phase1_scenarios"]} + {meta["phase2_scenarios"]} scenarios × 10K paths, '
        f'top {meta["phase3_scenarios"]} validated at 50K paths. Seed: {meta["seed"]}. '
        f'Constraint: annuity fixed at $25,000/yr × 10yr = $250,000.',
        styles['SmallNote']))

    # Build
    outfile = 'FutureProof_EPM_v14a_Phase2_Optimisation.pdf'
    doc = SimpleDocTemplate(outfile, pagesize=A4,
                            leftMargin=25*mm, rightMargin=25*mm,
                            topMargin=20*mm, bottomMargin=20*mm)
    doc.build(story, onFirstPage=footer, onLaterPages=footer)
    print(f"Report: {outfile}")


if __name__ == '__main__':
    generate()
