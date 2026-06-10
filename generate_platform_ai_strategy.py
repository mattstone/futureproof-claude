#!/usr/bin/env python3
"""FutureProof — Platform & AI Strategy (distributable, mixed senior audience).

A practical redo: what we're building, the stack and why (Rails: token-efficient for an
AI-built codebase, battle-tested), the system components and how they interact (with an
architecture chart), and how we develop, test, deploy and run it. Guff out, practical in.

Distributable. House PDF style (navy/teal, A4, cover, footer, tables, callouts).
Companion to the internal PLATFORM_BUILD_BRIEF.md.
"""
import os
from datetime import date
from reportlab.lib.pagesizes import A4
from reportlab.lib.units import mm
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.enums import TA_JUSTIFY, TA_CENTER, TA_LEFT
from reportlab.lib.colors import HexColor, white
from reportlab.platypus import (SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle,
                                PageBreak)

NAVY = HexColor('#2C3E50'); TEAL = HexColor('#3498A8'); CORAL = HexColor('#C0392B')
GREEN = HexColor('#27AE60'); AMBER = HexColor('#F39C12')
CHIP = HexColor('#EAF3F5'); TILE = HexColor('#F0F3F5'); ROW_ALT = HexColor('#F8F9FA')
GREY = HexColor('#95A5A6'); DEEP = HexColor('#DDEBEE')


def styles():
    s = getSampleStyleSheet()
    s.add(ParagraphStyle('Body', parent=s['BodyText'], fontSize=10.5, leading=15,
                         alignment=TA_JUSTIFY, spaceAfter=7))
    s.add(ParagraphStyle('H1', parent=s['Heading1'], fontSize=16, textColor=NAVY,
                         spaceBefore=12, spaceAfter=7, keepWithNext=1))
    s.add(ParagraphStyle('H2', parent=s['Heading2'], fontSize=12, textColor=TEAL,
                         spaceBefore=10, spaceAfter=3, keepWithNext=1))
    s.add(ParagraphStyle('Bul', parent=s['BodyText'], fontSize=10.5, leading=14.5,
                         leftIndent=12, spaceAfter=4))
    s.add(ParagraphStyle('Num', parent=s['BodyText'], fontSize=10.5, leading=14.5,
                         leftIndent=14, spaceAfter=5))
    s.add(ParagraphStyle('Call', parent=s['BodyText'], fontSize=10.5, leading=15,
                         alignment=TA_LEFT, backColor=CHIP, borderColor=TEAL,
                         borderWidth=0.6, borderPadding=12, spaceBefore=16, spaceAfter=16,
                         textColor=NAVY))
    s.add(ParagraphStyle('Lead', parent=s['BodyText'], fontSize=12, leading=17,
                         alignment=TA_LEFT, textColor=NAVY, spaceBefore=2, spaceAfter=8))
    s.add(ParagraphStyle('TitleBig', parent=s['Title'], fontSize=27, textColor=NAVY,
                         alignment=TA_CENTER))
    s.add(ParagraphStyle('Sub', parent=s['Title'], fontSize=15, textColor=TEAL,
                         alignment=TA_CENTER, spaceAfter=2))
    s.add(ParagraphStyle('SubL', parent=s['Title'], fontSize=11, textColor=GREY,
                         alignment=TA_CENTER, spaceAfter=2, fontName='Helvetica'))
    s.add(ParagraphStyle('Cell', parent=s['BodyText'], fontSize=9, leading=12))
    s.add(ParagraphStyle('CellH', parent=s['BodyText'], fontSize=9, leading=12,
                         textColor=white, fontName='Helvetica-Bold'))
    # diagram styles
    s.add(ParagraphStyle('aBand', parent=s['BodyText'], fontSize=10, leading=13,
                         alignment=TA_CENTER, textColor=white, fontName='Helvetica-Bold'))
    s.add(ParagraphStyle('aBox', parent=s['BodyText'], fontSize=9.5, leading=12.5,
                         alignment=TA_CENTER, textColor=white))
    s.add(ParagraphStyle('aBoxH', parent=s['BodyText'], fontSize=9.5, leading=12.5,
                         alignment=TA_CENTER, textColor=white, fontName='Helvetica-Bold'))
    s.add(ParagraphStyle('aChipH', parent=s['BodyText'], fontSize=9.5, leading=12,
                         alignment=TA_CENTER, textColor=NAVY, fontName='Helvetica-Bold'))
    s.add(ParagraphStyle('aChip', parent=s['BodyText'], fontSize=8.5, leading=11,
                         alignment=TA_CENTER, textColor=NAVY))
    s.add(ParagraphStyle('aFlow', parent=s['BodyText'], fontSize=8, leading=10,
                         alignment=TA_CENTER, textColor=TEAL, fontName='Helvetica-Oblique'))
    s.add(ParagraphStyle('aFoot', parent=s['BodyText'], fontSize=8.5, leading=11,
                         alignment=TA_CENTER, textColor=NAVY))
    return s


