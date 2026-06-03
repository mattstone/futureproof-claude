#!/usr/bin/env python3
"""FutureProof — Regional Regulatory Readiness (board briefing).

A director-facing distillation of the internal regional compliance work
(REGIONAL_COMPLIANCE_AUDIT.md + docs/compliance/{AU,NZ,UK,US}_COMPLIANCE.md).

Deliberately short and decision-focused: what each market requires, what binds us,
what is left before we can sign a customer, and a recommended entry order. The
internal AI-process planning content of the source audit (token budgets, model
selection, document-build sequencing) is intentionally omitted.

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
    s.add(ParagraphStyle('TitleBig', parent=s['Title'], fontSize=24, textColor=NAVY,
                         alignment=TA_CENTER))
    s.add(ParagraphStyle('Sub', parent=s['Title'], fontSize=13, textColor=TEAL,
                         alignment=TA_CENTER, spaceAfter=2))
    s.add(ParagraphStyle('SubL', parent=s['Title'], fontSize=11.5, textColor=NAVY,
                         alignment=TA_CENTER, spaceAfter=2, fontName='Helvetica'))
    s.add(ParagraphStyle('Red', parent=s['Title'], fontSize=11, textColor=CORAL,
                         alignment=TA_CENTER))
    s.add(ParagraphStyle('Cell', parent=s['BodyText'], fontSize=8.5, leading=11))
    s.add(ParagraphStyle('CellH', parent=s['BodyText'], fontSize=8.5, leading=11,
                         textColor=HexColor('#FFFFFF'), fontName='Helvetica-Bold'))
    return s


def tbl(data, widths, hdr=True):
    t = Table(data, colWidths=widths, repeatRows=1 if hdr else 0)
    st = [('GRID', (0, 0), (-1, -1), 0.4, GREY), ('VALIGN', (0, 0), (-1, -1), 'TOP'),
          ('FONTSIZE', (0, 0), (-1, -1), 8.5),
          ('TOPPADDING', (0, 0), (-1, -1), 5), ('BOTTOMPADDING', (0, 0), (-1, -1), 5),
          ('LEFTPADDING', (0, 0), (-1, -1), 6), ('RIGHTPADDING', (0, 0), (-1, -1), 6)]
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
    cellH = lambda t: Paragraph(t, s['CellH'])
    cell = lambda t: Paragraph(t, s['Cell'])

    # ---------------------------------------------------------------- COVER
    SP(46)
    P('FutureProof Financial', 'TitleBig'); SP(3)
    P('Regional Regulatory Readiness', 'Sub'); SP(6)
    P('What it takes to launch the Equity Preservation Mortgage in', 'SubL')
    P('Australia, New Zealand, the United Kingdom and the United States', 'SubL'); SP(10)
    P('BOARD BRIEFING — INTERNAL', 'Red'); SP(16)
    story.append(Paragraph(
        'The Equity Preservation Mortgage (EPM) is a <b>mortgage, not a loan the customer repays</b>. '
        'The customer receives a guaranteed income and makes no repayments; the lender and its funders '
        'carry the investment risk. Because that structure is genuinely new, the first regulatory '
        'question in every market is the same — <i>“what is this product?”</i> In all four markets it sits '
        'closest to equity-release / reverse-mortgage rules and can be operated inside existing credit and '
        'mortgage regimes. <b>None of the requirements in this briefing challenge the model.</b> They are '
        'executional: a classification ruling, the right licence, and locally-correct disclosure and '
        'contracts before we can sign a customer.', s['Call']))
    SP(2)
    P('Three things decide how fast we can open each market:')
    B('<b>Classification</b> — confirming the EPM is treated as a (reverse / lifetime) mortgage rather than '
      'a managed investment or security. This is the single biggest variable, and is best settled up front '
      'by a regulator ruling, no-action letter, or sandbox engagement.')
    B('<b>Licensing</b> — a single national licence in Australia, the UK and New Zealand; '
      'state-by-state in the United States.')
    B('<b>Distribution</b> — the UK requires every sale through a qualified adviser (no online-only); '
      'the other three are more flexible.')
    story.append(PageBreak())

    # ---------------------------------------------------------------- 1. AT A GLANCE
    P('1. Readiness at a glance', 'H1')
    P('The regulatory path is defined in all four markets, and nothing is a blocker to the product. '
      'The table below is the whole picture on one page; the sections that follow add only what a '
      'decision needs.')
    SP(2)
    head = [cellH(x) for x in ['Market', 'Regulator(s)', 'Likely classification &amp; licence we must hold',
                               'Hardest single requirement', 'Setup<br/>weight']]
    rows = [
        [cell('<b>Australia</b>'), cell('ASIC<br/>(APRA prudential)'),
         cell('Credit contract under the National Credit Code &mdash; <b>Australian Credit Licence (ACL)</b>'),
         cell('Confirming it is <i>credit</i>, not a managed investment scheme'),
         cell('Medium')],
        [cell('<b>New Zealand</b>'), cell('FMA, Commerce<br/>Commission, RBNZ'),
         cell('Consumer credit contract under the CCCFA &mdash; <b>FSP registration</b> + dispute scheme (no bespoke lending licence)'),
         cell('CCCFA responsible-lending verification; KiwiSaver conflict'),
         cell('Low')],
        [cell('<b>United Kingdom</b>'), cell('FCA<br/>(PRA prudential)'),
         cell('Lifetime mortgage / equity release (MCOB&nbsp;12) &mdash; <b>FCA authorisation</b> (mortgage + investment permissions)'),
         cell('Advised-only sales by CeRER-qualified advisers'),
         cell('High')],
        [cell('<b>United States</b>'), cell('CFPB, SEC,<br/>50 state regulators'),
         cell('Proprietary (non-FHA) reverse mortgage &mdash; <b>state-by-state NMLS licences</b>'),
         cell('50-state licensing; avoiding SEC &ldquo;security&rdquo; classification'),
         cell('Highest')],
    ]
    story.append(tbl([head] + rows, [22 * mm, 26 * mm, 56 * mm, 42 * mm, 16 * mm]))
    SP(3)
    story.append(Paragraph(
        '<b>Recommended entry order: New Zealand and Australia first, then the UK, then the US.</b> '
        'New Zealand and Australia authorise fastest and fit existing credit law cleanly; the UK carries '
        'the strongest customer proposition (Inheritance-Tax efficiency) but the heaviest setup; the US is '
        'the most fragmented and most expensive, and should come last. Weigh this regulatory-effort view '
        'against where the commercial opportunity is strongest.', s['Call']))
    story.append(PageBreak())

    # ---------------------------------------------------------------- 2. PER MARKET
    P('2. What each market requires', 'H1')

    P('Australia', 'H2')
    P('<b>Classification &amp; licence.</b> Almost certainly a credit contract under the National Credit '
      'Code, requiring an Australian Credit Licence (held by FutureProof or its lender partners). The live '
      'risk is that ASIC instead treats the income stream or investment as a managed investment scheme or '
      'financial product (AFSL). Settle this with an ASIC product ruling or no-action letter before launch.')
    P('<b>What binds us:</b>')
    B('Responsible lending, adapted to a no-repayment product — the test shifts from repayment '
      'affordability to assets, objectives, age, and capacity to meet rates, insurance and maintenance.')
    B('Maximum 80% LVR, independent valuation, annual revaluation with defined trigger points.')
    B('Pre-contractual disclosure (credit guide, key-facts sheet) and 7-year record retention.')
    P('<b>Market-specific:</b> EPM income can affect age-pension eligibility and interact with '
      'superannuation — this must be assessed and disclosed.')

    P('New Zealand', 'H2')
    P('<b>Classification &amp; licence.</b> A consumer credit contract under the CCCFA. New Zealand has no '
      'equity-release category and — importantly — no bespoke lending licence: the pathway is registration '
      'as a Financial Service Provider plus membership of an approved dispute-resolution scheme. A Financial '
      'Advice Provider licence is likely if we advise on the investment component. This is the '
      '<b>lightest-touch path of the four</b>.')
    P('<b>What binds us:</b>')
    B('CCCFA responsible-lending — verify the customer can meet rates, insurance and maintenance '
      '(roughly NZ$6k–23k p.a.) from existing plus EPM income.')
    B('Full pre-contractual and continuing disclosure; directors must pass a fit-and-proper assessment.')
    P('<b>Market-specific:</b> an EPM can block a KiwiSaver first-home withdrawal — screen and disclose. '
      'Special rules apply to Maori freehold land.')

    P('United Kingdom', 'H2')
    P('<b>Classification &amp; licence.</b> The closest fit is a lifetime mortgage (equity release) under '
      'MCOB&nbsp;12, requiring FCA authorisation with mortgage and, likely, investment permissions. The '
      'consumer-risk-free structure may qualify for expedited review — engage the FCA Innovation Hub / '
      'sandbox early.')
    P('<b>What binds us:</b>')
    B('<b>Advised-only sales</b> — no execution-only or online-only. Every customer must receive advice '
      'from an adviser holding the equity-release qualification (CeRER). This shapes the entire UK '
      'distribution model.')
    B('Mandatory No Negative Equity Guarantee (the EPM already exceeds it), personalised illustration, '
      'and Consumer Duty obligations.')
    P('<b>Market-specific — the strongest proposition of any market:</b> the mortgage stands as a liability '
      'against the estate, which can reduce Inheritance Tax (40% above the threshold). Confirm the '
      'wrapper-level tax treatment with UK counsel before this is used in marketing.')

    P('United States', 'H2')
    P('<b>Classification &amp; licence.</b> Structure as a proprietary (non-FHA) reverse mortgage to stay '
      'clear of HECM rules; it remains subject to TILA/RESPA and state mortgage law. Licensing is '
      'state-by-state through NMLS — the single largest compliance burden of any market. The investment '
      'component creates SEC &ldquo;security&rdquo; risk under the Howey test; structure so the customer '
      'receives income from the mortgage (not investment returns directly) and obtain an SEC opinion or '
      'no-action letter.')
    P('<b>What binds us:</b>')
    B('NMLS entity and originator licences per state — each with net-worth, surety-bond, FBI-check and '
      'continuing-education requirements, renewed annually.')
    B('TILA / TRID disclosures and an independent appraisal on every file.')
    P('<b>Market-specific:</b> do not launch nationally. Start with high-value markets — California, New '
      'York, Florida and Arizona cover roughly 40% of the target market. Highest cost and longest lead '
      'time of the four.')
    story.append(PageBreak())

    # ---------------------------------------------------------------- 3. CROSS-CUTTING
    P('3. Requirements that span all markets', 'H1')

    P('Data residency &amp; security', 'H2')
    P('The UK is the only market that requires data residency (UK GDPR — keep processing within the '
      'UK/EEA; EU hosting is acceptable if documented). Australia and New Zealand impose no localisation '
      'requirement; the US is state-led, with California (CCPA) the strictest. The efficient approach is to '
      'build once to the highest common bar: AES-256 at rest, TLS&nbsp;1.3 in transit, 7-year audit-trail '
      'retention, processor data-processing agreements, and payment handling through a PCI-compliant '
      'provider. SOC&nbsp;2 / ISO&nbsp;27001 are expected for UK and US operations and for investor due '
      'diligence; GDPR compliance is mandatory for the UK.')

    P('Breach notification', 'H2')
    head = [cellH(x) for x in ['Market', 'Notify the regulator within', 'Regulator']]
    rows = [
        [cell('Australia'), cell('As soon as practicable (assessment within 30 days)'), cell('OAIC')],
        [cell('New Zealand'), cell('Without undue delay'), cell('Privacy Commissioner')],
        [cell('United Kingdom'), cell('<b>72 hours</b>'), cell('ICO')],
        [cell('United States'), cell('State-dependent (California / Massachusetts ~30 days)'), cell('State Attorney-General')],
    ]
    story.append(tbl([head] + rows, [32 * mm, 88 * mm, 50 * mm]))
    SP(2)
    P('Build the breach process to the UK 72-hour standard and it satisfies every market.')

    P('Tax treatment', 'H2')
    P('Income, capital-gains and inheritance treatment differ materially by market. This is local-counsel '
      'territory and must never be presented to customers as tax advice. The one strategic point for the '
      'board: the UK Inheritance-Tax efficiency is a genuine differentiator — confirm the specifics '
      '(including investment-wrapper treatment) with UK tax counsel before relying on it commercially.')

    P('Estate &amp; inheritance', 'H2')
    P('The EPM is <b>not called due on death</b>. The home is not force-sold; the estate inherits the '
      'investment upside, and the mortgage stands as a liability against the estate. The required estate '
      'documentation — will reference, beneficiary options, post-death portfolio management — is '
      'straightforward, not a barrier.')

    P('Insurance', 'H2')
    P('Buildings insurance and property upkeep remain the customer’s responsibility (a disclosure and '
      'serviceability point, captured above). Because the customer makes no repayments, traditional '
      'mortgage-protection and income-protection insurance are <b>not relevant</b> to the EPM — the failure '
      'mode they exist to cover does not arise here. Lender-side investment and tail risk is managed '
      'through the reinsurance structure, covered in a separate paper.')
    story.append(PageBreak())

    # ---------------------------------------------------------------- 4. DONE / LEFT
    P('4. What is done, and what is left', 'H1')
    P('<b>Done (internal).</b> Detailed compliance analysis exists for all four markets, plus a security '
      'framework and tax / estate treatment. That work is the substance behind this briefing; it does not '
      'need redoing.')
    SP(1)
    P('<b>Left — the gate to the first customer in any chosen market:</b>')
    B('<b>External legal sign-off</b> of the product classification in that market.')
    B('<b>Regulatory engagement</b> to lock classification — ASIC ruling / no-action (AU), FCA sandbox '
      '(UK), SEC opinion (US), FMA guidance (NZ).')
    B('<b>Licence / authorisation</b> — ACL (AU), FCA authorisation (UK), FSP registration (NZ), NMLS state '
      'licences (US).')
    B('<b>Localised contracts, disclosures and illustrations</b> to the market’s rules.')
    B('<b>Data / security baseline</b> — encryption, retention, DPAs and breach process — built once to '
      'the highest bar.')
    SP(1)
    P('None of these is a research question. All are execution with known lead times.')

    P('5. Recommendation', 'H1')
    B('<b>Sequence the markets.</b> Open New Zealand and Australia first (fastest to authorise, cleanest '
      'fit to credit law); follow with the UK (highest-value proposition, but advised-only distribution '
      'and FCA authorisation take longer to stand up); take the US last (state-by-state licensing and SEC '
      'risk make it the slowest and most expensive).')
    B('<b>Settle classification early</b> in each market. It is the one variable that can move timelines by '
      'quarters, and it is resolved by a ruling — not by building.')
    B('<b>Build the data / security and breach baseline once</b>, to the UK/GDPR bar; it then satisfies '
      'every market.')
    B('<b>Decide the first market now</b> so external counsel and licensing can start in parallel. That — '
      'not the financial model — is the critical path to the first customer.')
    SP(6)
    story.append(Paragraph(
        f'Prepared for the board from the internal regional compliance analysis '
        f'(REGIONAL_COMPLIANCE_AUDIT.md and the per-market compliance files). Built {date.today().isoformat()}.',
        s['Cell']))
    return story


if __name__ == '__main__':
    os.chdir(os.path.dirname(os.path.abspath(__file__)))
    out = os.path.join('docs', 'pdfs', 'FutureProof_Regional_Regulatory_Readiness_Jun2026.pdf')
    doc = SimpleDocTemplate(out, pagesize=A4, topMargin=20 * mm, bottomMargin=22 * mm,
                            leftMargin=20 * mm, rightMargin=20 * mm)
    doc.build(build(styles()), onFirstPage=footer, onLaterPages=footer)
    print('Wrote', out)
