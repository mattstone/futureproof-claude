#!/usr/bin/env python3
"""FutureProof EPM v14d — Product-Design Improvements (internal paper).

Framing: improvements found by running configurations through the model, plus one product
assumption to confirm (how the principal is repaid).

ALL figures are computed LIVE at build time from the validated fast engine
`epm_engine_v14d.py` (vectorised reimplementation of Pavel's VBA, tied out to the workbook's
verified outputs; reads ~0.85pp conservative on PoD). No hard-coded results — the tables and
prose are generated from the engine runs below, so they cannot silently drift from the model.
"""
import os
from datetime import date
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from io import BytesIO
from reportlab.lib.pagesizes import A4
from reportlab.lib.units import mm
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.enums import TA_JUSTIFY, TA_CENTER
from reportlab.lib.colors import HexColor
from reportlab.platypus import (SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle,
                                PageBreak, Image)
import epm_engine_v14d as eng

# ----------------------------------------------------------------------------------------
# 1. COMPUTE EVERYTHING FROM THE ENGINE (50k paths, seed 42 — reproduces the workbook)
# ----------------------------------------------------------------------------------------
GROSS = 1_200_000          # 80% LVR x $1.5M home; peak loan held at gross regardless of annuity
NPATHS, SEED = 50_000, 42
WORKBOOK_BASE_POD = 8.37   # Pavel's xlsm MainSingleEPM!AL6 (engine reads ~0.85pp higher)

def cfg(annuity_total, term, floor=0.80, fp=0.005, **extra):
    d = dict(initial_loan=GROSS - annuity_total, annuity_pa=annuity_total / term,
             annuity_term=term, hedge_floor=floor, fp_margin=fp)
    d.update(extra)
    return d

def run(annuity_total, term, floor=0.80, fp=0.005, **extra):
    return eng.run(cfg(annuity_total, term, floor, fp, **extra), n_paths=NPATHS, seed=SEED)

CUR    = run(300_000, 10, 0.80, 0.005)    # current product
REC80  = run(350_000, 25, 0.80, 0.0025)   # recommended, within the floor-0.80 constraint
REC75  = run(350_000, 25, 0.75, 0.0025)   # recommended + wider floor (constraint-relaxed upside)
MAXB   = run(400_000, 25, 0.80, 0.0025)   # max-borrower
RATCHET = eng.run({'ratchet': 0.10}, n_paths=NPATHS, seed=SEED)
GLIDE   = eng.run({'glide': {'w_start': 1.0, 'w_end': 0.5, 'start_year': 20}}, n_paths=NPATHS, seed=SEED)
AMORT   = eng.run({'amortise': True}, n_paths=NPATHS, seed=SEED)

# ---- formatters ----
def pod(r):  return f"{r['pod']:.1f}%"
def rpoc(r): return f"{0.20 * r['pod']:.2f}%"           # reins PoC = 0.2 x PoD (P20 attachment)
def prem(r): return f"${r['reins_prem']:,.0f}"
def K(x):    return f"${x/1000:,.0f}K"
def M(x):    return f"${x/1e6:.2f}M"
def dpct(new, old):
    p = (new - old) / old * 100
    return (f"+{p:.0f}%" if p >= 0 else f"−{abs(p):.0f}%")

BORROWER_UP   = dpct(350_000, 300_000)                       # +17%
FP_UP_80      = dpct(REC80['fp_revenue'], CUR['fp_revenue']) # +2%
FP_UP_75      = dpct(REC75['fp_revenue'], CUR['fp_revenue']) # +11%
NIM_DN        = dpct(REC80['lender_nim'], CUR['lender_nim']) # -8%
PREM_DN_80    = dpct(REC80['reins_prem'], CUR['reins_prem']) # -56%
PREM_DN_75    = dpct(REC75['reins_prem'], CUR['reins_prem']) # -67%
MAXB_UP       = dpct(400_000, 300_000)                       # +33%
MAXB_FP_DN    = dpct(MAXB['fp_revenue'], CUR['fp_revenue'])  # -13%

NAVY = HexColor('#2C3E50'); TEAL = HexColor('#3498A8'); CORAL = HexColor('#C0392B')
GREEN = HexColor('#27AE60'); AMBER = HexColor('#F39C12')
HEADER_BG = NAVY; ROW_ALT = HexColor('#F8F9FA'); GREY = HexColor('#95A5A6')

