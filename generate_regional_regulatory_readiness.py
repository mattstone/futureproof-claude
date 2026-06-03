#!/usr/bin/env python3
"""FutureProof — Regional Regulatory Readiness (board briefing).

A director-facing distillation of the internal regional compliance work:
- REGIONAL_COMPLIANCE_AUDIT.md (originating gap analysis)
- docs/compliance/AUSTRALIA_COMPLIANCE.md, NZ_COMPLIANCE.md, UK_COMPLIANCE.md,
  US_COMPLIANCE.md, REGULATORY_ASSESSMENT_AU.md

Decision-focused: per market — classification fork, licence, AML/CFT, binding
obligations, indicative lead-times/costs — plus a legislation appendix. The internal
AI-process planning content of the source audit (token budgets, model selection,
build sequencing) is intentionally omitted.

House style matches docs/pdfs/ (navy/teal, A4, cover page, footer, tables, callouts).
"""
import os
from datetime import date
from reportlab.lib.pagesizes import A4
from reportlab.lib.units import mm
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.enums import TA_JUSTIFY, TA_CENTER
from reportlab.lib.colors import HexColor
from reportlab.platypus import (SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle,
                                PageBreak)

NAVY = HexColor('#2C3E50'); TEAL = HexColor('#3498A8'); CORAL = HexColor('#C0392B')
GREEN = HexColor('#27AE60'); AMBER = HexColor('#F39C12')
HEADER_BG = NAVY; ROW_ALT = HexColor('#F8F9FA'); GREY = HexColor('#95A5A6')


def styles():
    s = getSampleStyleSheet()
    s.add(ParagraphStyle('Body2', parent=s['BodyText'], fontSize=10, leading=14,
                         alignment=TA_JUSTIFY, spaceAfter=6))
    s.add(ParagraphStyle('H1', parent=s['Heading1'], fontSize=15, textColor=NAVY,
                         spaceBefore=10, spaceAfter=8, keepWithNext=1))
    s.add(ParagraphStyle('H2', parent=s['Heading2'], fontSize=12, textColor=TEAL,
                         spaceBefore=10, spaceAfter=3, keepWithNext=1))
    s.add(ParagraphStyle('Bul', parent=s['BodyText'], fontSize=10, leading=14,
                         leftIndent=12, spaceAfter=3))
    s.add(ParagraphStyle('Call', parent=s['BodyText'], fontSize=10, leading=14.5,
                         alignment=TA_JUSTIFY, backColor=HexColor('#EAF3F5'),
                         borderColor=TEAL, borderWidth=0.6, borderPadding=11,
                         spaceBefore=14, spaceAfter=14, textColor=NAVY))
    s.add(ParagraphStyle('Warn', parent=s['BodyText'], fontSize=10, leading=14.5,
                         alignment=TA_JUSTIFY, backColor=HexColor('#FCF0EC'),
                         borderColor=CORAL, borderWidth=0.6, borderPadding=11,
                         spaceBefore=12, spaceAfter=12, textColor=NAVY))
    s.add(ParagraphStyle('TitleBig', parent=s['Title'], fontSize=24, textColor=NAVY,
                         alignment=TA_CENTER))
    s.add(ParagraphStyle('Sub', parent=s['Title'], fontSize=13, textColor=TEAL,
                         alignment=TA_CENTER, spaceAfter=2))
    s.add(ParagraphStyle('SubL', parent=s['Title'], fontSize=11.5, textColor=NAVY,
                         alignment=TA_CENTER, spaceAfter=2, fontName='Helvetica'))
    s.add(ParagraphStyle('Red', parent=s['Title'], fontSize=11, textColor=CORAL,
                         alignment=TA_CENTER))
    s.add(ParagraphStyle('Cell', parent=s['BodyText'], fontSize=8.3, leading=10.8))
    s.add(ParagraphStyle('CellH', parent=s['BodyText'], fontSize=8.3, leading=10.8,
                         textColor=HexColor('#FFFFFF'), fontName='Helvetica-Bold'))
    s.add(ParagraphStyle('Caveat', parent=s['BodyText'], fontSize=8.5, leading=11.5,
                         textColor=HexColor('#5A6B7B'), alignment=TA_JUSTIFY, spaceBefore=2))
    return s