def tbl(data, widths):
    t = Table(data, colWidths=widths, repeatRows=1)
    t.setStyle(TableStyle([
        ('GRID', (0, 0), (-1, -1), 0.4, GREY), ('VALIGN', (0, 0), (-1, -1), 'TOP'),
        ('TOPPADDING', (0, 0), (-1, -1), 5), ('BOTTOMPADDING', (0, 0), (-1, -1), 5),
        ('LEFTPADDING', (0, 0), (-1, -1), 6), ('RIGHTPADDING', (0, 0), (-1, -1), 6),
        ('BACKGROUND', (0, 0), (-1, 0), NAVY),
        ('ROWBACKGROUNDS', (0, 1), (-1, -1), [white, ROW_ALT])]))
    return t


def architecture_diagram(s):
    """Layered architecture, top (customer) to bottom (funding), read downward."""
    P = lambda t, st: Paragraph(t, s[st])
    w = 170 / 3 * mm
    data = [
        [P('FRONT DOOR &mdash; per lender: customer (self-service) or adviser-led (UK)', 'aBand'), '', ''],
        [P('the customer (or adviser) starts a quote and an application', 'aFlow'), '', ''],
        [P('TENANT WEB APP &mdash; white-label Rails, one per lender<br/>application journey &middot; admin &middot; dashboards', 'aBoxH'), '', ''],
        [P('asks for a quote', 'aFlow'), P('delegates work to agents', 'aFlow'), P('queues comms &amp; tasks', 'aFlow')],
        [P('<b>PRODUCT BRAIN</b><br/>pricing &middot; actuarial<br/>business rules<br/>(central, versioned)', 'aChip'),
         P('<b>AI GATEWAY</b><br/>five agents<br/>human-approval gates<br/>every decision logged', 'aChip'),
         P('<b>BACKGROUND JOBS</b><br/>Solid Queue<br/>email &middot; lifecycle<br/>scheduled work', 'aChip')],
        [P('books &amp; funds the mortgage, and stands up its investment account', 'aFlow'), '', ''],
        [P('FUNDING LAYER &mdash; WHOLESALE FUNDERS', 'aBoxH'), '', ''],
        [P('wholesale funders &middot; mortgage pools &middot; insurance / reinsurance &middot; S&amp;P 500 hedge &middot; investment accounts', 'aBox'), '', ''],
        [P('Cross-cutting: per-lender data isolation, resident in-market &middot; audit log of every decision &middot; model &amp; compliance governance', 'aFoot'), '', ''],
    ]
    t = Table(data, colWidths=[w, w, w])
    t.setStyle(TableStyle([
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ('TOPPADDING', (0, 0), (-1, -1), 7), ('BOTTOMPADDING', (0, 0), (-1, -1), 7),
        # full-width spans
        ('SPAN', (0, 0), (2, 0)), ('SPAN', (0, 1), (2, 1)), ('SPAN', (0, 2), (2, 2)),
        ('SPAN', (0, 5), (2, 5)), ('SPAN', (0, 6), (2, 6)), ('SPAN', (0, 7), (2, 7)),
        ('SPAN', (0, 8), (2, 8)),
        # front-door band (TEAL)
        ('BACKGROUND', (0, 0), (2, 0), TEAL), ('BOX', (0, 0), (2, 0), 0.8, TEAL),
        # tenant web app (NAVY)
        ('BACKGROUND', (0, 2), (2, 2), NAVY), ('BOX', (0, 2), (2, 2), 0.8, NAVY),
        # three service boxes (CHIP)
        ('BACKGROUND', (0, 4), (2, 4), CHIP), ('BOX', (0, 4), (2, 4), 0.8, NAVY),
        ('INNERGRID', (0, 4), (2, 4), 0.6, white),
        # funding layer (NAVY, header + detail rows 6-7)
        ('BACKGROUND', (0, 6), (2, 7), NAVY), ('BOX', (0, 6), (2, 7), 0.8, NAVY),
        # cross-cutting footer band (TILE)
        ('BACKGROUND', (0, 8), (2, 8), DEEP), ('BOX', (0, 8), (2, 8), 0.6, TEAL),
        # tighten the flow-label rows
        ('TOPPADDING', (0, 1), (2, 1), 3), ('BOTTOMPADDING', (0, 1), (2, 1), 3),
        ('TOPPADDING', (0, 3), (2, 3), 3), ('BOTTOMPADDING', (0, 3), (2, 3), 3),
        ('TOPPADDING', (0, 5), (2, 5), 3), ('BOTTOMPADDING', (0, 5), (2, 5), 3),
    ]))
    return t