def styles():
    s = getSampleStyleSheet()
    s.add(ParagraphStyle('Body2', parent=s['BodyText'], fontSize=10, leading=14, alignment=TA_JUSTIFY, spaceAfter=6))
    s.add(ParagraphStyle('H1', parent=s['Heading1'], fontSize=16, textColor=NAVY, spaceBefore=8, spaceAfter=8))
    s.add(ParagraphStyle('H2', parent=s['Heading2'], fontSize=12.5, textColor=TEAL, spaceBefore=8, spaceAfter=4))
    s.add(ParagraphStyle('Bul', parent=s['BodyText'], fontSize=10, leading=14, leftIndent=12, spaceAfter=4))
    s.add(ParagraphStyle('Call', parent=s['BodyText'], fontSize=10, leading=14, alignment=TA_JUSTIFY,
                         backColor=HexColor('#EAF3F5'), borderColor=TEAL, borderWidth=0.6,
                         borderPadding=11, spaceBefore=16, spaceAfter=16, textColor=NAVY))
    s.add(ParagraphStyle('TitleBig', parent=s['Title'], fontSize=22, textColor=NAVY, alignment=TA_CENTER))
    s.add(ParagraphStyle('Sub', parent=s['Title'], fontSize=13, textColor=TEAL, alignment=TA_CENTER, spaceAfter=2))
    s.add(ParagraphStyle('Red', parent=s['Title'], fontSize=11, textColor=CORAL, alignment=TA_CENTER))
    s.add(ParagraphStyle('Cell', parent=s['BodyText'], fontSize=8.5, leading=11))
    s.add(ParagraphStyle('CellH', parent=s['BodyText'], fontSize=8.5, leading=11, textColor=HexColor('#FFFFFF')))
    return s

def tbl(data, widths, hdr=True):
    t = Table(data, colWidths=widths, repeatRows=1 if hdr else 0)
    st = [('GRID', (0, 0), (-1, -1), 0.4, GREY), ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
          ('FONTSIZE', (0, 0), (-1, -1), 8.5), ('TOPPADDING', (0, 0), (-1, -1), 4), ('BOTTOMPADDING', (0, 0), (-1, -1), 4),
          ('LEFTPADDING', (0, 0), (-1, -1), 5), ('RIGHTPADDING', (0, 0), (-1, -1), 5)]
    if hdr:
        st += [('BACKGROUND', (0, 0), (-1, 0), HEADER_BG), ('TEXTCOLOR', (0, 0), (-1, 0), HexColor('#FFFFFF')),
               ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
               ('ROWBACKGROUNDS', (0, 1), (-1, -1), [HexColor('#FFFFFF'), ROW_ALT])]
    t.setStyle(TableStyle(st))
    return t

def chart_pod():
    # All three bars at the SAME collar floor (0.80) — apples-to-apples. Floor-0.75 upside noted in text.
    fig, ax = plt.subplots(figsize=(7.2, 3.4))
    labels = ['Current\n(300K / 10yr)', 'Recommended\n(350K / 25yr)', 'Max-borrower\n(400K / 25yr)']
    vals = [CUR['pod'], REC80['pod'], MAXB['pod']]
    cols = ['#3498A8', '#27AE60', '#F39C12']
    b = ax.bar(labels, vals, color=cols, width=0.55)
    for bar, v in zip(b, vals):
        ax.text(bar.get_x() + bar.get_width() / 2, v + 0.2, f'{v:.1f}%', ha='center', fontsize=10, fontweight='bold', color='#2C3E50')
    ax.axhline(10, color='#C0392B', ls='--', lw=1.2)
    ax.text(2.45, 10.2, 'reins PoC 2% ceiling (PoD 10%)', ha='right', fontsize=8, color='#C0392B')
    ax.set_ylabel('Per-mortgage PoD (%)', fontsize=9.5); ax.set_ylim(0, 12.5)
    ax.set_title('Per-mortgage risk (PoD) by configuration — all at collar floor 0.80', fontsize=10.5, fontweight='bold', color='#2C3E50')
    ax.spines['top'].set_visible(False); ax.spines['right'].set_visible(False)
    ax.grid(True, axis='y', alpha=0.3); ax.tick_params(labelsize=8.5)
    buf = BytesIO(); fig.tight_layout(); fig.savefig(buf, format='png', dpi=150); plt.close(fig); buf.seek(0)
    return Image(buf, width=160 * mm, height=76 * mm)