def tbl(data, widths, hdr=True, fs=8.3):
    t = Table(data, colWidths=widths, repeatRows=1 if hdr else 0)
    st = [('GRID', (0, 0), (-1, -1), 0.4, GREY), ('VALIGN', (0, 0), (-1, -1), 'TOP'),
          ('FONTSIZE', (0, 0), (-1, -1), fs),
          ('TOPPADDING', (0, 0), (-1, -1), 4.5), ('BOTTOMPADDING', (0, 0), (-1, -1), 4.5),
          ('LEFTPADDING', (0, 0), (-1, -1), 5), ('RIGHTPADDING', (0, 0), (-1, -1), 5)]
    if hdr:
        st += [('BACKGROUND', (0, 0), (-1, 0), HEADER_BG),
               ('ROWBACKGROUNDS', (0, 1), (-1, -1), [HexColor('#FFFFFF'), ROW_ALT])]
    t.setStyle(TableStyle(st))
    return t


def footer(canvas, doc):
    canvas.saveState()
    canvas.setStrokeColor(GREY); canvas.setLineWidth(0.4)
    canvas.line(20 * mm, 15 * mm, 190 * mm, 15 * mm)
    canvas.setFont('Helvetica', 8); canvas.setFillColor(GREY)
    canvas.drawString(20 * mm, 11 * mm,
                      'FutureProof  |  Regional Regulatory Readiness  |  Board Briefing — Internal  |  June 2026')
    canvas.drawRightString(190 * mm, 11 * mm, f'Page {doc.page}')
    canvas.restoreState()