def build(s):
    story = []
    P = lambda t, st='Body': story.append(Paragraph(t, s[st]))
    SP = lambda h=4: story.append(Spacer(1, h * mm))
    B = lambda t: story.append(Paragraph(f'<bullet>&bull;</bullet> {t}', s['Bul']))
    N = lambda n, t: story.append(Paragraph(f'<b>{n}.</b>&nbsp;&nbsp;{t}', s['Num']))
    cH = lambda t: Paragraph(t, s['CellH'])
    c = lambda t: Paragraph(t, s['Cell'])

    # ============================================================ COVER
    SP(48)
    P('FutureProof Financial', 'TitleBig'); SP(4)
    P('Platform &amp; AI Strategy', 'Sub'); SP(2)
    P('What we\'re building, and how we build it', 'SubL'); SP(16)
    story.append(Paragraph(
        'FutureProof has built a new kind of mortgage &mdash; one that pays the homeowner &mdash; and a working '
        'system to demonstrate it. This paper is the practical plan for the platform that takes it to every '
        'market: <b>what we are building, the technology we have chosen and why, how the pieces fit together, and '
        'how we develop, test, deploy and run it.</b> It is deliberately concrete.', s['Call']))
    SP(2)
    P('June 2026', 'SubL')
    story.append(PageBreak())

    # ============================================================ 1. WHAT WE'RE BUILDING
    P('1. What we\'re building', 'H1')
    story.append(Paragraph('One platform, owned by FutureProof, that runs the product in every market.', s['Lead']))
    P('Licensed lenders run on it &mdash; one or several per market &mdash; each white-labelled, under its own '
      'licence. We own the engine; the lenders drive. In plain terms:')
    B('<b>One product brain.</b> Pricing, the actuarial models and the business rules live in one place, owned by '
      'us, and are identical in every market. A market configures within bounds we set; no lender can fork the product.')
    B('<b>Many lenders, cleanly separated.</b> Each lender is a branded, isolated tenant with its own licence and '
      'its own ring-fenced data &mdash; several can operate in one market. Adding a lender (or a market) means '
      'standing up a tenant and a licence, not rebuilding the product.')
    B('<b>Run by a small team and five AI agents.</b> A standing team of agents does the repeatable work in every '
      'market at once, with a person on every consequential decision.')
    B('<b>Market-agnostic by design.</b> Australia is the live build. The platform is built so the next market '
      '&mdash; whichever it is &mdash; is a configuration-and-licence exercise, measured in months.')
    SP(2)
    P('The rest of this paper is the &ldquo;how&rdquo;: the stack and why (Section 2), the system and how it fits '
      'together (Section 3), and the way we work &mdash; build, test, deploy, run (Section 4).')
    story.append(PageBreak())

    # ============================================================ 2. THE STACK AND WHY
    P('2. The stack, and why', 'H1')

    P('Why Rails', 'H2')
    P('We build on Ruby on Rails. The reasons compound for a small team building with AI:')
    B('<b>It is token-efficient &mdash; which matters because we build with AI.</b> Two decades of Rails code and '
      'documentation sit in every model\'s training data, and Rails\' &ldquo;convention over configuration&rdquo; '
      'means there is usually one idiomatic way to do a thing &mdash; so our AI agents\' first attempt is more '
      'often correct and consistent. Rails is also concise: little boilerplate, so the agents generate less code, '
      'hold more of the system in context at once, and we have less to review. Less code, more correctness, '
      'faster iterations.')
    B('<b>A small team ships a lot.</b> Batteries are included &mdash; database, background jobs, email, '
      'authentication and security defaults all in the box (Rails 8 bundles its own job queue and auth) &mdash; '
      'and with Stimulus/Hotwire the same framework renders the interface. No separate frontend stack or team: '
      'one language, one codebase, one deploy.')
    B('<b>It fits the architecture we chose.</b> We are building a modular monolith with a separate database per '
      'lender. Rails has had first-class support for multiple databases and per-request connection switching '
      'since version 6 &mdash; the exact mechanism our tenant isolation needs. The framework and the architecture '
      'pull the same way.')
    B('<b>Boring, stable and secure.</b> Rails is twenty years old, prizes backwards-compatibility, and does not '
      'churn the way the JavaScript ecosystem does &mdash; the right trait for a regulated platform meant to run '
      'for years. It is secure by default, with built-in protection against the common web vulnerabilities '
      '(cross-site request forgery, SQL injection, cross-site scripting) and encrypted credentials.')
    B('<b>Proven at any scale we will reach.</b> Shopify, GitHub and GitLab run enormous Rails monoliths today, '
      'and Basecamp &mdash; which created Rails &mdash; runs its products on it. It carries companies from the '
      'first commit to global scale; we will not out-grow it before we need to.')

    story.append(PageBreak())
    P('The rest of the stack', 'H2')
    head = [cH(x) for x in ['Layer', 'Choice', 'Why']]
    rows = [
        [c('<b>Framework</b>'), c('Ruby on Rails'), c('Token-efficient, battle-tested, fast for a small team (above)')],
        [c('<b>Database</b>'), c('PostgreSQL'), c('Rock-solid; a database per lender gives clean isolation, and per-market hosting keeps data resident')],
        [c('<b>Interface</b>'), c('Server-rendered + Stimulus'), c('Logic stays on the server; the browser does presentation only &mdash; simpler and safer')],
        [c('<b>Styling</b>'), c('Our own CSS design system'), c('Full control of every market\'s brand; no third-party framework to fight or outgrow')],
        [c('<b>Background work</b>'), c('Solid Queue'), c('Jobs run on the database we already have &mdash; no extra moving parts to operate')],
        [c('<b>Hosting</b>'), c('Fly.io'), c('Simple, multi-region deploys close to each market; scales when we need it')],
    ]
    story.append(tbl([head] + rows, [30 * mm, 44 * mm, 96 * mm]))

    P('What we deliberately don\'t do (yet)', 'H2')
    P('Keeping the system small is a feature. We do not add Kafka, microservices or a sprawling cloud estate '
      'before scale forces them, and we do not claim certifications (SOC 2, ISO 27001) before we have earned '
      'them. Each piece of weight is added only when it pays for itself. This is the mainstream engineering view '
      'in 2026, and it is what lets a small team build quickly and cheaply.')
    story.append(PageBreak())

    # ============================================================ 3. THE SYSTEM
    P('3. The system, and how it fits together', 'H1')
    P('Six parts. The chart reads top to bottom &mdash; a customer enters at the top, a funded mortgage sits at '
      'the bottom.')
    story.append(architecture_diagram(s))
    SP(4)
    head = [cH('Component'), cH('What it does')]
    rows = [
        [c('<b>Tenant web app</b>'), c('The branded front door for one lender: the application journey, admin tooling and dashboards. White-labelled, with its own domain and its own isolated database; several lenders can run in one market.')],
        [c('<b>Product brain</b>'), c('The central, versioned service that answers &ldquo;what is the quote and the terms for this customer?&rdquo; Pricing, actuarial models and business rules &mdash; one source of truth, owned by FutureProof, that every lender calls and none can edit.')],
        [c('<b>AI gateway</b>'), c('Where the five agents act, behind human-approval gates, with every decision logged. The single controlled path for anything the AI does.')],
        [c('<b>Background jobs</b>'), c('Timed and queued work &mdash; emails, lifecycle steps, scheduled tasks &mdash; run on Solid Queue.')],
        [c('<b>Funding layer (Wholesale Funders)</b>'), c('The shared funding stack behind every mortgage: wholesale funders, mortgage pools, insurance and reinsurance, the S&amp;P 500 hedge, and the investment account that pays the homeowner and services the interest. Built once; every market plugs in.')],
        [c('<b>Governance &amp; data</b>'), c('Cross-cutting: each lender\'s data is isolated from every other lender, and each market\'s data stays in its jurisdiction; every real decision is logged and explainable; model and compliance governance sits in the centre.')],
    ]
    story.append(tbl([head] + rows, [40 * mm, 130 * mm]))

    P('The five agents', 'H2')
    P('A standing team that works in every market at once. These are internal working names; customers never '
      'hear them.')
    head = [cH('Agent'), cH('Role')]
    rows = [
        [c('<b>Akane</b>'), c('Customer acquisition &mdash; first contact, qualification, guiding the application')],
        [c('<b>Misato</b>'), c('Customer communications and service after onboarding')],
        [c('<b>Rie</b>'), c('Back-office operations')],
        [c('<b>Yumi</b>'), c('Investment account management')],
        [c('<b>Motoko</b>'), c('Engineering and ops &mdash; builds and runs the other four')],
    ]
    story.append(tbl([head] + rows, [30 * mm, 140 * mm]))
    SP(2)
    story.append(Paragraph(
        '<b>The line our AI stays behind.</b> There is a hard regulatory line between general guidance and '
        'personal financial advice. Our agents inform, explain and run the operation; they never tell a customer '
        'this product suits <i>them</i> and they should take it &mdash; that is personal advice, which requires a '
        'licence and, in the UK, a qualified human adviser. The AI makes our people faster; it does not replace '
        'the regulated judgement.', s['Call']))
    story.append(PageBreak())

    # ============================================================ 4. HOW WE WORK
    P('4. How we work', 'H1')
    P('The same disciplined loop for every component, from how it looks to how it runs. Our demonstration '
      'system already works to this standard &mdash; 382 automated tests, zero failures &mdash; and the platform '
      'inherits it.')

    P('Design &amp; UX', 'H2')
    B('<b>One design system, themed per lender.</b> A single custom-built component library &mdash; buttons, '
      'cards, forms, alerts &mdash; owned by us. Each lender gets its own brand skin (colour, logo, type) over '
      'the same proven patterns: consistency for us, distinctiveness for them, and no design rework per market.')
    B('<b>Designed for the people who use it.</b> Our customers are homeowners, often retired and not digital '
      'natives, making a major financial decision. The interface is plain-language, uncluttered and accessible '
      '&mdash; large legible type, clear steps, no jargon &mdash; explaining a genuinely new product simply, '
      'never in the language of debt.')
    B('<b>The interface respects the advice wall.</b> It informs and explains &mdash; what the income is, how it '
      'works, what happens at the end &mdash; but never pressures or tells a customer &ldquo;you should.&rdquo; '
      'For a regulated product, clarity and honesty are design requirements, not afterthoughts.')

    P('Development', 'H2')
    P('We build a modular monolith one component at a time, a small team working alongside AI coding agents. Each '
      'component follows one loop:')
    N(1, '<b>Refresh the prompt</b> &mdash; pin down what the component does, its inputs and outputs, its '
         'definition of done, and the rules it must respect, so the AI builds from accurate context.')
    N(2, '<b>Collect test data</b> &mdash; gather realistic data (customers, properties, quotes, market configs) '
         'that becomes the fixtures the tests run on.')
    N(3, '<b>Build</b> &mdash; the smallest slice that meets the definition of done; business logic on the '
         'server, the browser for presentation only.')
    N(4, '<b>Test, review, deploy</b> &mdash; covered below. Then move to the next component.')

    P('Testing', 'H2')
    B('<b>Test-first and integration-first.</b> We write a test that drives the real path, then make it pass; '
      'we verify in a real browser against the real URL, not just in isolation.')
    B('<b>Nothing ships on a red suite.</b> The full automated test suite must pass before a change moves on.')
    B('<b>Security and quality gates on every change:</b> an automated security scan (Brakeman), a style check '
      '(RuboCop), and a content-security check &mdash; run before every commit.')

    story.append(PageBreak())
    P('Deployment', 'H2')
    B('<b>One safe path to production.</b> Deploys go to Fly.io with a fixed pre-flight &mdash; confirm the '
      'account, confirm the app, confirm status, then deploy.')
    B('<b>Released behind configuration, per lender and per market.</b> A lender or a market can be switched on, '
      'or a feature rolled out, without touching another.')
    B('<b>Reversible, idempotent database changes.</b> Migrations can always be rolled back; we never '
      'destructively touch data.')

    P('Management', 'H2')
    B('<b>Run by the agents, governed by people.</b> Operations run on the five agents, with a person on every '
      'consequential decision; Motoko (engineering/ops) builds and runs the other four.')
    B('<b>The signal we watch is Investment Health</b> &mdash; the share of accounts in good standing. (An EPM '
      'customer never pays, so there is no concept of arrears.)')
    B('<b>Everything is auditable.</b> Every agent decision is logged and explainable; model and compliance '
      'governance is owned centrally; each lender\'s data is isolated and stays in its market\'s jurisdiction.')
    SP(3)
    story.append(Paragraph(
        'In short: a proven, token-efficient stack, owned in the centre and isolated at the edge, with a '
        'build-test-deploy-run loop a small team can sustain. That makes &ldquo;one engine, every market&rdquo; '
        'a plan, not an ambition.', s['Lead']))
    return story


if __name__ == '__main__':
    os.chdir(os.path.dirname(os.path.abspath(__file__)))
    out = os.path.join('docs', 'pdfs', 'FutureProof_Platform_and_AI_Strategy_Jun2026.pdf')
    doc = SimpleDocTemplate(out, pagesize=A4, topMargin=20 * mm, bottomMargin=22 * mm,
                            leftMargin=20 * mm, rightMargin=20 * mm)

    def footer(canvas, d):
        canvas.saveState()
        canvas.setStrokeColor(GREY); canvas.setLineWidth(0.4)
        canvas.line(20 * mm, 15 * mm, 190 * mm, 15 * mm)
        canvas.setFont('Helvetica', 8); canvas.setFillColor(GREY)
        canvas.drawString(20 * mm, 11 * mm,
                          'FutureProof  |  Platform & AI Strategy  |  June 2026')
        canvas.drawRightString(190 * mm, 11 * mm, f'Page {d.page}')
        canvas.restoreState()

    doc.build(build(styles()), onFirstPage=footer, onLaterPages=footer)
    print('Wrote', out)
