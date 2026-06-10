#!/usr/bin/env python3
"""
Generate Constrained Optimisation Report
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
    canvas.drawString(25*mm, 12*mm, 'FutureProof | Constrained Optimisation Report | March 2025')
    canvas.drawRightString(A4[0] - 25*mm, 12*mm, f'Page {doc.page}')
    canvas.restoreState()


def generate():
    with open('optimisation_v14a_constrained_results.json') as f:
        data = json.load(f)

    bl = data['baseline']
    rec_re = data['recommended_reinsurance']
    rec_lmi = data['recommended_lmi']
    t1 = data['tier1_reinsurance_50k']
    t2 = data['tier2_lmi_50k']
    pareto_t1 = data['pareto_reinsurance_50k']
    pareto_t2 = data['pareto_lmi_50k']
    meta = data['metadata']
    constraints = meta['constraints']
    best_dur = data['best_by_duration']

    styles = get_styles()
    story = []

    # ── Title Page ──
    story.append(Spacer(1, 60*mm))
    story.append(Paragraph('Futureproof', styles['ReportTitle']))
    story.append(Spacer(1, 15*mm))
    story.append(Paragraph('EPM v14a', styles['ReportTitle']))
    story.append(Spacer(1, 4*mm))
    story.append(Paragraph('Constrained Parameter Optimisation', styles['ReportTitle']))
    story.append(Spacer(1, 4*mm))
    story.append(Paragraph('Annuity Rate &amp; Probability of Claim Constraints', styles['ReportSubtitle']))
    story.append(Paragraph('March 2025', styles['ReportSubtitle']))
    story.append(Spacer(1, 15*mm))
    story.append(Paragraph('CONFIDENTIAL — For Internal Use Only', styles['Confidential']))
    story.append(PageBreak())

    # ── Executive Summary ──
    story.append(Paragraph('Executive Summary', styles['SectionHead']))
    story.append(Paragraph(
        'This report optimises all EPM v14a parameters subject to two hard constraints that reflect '
        'real-world product design requirements:',
        styles['BodyText2']))

    story.append(make_table(
        ['Constraint', 'Requirement', 'Rationale'],
        [
            ['Annuity Rate (P&I)', f'{constraints["pi_annuity_range"]} of property value p.a.',
             'Minimum income to be attractive to borrowers'],
            ['Annuity Rate (IO)', f'{constraints["io_annuity_range"]} of property value p.a.',
             'Higher rate for IO (no principal repayment benefit)'],
            ['PoC — Reinsurance', f'≤ {constraints["poc_reinsurance"]:.0f}%',
             'Portfolio-level reinsurance pricing threshold'],
            ['PoC — Individual LMI', f'≤ {constraints["poc_lmi"]:.0f}%',
             'Individual mortgage insurance pricing threshold'],
        ],
        col_widths=[35*mm, 42*mm, 75*mm]
    ))

    total_scenarios = meta['phase1_scenarios'] + meta['phase2_scenarios']
    story.append(Spacer(1, 3*mm))
    story.append(Paragraph(
        f'A total of <b>{total_scenarios:,} scenarios</b> were screened at 10,000 Monte Carlo paths, '
        f'with {meta["phase3_scenarios"]} validated at 50,000 paths. Of the validated configurations, '
        f'<b>{meta["tier1_count_50k"]} met the reinsurance threshold</b> (PoC ≤ 5%) and '
        f'<b>{meta["tier2_count_50k"]} met the LMI threshold</b> (PoC ≤ 12%).',
        styles['BodyText2']))

    story.append(Spacer(1, 3*mm))
    story.append(Paragraph('Key Findings', styles['SubHead']))

    # Best configs summary
    story.append(make_table(
        ['Metric', 'v14a Baseline', 'Reinsurance Grade', 'LMI Grade'],
        [
            ['Annuity Rate', f'{bl["annuity_pct"]:.2f}%', f'{rec_re["annuity_pct"]:.2f}%',
             f'{rec_lmi["annuity_pct"]:.2f}%'],
            ['Payout', f'${bl["annuity_pa"]/1000:.0f}K×{bl["annuity_term"]}yr',
             f'${rec_re["annuity_pa"]/1000:.0f}K×{rec_re["annuity_term"]}yr',
             f'${rec_lmi["annuity_pa"]/1000:.0f}K×{rec_lmi["annuity_term"]}yr'],
            ['Total Income', f'${bl["total_annuity"]:,.0f}', f'${rec_re["total_annuity"]:,.0f}',
             f'${rec_lmi["total_annuity"]:,.0f}'],
            ['Loan Type', bl['loan_type'], rec_re['loan_type'], rec_lmi['loan_type']],
            ['PoC Year 30', f'{bl["pod_yr30"]:.1f}%', f'{rec_re["pod_yr30"]:.1f}%',
             f'{rec_lmi["pod_yr30"]:.1f}%'],
            ['FP Revenue', f'${bl["mean_total_fp_revenue"]:,.0f}',
             f'${rec_re["mean_total_fp_revenue"]:,.0f}',
             f'${rec_lmi["mean_total_fp_revenue"]:,.0f}'],
            ['Mean Surplus', f'${bl["mean_surplus_yr30"]:,.0f}',
             f'${rec_re["mean_surplus_yr30"]:,.0f}',
             f'${rec_lmi["mean_surplus_yr30"]:,.0f}'],
            ['Protection', f'{bl["mean_borrower_equity_return"]:.1f}%',
             f'{rec_re["mean_borrower_equity_return"]:.1f}%',
             f'{rec_lmi["mean_borrower_equity_return"]:.1f}%'],
            ['Premium', f'${bl["fair_premium_loaded"]:,.0f}',
             f'${rec_re["fair_premium_loaded"]:,.0f}',
             f'${rec_lmi["fair_premium_loaded"]:,.0f}'],
        ],
        col_widths=[28*mm, 38*mm, 38*mm, 38*mm]
    ))

    story.append(Spacer(1, 4*mm))
    story.append(Paragraph(
        f'Both the reinsurance and LMI recommendations converge on the same optimal configuration: '
        f'<b>P&amp;I at 1.25%, ±35% collar, holiday entry 1.05, 25% profit share every 3 years, '
        f'0.15% FP margin</b>. This configuration reduces PoC from {bl["pod_yr30"]:.1f}% to '
        f'{rec_re["pod_yr30"]:.1f}% while increasing FP revenue by '
        f'+{(rec_re["mean_total_fp_revenue"]/bl["mean_total_fp_revenue"] - 1)*100:.0f}%.',
        styles['BodyText2']))

    story.append(PageBreak())

    # ── Constraint Satisfaction ──
    story.append(Paragraph('Constraint Satisfaction by Payout Duration', styles['SectionHead']))
    story.append(Paragraph(
        'The annuity rate constraint ensures borrowers receive meaningful income — at least 1.25% of property '
        'value per annum for P&amp;I mortgages, or 1.50% for IO mortgages. The key question is: how long can '
        'the payout term be extended while keeping PoC within bounds?',
        styles['BodyText2']))

    # Duration feasibility table
    dur_rows = []
    for min_term in [10, 15, 20, 25]:
        re_cfg = best_dur.get('reinsurance', {}).get(f'min_{min_term}yr')
        lmi_cfg = best_dur.get('lmi', {}).get(f'min_{min_term}yr')
        re_text = f'{re_cfg["pod_yr30"]:.1f}% ✓' if re_cfg else 'No feasible config'
        lmi_text = f'{lmi_cfg["pod_yr30"]:.1f}% ✓' if lmi_cfg else 'No feasible config'
        total_re = f'${re_cfg["total_annuity"]:,.0f}' if re_cfg else '—'
        total_lmi = f'${lmi_cfg["total_annuity"]:,.0f}' if lmi_cfg else '—'
        dur_rows.append([f'≥{min_term} years', total_re, re_text, total_lmi, lmi_text])

    story.append(make_table(
        ['Payout Term', 'Total (RE)', 'PoC (RE ≤5%)', 'Total (LMI)', 'PoC (LMI ≤12%)'],
        dur_rows,
        col_widths=[28*mm, 28*mm, 30*mm, 28*mm, 32*mm]
    ))

    story.append(Spacer(1, 4*mm))

    # Get the longer-term configs for discussion
    lmi_15 = best_dur.get('lmi', {}).get('min_15yr')
    lmi_20 = best_dur.get('lmi', {}).get('min_20yr')
    lmi_25 = best_dur.get('lmi', {}).get('min_25yr')
    re_15 = best_dur.get('reinsurance', {}).get('min_15yr')

    story.append(Paragraph(
        '<b>Reinsurance grade (PoC ≤ 5%):</b> Feasible for up to 15-year payouts. At 1.25% '
        f'(${rec_re["annuity_pa"]:,.0f}/yr), a 15-year payout delivers ${re_15["total_annuity"]:,.0f} total '
        f'income with PoC of {re_15["pod_yr30"]:.1f}%. '
        'Beyond 15 years, no configuration meets the 5% threshold.'
        if re_15 else
        '<b>Reinsurance grade (PoC ≤ 5%):</b> Only feasible for 10-year payouts.',
        styles['BodyText2']))

    if lmi_25:
        story.append(Paragraph(
            f'<b>LMI grade (PoC ≤ 12%):</b> Feasible for all payout terms up to 25 years. '
            f'At 1.25% ($25,000/yr), a 25-year payout delivers ${lmi_25["total_annuity"]:,.0f} total income '
            f'with PoC of {lmi_25["pod_yr30"]:.1f}%. A 20-year payout achieves '
            f'${lmi_20["total_annuity"]:,.0f} at PoC {lmi_20["pod_yr30"]:.1f}%.',
            styles['BodyText2']))

    story.append(PageBreak())

    # ── Recommended Configuration ──
    story.append(Paragraph('Recommended Configuration', styles['SectionHead']))
    story.append(make_table(
        ['Parameter', 'v14a Baseline', 'Recommended', 'Rationale'],
        [
            ['Annuity Rate', f'{bl["annuity_pct"]:.2f}%', f'{rec_re["annuity_pct"]:.2f}%',
             'Floor of P&I range — maximises headroom'],
            ['Loan Type', bl['loan_type'], rec_re['loan_type'],
             'Amortises to $0, eliminates tail risk'],
            ['Collar Width', f'±{(bl["buffer_cap"]-1)*100:.0f}%', f'±{(rec_re["buffer_cap"]-1)*100:.0f}%',
             'Captures more equity upside'],
            ['Holiday Entry', f'{bl["holiday_entry"]:.2f}', f'{rec_re["holiday_entry"]:.2f}',
             'More aggressive capital preservation'],
            ['Profit Share', f'{bl["profit_share_pct"]*100:.0f}% q{bl["profit_share_years"]}',
             f'{rec_re["profit_share_pct"]*100:.0f}% q{rec_re["profit_share_years"]}',
             'More frequent extraction'],
            ['FP Margin', f'{bl["fp_margin"]*100:.2f}%', f'{rec_re["fp_margin"]*100:.2f}%',
             'Lower margin improves risk metrics'],
        ],
        col_widths=[28*mm, 32*mm, 32*mm, 58*mm]
    ))

    story.append(Spacer(1, 4*mm))
    story.append(Paragraph(
        'The annuity rate sits at the floor of the P&amp;I range (1.25%). This is deliberate — the optimizer '
        'cannot reduce it below 1.25%, ensuring the borrower receives meaningful income. The annuity rate is '
        'the <b>binding constraint</b>; all other parameters are free to adjust within their natural ranges.',
        styles['BodyText2']))

    # ── PoC Trajectory ──
    story.append(Spacer(1, 4*mm))
    story.append(Paragraph('PoC Trajectory', styles['SubHead']))

    fig, ax = plt.subplots(figsize=(9, 5))
    years = list(range(1, 31))
    ax.plot(years, bl['pod_by_year'], color=MPL['coral'], linewidth=2.5,
            label=f'Baseline (IO, 1.25%, 10yr)', linestyle='--')
    ax.plot(years, rec_re['pod_by_year'], color=MPL['green'], linewidth=2.5,
            label=f'Best 10yr (PI, 1.25%)')

    # Add longer payout configs if available
    if re_15:
        ax.plot(years, re_15['pod_by_year'], color=MPL['teal'], linewidth=2.5,
                label=f'Best 15yr (PI, 1.25%)')
    if lmi_20:
        ax.plot(years, lmi_20['pod_by_year'], color=MPL['blue'], linewidth=2,
                label=f'Best 20yr (PI, 1.25%)')
    if lmi_25:
        ax.plot(years, lmi_25['pod_by_year'], color=MPL['purple'], linewidth=2,
                label=f'Best 25yr (PI, 1.25%)')

    ax.axhline(y=5, color=MPL['green'], linestyle=':', alpha=0.7, label='5% reinsurance')
    ax.axhline(y=12, color=MPL['orange'], linestyle=':', alpha=0.7, label='12% LMI')
    ax.set_xlabel('Year', fontsize=11)
    ax.set_ylabel('Probability of Claim (%)', fontsize=11)
    ax.set_title('PoC Over Time — Constrained Annuity Rate', fontsize=13, fontweight='bold', color=MPL['navy'])
    ax.legend(fontsize=8, loc='upper right')
    ax.set_xlim(1, 30)
    ax.set_ylim(0, max(bl['pod_by_year']) * 1.05)
    ax.grid(True, alpha=0.3)
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    fig.tight_layout()
    story.append(fig_to_image(fig, width=170*mm, height=105*mm))

    story.append(Paragraph(
        f'The optimised 10-year payout (green) stays well below the 5% reinsurance threshold throughout. '
        f'The 15-year payout sits just below 5% at maturity. The 20 and 25-year payouts exceed the reinsurance '
        f'threshold but remain within LMI bounds.',
        styles['BodyText2']))

    story.append(PageBreak())

    # ── Surplus & Loan Trajectories ──
    story.append(Paragraph('Surplus Trajectory', styles['SubHead']))

    fig, ax = plt.subplots(figsize=(9, 5))
    ax.plot(years, [s/1e6 for s in bl['mean_surplus_by_year']], color=MPL['coral'],
            linewidth=2.5, label='Baseline', linestyle='--')
    ax.plot(years, [s/1e6 for s in rec_re['mean_surplus_by_year']], color=MPL['green'],
            linewidth=2.5, label=f'10yr ($250K)')
    if re_15:
        ax.plot(years, [s/1e6 for s in re_15['mean_surplus_by_year']], color=MPL['teal'],
                linewidth=2.5, label=f'15yr ($375K)')
    if lmi_20:
        ax.plot(years, [s/1e6 for s in lmi_20['mean_surplus_by_year']], color=MPL['blue'],
                linewidth=2, label=f'20yr ($500K)')
    if lmi_25:
        ax.plot(years, [s/1e6 for s in lmi_25['mean_surplus_by_year']], color=MPL['purple'],
                linewidth=2, label=f'25yr ($625K)')
    ax.axhline(y=0, color=MPL['coral'], linestyle='--', alpha=0.5)
    ax.set_xlabel('Year', fontsize=11)
    ax.set_ylabel('Mean Surplus ($M)', fontsize=11)
    ax.set_title('Mean Surplus — Constrained Annuity Rate (1.25%)', fontsize=13, fontweight='bold', color=MPL['navy'])
    ax.legend(fontsize=9)
    ax.set_xlim(1, 30)
    ax.yaxis.set_major_formatter(mticker.FormatStrFormatter('$%.1fM'))
    ax.grid(True, alpha=0.3)
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    fig.tight_layout()
    story.append(fig_to_image(fig, width=170*mm, height=105*mm))

    # Loan balance
    story.append(Spacer(1, 6*mm))
    story.append(Paragraph('Loan Balance', styles['SubHead']))

    fig, ax = plt.subplots(figsize=(9, 5))
    yrs = list(range(0, 31))
    ax.plot(yrs, [l/1e6 for l in bl['mean_loan_by_year']], color=MPL['coral'],
            linewidth=2.5, label='Baseline (IO)', linestyle='--')
    ax.plot(yrs, [l/1e6 for l in rec_re['mean_loan_by_year']], color=MPL['green'],
            linewidth=2.5, label='10yr PI')
    if re_15:
        ax.plot(yrs, [l/1e6 for l in re_15['mean_loan_by_year']], color=MPL['teal'],
                linewidth=2.5, label='15yr PI')
    if lmi_20:
        ax.plot(yrs, [l/1e6 for l in lmi_20['mean_loan_by_year']], color=MPL['blue'],
                linewidth=2, label='20yr PI')
    if lmi_25:
        ax.plot(yrs, [l/1e6 for l in lmi_25['mean_loan_by_year']], color=MPL['purple'],
                linewidth=2, label='25yr PI')
    ax.set_xlabel('Year', fontsize=11)
    ax.set_ylabel('Loan Balance ($M)', fontsize=11)
    ax.set_title('Mortgage Balance — All P&I Amortise to $0', fontsize=13, fontweight='bold', color=MPL['navy'])
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
    all_val = data['all_50k_validated']
    for r in all_val:
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

    # Constraint regions
    ax.axvline(x=5, color=MPL['green'], linestyle='--', alpha=0.4, linewidth=1.5)
    ax.axvline(x=12, color=MPL['orange'], linestyle='--', alpha=0.4, linewidth=1.5)
    ax.text(4.8, ax.get_ylim()[0] if ax.get_ylim()[0] > 0 else 0.5, 'RE ≤5%',
            fontsize=8, color=MPL['green'], ha='right', va='bottom', rotation=90)
    ax.text(11.8, ax.get_ylim()[0] if ax.get_ylim()[0] > 0 else 0.5, 'LMI ≤12%',
            fontsize=8, color=MPL['orange'], ha='right', va='bottom', rotation=90)

    # Baseline
    ax.scatter(bl['pod_yr30'], bl['mean_total_fp_revenue']/1e6,
              c=MPL['coral'], s=150, marker='X', zorder=6, edgecolors=MPL['navy'], linewidths=1,
              label='v14a Baseline')
    # Recommended
    ax.scatter(rec_re['pod_yr30'], rec_re['mean_total_fp_revenue']/1e6,
              c=MPL['green'], s=200, marker='*', zorder=7, edgecolors=MPL['navy'], linewidths=1,
              label='Recommended')

    ax.scatter([], [], c=MPL['green'], marker='o', s=40, label='10yr payout')
    ax.scatter([], [], c=MPL['teal'], marker='s', s=40, label='15yr payout')
    ax.scatter([], [], c=MPL['blue'], marker='D', s=40, label='20yr payout')
    ax.scatter([], [], c=MPL['purple'], marker='^', s=40, label='25yr payout')

    ax.set_xlabel('Probability of Claim at Year 30 (%)', fontsize=11)
    ax.set_ylabel('FP Total Revenue ($M)', fontsize=11)
    ax.set_title('Efficient Frontier — Constrained Annuity Rate', fontsize=13, fontweight='bold', color=MPL['navy'])
    ax.legend(fontsize=8, loc='lower right', ncol=2)
    ax.grid(True, alpha=0.3)
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    ax.yaxis.set_major_formatter(mticker.FormatStrFormatter('$%.1fM'))
    fig.tight_layout()
    story.append(fig_to_image(fig, width=170*mm, height=110*mm))

    story.append(PageBreak())

    # ── Reinsurance Tier Table ──
    story.append(Paragraph(f'Tier 1 — Reinsurance Grade (PoC ≤ 5%)', styles['SectionHead']))
    story.append(Paragraph(f'{len(t1)} configurations meet the reinsurance threshold:', styles['BodyText2']))

    t1_rows = []
    for i, r in enumerate(t1[:14]):
        marker = ' ★' if r['label'] == rec_re['label'] else ''
        payout = f'${r["annuity_pa"]/1000:.0f}K×{r["annuity_term"]}yr'
        t1_rows.append([
            str(i+1), r['label'][:35] + marker, r['loan_type'],
            f'{r["annuity_pct"]:.2f}%', payout,
            f'{r["pod_yr30"]:.1f}%', f'${r["mean_total_fp_revenue"]:,.0f}',
            f'{r["sharpe_like"]:.3f}',
        ])
    story.append(make_table(
        ['#', 'Configuration', 'Type', 'Ann%', 'Payout', 'PoC %', 'FP Revenue', 'Sharpe'],
        t1_rows,
        col_widths=[8*mm, 44*mm, 10*mm, 14*mm, 24*mm, 14*mm, 26*mm, 14*mm]
    ))
    story.append(Paragraph('★ = Recommended', styles['SmallNote']))

    story.append(PageBreak())

    # ── LMI Tier — Longer Payouts ──
    story.append(Paragraph(f'Tier 2 — LMI Grade (PoC ≤ 12%)', styles['SectionHead']))
    story.append(Paragraph(f'{len(t2)} configurations meet the LMI threshold. Longer payouts shown below:', styles['BodyText2']))

    t2_rows = []
    for i, r in enumerate(t2):
        marker = ''
        if r['label'] == rec_lmi['label']:
            marker = ' ★'
        payout = f'${r["annuity_pa"]/1000:.0f}K×{r["annuity_term"]}yr'
        t2_rows.append([
            str(i+1), r['label'][:35] + marker, r['loan_type'],
            f'{r["annuity_pct"]:.2f}%', payout,
            f'${r["total_annuity"]:,.0f}',
            f'{r["pod_yr30"]:.1f}%', f'${r["mean_total_fp_revenue"]:,.0f}',
            f'{r["sharpe_like"]:.3f}',
        ])
    story.append(make_table(
        ['#', 'Configuration', 'Type', 'Ann%', 'Payout', 'Total Income', 'PoC %', 'FP Revenue', 'Sharpe'],
        t2_rows,
        col_widths=[8*mm, 38*mm, 10*mm, 12*mm, 22*mm, 22*mm, 12*mm, 24*mm, 12*mm]
    ))

    story.append(PageBreak())

    # ── Detailed Comparison ──
    story.append(Paragraph('Detailed Comparison by Payout Duration', styles['SectionHead']))

    configs_to_compare = [('Baseline', bl)]
    configs_to_compare.append(('10yr (RE)', rec_re))
    if re_15:
        configs_to_compare.append(('15yr (RE)', re_15))
    if lmi_20:
        configs_to_compare.append(('20yr (LMI)', lmi_20))
    if lmi_25:
        configs_to_compare.append(('25yr (LMI)', lmi_25))

    headers = ['Metric'] + [lbl for lbl, _ in configs_to_compare]

    def row(metric, key, fmt='${:,.0f}', pct=False):
        vals = []
        for _, cfg in configs_to_compare:
            v = cfg[key]
            if pct:
                vals.append(f'{v:.1f}%')
            else:
                vals.append(fmt.format(v))
        return [metric] + vals

    detail_rows = [
        row('Annuity Rate', 'annuity_pct', '{:.2f}%'),
        ['Payout'] + [f'${c["annuity_pa"]/1000:.0f}K×{c["annuity_term"]}yr' for _, c in configs_to_compare],
        row('Total Income', 'total_annuity'),
        ['Loan Type'] + [c['loan_type'] for _, c in configs_to_compare],
        ['Collar'] + [f'±{(c["buffer_cap"]-1)*100:.0f}%' for _, c in configs_to_compare],
        ['Holiday Entry'] + [f'{c["holiday_entry"]:.2f}' for _, c in configs_to_compare],
        ['PS Config'] + [f'{c["profit_share_pct"]*100:.0f}% q{c["profit_share_years"]}' for _, c in configs_to_compare],
        ['', ''] + [''] * (len(configs_to_compare) - 1),
        row('PoC Year 30', 'pod_yr30', '{:.1f}%'),
        row('PoC Year 20', 'pod_yr20', '{:.1f}%'),
        row('PoC Year 15', 'pod_yr15', '{:.1f}%'),
        row('Mean Surplus', 'mean_surplus_yr30'),
        row('Sharpe Ratio', 'sharpe_like', '{:.3f}'),
        ['', ''] + [''] * (len(configs_to_compare) - 1),
        row('FP Revenue', 'mean_total_fp_revenue'),
        row('  Profit Share', 'mean_total_profit_share'),
        row('  FP Margin', 'mean_fp_margin_income'),
        row('Funder Surplus', 'mean_funder_surplus_share'),
        row('Premium', 'fair_premium_loaded'),
        ['', ''] + [''] * (len(configs_to_compare) - 1),
        row('Final Loan', 'mean_final_loan_balance'),
        row('Protection', 'mean_borrower_equity_return', '{:.1f}%'),
    ]

    ncols = len(configs_to_compare) + 1
    cw = max(28, int(152 / ncols))
    story.append(make_table(headers, detail_rows,
                            col_widths=[28*mm] + [cw*mm] * len(configs_to_compare)))

    story.append(PageBreak())

    # ── Product Menu ──
    story.append(Paragraph('Product Menu — Constrained Configurations', styles['SectionHead']))
    story.append(Paragraph(
        'Based on the constrained optimisation, the following product tiers are feasible at 1.25% annuity rate '
        '(P&amp;I), with all other parameters set to: ±35% collar, 1.05 holiday entry, 0.15% FP margin.',
        styles['BodyText2']))

    menu_rows = [
        ['Payout Term', '10 years', '15 years', '20 years', '25 years'],
        ['Annual Income', '$25,000', '$25,000', '$25,000', '$25,000'],
        ['Total Income', '$250,000', '$375,000', '$500,000', '$625,000'],
        ['PoC', f'{rec_re["pod_yr30"]:.1f}%', f'{re_15["pod_yr30"]:.1f}%' if re_15 else '—',
         f'{lmi_20["pod_yr30"]:.1f}%' if lmi_20 else '—',
         f'{lmi_25["pod_yr30"]:.1f}%' if lmi_25 else '—'],
        ['Insurance Tier', 'Reinsurance ✓', f'{"Reinsurance ✓" if re_15 and re_15["pod_yr30"] <= 5.0 else "LMI ✓"}',
         'LMI ✓' if lmi_20 else '—', 'LMI ✓' if lmi_25 else '—'],
        ['Protection', f'{rec_re["mean_borrower_equity_return"]:.1f}%',
         f'{re_15["mean_borrower_equity_return"]:.1f}%' if re_15 else '—',
         f'{lmi_20["mean_borrower_equity_return"]:.1f}%' if lmi_20 else '—',
         f'{lmi_25["mean_borrower_equity_return"]:.1f}%' if lmi_25 else '—'],
        ['FP Revenue', f'${rec_re["mean_total_fp_revenue"]:,.0f}',
         f'${re_15["mean_total_fp_revenue"]:,.0f}' if re_15 else '—',
         f'${lmi_20["mean_total_fp_revenue"]:,.0f}' if lmi_20 else '—',
         f'${lmi_25["mean_total_fp_revenue"]:,.0f}' if lmi_25 else '—'],
        ['Premium', f'${rec_re["fair_premium_loaded"]:,.0f}',
         f'${re_15["fair_premium_loaded"]:,.0f}' if re_15 else '—',
         f'${lmi_20["fair_premium_loaded"]:,.0f}' if lmi_20 else '—',
         f'${lmi_25["fair_premium_loaded"]:,.0f}' if lmi_25 else '—'],
        ['Final Loan', '$0', '$0', '$0', '$0'],
    ]
    story.append(make_table(
        ['', '10yr', '15yr', '20yr', '25yr'],
        menu_rows,
        col_widths=[28*mm, 32*mm, 32*mm, 32*mm, 32*mm]
    ))

    story.append(Spacer(1, 6*mm))
    story.append(Paragraph(
        'All four configurations use the same P&amp;I structure, so the mortgage amortises to $0 at maturity '
        'regardless of payout term. The trade-off is purely between total income (borrower attractiveness) and '
        'PoC (insurance cost). The 10-year and 15-year products qualify for portfolio reinsurance; the 20 and '
        '25-year products require individual LMI pricing.',
        styles['BodyText2']))

    story.append(PageBreak())

    # ── Conclusions ──
    story.append(Paragraph('Conclusions', styles['SectionHead']))

    points = [
        f'<b>Annuity rate is the binding constraint:</b> The optimizer naturally settles at the floor '
        f'of the allowed range (1.25% for P&amp;I). All other levers have room to move without hitting bounds.',

        f'<b>P&amp;I dominates IO within constraints:</b> At the constrained annuity rates, P&amp;I configurations '
        f'consistently achieve lower PoC than IO. The best IO configuration (1.50%, $30K×10yr) has PoC of 6.0% — '
        f'still within LMI bounds but above reinsurance.',

        f'<b>Core parameter set is robust:</b> ±35% collar, 1.05 holiday entry, and 0.15% FP margin are optimal '
        f'across all payout durations. These are not sensitive to the annuity structure.',

        f'<b>15-year payout is the longest reinsurance-grade product:</b> At $25K/yr for 15 years ($375K total), '
        f'PoC sits just below 5%. This is 50% more total income than the 10-year product.'
        if re_15 else
        f'<b>10-year payout is the only reinsurance-grade product</b> under these constraints.',

        f'<b>25-year payout is viable at LMI grade:</b> $25K/yr for 25 years ($625K total) with PoC of '
        f'{lmi_25["pod_yr30"]:.1f}% — well within the 12% LMI threshold. This delivers 2.5× the baseline income.'
        if lmi_25 else '',
    ]
    for p in [x for x in points if x]:
        story.append(Paragraph(p, styles['BulletCustom'], bulletText='•'))

    story.append(Spacer(1, 8*mm))
    story.append(Paragraph('Methodology', styles['SmallNote']))
    story.append(Paragraph(
        f'{meta["phase1_scenarios"]} Phase 1 + {meta["phase2_scenarios"]} Phase 2 scenarios × 10K paths, '
        f'top {meta["phase3_scenarios"]} validated at 50K paths. Seed: {meta["seed"]}. '
        f'P&I annuity: {constraints["pi_annuity_range"]} ($25K–$30K/yr). '
        f'IO annuity: {constraints["io_annuity_range"]} ($30K–$40K/yr). '
        f'PoC thresholds: ≤{constraints["poc_reinsurance"]:.0f}% (reinsurance), '
        f'≤{constraints["poc_lmi"]:.0f}% (LMI).',
        styles['SmallNote']))

    # Build
    outfile = 'FutureProof_EPM_v14a_Constrained_Optimisation.pdf'
    doc = SimpleDocTemplate(outfile, pagesize=A4,
                            leftMargin=25*mm, rightMargin=25*mm,
                            topMargin=20*mm, bottomMargin=20*mm)
    doc.build(story, onFirstPage=footer, onLaterPages=footer)
    print(f"Report: {outfile}")


if __name__ == '__main__':
    generate()