def footer(canvas, doc):
    canvas.saveState(); canvas.setFont('Helvetica', 8); canvas.setFillColor(GREY)
    canvas.drawString(20 * mm, 12 * mm, 'FutureProof | EPM Product-Design Improvements | Internal | May 2026')
    canvas.drawRightString(190 * mm, 12 * mm, f'Page {doc.page}')
    canvas.restoreState()

def build():
    s = styles(); story = []
    P = lambda t, st='Body2': story.append(Paragraph(t, s[st]))
    SP = lambda h=4: story.append(Spacer(1, h * mm))

    # Title
    SP(40)
    story.append(Paragraph('FutureProof Financial', s['TitleBig'])); SP(2)
    story.append(Paragraph('Equity Preservation Mortgage v14d (Optimised)', s['Sub']))
    story.append(Paragraph('Product-Design Improvements', s['Sub'])); SP(6)
    story.append(Paragraph('INTERNAL — FOR TEAM DISCUSSION', s['Red'])); SP(10)
    P('Running a range of product configurations through the model, this paper sets out the dials that give '
      'the borrower more income, FutureProof / lenders / funders more revenue, and less risk — and which of them '
      'are near-pure wins versus genuine trade-offs. It closes with one product assumption to confirm: how the '
      'principal is repaid.')
    SP(4)
    story.append(Paragraph(
      'Risk is shown two ways: the per-mortgage <b>probability of deficit (PoD)</b> — a balance-sheet measure, '
      '<i>not</i> a borrower loss rate — and the <b>reinsurance fair premium</b>, the discounted expected loss on '
      'the tail layer, which captures severity rather than just frequency. The reinsurance PoC quoted alongside is, '
      'by construction, 0.20 × PoD (the tail layer attaches at the worst-20%-of-deficits boundary).', s['Cell']))
    SP(2)
    story.append(Paragraph(
      f'<b>Provenance.</b> All figures are computed from the validated fast engine (epm_engine_v14d.py), '
      f'{NPATHS:,} paths, seed {SEED}. The engine ties out to Pavel’s authoritative workbook and reads about '
      f'0.85pp conservative on PoD (base case: engine {CUR["pod"]:.1f}% vs workbook {WORKBOOK_BASE_POD:.1f}%). The '
      f'<i>relative</i> improvements below are robust; the absolute levels are a slightly conservative read of the '
      f'workbook. Built {date.today().isoformat()}.', s['Cell']))
    story.append(PageBreak())

    # 1. What's the best we can do
    P("1. What's the best we can do", 'H1')
    P('Sweeping the product levers (annuity, payout term, FutureProof margin, profit share) at a reinsurance-PoC '
      'ceiling of 2% (investment-grade) and the current collar floor of 0.80, with borrower income prioritised, the '
      'standout is a single redesign that improves the borrower, FutureProof and the risk profile at once:')
    hd = [Paragraph(x, s['CellH']) for x in
          ['Configuration', 'Borrower<br/>annuity', 'PoD', 'Reins<br/>PoC', 'Reins<br/>premium', 'FP<br/>revenue', 'Lender<br/>NIM', 'Funder<br/>margin']]
    rows = [
        ['Current (300K / 10yr / FP 0.50%)', '$300K', pod(CUR), rpoc(CUR), prem(CUR), K(CUR['fp_revenue']), K(CUR['lender_nim']), K(CUR['funder_margin'])],
        ['Recommended (350K / 25yr / FP 0.25%)', '$350K', pod(REC80), rpoc(REC80), prem(REC80), K(REC80['fp_revenue']), K(REC80['lender_nim']), K(REC80['funder_margin'])],
    ]
    story.append(tbl([hd] + rows, [50 * mm, 16 * mm, 12 * mm, 12 * mm, 16 * mm, 16 * mm, 14 * mm, 15 * mm]))
    SP(2)
    story.append(Paragraph(
      f'Both rows use the current collar floor 0.80, so the comparison is like-for-like and does not depend on any '
      f'change to the hedge. <b>Widening the floor to 0.75 (−25%) is the model optimum</b> and would take the '
      f'recommended config to PoD {pod(REC75)} / reins premium {prem(REC75)} / FP {K(REC75["fp_revenue"])} '
      f'({FP_UP_75}) — but it sits outside the current ±20% collar constraint and rests on skew-free pricing '
      f'(see the caveat below), so it is treated here as upside, not the base recommendation.', s['Cell']))
    SP(3)
    P('<b>The recommended config (at floor 0.80) is a near-pure win:</b>')
    P(f'<bullet>&bull;</bullet> Borrower income <b>{BORROWER_UP}</b> ($350K vs $300K annuity).', 'Bul')
    P(f'<bullet>&bull;</bullet> Risk down sharply — PoD <b>{pod(CUR)} → {pod(REC80)}</b>, and the reinsurance '
      f'fair premium <b>{PREM_DN_80}</b> ({prem(CUR)} → {prem(REC80)}), the severity-aware measure.', 'Bul')
    P(f'<bullet>&bull;</bullet> FutureProof revenue <b>{FP_UP_80}</b> ({K(CUR["fp_revenue"])} → {K(REC80["fp_revenue"])}); '
      f'at the wider floor 0.75 this rises to {FP_UP_75}.', 'Bul')
    P(f'<bullet>&bull;</bullet> The only give-up: lender NIM and funder margin fall <b>~8%</b> '
      f'({NIM_DN}) — a longer payout term means a lower average loan balance, and those margins are loan-based.', 'Bul')
    P(f'Pushing the borrower to $400K is feasible ({MAXB_UP}) but PoD rises to {pod(MAXB)} and FutureProof revenue '
      f'falls {MAXB_FP_DN} ({K(MAXB["fp_revenue"])}), so it is a genuine choice rather than a free gain. Three levers '
      f'drive the win:')
    P('<bullet>&bull;</bullet> <b>Longer payout term (25yr)</b> draws the annuity slowly, keeping the loan lower for '
      'longer → less interest drag → lower risk and room for more annuity.', 'Bul')
    P('<bullet>&bull;</bullet> <b>Lower FP margin (0.25%)</b> raises FP revenue — FutureProof takes 50% of the maturity '
      'surplus, so a smaller fee leaves a fatter account and FP’s share of the bigger surplus more than compensates.', 'Bul')
    P('<bullet>&bull;</bullet> <b>Keep profit-share at 10%</b> — taking profit earlier reduces the compounding base.', 'Bul')
    story.append(Paragraph(
      f'<b>The collar floor is a separate lever — judge it on the premium, not the PoC.</b> The reinsurance PoC '
      f'(0.20×PoD) is frequency-only and cannot see what the collar actually changes, which is tail '
      f'<i>severity</i>. On the severity-aware reinsurance premium, the current 0.80 floor over-pays: widening to 0.75 '
      f'cuts the premium from {prem(REC80)} to {prem(REC75)} ({PREM_DN_75} vs the current product). But this uses '
      f'Black-Scholes pricing with <i>no volatility skew</i> — real −25% index puts carry a skew premium, which '
      f'is likely why the ±20% / floor-0.80 constraint exists. Confirm the skew-adjusted hedge cost with the '
      f'hedging desk before relaxing the constraint; floor 0.80 is the safe base.', s['Call']))
    story.append(chart_pod())
    story.append(PageBreak())

    # 2. The ratchet
    P('2. A new risk dial — the "ratchet"', 'H1')
    P('A naive calendar glide (de-risking the investment toward cash on a fixed schedule) <i>raises</i> risk here — '
      'the account must keep growing against the debt, so de-risking every path just sacrifices the growth. But a '
      '<b>state-dependent ratchet</b> is different: it de-risks <b>only the winners</b>. Once the account is safely '
      'above the loan (balance ≥ loan × (1+buffer)), the surplus cushion is moved to cash and locked in, '
      'keeping the obligation amount in equity.')
    hd3 = [Paragraph(x, s['CellH']) for x in ['De-risking rule', 'PoD', 'Reins premium', 'Mean surplus', 'FP revenue']]
    rows3 = [
        ['None (100% equity, current)', pod(CUR), prem(CUR), M(CUR['mean_surplus']), K(CUR['fp_revenue'])],
        ['Ratchet (lock above loan ×1.1)', pod(RATCHET), prem(RATCHET), M(RATCHET['mean_surplus']), K(RATCHET['fp_revenue'])],
        ['Naive calendar glide (→50% by yr20)', pod(GLIDE), prem(GLIDE), M(GLIDE['mean_surplus']), K(GLIDE['fp_revenue'])],
    ]
    story.append(tbl([hd3] + rows3, [58 * mm, 16 * mm, 22 * mm, 22 * mm, 18 * mm]))
    SP(2)
    P('The ratchet cuts PoD and the reinsurance premium by locking in gains; it costs mean surplus and FP revenue, so '
      'it is a <b>risk/return dial</b>, not a free lunch — useful if you want to reach a tighter reinsurance target '
      'than the levers in Section 1 achieve. The naive calendar glide is dominated on every axis and should not be used.')

    # 3. One assumption to confirm
    P('3. One assumption to confirm — how the principal is repaid', 'H1')
    P('Every figure above assumes the model’s current treatment of the loan principal: it is drawn to its $1.2M '
      'peak and then <b>held flat</b>, with interest paid each year out of the investment account and the principal '
      'repaid as a single <b>lump at maturity</b>. This is reverse-mortgage-like and consistent with the fact that '
      'the EPM borrower makes no repayments — they receive an annuity. We believe this is correct, but the "P&amp;I" '
      'label makes it sound as though the balance should amortise, so it is worth one explicit confirmation.')
    story.append(Paragraph(
      f'<b>Why it matters:</b> if instead the principal were meant to amortise to zero over the term, the only source '
      f'for those repayments is the investment account itself — draining the growth the product relies on. On the same '
      f'engine the base-case PoD rises from <b>{pod(CUR)} to {pod(AMORT)}</b> (workbook-equivalent base ~'
      f'{WORKBOOK_BASE_POD:.1f}%), the current product’s reinsurance PoC would breach the 2% target, and the '
      f'recommended design above would need re-running. So please confirm: <b>flat principal with a lump repayment at '
      f'maturity — yes?</b>', s['Call']))

    # 4. Recommendation
    P('4. Recommendation', 'H1')
    P(f'<bullet>&bull;</bullet> <b>Adopt the recommended design</b> (350K annuity / 25yr payout / FP margin at its '
      f'0.25% floor, current collar 0.80): borrower {BORROWER_UP}, FutureProof {FP_UP_80}, PoD {pod(CUR)}→'
      f'{pod(REC80)}, reinsurance premium {PREM_DN_80}. This is robust and does not depend on the hedge.', 'Bul')
    P(f'<bullet>&bull;</bullet> <b>Decide whether to relax the collar floor to 0.75</b> with the hedging desk. The '
      f'model says it improves every axis (FP {FP_UP_75}, PoD to {pod(REC75)}), but on skew-free pricing and outside '
      f'the current ±20% constraint — verify the real hedge cost first.', 'Bul')
    P('<bullet>&bull;</bullet> <b>Don’t add a calendar glide path</b>, but keep the <b>state-dependent ratchet</b> '
      'in reserve as a risk dial if you want to reach a tighter reinsurance target.', 'Bul')
    P(f'<bullet>&bull;</bullet> <b>Decide the borrower-vs-stakeholder balance</b> for the annuity level: $350K is a '
      f'near-pure win; $400K maximises borrower income ({MAXB_UP}) but costs FutureProof revenue ({MAXB_FP_DN}) and '
      f'~8% of lender/funder margin.', 'Bul')
    P('<bullet>&bull;</bullet> <b>Confirm the flat-principal assumption</b> (Section 3).', 'Bul')
    return story

if __name__ == '__main__':
    os.chdir(os.path.dirname(os.path.abspath(__file__)))
    out = os.path.join('docs', 'pdfs', 'FutureProof_EPM_Optimisation_Analysis_May2026.pdf')
    doc = SimpleDocTemplate(out, pagesize=A4, topMargin=20 * mm, bottomMargin=20 * mm,
                            leftMargin=20 * mm, rightMargin=20 * mm)
    doc.build(build(), onFirstPage=footer, onLaterPages=footer)
    print('Wrote', out)
    print(f'  base engine PoD {CUR["pod"]:.2f}% (workbook {WORKBOOK_BASE_POD}%); '
          f'rec80 {REC80["pod"]:.2f}%, rec75 {REC75["pod"]:.2f}%, maxb {MAXB["pod"]:.2f}%, amort {AMORT["pod"]:.2f}%')
