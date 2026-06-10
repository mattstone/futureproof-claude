#!/usr/bin/env python3
"""
Generate Constrained Optimisation v2 Report
Corrected constraints: collar ≤±20%, FP margin ≥0.25%, fixed total annuity
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
    canvas.drawString(25*mm, 12*mm, 'FutureProof | Constrained Optimisation v2 | March 2025')
    canvas.drawRightString(A4[0] - 25*mm, 12*mm, f'Page {doc.page}')
    canvas.restoreState()


def generate():
    with open('optimisation_v14a_constrained_v2_results.json') as f:
        data = json.load(f)

    bl = data['baseline']
    rec_re = data['recommended_reinsurance']
    rec_lmi = data['recommended_lmi']
    t1 = data['tier1_reinsurance_50k']
    t2 = data['tier2_lmi_50k']
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
    story.append(Paragraph('v2 — Corrected Constraints', styles['ReportSubtitle']))
    story.append(Paragraph('March 2025', styles['ReportSubtitle']))
    story.append(Spacer(1, 15*mm))
    story.append(Paragraph('CONFIDENTIAL — For Internal Use Only', styles['Confidential']))
    story.append(PageBreak())

    # ════════════════════════════════════════════════════════
    # PAGE 2: CONSTRAINTS & PARAMETERS
    # ════════════════════════════════════════════════════════
    story.append(Paragraph('Constraints &amp; Parameters', styles['SectionHead']))
    story.append(Paragraph(
        'This section documents every constraint and parameter used in the optimisation. '
        'All scenarios are subject to these bounds — no configuration that violates a constraint '
        'is included in the results.',
        styles['BodyText2']))

    # Hard constraints table
    story.append(Paragraph('Hard Constraints', styles['SubHead']))
    story.append(make_table(
        ['#', 'Constraint', 'Bound', 'Rationale'],
        [
            ['C1', 'Collar width', '≤ ±20%',
             'Wider collars too costly to hedge in practice'],
            ['C2', 'FP margin', '≥ 0.25% (25 bps) p.a.',
             'Commercial floor — minimum FP return'],
            ['C3', 'IO annuity ≥ PI annuity', 'Product design rule',
             'Analysis uses identical ranges for like-for-like comparison'],
            ['C4', 'Total annuity is FIXED', 'Does not increase with longer term',
             'Borrower chooses how to spread a fixed total over time'],
            ['C5', 'PoC — Reinsurance', '≤ 5%',
             'Portfolio-level reinsurance pricing threshold'],
            ['C6', 'PoC — Individual LMI', '≤ 12%',
             'Individual mortgage insurance pricing threshold'],
        ],
        col_widths=[8*mm, 35*mm, 40*mm, 72*mm]
    ))

    story.append(Spacer(1, 5*mm))

    # Fixed model parameters
    story.append(Paragraph('Fixed Model Parameters (not optimised)', styles['SubHead']))
    story.append(make_table(
        ['Parameter', 'Value', 'Notes'],
        [
            ['Property value', '$2,000,000', 'Reference property'],
            ['LVR', '80%', ''],
            ['Gross mortgage', '$1,600,000', '80% LVR × $2M'],
            ['Initial mortgage', 'Dynamic', '$1,600,000 − total annuity (e.g. $1,350,000 at $250K annuity)'],
            ['Mortgage term', '30 years', ''],
            ['Wholesale margin', '2.00% p.a.', 'Funder cost of funds spread'],
            ['Hedging fee', '0.25% p.a.', 'Collar hedging cost on investment account'],
            ['Retail margin', '0.70% p.a.', 'Lender retail margin on mortgage balance'],
            ['LMI upfront', '1.60% of peak mortgage', 'Lenders mortgage insurance'],
            ['Reinsurance upfront', '0.10% of peak mortgage', 'Portfolio reinsurance layer'],
            ['Equity return (mean)', '10.0% p.a.', '~70% S&P 500, ~30% fixed income'],
            ['Equity volatility', '10.0% p.a.', 'Blended portfolio vol'],
            ['Cash rate (initial)', '4.40%', ''],
            ['Cash rate (long-run)', '4.40%', 'Ornstein-Uhlenbeck mean reversion'],
            ['Cash rate (kappa)', '0.80', 'Mean reversion speed'],
            ['Cash rate (sigma)', '1.50%', 'Cash rate vol'],
            ['Equity-rate correlation', '0.069', ''],
            ['Holiday exit/entry ratio', '1.62×', 'Fixed ratio'],
        ],
        col_widths=[40*mm, 35*mm, 80*mm]
    ))

    story.append(PageBreak())

    # Optimised parameters
    story.append(Paragraph('Optimised Parameters (search grid)', styles['SubHead']))
    story.append(make_table(
        ['Parameter', 'Values Tested', 'Notes'],
        [
            ['Mortgage type', 'P&I, IO', 'P&I amortises to $0 at maturity; IO does not'],
            ['Total annuity (both)', '$250,000 / $275,000 / $300,000 / $350,000 / $400,000',
             '1.25%–2.00% of property value — identical range for like-for-like comparison'],
            ['Payout term', '10, 15, 20, 25 years',
             'Annual draw = total ÷ term (total stays fixed)'],
            ['Collar width', '±10%, ±15%, ±20%',
             'Symmetric cap/floor on equity returns'],
            ['Holiday entry threshold', '0.90, 0.95, 1.00, 1.05',
             'As multiple of initial mortgage balance'],
            ['Profit share %', '20%, 25%',
             'Share of surplus extracted for FP'],
            ['Profit share period', 'Every 3yr, Every 5yr',
             '5yr preferred (better compounding)'],
            ['FP margin', '0.25%, 0.30%, 0.35%',
             'Applied to investment account balance p.a.'],
        ],
        col_widths=[35*mm, 42*mm, 78*mm]
    ))

    story.append(Spacer(1, 4*mm))

    # Annuity structure explanation
    story.append(Paragraph('Annuity Structure (Critical)', styles['SubHead']))
    story.append(Paragraph(
        'The <b>total annuity</b> is set by the annuity rate and is <b>fixed</b>. Longer payout terms '
        'spread the same total over more years, reducing the annual draw. However, the <b>peak mortgage '
        'is the same</b> for all terms ($1.6M) because initial loan + total annuity = gross loan regardless '
        'of how the annuity is spread. For P&amp;I, shorter payout terms leave more years for amortisation '
        'after the annuity period ends, which generally produces <b>better PoC</b>.',
        styles['BodyText2']))

    story.append(make_table(
        ['Total Annuity', 'Rate', '10yr', '15yr', '20yr', '25yr'],
        [
            ['$250,000', '1.25%', '$25,000/yr', '$16,667/yr', '$12,500/yr', '$10,000/yr'],
            ['$275,000', '1.375%', '$27,500/yr', '$18,333/yr', '$13,750/yr', '$11,000/yr'],
            ['$300,000', '1.50%', '$30,000/yr', '$20,000/yr', '$15,000/yr', '$12,000/yr'],
            ['$350,000', '1.75%', '$35,000/yr', '$23,333/yr', '$17,500/yr', '$14,000/yr'],
            ['$400,000', '2.00%', '$40,000/yr', '$26,667/yr', '$20,000/yr', '$16,000/yr'],
        ],
        col_widths=[30*mm, 15*mm, 25*mm, 25*mm, 25*mm, 25*mm]
    ))

    story.append(Spacer(1, 4*mm))

    # Simulation methodology
    story.append(Paragraph('Simulation Methodology', styles['SubHead']))
    total_scenarios = meta['phase1_scenarios'] + meta['phase2_scenarios']
    story.append(make_table(
        ['Phase', 'Scenarios', 'Monte Carlo Paths', 'Purpose'],
        [
            ['Phase 1 — Individual levers', str(meta['phase1_scenarios']),
             '10,000', 'Isolate impact of each parameter'],
            ['Phase 2 — Combined grid', str(meta['phase2_scenarios']),
             '10,000', 'Full factorial search within constraints'],
            ['Phase 3 — Validation', str(meta['phase3_scenarios']),
             '50,000', 'High-precision validation of top candidates'],
            ['Total', f'{total_scenarios + meta["phase3_scenarios"]:,}', '', ''],
        ],
        col_widths=[35*mm, 25*mm, 28*mm, 65*mm]
    ))
    story.append(Paragraph(f'Random seed: {meta["seed"]}. All phases use identical seed for reproducibility.',
                           styles['SmallNote']))

    story.append(PageBreak())

    # ════════════════════════════════════════════════════════
    # EXECUTIVE SUMMARY
    # ════════════════════════════════════════════════════════
    story.append(Paragraph('Executive Summary', styles['SectionHead']))

    story.append(Paragraph(
        f'With corrected constraints (collar ≤±20%, FP margin ≥0.25%, fixed total annuity), the optimisation '
        f'tested {total_scenarios:,} scenarios and validated {meta["phase3_scenarios"]} at 50,000 paths. '
        f'Of the validated configurations, <b>{meta["tier1_count_50k"]} met the reinsurance threshold</b> '
        f'(PoC ≤ 5%) and <b>{meta["tier2_count_50k"]} met the LMI threshold</b> (PoC ≤ 12%).',
        styles['BodyText2']))

    # Results summary
    story.append(make_table(
        ['Metric', 'v14a Baseline', 'Reinsurance (≤5%)', 'LMI (≤12%)'],
        [
            ['Total Annuity', f'${bl["total_annuity"]:,.0f}', f'${rec_re["total_annuity"]:,.0f}',
             f'${rec_lmi["total_annuity"]:,.0f}'],
            ['Payout', f'{bl["annuity_term"]}yr @ ${bl["annuity_pa"]:,.0f}',
             f'{rec_re["annuity_term"]}yr @ ${rec_re["annuity_pa"]:,.0f}',
             f'{rec_lmi["annuity_term"]}yr @ ${rec_lmi["annuity_pa"]:,.0f}'],
            ['Mortgage Type', bl['loan_type'], rec_re['loan_type'], rec_lmi['loan_type']],
            ['Collar', f'±{(bl["buffer_cap"]-1)*100:.0f}%', f'±{(rec_re["buffer_cap"]-1)*100:.0f}%',
             f'±{(rec_lmi["buffer_cap"]-1)*100:.0f}%'],
            ['Holiday Entry', f'{bl["holiday_entry"]:.2f}', f'{rec_re["holiday_entry"]:.2f}',
             f'{rec_lmi["holiday_entry"]:.2f}'],
            ['PS Config', f'{bl["profit_share_pct"]*100:.0f}% q{bl["profit_share_years"]}',
             f'{rec_re["profit_share_pct"]*100:.0f}% q{rec_re["profit_share_years"]}',
             f'{rec_lmi["profit_share_pct"]*100:.0f}% q{rec_lmi["profit_share_years"]}'],
            ['FP Margin', f'{bl["fp_margin"]*100:.2f}%', f'{rec_re["fp_margin"]*100:.2f}%',
             f'{rec_lmi["fp_margin"]*100:.2f}%'],
            ['', '', '', ''],
            ['PoC Year 30', f'{bl["poc_yr30"]:.1f}%', f'{rec_re["poc_yr30"]:.1f}%',
             f'{rec_lmi["poc_yr30"]:.1f}%'],
            ['FP Revenue', f'${bl["mean_total_fp_revenue"]:,.0f}',
             f'${rec_re["mean_total_fp_revenue"]:,.0f}',
             f'${rec_lmi["mean_total_fp_revenue"]:,.0f}'],
            ['Mean Surplus', f'${bl["mean_surplus_yr30"]:,.0f}',
             f'${rec_re["mean_surplus_yr30"]:,.0f}',
             f'${rec_lmi["mean_surplus_yr30"]:,.0f}'],
            ['Sharpe', f'{bl["sharpe_like"]:.3f}', f'{rec_re["sharpe_like"]:.3f}',
             f'{rec_lmi["sharpe_like"]:.3f}'],
            ['Premium', f'${bl["fair_premium_loaded"]:,.0f}',
             f'${rec_re["fair_premium_loaded"]:,.0f}',
             f'${rec_lmi["fair_premium_loaded"]:,.0f}'],
            ['Protection', f'{bl["mean_borrower_equity_return"]:.1f}%',
             f'{rec_re["mean_borrower_equity_return"]:.1f}%',
             f'{rec_lmi["mean_borrower_equity_return"]:.1f}%'],
            ['Final Mortgage', f'${bl["mean_final_loan_balance"]:,.0f}',
             f'${rec_re["mean_final_loan_balance"]:,.0f}',
             f'${rec_lmi["mean_final_loan_balance"]:,.0f}'],
        ],
        col_widths=[28*mm, 38*mm, 38*mm, 38*mm]
    ))

    story.append(Spacer(1, 4*mm))
    story.append(Paragraph(
        f'The key structural change from baseline is <b>P&amp;I amortisation</b> (mortgage repays to $0) and '
        f'<b>holiday entry at 1.05</b> (more aggressive capital preservation). The collar remains at ±20% '
        f'(same as baseline) and FP margin remains at 0.25% (same as baseline). The main revenue improvement '
        f'comes from switching profit share to <b>every 3 years</b> instead of every 5.',
        styles['BodyText2']))

    story.append(PageBreak())

    # ════════════════════════════════════════════════════════
    # PAYOUT DURATION ANALYSIS
    # ════════════════════════════════════════════════════════
    story.append(Paragraph('Payout Duration Analysis', styles['SectionHead']))
    story.append(Paragraph(
        'Since total annuity is fixed, all payout terms reach the same peak mortgage ($1.6M). '
        'The key difference is <b>when amortisation begins</b>: a 10-year payout finishes drawing at year 10, '
        'leaving 20 years of P&amp;I repayment. A 25-year payout doesn\'t start amortising until year 25, '
        'leaving only 5 years. Shorter payout terms therefore tend to produce better PoC for P&amp;I mortgages.',
        styles['BodyText2']))

    # Get best by duration configs
    lmi_10 = best_dur.get('lmi', {}).get('min_10yr')
    lmi_15 = best_dur.get('lmi', {}).get('min_15yr')
    lmi_20 = best_dur.get('lmi', {}).get('min_20yr')
    lmi_25 = best_dur.get('lmi', {}).get('min_25yr')

    # Duration table
    dur_rows = []
    for label, cfg in [('10yr', lmi_10), ('15yr', lmi_15), ('20yr', lmi_20), ('25yr', lmi_25)]:
        if cfg:
            tier = 'RE ✓' if cfg['poc_yr30'] <= 5.0 else 'LMI ✓'
            dur_rows.append([
                label, f'${cfg["total_annuity"]:,.0f}', f'${cfg["annuity_pa"]:,.0f}/yr',
                f'{cfg["poc_yr30"]:.1f}%', tier,
                f'${cfg["mean_total_fp_revenue"]:,.0f}', f'{cfg["sharpe_like"]:.3f}',
            ])
    story.append(make_table(
        ['Term', 'Total', 'Annual Draw', 'PoC', 'Tier', 'FP Revenue', 'Sharpe'],
        dur_rows,
        col_widths=[15*mm, 22*mm, 25*mm, 15*mm, 15*mm, 28*mm, 18*mm]
    ))

    story.append(Spacer(1, 4*mm))

    # PoC trajectory chart
    fig, ax = plt.subplots(figsize=(9, 5))
    years = list(range(1, 31))
    ax.plot(years, bl['poc_by_year'], color=MPL['coral'], linewidth=2.5,
            label=f'Baseline (IO, $25K×10yr)', linestyle='--')

    if lmi_10:
        ax.plot(years, lmi_10['poc_by_year'], color=MPL['green'], linewidth=2.5,
                label=f'10yr ($25K/yr)')
    if lmi_15:
        ax.plot(years, lmi_15['poc_by_year'], color=MPL['teal'], linewidth=2.5,
                label=f'15yr ($16.7K/yr)')
    if lmi_20:
        ax.plot(years, lmi_20['poc_by_year'], color=MPL['blue'], linewidth=2,
                label=f'20yr ($12.5K/yr)')
    if lmi_25:
        ax.plot(years, lmi_25['poc_by_year'], color=MPL['purple'], linewidth=2,
                label=f'25yr ($10K/yr)')

    ax.axhline(y=5, color=MPL['green'], linestyle=':', alpha=0.7, label='5% reinsurance')
    ax.axhline(y=12, color=MPL['orange'], linestyle=':', alpha=0.7, label='12% LMI')
    ax.set_xlabel('Year', fontsize=11)
    ax.set_ylabel('Probability of Claim (%)', fontsize=11)
    ax.set_title('PoC Over Time — Fixed Total $250K, Varying Payout Term', fontsize=13,
                 fontweight='bold', color=MPL['navy'])
    ax.legend(fontsize=8, loc='upper right')
    ax.set_xlim(1, 30)
    ax.set_ylim(0, max(bl['poc_by_year']) * 1.05)
    ax.grid(True, alpha=0.3)
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    fig.tight_layout()
    story.append(fig_to_image(fig, width=170*mm, height=105*mm))

    story.append(Paragraph(
        'All optimised configurations dramatically outperform the baseline. The 10-year payout (green) '
        'achieves the <b>lowest</b> terminal PoC because the annuity period ends at year 10, leaving '
        '20 years of P&amp;I amortisation to reduce the mortgage. Longer payouts delay the amortisation phase, '
        'resulting in higher PoC despite the lower annual draw.',
        styles['BodyText2']))

    story.append(PageBreak())

    # ── Surplus trajectory ──
    story.append(Paragraph('Surplus &amp; Mortgage Trajectories', styles['SectionHead']))

    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(11, 5))

    # Surplus
    ax1.plot(years, [s/1e6 for s in bl['mean_surplus_by_year']], color=MPL['coral'],
             linewidth=2, label='Baseline', linestyle='--')
    for label, cfg, c in [('10yr', lmi_10, MPL['green']), ('15yr', lmi_15, MPL['teal']),
                           ('20yr', lmi_20, MPL['blue']), ('25yr', lmi_25, MPL['purple'])]:
        if cfg:
            ax1.plot(years, [s/1e6 for s in cfg['mean_surplus_by_year']], color=c, linewidth=2, label=label)
    ax1.axhline(y=0, color=MPL['coral'], linestyle='--', alpha=0.3)
    ax1.set_xlabel('Year', fontsize=10)
    ax1.set_ylabel('Mean Surplus ($M)', fontsize=10)
    ax1.set_title('Mean Surplus', fontsize=11, fontweight='bold', color=MPL['navy'])
    ax1.legend(fontsize=8)
    ax1.set_xlim(1, 30)
    ax1.yaxis.set_major_formatter(mticker.FormatStrFormatter('$%.1fM'))
    ax1.grid(True, alpha=0.3)
    ax1.spines['top'].set_visible(False)
    ax1.spines['right'].set_visible(False)

    # Mortgage balance
    yrs = list(range(0, 31))
    ax2.plot(yrs, [l/1e6 for l in bl['mean_loan_by_year']], color=MPL['coral'],
             linewidth=2, label='Baseline (IO)', linestyle='--')
    for label, cfg, c in [('10yr PI', lmi_10, MPL['green']), ('15yr PI', lmi_15, MPL['teal']),
                           ('20yr PI', lmi_20, MPL['blue']), ('25yr PI', lmi_25, MPL['purple'])]:
        if cfg:
            ax2.plot(yrs, [l/1e6 for l in cfg['mean_loan_by_year']], color=c, linewidth=2, label=label)
    ax2.set_xlabel('Year', fontsize=10)
    ax2.set_ylabel('Mortgage Balance ($M)', fontsize=10)
    ax2.set_title('Mortgage Balance (all P&I → $0)', fontsize=11, fontweight='bold', color=MPL['navy'])
    ax2.legend(fontsize=8)
    ax2.set_xlim(0, 30)
    ax2.set_ylim(0)
    ax2.yaxis.set_major_formatter(mticker.FormatStrFormatter('$%.1fM'))
    ax2.grid(True, alpha=0.3)
    ax2.spines['top'].set_visible(False)
    ax2.spines['right'].set_visible(False)

    fig.tight_layout()
    story.append(fig_to_image(fig, width=170*mm, height=100*mm))

    story.append(Paragraph(
        'Left: Longer payout terms build higher surplus because the lower annual draw leaves more capital '
        'in the investment account to compound. Right: All P&amp;I configurations amortise to $0. All terms '
        'peak at the same $1.6M, but the 10-year payout peaks at year 10 then amortises over 20 years; '
        'the 25-year payout peaks at year 25 then amortises over just 5 years.',
        styles['BodyText2']))

    story.append(PageBreak())

    # ════════════════════════════════════════════════════════
    # EFFICIENT FRONTIER
    # ════════════════════════════════════════════════════════
    story.append(Paragraph('Efficient Frontier', styles['SectionHead']))

    fig, ax = plt.subplots(figsize=(9, 5.5))
    all_val = data['all_50k_validated']
    for r in all_val:
        if r['label'] == bl['label']:
            continue
        term = r.get('annuity_term', 10)
        if term <= 10: c, m = MPL['green'], 'o'
        elif term <= 15: c, m = MPL['teal'], 's'
        elif term <= 20: c, m = MPL['blue'], 'D'
        else: c, m = MPL['purple'], '^'
        ax.scatter(r['poc_yr30'], r['mean_total_fp_revenue']/1e6, c=c, marker=m, s=50,
                  zorder=4, edgecolors=MPL['navy'], linewidths=0.5, alpha=0.7)

    ax.axvline(x=5, color=MPL['green'], linestyle='--', alpha=0.4, linewidth=1.5)
    ax.axvline(x=12, color=MPL['orange'], linestyle='--', alpha=0.4, linewidth=1.5)

    ax.scatter(bl['poc_yr30'], bl['mean_total_fp_revenue']/1e6,
              c=MPL['coral'], s=150, marker='X', zorder=6, edgecolors=MPL['navy'], linewidths=1,
              label='v14a Baseline')
    if rec_re:
        ax.scatter(rec_re['poc_yr30'], rec_re['mean_total_fp_revenue']/1e6,
                  c=MPL['green'], s=200, marker='*', zorder=7, edgecolors=MPL['navy'], linewidths=1,
                  label='Recommended (RE)')
    if rec_lmi and rec_lmi['label'] != rec_re['label']:
        ax.scatter(rec_lmi['poc_yr30'], rec_lmi['mean_total_fp_revenue']/1e6,
                  c=MPL['teal'], s=200, marker='*', zorder=7, edgecolors=MPL['navy'], linewidths=1,
                  label='Recommended (LMI)')

    ax.scatter([], [], c=MPL['green'], marker='o', s=40, label='10yr payout')
    ax.scatter([], [], c=MPL['teal'], marker='s', s=40, label='15yr payout')
    ax.scatter([], [], c=MPL['blue'], marker='D', s=40, label='20yr payout')
    ax.scatter([], [], c=MPL['purple'], marker='^', s=40, label='25yr payout')

    ax.set_xlabel('Probability of Claim at Year 30 (%)', fontsize=11)
    ax.set_ylabel('FP Total Revenue ($M)', fontsize=11)
    ax.set_title('Efficient Frontier — Constrained (±20% collar, ≥0.25% FM)', fontsize=13,
                 fontweight='bold', color=MPL['navy'])
    ax.legend(fontsize=8, loc='lower right', ncol=2)
    ax.grid(True, alpha=0.3)
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    ax.yaxis.set_major_formatter(mticker.FormatStrFormatter('$%.1fM'))
    fig.tight_layout()
    story.append(fig_to_image(fig, width=170*mm, height=110*mm))

    story.append(PageBreak())

    # ════════════════════════════════════════════════════════
    # VALIDATED TABLES
    # ════════════════════════════════════════════════════════
    story.append(Paragraph(f'Tier 1 — Reinsurance Grade (PoC ≤ 5%)', styles['SectionHead']))
    story.append(Paragraph(f'{len(t1)} configuration(s) meet the reinsurance threshold at 50K paths:',
                           styles['BodyText2']))

    t1_rows = []
    for i, r in enumerate(t1):
        marker = ' ★' if rec_re and r['label'] == rec_re['label'] else ''
        t1_rows.append([
            str(i+1), r['label'][:40] + marker, r['loan_type'],
            f'${r["total_annuity"]/1000:.0f}K/{r["annuity_term"]}yr',
            f'{r["poc_yr30"]:.1f}%', f'${r["mean_total_fp_revenue"]:,.0f}',
            f'{r["sharpe_like"]:.3f}',
        ])
    story.append(make_table(
        ['#', 'Configuration', 'Type', 'Payout', 'PoC %', 'FP Revenue', 'Sharpe'],
        t1_rows,
        col_widths=[8*mm, 52*mm, 10*mm, 24*mm, 14*mm, 26*mm, 14*mm]
    ))
    story.append(Paragraph('★ = Recommended', styles['SmallNote']))

    story.append(Spacer(1, 6*mm))
    story.append(Paragraph(f'Tier 2 — LMI Grade (PoC ≤ 12%)', styles['SectionHead']))
    story.append(Paragraph(f'{len(t2)} configurations meet the LMI threshold. Top 25:', styles['BodyText2']))

    t2_rows = []
    for i, r in enumerate(t2[:25]):
        marker = ''
        if rec_lmi and r['label'] == rec_lmi['label']:
            marker = ' ★'
        elif rec_re and r['label'] == rec_re['label']:
            marker = ' ★RE'
        t2_rows.append([
            str(i+1), r['label'][:38] + marker, r['loan_type'],
            f'${r["total_annuity"]/1000:.0f}K/{r["annuity_term"]}yr',
            f'${r["annuity_pa"]:,.0f}/yr',
            f'{r["poc_yr30"]:.1f}%', f'${r["mean_total_fp_revenue"]:,.0f}',
            f'{r["sharpe_like"]:.3f}',
        ])
    story.append(make_table(
        ['#', 'Configuration', 'Type', 'Payout', 'Annual', 'PoC %', 'FP Revenue', 'Sharpe'],
        t2_rows,
        col_widths=[8*mm, 42*mm, 10*mm, 20*mm, 18*mm, 12*mm, 24*mm, 14*mm]
    ))

    story.append(PageBreak())

    # ════════════════════════════════════════════════════════
    # DETAILED COMPARISON
    # ════════════════════════════════════════════════════════
    story.append(Paragraph('Detailed Comparison', styles['SectionHead']))

    configs = [('Baseline', bl)]
    if rec_re:
        configs.append(('RE Grade', rec_re))
    if rec_lmi and (not rec_re or rec_lmi['label'] != rec_re['label']):
        configs.append(('LMI Grade', rec_lmi))
    if lmi_15:
        configs.append(('15yr (LMI)', lmi_15))
    if lmi_20:
        configs.append(('20yr (LMI)', lmi_20))
    if lmi_25:
        configs.append(('25yr (LMI)', lmi_25))

    headers = ['Metric'] + [lbl for lbl, _ in configs]

    detail_rows = [
        ['Total Annuity'] + [f'${c["total_annuity"]:,.0f}' for _, c in configs],
        ['Payout'] + [f'{c["annuity_term"]}yr @ ${c["annuity_pa"]:,.0f}' for _, c in configs],
        ['Mortgage Type'] + [c['loan_type'] for _, c in configs],
        ['Collar'] + [f'±{(c["buffer_cap"]-1)*100:.0f}%' for _, c in configs],
        ['Holiday Entry'] + [f'{c["holiday_entry"]:.2f}' for _, c in configs],
        ['PS Config'] + [f'{c["profit_share_pct"]*100:.0f}% q{c["profit_share_years"]}' for _, c in configs],
        ['FP Margin'] + [f'{c["fp_margin"]*100:.2f}%' for _, c in configs],
        [''] + [''] * len(configs),
        ['PoC Year 30'] + [f'{c["poc_yr30"]:.1f}%' for _, c in configs],
        ['PoC Year 20'] + [f'{c["poc_yr20"]:.1f}%' for _, c in configs],
        ['PoC Year 15'] + [f'{c["poc_yr15"]:.1f}%' for _, c in configs],
        ['Mean Surplus'] + [f'${c["mean_surplus_yr30"]:,.0f}' for _, c in configs],
        ['P5 Surplus'] + [f'${c["p5_surplus"]:,.0f}' for _, c in configs],
        ['Sharpe'] + [f'{c["sharpe_like"]:.3f}' for _, c in configs],
        [''] + [''] * len(configs),
        ['FP Revenue'] + [f'${c["mean_total_fp_revenue"]:,.0f}' for _, c in configs],
        ['  Profit Share'] + [f'${c["mean_total_profit_share"]:,.0f}' for _, c in configs],
        ['  FP Margin'] + [f'${c["mean_fp_margin_income"]:,.0f}' for _, c in configs],
        ['Funder Surplus'] + [f'${c["mean_funder_surplus_share"]:,.0f}' for _, c in configs],
        ['Premium'] + [f'${c["fair_premium_loaded"]:,.0f}' for _, c in configs],
        [''] + [''] * len(configs),
        ['Final Mortgage'] + [f'${c["mean_final_loan_balance"]:,.0f}' for _, c in configs],
        ['Protection'] + [f'{c["mean_borrower_equity_return"]:.1f}%' for _, c in configs],
    ]

    ncols = len(configs)
    cw = max(24, int(130 / ncols))
    story.append(make_table(headers, detail_rows,
                            col_widths=[26*mm] + [cw*mm] * ncols))

    story.append(PageBreak())

    # ════════════════════════════════════════════════════════
    # CONCLUSIONS
    # ════════════════════════════════════════════════════════
    story.append(Paragraph('Conclusions', styles['SectionHead']))

    points = [
        f'<b>P&amp;I + holiday entry 1.05 are the dominant levers:</b> These two changes alone reduce PoC '
        f'from {bl["poc_yr30"]:.1f}% to ~5%. The collar stays at ±20% (baseline) and FP margin at 0.25% (baseline).',

        f'<b>Only one configuration meets reinsurance grade:</b> PI, $250K/10yr, ±20%, HE=1.05, PS 20% q3, '
        f'FM 0.25% — at PoC {rec_re["poc_yr30"]:.1f}%. The reinsurance threshold is tight with a ±20% collar.'
        if rec_re else '',

        f'<b>Payout duration trade-off (fixed total):</b> At $250K total, 10yr payout ({lmi_10["poc_yr30"]:.1f}% PoC) '
        f'outperforms 25yr ({lmi_25["poc_yr30"]:.1f}% PoC) because the shorter annuity period leaves more '
        f'years for the P&amp;I amortisation to reduce the mortgage. All durations remain within LMI threshold, '
        f'so the choice is borrower preference: higher annual income (10yr) vs longer income stream (25yr).'
        if lmi_25 and lmi_10 else '',

        f'<b>3-year profit share boosts FP revenue significantly:</b> Switching from q5 to q3 adds '
        f'~$200K–$300K in cumulative FP revenue, at the cost of ~0.5pp PoC. The 5-year period is '
        f'preferred for reinvestment compounding but generates less revenue.',

        f'<b>IO is not competitive under these constraints:</b> With collar ≤±20%, no IO configuration '
        f'meets the reinsurance threshold. IO requires a wider collar to offset the permanent mortgage balance.',
    ]
    for p in [x for x in points if x]:
        story.append(Paragraph(p, styles['BulletCustom'], bulletText='•'))

    story.append(Spacer(1, 8*mm))
    story.append(Paragraph('Methodology', styles['SmallNote']))
    story.append(Paragraph(
        f'{meta["phase1_scenarios"]} Phase 1 + {meta["phase2_scenarios"]} Phase 2 = '
        f'{total_scenarios:,} scenarios × 10K paths; '
        f'{meta["phase3_scenarios"]} validated at 50K paths. Seed: {meta["seed"]}.',
        styles['SmallNote']))

    # Build
    outfile = 'FutureProof_EPM_v14a_Constrained_v2_Optimisation.pdf'
    doc = SimpleDocTemplate(outfile, pagesize=A4,
                            leftMargin=25*mm, rightMargin=25*mm,
                            topMargin=20*mm, bottomMargin=20*mm)
    doc.build(story, onFirstPage=footer, onLaterPages=footer)
    print(f"Report: {outfile}")


if __name__ == '__main__':
    generate()