def build(s):
    story = []
    P = lambda t, st='Body2': story.append(Paragraph(t, s[st]))
    SP = lambda h=4: story.append(Spacer(1, h * mm))
    B = lambda t: story.append(Paragraph(f'<bullet>&bull;</bullet> {t}', s['Bul']))
    cH = lambda t: Paragraph(t, s['CellH'])
    c = lambda t: Paragraph(t, s['Cell'])

    # ---------------------------------------------------------------- COVER
    SP(40)
    P('FutureProof Financial', 'TitleBig'); SP(3)
    P('Regional Regulatory Readiness', 'Sub'); SP(6)
    P('What it takes to launch the Equity Preservation Mortgage in', 'SubL')
    P('Australia, New Zealand, the United Kingdom and the United States', 'SubL'); SP(10)
    P('BOARD BRIEFING — INTERNAL', 'Red'); SP(14)
    story.append(Paragraph(
        'The Equity Preservation Mortgage (EPM) is a <b>mortgage, not a loan the customer repays</b>. '
        'The customer receives a guaranteed income and makes no repayments; the lender and its funders carry '
        'the investment risk. Because that structure is genuinely new, the first regulatory question in every '
        'market is the same — <i>"what is this product?"</i> — and the answer carries a <b>light path and a heavy '
        'path</b>. Which one applies is the single biggest driver of cost and time. <b>None of this challenges '
        'the model.</b> It is executional: a classification ruling, the right licence, locally-correct '
        'disclosure and contracts, before we can sign a customer.', s['Call']))
    SP(1)
    P('Three things decide how fast we can open each market:')
    B('<b>Classification — the master variable.</b> Is the investment / income component a regulated '
      '<i>financial product</i> (AU: AFSL; NZ: FAP or managed-investment scheme; UK: COBS / managed '
      'investment; US: an SEC "security")? Or can it sit in the simpler mortgage / credit lane? Light vs heavy '
      'path — best settled up front by a legal opinion, regulator ruling, no-action letter or sandbox. See §2.')
    B('<b>Licensing.</b> A single national licence in Australia, the UK and New Zealand; '
      '<b>state-by-state</b> in the United States.')
    B('<b>Distribution.</b> The UK requires <b>advised-only sales</b> through qualified advisers (no '
      'online-only) — which directly constrains an AI-led acquisition model. The other three are more flexible.')
    story.append(PageBreak())

    # ---------------------------------------------------------------- 1. AT A GLANCE
    P('1. Readiness at a glance', 'H1')
    P('The regulatory path is defined in all four markets, and nothing is a blocker to the product. The '
      'one variable that moves timelines by quarters is the classification fork (§2).')
    SP(2)
    head = [cH(x) for x in ['Market', 'Regulator(s)', 'Likely classification &amp; licence',
                            'Hardest single requirement', 'Setup<br/>weight']]
    rows = [
        [c('<b>New Zealand</b>'), c('FMA, Commerce<br/>Commission, RBNZ'),
         c('Consumer credit (CCCFA) — <b>FSP registration</b> + dispute scheme; <b>no bespoke lending licence</b>'),
         c('Investment-component classification (FAP / managed scheme)'), c('Low–Med')],
        [c('<b>Australia</b>'), c('ASIC, APRA,<br/>AUSTRAC, AFCA'),
         c('Credit contract (National Credit Code) — <b>ACL</b>; <b>AFSL likely</b> for the investment / advice'),
         c('ACL-vs-AFSL fork; comparison-rate problem'), c('Med–High*')],
        [c('<b>United Kingdom</b>'), c('FCA, PRA,<br/>NCA, ICO'),
         c('Lifetime mortgage / equity release (MCOB 12) — <b>FCA authorisation</b> + investment permission'),
         c('Advised-only sales by CeRER-qualified advisers'), c('High')],
        [c('<b>United States</b>'), c('CFPB, SEC,<br/>FinCEN, 50 states'),
         c('Proprietary (non-FHA) reverse mortgage — <b>state-by-state NMLS</b> licences'),
         c('50-state licensing + SEC "security" (Howey) risk'), c('Highest')],
    ]
    story.append(tbl([head] + rows, [22 * mm, 25 * mm, 53 * mm, 40 * mm, 22 * mm]))
    SP(1)
    P('* Australia is rated Med–High because its timeline depends entirely on the classification fork: the '
      'credit / ACL path is weeks-to-months, but if the investment advice is treated as <i>personal</i> advice '
      'the AFSL path is ~6–12 months (see §2 and §3).', 'Caveat')
    SP(2)
    story.append(Paragraph(
        '<b>Indicative entry order: New Zealand, then Australia, then the UK, then the US</b> — subject to two '
        'honest caveats. (1) Australia\'s "speed" holds only if it stays in the credit / general-advice lane; '
        'the personal-advice AFSL path is UK-scale. (2) The UK\'s advised-only rule may be incompatible with a '
        'self-service / AI-led acquisition model — treat UK as a strategic decision, not just a sequencing one. '
        'Weigh all of this against where the commercial opportunity is strongest.', s['Call']))
    story.append(PageBreak())

    # ---------------------------------------------------------------- 2. MASTER VARIABLE
    P('2. The master variable — one product, two paths', 'H1')
    P('The EPM bundles a mortgage with a managed investment that funds the customer\'s income. Every '
      'regulator will ask whether that investment / income element makes it a <b>regulated financial product</b> '
      '(heavy path) or whether it can be run as a <b>mortgage / credit product</b> (light path). The same '
      'question recurs in all four markets, under different names:')
    SP(2)
    head = [cH(x) for x in ['Market', 'Light path (mortgage / credit)', 'Heavy path (financial product / security)',
                            'What tips it heavy']]
    rows = [
        [c('<b>AU</b>'), c('ACL only; <b>general</b>-advice warnings; fund-manager PDS provided'),
         c('<b>AFSL</b> — and if <i>personal</i> advice: Statement of Advice, Best Interests Duty, qualified advisers (~6–12 mo)'),
         c('Giving the customer personalised income projections ("you\'ll get $3,200/mo")')],
        [c('<b>NZ</b>'), c('FSP registration + CCCFA compliance'),
         c('<b>FAP licence</b> (FMA) and/or <b>managed-investment scheme</b> (FMC Act Pt 4)'),
         c('Advising on the investment, or pooling customer funds')],
        [c('<b>UK</b>'), c('Lifetime mortgage under MCOB 12'),
         c('Additional <b>investment (COBS) permission</b>; possible managed-investment treatment + FCA waiver'),
         c('Managing / advising on the portfolio component')],
        [c('<b>US</b>'), c('Proprietary reverse mortgage (loan advances)'),
         c('An SEC <b>"security"</b> under the Howey test — registration / no-action burden'),
         c('Income tied to investment returns; any pooling; portfolio language to customers')],
    ]
    story.append(tbl([head] + rows, [16 * mm, 46 * mm, 64 * mm, 44 * mm]))
    SP(3)
    story.append(Paragraph(
        '<b>Implication.</b> Settle this question first in each market — by legal opinion plus regulator '
        'engagement (ASIC ruling, FMA guidance, FCA sandbox, SEC no-action). It is the difference between a '
        'weeks-to-months launch and a 6–12-month one, and it is resolved by a ruling, not by building. The '
        'standard mitigation is the same everywhere: structure income as arising from the <b>mortgage</b>, keep '
        'the customer out of any pooled or discretionary investment, and give <b>general</b> rather than '
        'personal advice.', s['Call']))
    story.append(PageBreak())

    # ---------------------------------------------------------------- 3. PER MARKET
    P('3. What each market requires', 'H1')

    # ---- NZ
    P('New Zealand', 'H2')
    P('<b>Regulators:</b> FMA, Commerce Commission, RBNZ; DIA (AML); Privacy Commissioner.')
    P('<b>Classification &amp; licence.</b> Consumer credit under the CCCFA, with <b>no bespoke lending '
      'licence</b> — the lightest licensing of the four. The pathway is registration as a Financial Service '
      'Provider plus membership of an approved dispute-resolution scheme. A <b>Financial Advice Provider (FAP) '
      'licence is likely</b> if we advise on the investment, and a managed-investment-scheme classification is '
      'possible if the portfolio is pooled — the §2 fork.')
    P('<b>What binds us:</b>')
    B('CCCFA responsible lending — verify the customer can meet property costs (~NZ$6k–23k p.a.) from existing '
      'plus EPM income; full pre-contractual and continuing disclosure (s17–33).')
    B('Mandatory dispute-resolution scheme (FSCL / FDRS / IFSO); 40-working-day internal-complaints target; '
      'scheme decisions binding up to NZ$350k.')
    B('<b>Maori freehold land must be excluded at launch</b> (Te Ture Whenua Maori Act 1993 — Land Court '
      'approval required); credit reporting under the Credit Reporting Privacy Code.')
    B('AML/CFT Act 2009 (supervisor DIA, or FMA/RBNZ by entity type) — see the AML comparison in §4.')
    P('<b>Open item:</b> who bears <b>FIF tax</b> on the portfolio (customer vs lender) is unresolved and '
      'materially affects net income to the customer — settle in product design.')
    P('<b>Market-specific (a real tailwind):</b> <b>NZ Super is not income-tested</b> — EPM income does not '
      'reduce NZ Super. This removes a whole class of suitability friction that exists in Australia.')

    # ---- AU
    P('Australia', 'H2')
    P('<b>Regulators:</b> ASIC (conduct), APRA (prudential), AUSTRAC (AML), AFCA (disputes).')
    P('<b>Classification &amp; licence.</b> An <b>ACL</b> is almost certain (credit). The question that sizes '
      'the whole AU effort is <b>AFSL</b>: managing the portfolio and giving income projections likely triggers '
      'it. <b>General-advice-only</b> is the lighter route (warnings, fund-manager PDS, no personal '
      'recommendations); <b>personal advice</b> is much heavier — Statement of Advice, Best Interests Duty and '
      'qualified advisers, a ~6–12-month build. Settle via legal opinion plus ASIC guidance before launch.')
    P('<b>What binds us:</b>')
    B('Responsible lending adapted to a no-repayment product (assets, objectives, age, and capacity for rates / '
      'insurance / maintenance — not repayment affordability); 80% LVR, independent valuation, annual revaluation.')
    B('Pre-contractual disclosure (Credit Guide, Key Facts Sheet); 14-day cooling-off; hardship process and '
      '<b>AFCA</b> membership.')
    B('<b>Comparison-rate problem</b> — the mandatory comparison rate assumes repayments the EPM does not have; '
      'needs ASIC guidance or an alternative-disclosure exemption.')
    B('<b>Credit reporting</b> — the EPM appears on the customer\'s credit file and can affect future borrowing; '
      'must be disclosed. AUSTRAC AML obligations (§4).')
    P('<b>Market-specific:</b> EPM income is assessable under the <b>Age Pension</b> income test, and the '
      'portfolio may be deemed / assets-tested — taking an EPM can reduce pension entitlements, and this must be '
      'disclosed. (Contrast New Zealand.)')

    # ---- UK
    P('United Kingdom', 'H2')
    P('<b>Regulators:</b> FCA (conduct), PRA (prudential); NCA (AML reports); ICO (data); FOS (disputes).')
    P('<b>Classification &amp; licence.</b> Closest fit is a lifetime mortgage / equity release under MCOB 12, '
      'requiring FCA Part 4A authorisation with mortgage permissions and, likely, an <b>investment (COBS) '
      'permission</b>; a managed-investment treatment is possible and may need an FCA product waiver — engage '
      'the FCA Innovation Hub / sandbox early. Compliance Officer (CF10/11), MLRO (SMF17) and DPO must be in '
      'place before launch.')
    P('<b>What binds us:</b>')
    B('<b>Advised-only sales (MCOB 12.3) — no execution-only or online-only.</b> Every customer must be advised '
      'by someone holding the equity-release qualification (CeRER), and Equity Release Council membership is '
      'effectively essential for broker distribution.')
    B('No Negative Equity Guarantee (the EPM already exceeds it); personalised illustration (MCOB 12.4); '
      'Consumer Duty; financial promotions rules (MCOB 3A); FOS complaints (award limit £415,000); SCA / PSD2.')
    B('Money Laundering Regulations 2017 — SARs to the NCA, MLRO (SMF17); UK GDPR data residency (§4).')
    story.append(Paragraph(
        '<b>Strategic flags.</b> (1) Advised-only distribution structurally <b>blocks a self-service / AI-led '
        'funnel</b> in the UK — we would have to recruit and contract qualified advisers. (2) <b>IHT is not a '
        'safe headline:</b> the UK analysis\'s own worked example shows Inheritance Tax can be <i>higher</i> '
        'with an EPM in some cases. The dependable UK benefit is <b>tax-free lifetime income and the right to '
        'remain</b>; any IHT effect must be modelled per customer with an IHT specialist, never marketed as a '
        'blanket reduction.', s['Warn']))

    # ---- US
    P('United States', 'H2')
    P('<b>Regulators:</b> CFPB (federal conduct), SEC (securities), FinCEN / OFAC (AML), HUD / FHA '
      '(reverse-mortgage), plus 50 state regulators.')
    P('<b>Classification &amp; licence.</b> Structure as a <b>proprietary (non-FHA) reverse mortgage</b> to '
      'avoid HECM rules; it remains subject to TILA / RESPA and state law. Licensing is <b>state-by-state via '
      'NMLS</b> (entity + per-originator), each with net-worth, surety-bond, FBI-check and education '
      'requirements, renewed annually — about <b>3–6 months per state</b> (parallelisable). The <b>SEC / Howey '
      '"security" question is the highest risk and biggest schedule driver</b>: structure so the customer '
      'receives <b>loan advances, not investment returns</b> (no portfolio / returns language in customer '
      'materials) and obtain an SEC no-action letter or opinion (3–12 months) before launch.')
    P('<b>What binds us:</b>')
    B('TILA / Reg Z reverse-mortgage disclosures (TALC, right of rescission); RESPA; independent appraisal '
      '(FIRREA / USPAP); HMDA reporting at scale; UDAAP scrutiny (elderly demographic = high risk).')
    B('State reverse-mortgage overrides — e.g. California 7-day rescission, New York age 60 + HUD counseling, '
      'Texas constitutional 80% cap + 12-day wait.')
    B('Bank Secrecy Act AML — FinCEN (SARs, CTRs), OFAC SDN screening (strict liability, up to $20M+ per '
      'violation) (§4).')
    P('<b>Market-specific:</b> do not launch nationally. Phase 1 = <b>California, New York, Florida, Arizona</b> '
      '(~40% of the target market; Arizona simplest); defer Texas (constitutional restrictions). Highest cost '
      'and longest lead time of the four.')
    story.append(PageBreak())

    # ---------------------------------------------------------------- 4. CROSS-CUTTING
    P('4. Requirements that span all markets', 'H1')

    P('AML / CFT', 'H2')
    P('All four markets require a board-approved AML programme, risk-based customer due diligence (with PEP and '
      'sanctions screening), ongoing monitoring and a designated compliance officer. The regime differs only in '
      'plumbing — build once to a common standard and localise the reporting channel:')
    SP(2)
    head = [cH(x) for x in ['Market', 'Regime', 'Supervisor', 'Report channel &amp; key threshold report', 'Retain']]
    rows = [
        [c('AU'), c('AML/CTF Act 2006'), c('AUSTRAC'),
         c('AUSTRAC — SMR; Threshold Transaction Report for cash at/above A$10,000'), c('7 yrs')],
        [c('NZ'), c('AML/CFT Act 2009'), c('DIA (or FMA/RBNZ)'),
         c('FIU (NZ Police) via goAML — SAR; Prescribed Transaction Report cash >NZ$10k / wire >NZ$1k'), c('5 yrs')],
        [c('UK'), c('Money Laundering Regs 2017'), c('FCA (MLRO, SMF17)'),
         c('NCA via SAR Online — Suspicious Activity Report (no fixed cash threshold)'), c('5 yrs')],
        [c('US'), c('Bank Secrecy Act'), c('FinCEN / Treasury'),
         c('FinCEN BSA E-Filing — SAR; Currency Transaction Report cash >$10k; OFAC SDN screening'), c('5 yrs')],
    ]
    story.append(tbl([head] + rows, [16 * mm, 32 * mm, 30 * mm, 73 * mm, 14 * mm]))

    P('Data residency &amp; security', 'H2')
    P('The UK is the only market requiring data residency (UK GDPR — process within the UK/EEA; EU hosting '
      'acceptable if documented). Australia and New Zealand impose no localisation requirement; the US is '
      'state-led, with California (CCPA/CPRA) strictest. Build once to the highest common bar: AES-256 at rest, '
      'TLS 1.3 in transit, 7-year audit-trail retention, processor data-processing agreements, payments through '
      'a PCI-compliant provider. SOC 2 / ISO 27001 are expected for UK and US operations and for investor due '
      'diligence. <b>Note:</b> the AU assessment flags encryption-at-rest as a current <b>critical gap</b> to '
      'close before any launch.')

    P('Breach notification', 'H2')
    head = [cH(x) for x in ['Market', 'Notify the regulator within', 'Regulator (max penalty noted)']]
    rows = [
        [c('Australia'), c('As soon as practicable (assess within 30 days)'), c('OAIC (up to A$50M / 30% turnover)')],
        [c('New Zealand'), c('As soon as practicable'), c('Privacy Commissioner')],
        [c('United Kingdom'), c('<b>72 hours</b>'), c('ICO')],
        [c('United States'), c('State-dependent (CA / MA ~30 days)'), c('State Attorney-General')],
    ]
    story.append(tbl([head] + rows, [30 * mm, 80 * mm, 60 * mm]))
    SP(2)
    P('Build the breach process to the UK 72-hour standard and it satisfies every market.')

    P('Tax treatment', 'H2')
    P('Income, capital-gains and inheritance treatment differ materially by market — local-counsel territory, '
      'never presented to customers as tax advice. The points that matter to the board: <b>UK</b> — tax-free '
      'lifetime income is the dependable benefit; the IHT effect is case-specific (can go either way) and must '
      'be modelled per customer. <b>AU</b> — EPM income is assessable for the Age Pension. <b>NZ</b> — NZ Super '
      'is not income-tested (an advantage), but the FIF-tax question on the portfolio is open. <b>US</b> — '
      'structured as loan advances, the income is not taxable and no Form 1098 issues.')

    P('Estate &amp; inheritance', 'H2')
    P('The EPM is <b>not called due on death</b>. The home is not force-sold; the estate inherits the '
      'investment upside, and the mortgage stands as a liability against the estate. The required documentation '
      '(will reference, beneficiary options, post-death portfolio management) is straightforward.')

    P('Insurance', 'H2')
    P('Buildings insurance and upkeep remain the customer\'s responsibility (a disclosure / serviceability '
      'point). Because the customer makes no repayments, traditional mortgage-protection and income-protection '
      'insurance are <b>not relevant</b> — the failure mode they cover does not arise. Lender-side investment '
      'and tail risk is managed through the reinsurance structure, covered separately.')
    story.append(PageBreak())

    # ---------------------------------------------------------------- 5. LEAD TIMES & COSTS
    P('5. Indicative lead-times &amp; costs', 'H1')
    P('Only the Australian and US analyses carry costed estimates; the UK and NZ figures are not yet scoped '
      'and need local counsel. These are planning estimates, not quotes.')
    SP(2)
    head = [cH(x) for x in ['Market', 'Indicative timeline', 'Indicative cost', 'Basis']]
    rows = [
        [c('<b>NZ</b>'), c('FSP registration ~weeks; the gating item is the investment-classification opinion, not the registration'),
         c('Not scoped'), c('Local counsel')],
        [c('<b>AU</b>'),
         c('Legal opinion 2–4 wks; ACL ~45 business days; AML setup 4–6 wks — total <b>8–16 weeks</b>. '
           '<b>Add 6–12 months if the AFSL personal-advice path applies.</b>'),
         c('<b>~$40k–$90k</b> total (legal opinion $5–15k, ACL $5–10k, AML $15–30k, security audit $10–25k, '
           'AFCA $350/yr). AFSL personal-advice path: +$20–50k.'),
         c('Internal AU assessment')],
        [c('<b>UK</b>'), c('FCA authorisation is a multi-month process; standing up advised distribution '
                           '(CeRER advisers, ERC) is the larger dependency'),
         c('Not scoped'), c('Local counsel')],
        [c('<b>US</b>'), c('Per-state licensing <b>3–6 months</b> (parallelisable); SEC no-action '
                           '<b>3–12 months</b> — the binding schedule item'),
         c('Net worth $25k–$1M+ per state; surety bond $10k–$500k per state; full $ setup not scoped'),
         c('Internal US analysis')],
    ]
    story.append(tbl([head] + rows, [16 * mm, 61 * mm, 61 * mm, 32 * mm]))
    SP(2)
    P('These figures are planning estimates drawn from the internal compliance analysis (AU and US) or are '
      'indicative pending local counsel (UK and NZ). They are not legal advice; every classification call '
      'requires qualified local counsel in-market.', 'Caveat')

    P('6. What is done, and what is left', 'H1')
    P('<b>Done (internal).</b> Detailed compliance analysis exists for all four markets, plus a separate '
      'Australian regulatory assessment, a security framework and tax / estate treatment. The legislation behind '
      'it is listed in Appendix A.')
    SP(1)
    P('<b>Left — the gate to the first customer in any chosen market:</b>')
    B('<b>Settle the §2 classification fork</b> with external counsel and regulator engagement (ASIC ruling, '
      'FMA guidance, FCA sandbox, SEC no-action).')
    B('<b>Obtain the licence / authorisation</b> — FSP (NZ), ACL [+ AFSL] (AU), FCA authorisation (UK), NMLS '
      'state licences (US).')
    B('<b>Stand up AML, data-security and breach baselines</b> once, to the highest bar.')
    B('<b>Localise contracts, disclosures and illustrations</b> to the market\'s rules.')

    P('7. Recommendation', 'H1')
    B('<b>Settle classification first</b> in each market — it resolves the light-vs-heavy fork and is the one '
      'thing that moves timelines by quarters.')
    B('<b>Sequence NZ -> AU -> UK -> US</b>, but hold two caveats in view: Australia is only "fast" in the '
      'credit / general-advice lane (personal-advice AFSL is UK-scale), and the UK\'s advised-only rule may not '
      'fit a self-service / AI-led model — decide whether the UK warrants a separate adviser-based build or a '
      'later entry.')
    B('<b>Build the AML, security and breach baseline once</b>, to the UK/GDPR / 72-hour bar; it then satisfies '
      'every market.')
    B('<b>Decide the first market now</b> so counsel and licensing can start in parallel. That — not the '
      'financial model — is the critical path to the first customer.')
    story.append(PageBreak())

    # ---------------------------------------------------------------- APPENDIX A
    P('Appendix A — Legislation reviewed', 'H1')
    P('The instruments below were reviewed in the underlying per-market compliance analysis. This is a record '
      'of scope, not a legal opinion; enacted years are given for reference.')

    def leg_table(title, rows_data):
        P(title, 'H2')
        head = [cH(x) for x in ['Instrument', 'Regulator / body', 'Governs']]
        story.append(tbl([head] + [[c(a), c(b), c(d)] for a, b, d in rows_data],
                         [62 * mm, 32 * mm, 76 * mm]))

    leg_table('Australia', [
        ('National Consumer Credit Protection Act 2009 (incl. National Credit Code)', 'ASIC',
         'Credit licensing (ACL), responsible lending, disclosure, hardship'),
        ('Corporations Act 2001', 'ASIC', 'Financial product / AFSL, financial advice, managed investment schemes'),
        ('Australian Securities and Investments Commission Act 2001', 'ASIC', 'Consumer protection in financial services'),
        ('Competition and Consumer Act 2010 (Australian Consumer Law, Sch 2)', 'ACCC / ASIC',
         'Misleading conduct, unfair contract terms, consumer guarantees'),
        ('Anti-Money Laundering and Counter-Terrorism Financing Act 2006', 'AUSTRAC',
         'AML programme, KYC, SMR / TTR reporting'),
        ('Privacy Act 1988 (Australian Privacy Principles; NDB scheme)', 'OAIC',
         'Privacy, credit reporting, data-breach notification'),
        ('APRA prudential standards (e.g. APS 220 valuation)', 'APRA', 'LVR / valuation expectations for ADIs'),
        ('State duties &amp; land-titles legislation', 'State revenue / titles offices',
         'Mortgage duty (SA), mortgage registration / discharge'),
    ])
    leg_table('New Zealand', [
        ('Credit Contracts and Consumer Finance Act 2003 (incl. 2021 amendments)', 'Commerce Commission',
         'Responsible lending, disclosure, cooling-off, hardship'),
        ('Financial Markets Conduct Act 2013', 'FMA', 'Financial advice (FAP), managed investment schemes'),
        ('Financial Service Providers (Registration and Dispute Resolution) Act 2008', 'Companies Office / FMA',
         'FSP registration, mandatory dispute scheme'),
        ('Property Law Act 2007', 'Courts', 'Mortgage / security interest in land'),
        ('Te Ture Whenua Maori Act 1993', 'Maori Land Court', 'Restrictions on mortgaging Maori freehold land'),
        ('Anti-Money Laundering and Countering Financing of Terrorism Act 2009', 'DIA / FMA / RBNZ',
         'AML programme, CDD, SAR / PTR via goAML'),
        ('Privacy Act 2020 (incl. Credit Reporting Privacy Code 2004)', 'Privacy Commissioner',
         'Privacy, credit reporting, breach notification'),
    ])
    leg_table('United Kingdom', [
        ('Financial Services and Markets Act 2000 (Part 4A authorisation)', 'FCA / PRA',
         'Authorisation to carry on regulated activity'),
        ('FCA Handbook — MCOB (esp. ch. 12), COBS, CONC, PROD, DISP', 'FCA',
         'Mortgage / equity-release conduct, investments, product governance, complaints'),
        ('Consumer Duty (2023)', 'FCA', 'Good outcomes, fair value, consumer understanding &amp; support'),
        ('Consumer Credit Act 1974', 'FCA', 'Consumer-credit framework (context)'),
        ('Money Laundering, Terrorist Financing and Transfer of Funds Regulations 2017', 'FCA / NCA',
         'AML programme, CDD / EDD, SARs to the NCA'),
        ('UK GDPR &amp; Data Protection Act 2018', 'ICO', 'Data protection, residency, breach notification (72h)'),
        ('Payment Services Regulations / PSD2; eIDAS', 'FCA', 'Strong Customer Authentication; e-signatures'),
    ])
    leg_table('United States', [
        ('Truth in Lending Act / Reg Z (incl. §1026.33 reverse-mortgage)', 'CFPB',
         'APR / cost disclosure, rescission, appraisal independence'),
        ('Real Estate Settlement Procedures Act / Reg X; TRID', 'CFPB', 'Settlement disclosure, Loan Estimate / Closing Disclosure'),
        ('SAFE Act (2008)', 'NMLS / state &amp; federal regulators', 'Mortgage lender &amp; originator licensing'),
        ('Dodd-Frank Act (2010) — incl. §1031 UDAAP, §1472 appraisal', 'CFPB', 'Unfair/abusive practices; appraisal independence'),
        ('Securities Act of 1933; Investment Advisers Act of 1940; Howey test', 'SEC',
         '"Security" classification of the investment component'),
        ('FIRREA (1989) / USPAP; ECOA (Reg B); HMDA (Reg C)', 'Federal banking agencies / CFPB',
         'Appraisal standards; equal credit; mortgage data reporting'),
        ('Bank Secrecy Act; OFAC sanctions', 'FinCEN / OFAC (Treasury)', 'AML — SAR / CTR; SDN sanctions screening'),
        ('HECM regulations (FHA); state reverse-mortgage &amp; privacy statutes', 'HUD/FHA; state regulators',
         'Reverse-mortgage rules; state overrides (CA, NY, FL, TX) &amp; CCPA/CPRA'),
    ])
    SP(6)
    story.append(Paragraph(
        f'Prepared for the board from the internal regional compliance analysis (REGIONAL_COMPLIANCE_AUDIT.md, '
        f'the four per-market compliance files, and REGULATORY_ASSESSMENT_AU.md). Built {date.today().isoformat()}.',
        s['Cell']))
    return story


if __name__ == '__main__':
    os.chdir(os.path.dirname(os.path.abspath(__file__)))
    out = os.path.join('docs', 'pdfs', 'FutureProof_Regional_Regulatory_Readiness_Jun2026.pdf')
    doc = SimpleDocTemplate(out, pagesize=A4, topMargin=20 * mm, bottomMargin=22 * mm,
                            leftMargin=20 * mm, rightMargin=20 * mm)
    doc.build(build(styles()), onFirstPage=footer, onLaterPages=footer)
    print('Wrote', out)
