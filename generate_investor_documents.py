#!/usr/bin/env python3
"""
Generate rewritten FutureProof investor documents:
1. Investor Outreach 1-pager
2. Pitchdeck content (slide-by-slide rewrite)

Visual design: Professional, clean, Apple-inspired with brand colours.
"""

import json
import os
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np
from reportlab.lib import colors
from reportlab.lib.pagesizes import A4, landscape
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import mm, cm, inch
from reportlab.lib.enums import TA_LEFT, TA_CENTER, TA_RIGHT, TA_JUSTIFY
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle,
    PageBreak, Image, KeepTogether, HRFlowable, ListFlowable, ListItem,
    FrameBreak, Frame, PageTemplate, BaseDocTemplate, Flowable
)
from reportlab.lib.colors import HexColor
from reportlab.graphics.shapes import Drawing, Rect, Line
from io import BytesIO

# ============================================================
# BRAND COLOURS (matched to logo)
# ============================================================
BRAND_BLUE = HexColor('#2D9CDB')    # Primary blue from logo
BRAND_DARK = HexColor('#1A1A2E')    # Near-black for text
DARK_NAVY = HexColor('#1B2A4A')
NAVY = HexColor('#2C3E50')
TEAL = HexColor('#2D9CDB')          # Match brand blue
BLUE = HexColor('#2980B9')
LIGHT_BLUE = HexColor('#EBF5FB')
VERY_LIGHT_BLUE = HexColor('#F4FAFF')
CORAL = HexColor('#E74C3C')
GREEN = HexColor('#27AE60')
ORANGE = HexColor('#E67E22')
LIGHT_GREY = HexColor('#F8F9FA')
MID_GREY = HexColor('#95A5A6')
DARK_GREY = HexColor('#5D6D7E')
WHITE = colors.white
HEADER_BG = HexColor('#1A1A2E')
ROW_ALT = HexColor('#F4FAFF')
ACCENT_GRADIENT_START = HexColor('#2D9CDB')
ACCENT_GRADIENT_END = HexColor('#1A6FB5')

LOGO_PATH = 'app/assets/images/futureproof-logo.png'


# ============================================================
# CUSTOM FLOWABLES
# ============================================================
class AccentBar(Flowable):
    """A coloured accent bar spanning the page width."""
    def __init__(self, width, height=3, color=TEAL):
        Flowable.__init__(self)
        self.width = width
        self.height = height
        self.color = color

    def draw(self):
        self.canv.setFillColor(self.color)
        self.canv.rect(0, 0, self.width, self.height, fill=1, stroke=0)


class GradientBar(Flowable):
    """A gradient bar from brand blue to darker blue."""
    def __init__(self, width, height=4):
        Flowable.__init__(self)
        self.width = width
        self.height = height

    def draw(self):
        steps = 50
        step_w = self.width / steps
        for i in range(steps):
            r = 0.176 + (0.102 - 0.176) * (i / steps)
            g = 0.612 + (0.435 - 0.612) * (i / steps)
            b = 0.859 + (0.710 - 0.859) * (i / steps)
            self.canv.setFillColorRGB(r, g, b)
            self.canv.rect(i * step_w, 0, step_w + 1, self.height, fill=1, stroke=0)


class CalloutBox(Flowable):
    """A styled callout box with left accent bar."""
    def __init__(self, text, width, style, accent_color=TEAL, bg_color=VERY_LIGHT_BLUE):
        Flowable.__init__(self)
        self.text = text
        self.box_width = width
        self.style = style
        self.accent_color = accent_color
        self.bg_color = bg_color
        # Pre-calculate height
        from reportlab.platypus.paragraph import Paragraph as P
        p = P(text, style)
        pw, ph = p.wrap(width - 20*mm, 500*mm)
        self.box_height = ph + 12*mm

    def wrap(self, availWidth, availHeight):
        return (self.box_width, self.box_height)

    def draw(self):
        # Background
        self.canv.setFillColor(self.bg_color)
        self.canv.roundRect(0, 0, self.box_width, self.box_height, 3, fill=1, stroke=0)
        # Left accent bar
        self.canv.setFillColor(self.accent_color)
        self.canv.roundRect(0, 0, 4, self.box_height, 2, fill=1, stroke=0)
        # Text
        from reportlab.platypus.paragraph import Paragraph as P
        p = P(self.text, self.style)
        pw, ph = p.wrap(self.box_width - 20*mm, self.box_height)
        p.drawOn(self.canv, 12*mm, (self.box_height - ph) / 2)


class SectionDivider(Flowable):
    """A thin divider line with subtle gradient."""
    def __init__(self, width):
        Flowable.__init__(self)
        self.width = width

    def wrap(self, availWidth, availHeight):
        return (self.width, 6*mm)

    def draw(self):
        self.canv.setStrokeColor(TEAL)
        self.canv.setLineWidth(0.8)
        self.canv.line(0, 3*mm, self.width * 0.3, 3*mm)
        # Fade out
        steps = 20
        fade_start = self.width * 0.3
        fade_len = self.width * 0.15
        for i in range(steps):
            alpha = 1.0 - (i / steps)
            self.canv.setStrokeColorRGB(
                0.176 * alpha + 0.96 * (1 - alpha),
                0.612 * alpha + 0.96 * (1 - alpha),
                0.859 * alpha + 0.96 * (1 - alpha)
            )
            x0 = fade_start + (i / steps) * fade_len
            x1 = fade_start + ((i + 1) / steps) * fade_len
            self.canv.line(x0, 3*mm, x1, 3*mm)


# ============================================================
# STYLES
# ============================================================
def get_styles():
    styles = getSampleStyleSheet()

    # 1-pager styles
    styles.add(ParagraphStyle('DocTitle', fontSize=28, leading=34,
        textColor=BRAND_DARK, spaceAfter=2*mm, fontName='Helvetica-Bold'))
    styles.add(ParagraphStyle('DocSubtitle', fontSize=12, leading=16,
        textColor=DARK_GREY, spaceAfter=6*mm, fontName='Helvetica'))
    styles.add(ParagraphStyle('SectionHead', fontSize=13, leading=17,
        textColor=BRAND_DARK, spaceBefore=5*mm, spaceAfter=2*mm,
        fontName='Helvetica-Bold'))
    styles.add(ParagraphStyle('SubHead', fontSize=10, leading=13,
        textColor=TEAL, spaceBefore=3*mm, spaceAfter=2*mm,
        fontName='Helvetica-Bold'))
    styles.add(ParagraphStyle('Body', fontSize=9, leading=13,
        textColor=NAVY, spaceAfter=2*mm, fontName='Helvetica',
        alignment=TA_JUSTIFY))
    styles.add(ParagraphStyle('BodyBold', fontSize=9, leading=13,
        textColor=NAVY, spaceAfter=2*mm, fontName='Helvetica-Bold'))
    styles.add(ParagraphStyle('FPBullet', fontSize=9, leading=12.5,
        textColor=NAVY, leftIndent=14, spaceAfter=1.5*mm,
        fontName='Helvetica', bulletIndent=5))
    styles.add(ParagraphStyle('SmallNote', fontSize=7, leading=9,
        textColor=MID_GREY, spaceAfter=1*mm, fontName='Helvetica-Oblique'))
    styles.add(ParagraphStyle('CalloutText', fontSize=9, leading=13,
        textColor=DARK_NAVY, fontName='Helvetica',
        alignment=TA_JUSTIFY))
    styles.add(ParagraphStyle('CalloutBold', fontSize=9.5, leading=13.5,
        textColor=DARK_NAVY, fontName='Helvetica-Bold',
        alignment=TA_JUSTIFY))
    styles.add(ParagraphStyle('BigNumber', fontSize=22, leading=26,
        textColor=TEAL, fontName='Helvetica-Bold', alignment=TA_CENTER))
    styles.add(ParagraphStyle('BigLabel', fontSize=7.5, leading=9.5,
        textColor=DARK_GREY, fontName='Helvetica', alignment=TA_CENTER,
        spaceAfter=2*mm))
    styles.add(ParagraphStyle('FooterText', fontSize=7, leading=9,
        textColor=MID_GREY, fontName='Helvetica', alignment=TA_CENTER))
    styles.add(ParagraphStyle('ContactInfo', fontSize=8.5, leading=12,
        textColor=NAVY, fontName='Helvetica'))

    # Pitchdeck styles
    styles.add(ParagraphStyle('SlideTitle', fontSize=18, leading=22,
        textColor=BRAND_DARK, spaceBefore=4*mm, spaceAfter=2*mm,
        fontName='Helvetica-Bold'))
    styles.add(ParagraphStyle('SlideSubtitle', fontSize=11, leading=14,
        textColor=DARK_GREY, spaceAfter=4*mm, fontName='Helvetica'))
    styles.add(ParagraphStyle('SlideBody', fontSize=9.5, leading=13.5,
        textColor=NAVY, spaceAfter=2.5*mm, fontName='Helvetica',
        alignment=TA_JUSTIFY))
    styles.add(ParagraphStyle('SlideBullet', fontSize=9.5, leading=13.5,
        textColor=NAVY, leftIndent=14, spaceAfter=2*mm,
        fontName='Helvetica', bulletIndent=5))
    styles.add(ParagraphStyle('SlideNote', fontSize=7.5, leading=10,
        textColor=DARK_GREY, fontName='Helvetica-Oblique',
        spaceAfter=2*mm))
    styles.add(ParagraphStyle('SlideCalloutText', fontSize=10, leading=14,
        textColor=DARK_NAVY, fontName='Helvetica-Bold'))
    styles.add(ParagraphStyle('TitlePageTag', fontSize=14, leading=18,
        textColor=DARK_GREY, fontName='Helvetica', alignment=TA_CENTER))
    styles.add(ParagraphStyle('TitlePageSub', fontSize=10, leading=14,
        textColor=MID_GREY, fontName='Helvetica', alignment=TA_CENTER))

    return styles


def make_table(data, col_widths=None, header_rows=1):
    """Professional table with brand-coloured header."""
    style_cmds = [
        ('BACKGROUND', (0, 0), (-1, header_rows - 1), HEADER_BG),
        ('TEXTCOLOR', (0, 0), (-1, header_rows - 1), WHITE),
        ('FONTNAME', (0, 0), (-1, header_rows - 1), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 0), (-1, header_rows - 1), 8),
        ('FONTNAME', (0, header_rows), (-1, -1), 'Helvetica'),
        ('FONTSIZE', (0, header_rows), (-1, -1), 8),
        ('ALIGN', (1, 0), (-1, -1), 'RIGHT'),
        ('ALIGN', (0, 0), (0, -1), 'LEFT'),
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ('GRID', (0, 0), (-1, -1), 0.3, HexColor('#DEE2E6')),
        ('TOPPADDING', (0, 0), (-1, -1), 4),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 4),
        ('LEFTPADDING', (0, 0), (-1, -1), 6),
        ('RIGHTPADDING', (0, 0), (-1, -1), 6),
        ('ROUNDEDCORNERS', [3, 3, 3, 3]),
    ]
    for i in range(header_rows, len(data)):
        if (i - header_rows) % 2 == 1:
            style_cmds.append(('BACKGROUND', (0, i), (-1, i), ROW_ALT))
    t = Table(data, colWidths=col_widths, repeatRows=header_rows)
    t.setStyle(TableStyle(style_cmds))
    return t


def section_divider(width=170*mm):
    return SectionDivider(width)


# ============================================================
# PAGE TEMPLATES
# ============================================================
def _one_pager_header_footer(canvas, doc):
    """Header bar + footer for the 1-pager."""
    canvas.saveState()
    w, h = A4

    # Top accent bar (thin gradient)
    steps = 60
    bar_h = 3
    step_w = w / steps
    for i in range(steps):
        r = 0.176 + (0.102 - 0.176) * (i / steps)
        g = 0.612 + (0.435 - 0.612) * (i / steps)
        b = 0.859 + (0.710 - 0.859) * (i / steps)
        canvas.setFillColorRGB(r, g, b)
        canvas.rect(i * step_w, h - bar_h, step_w + 1, bar_h, fill=1, stroke=0)

    # Footer line
    canvas.setStrokeColor(HexColor('#DEE2E6'))
    canvas.setLineWidth(0.5)
    canvas.line(18*mm, 10*mm, w - 18*mm, 10*mm)

    # Footer text
    canvas.setFont('Helvetica', 6.5)
    canvas.setFillColor(MID_GREY)
    canvas.drawString(18*mm, 6.5*mm,
        '\u00a92026 Futureproof Financial Group Limited. Confidential.')
    canvas.drawRightString(w - 18*mm, 6.5*mm,
        'futureprooffinancial.co')

    canvas.restoreState()


def _pitchdeck_header_footer(canvas, doc):
    """Header with logo + page number footer for pitchdeck."""
    canvas.saveState()
    w, h = A4

    # Top accent bar
    steps = 60
    bar_h = 3
    step_w = w / steps
    for i in range(steps):
        r = 0.176 + (0.102 - 0.176) * (i / steps)
        g = 0.612 + (0.435 - 0.612) * (i / steps)
        b = 0.859 + (0.710 - 0.859) * (i / steps)
        canvas.setFillColorRGB(r, g, b)
        canvas.rect(i * step_w, h - bar_h, step_w + 1, bar_h, fill=1, stroke=0)

    # Small logo in top-left (on non-title pages)
    if doc.page > 1 and os.path.exists(LOGO_PATH):
        canvas.drawImage(LOGO_PATH, 20*mm, h - 14*mm, width=35*mm,
                         height=35*mm * (174/813), preserveAspectRatio=True,
                         mask='auto')

    # Footer
    canvas.setStrokeColor(HexColor('#DEE2E6'))
    canvas.setLineWidth(0.5)
    canvas.line(20*mm, 12*mm, w - 20*mm, 12*mm)

    canvas.setFont('Helvetica', 6.5)
    canvas.setFillColor(MID_GREY)
    canvas.drawString(20*mm, 8*mm,
        '\u00a92026 Futureproof Financial Group Limited. Confidential.')
    canvas.drawCentredString(w / 2, 8*mm, f'{doc.page}')
    canvas.drawRightString(w - 20*mm, 8*mm, 'futureprooffinancial.co')

    canvas.restoreState()


def _pitchdeck_title_page(canvas, doc):
    """Special treatment for title page — no small header logo."""
    canvas.saveState()
    w, h = A4

    # Top accent bar
    steps = 60
    bar_h = 4
    step_w = w / steps
    for i in range(steps):
        r = 0.176 + (0.102 - 0.176) * (i / steps)
        g = 0.612 + (0.435 - 0.612) * (i / steps)
        b = 0.859 + (0.710 - 0.859) * (i / steps)
        canvas.setFillColorRGB(r, g, b)
        canvas.rect(i * step_w, h - bar_h, step_w + 1, bar_h, fill=1, stroke=0)

    # Bottom accent bar
    for i in range(steps):
        r = 0.176 + (0.102 - 0.176) * (i / steps)
        g = 0.612 + (0.435 - 0.612) * (i / steps)
        b = 0.859 + (0.710 - 0.859) * (i / steps)
        canvas.setFillColorRGB(r, g, b)
        canvas.rect(i * step_w, 0, step_w + 1, bar_h, fill=1, stroke=0)

    canvas.restoreState()


# ============================================================
# DOCUMENT 1: INVESTOR OUTREACH 1-PAGER
# ============================================================
def build_one_pager():
    output = 'docs/Outreach/Futureproof - Investor Outreach v3.pdf'
    os.makedirs(os.path.dirname(output), exist_ok=True)

    doc = BaseDocTemplate(output, pagesize=A4,
        leftMargin=18*mm, rightMargin=18*mm,
        topMargin=18*mm, bottomMargin=14*mm)

    content_width = A4[0] - 36*mm

    frame = Frame(18*mm, 14*mm, content_width, A4[1] - 32*mm,
                  id='main', showBoundary=0)
    doc.addPageTemplates([
        PageTemplate(id='onepager', frames=[frame],
                     onPage=_one_pager_header_footer)
    ])

    styles = get_styles()
    story = []

    # Logo
    if os.path.exists(LOGO_PATH):
        logo = Image(LOGO_PATH, width=55*mm, height=55*mm * (174/813))
        story.append(logo)
        story.append(Spacer(1, 3*mm))

    # Tagline
    story.append(Paragraph(
        'Saving the retirement of 36M American homeowners — '
        'and millions more worldwide', styles['DocSubtitle']))

    story.append(GradientBar(content_width, 2.5))
    story.append(Spacer(1, 3*mm))

    # THE PROBLEM
    story.append(Paragraph('The Problem', styles['SectionHead']))
    story.append(Paragraph(
        '65% of retirees are asset-rich and cash-poor. Their wealth is locked in residential '
        'property — the world\'s largest asset class — yet no financial institution offers a '
        'fit-for-purpose product to convert that equity into retirement income without selling '
        'the home, depleting equity, or sharing property appreciation. Existing products '
        '(reverse mortgages, shared appreciation mortgages) are expensive, predatory, and '
        'difficult to fund or securitise. This problem has been hiding in plain sight for 35 years.',
        styles['Body']))

    # Key numbers — styled metric cards
    num_data = [
        ['$25T', '36M', '65%', '$20T'],
        ['Home equity in\ntarget markets', 'Under-funded US\nhomeowner retirees',
         'Of retirees are\nasset-rich, cash-poor', 'Locked in illiquid\nresidential property'],
    ]
    num_style = [
        ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 0), (-1, 0), 18),
        ('LEADING', (0, 0), (-1, 0), 22),
        ('TEXTCOLOR', (0, 0), (-1, 0), TEAL),
        ('FONTNAME', (0, 1), (-1, 1), 'Helvetica'),
        ('FONTSIZE', (0, 1), (-1, 1), 7),
        ('LEADING', (0, 1), (-1, 1), 10),
        ('TEXTCOLOR', (0, 1), (-1, 1), DARK_GREY),
        ('ALIGN', (0, 0), (-1, -1), 'CENTER'),
        ('VALIGN', (0, 0), (- 1, 0), 'BOTTOM'),
        ('VALIGN', (0, 1), (-1, 1), 'TOP'),
        ('TOPPADDING', (0, 0), (-1, 0), 8),
        ('BOTTOMPADDING', (0, 0), (-1, 0), 4),
        ('TOPPADDING', (0, 1), (-1, 1), 2),
        ('BOTTOMPADDING', (0, 1), (-1, 1), 8),
        ('BACKGROUND', (0, 0), (-1, -1), VERY_LIGHT_BLUE),
        ('ROUNDEDCORNERS', [4, 4, 4, 4]),
        ('BOX', (0, 0), (-1, -1), 0.5, HexColor('#D6EAF8')),
        ('LINEAFTER', (0, 0), (2, -1), 0.3, HexColor('#D6EAF8')),
    ]
    cw = content_width / 4
    num_table = Table(num_data, colWidths=[cw]*4, rowHeights=[28, 24])
    num_table.setStyle(TableStyle(num_style))
    story.append(num_table)
    story.append(Spacer(1, 3*mm))

    # THE SOLUTION
    story.append(Paragraph('The Solution: Equity Preservation Mortgage\u00ae', styles['SectionHead']))
    story.append(Paragraph(
        'FutureProof has designed a new index-linked mortgage referenced to the S&P 500 that '
        'converts home equity into tax-efficient retirement income — without selling the home, '
        'depleting equity, or sharing property appreciation. All home wealth is preserved for '
        'future needs or family inheritance.',
        styles['Body']))

    story.append(Paragraph('How it works:', styles['SubHead']))
    how_items = [
        'Borrower takes a 30-year mortgage secured against their home (up to 80% LTV)',
        'Mortgage capital is invested in passive S&P 500 index ETFs via a segregated offset account',
        'Long-term index returns (~10% p.a.) pay all mortgage interest and costs on behalf of the borrower',
        'Surplus generates a tax-free annuity income of ~1.25% of home value p.a. for 10 years',
        'Built-in volatility buffer (80-120% collar) and mortgage insurance eliminate lender risk',
        'At maturity, the mortgage is repaid from the investment account — home equity fully preserved',
    ]
    for item in how_items:
        story.append(Paragraph(f'<font color="{TEAL.hexval()}">\u25B8</font>  {item}',
                               styles['FPBullet']))

    # Callout box
    callout_text = (
        'The core insight: over any 30-year period, long-term equity index returns have reliably '
        'exceeded mortgage funding costs by 3-4% p.a. The EPM captures this spread through '
        'a proprietary investment structure validated by 50,000-path Monte Carlo simulation '
        'with a Probability of Claim under 5% in the optimised model.'
    )
    story.append(Spacer(1, 1*mm))
    story.append(CalloutBox(callout_text, content_width,
                            styles['CalloutBold'], TEAL, VERY_LIGHT_BLUE))
    story.append(Spacer(1, 2*mm))

    # WHY NOW
    story.append(Paragraph('Why Now', styles['SectionHead']))
    why_items = [
        'Buffer ETF products now exist at scale, enabling efficient collar hedging',
        'Regulatory frameworks for novel mortgage products have matured (FCA sandbox, APRA innovation pathway)',
        'Reinsurance capacity for longevity and index-linked risk has expanded significantly',
        'Demographic pressure: dependency ratio now 2:1, governments shifting to user-pay models',
        'Technology: SaaS platform enables multi-jurisdiction deployment at low marginal cost',
    ]
    for item in why_items:
        story.append(Paragraph(f'<font color="{TEAL.hexval()}">\u25B8</font>  {item}',
                               styles['FPBullet']))

    # BUSINESS MODEL
    story.append(Paragraph('Business Model: B2B2C SaaS + Ecosystem', styles['SectionHead']))
    story.append(Paragraph(
        'FutureProof is a B2B2C fintech platform. The EPM is embedded in our SaaS platform and '
        'licensed exclusively to regulated financial institutions (Product Issuers). Revenue is '
        'multi-layered and recurring:',
        styles['Body']))

    rev_data = [
        ['Revenue Stream', 'Type', 'Mechanism'],
        ['SaaS Platform Fee', 'Recurring (30yr)', '25bps margin on each mortgage, life-of-loan'],
        ['Profit Share', 'Periodic', '20% of surplus drawn every 3 years'],
        ['End-of-Term Surplus', 'At maturity', '50% share of surplus at mortgage expiry'],
        ['Capital Markets', 'Fee-based', 'Arranging fees, warehousing, securitisation'],
        ['Insurance', 'Commission', 'Captive insurer, retained underwriting participation'],
    ]
    story.append(make_table(rev_data, col_widths=[35*mm, 27*mm, content_width - 62*mm]))
    story.append(Spacer(1, 1*mm))
    story.append(Paragraph(
        'Estimated lifetime gross revenue per mortgage: ~$2.3M (30-year, undiscounted). '
        'NPV at 4.4%: ~$1.2M per mortgage.',
        styles['SmallNote']))

    # TRACTION
    story.append(Paragraph('Traction & Partners', styles['SectionHead']))
    story.append(Paragraph(
        '<b>Global Collaboration:</b> Accenture (approved business intermediary), '
        'Jones Day (global legal partner). '
        '<b>Product Co-Design:</b> PwC, BlackRock, Spiderock, Atlas SP/Apollo. '
        '<b>In Negotiation:</b> PIMCO, Macquarie, Munich Re, Gallagher Re, Lockton Re, Asia Insurance. '
        '<b>Pipeline:</b> 12 financial institutions across Australia, Asia, UK and USA as prospective Product Issuers.',
        styles['Body']))

    # THE ASK
    story.append(Paragraph('The Ask', styles['SectionHead']))

    ask_data = [
        ['', ''],
        ['Raise', '$5M Late Seed (min. $1M on SAFE)'],
        ['Purpose', 'Sprint-to-market: complete SaaS build, fund AU launch, close first Product Issuer'],
        ['Launch', 'Australia Q3 2026, UK Q2 2027, USA Q4 2027'],
        ['Near-Term Target', '$100M loan book by end 2026 (~50 mortgages via first Product Issuer)'],
        ['5-Year Target', '20 Product Issuers across 3 markets'],
        ['Founded By', 'Allianz alumni; bootstrapped $3M + $2M from Family Offices/HNW'],
    ]
    ask_style = [
        ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 0), (-1, -1), 8),
        ('FONTNAME', (0, 1), (0, -1), 'Helvetica-Bold'),
        ('TEXTCOLOR', (0, 1), (0, -1), TEAL),
        ('FONTNAME', (1, 1), (1, -1), 'Helvetica'),
        ('TEXTCOLOR', (0, 0), (-1, -1), NAVY),
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ('TOPPADDING', (0, 0), (-1, -1), 3),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 3),
        ('LEFTPADDING', (0, 0), (-1, -1), 6),
        ('GRID', (0, 1), (-1, -1), 0.3, HexColor('#DEE2E6')),
        ('BACKGROUND', (0, 1), (0, -1), VERY_LIGHT_BLUE),
        ('ROUNDEDCORNERS', [3, 3, 3, 3]),
    ]
    ask_table = Table(ask_data, colWidths=[35*mm, content_width - 35*mm])
    ask_table.setStyle(TableStyle(ask_style))
    story.append(ask_table)

    story.append(Spacer(1, 4*mm))

    # Contact
    story.append(GradientBar(content_width, 1.5))
    story.append(Spacer(1, 2*mm))
    story.append(Paragraph(
        '<b>John R Innes</b>  |  Co-Founder & Executive Director  |  '
        'john.innes@futureprooffinancial.co  |  +61 (0)408 306 235',
        styles['ContactInfo']))

    doc.build(story)
    print(f"1-pager generated: {output}")
    return output


# ============================================================
# DOCUMENT 2: PITCHDECK REWRITE
# ============================================================
def build_pitchdeck():
    output = 'docs/Outreach/Futureproof - Pitchdeck v3.pdf'
    os.makedirs(os.path.dirname(output), exist_ok=True)

    doc = BaseDocTemplate(output, pagesize=A4,
        leftMargin=20*mm, rightMargin=20*mm,
        topMargin=20*mm, bottomMargin=18*mm)

    content_width = A4[0] - 40*mm

    # Two page templates: title page + content pages
    title_frame = Frame(20*mm, 18*mm, content_width, A4[1] - 38*mm,
                        id='title_frame', showBoundary=0)
    content_frame = Frame(20*mm, 18*mm, content_width, A4[1] - 38*mm,
                          id='content_frame', showBoundary=0)

    doc.addPageTemplates([
        PageTemplate(id='title', frames=[title_frame],
                     onPage=_pitchdeck_title_page),
        PageTemplate(id='content', frames=[content_frame],
                     onPage=_pitchdeck_header_footer),
    ])

    styles = get_styles()
    story = []

    def slide_header(num, title, subtitle=None):
        story.append(Paragraph(f'<font color="{TEAL.hexval()}">{num}</font>  {title}',
                               styles['SlideTitle']))
        if subtitle:
            story.append(Paragraph(subtitle, styles['SlideSubtitle']))
        story.append(SectionDivider(content_width))

    def slide_note(text):
        story.append(Spacer(1, 2*mm))
        story.append(Paragraph(f'<i>Design note: {text}</i>', styles['SlideNote']))

    def bullet(text):
        story.append(Paragraph(
            f'<font color="{TEAL.hexval()}">\u25B8</font>  {text}',
            styles['SlideBullet']))

    def callout(text):
        story.append(Spacer(1, 1*mm))
        story.append(CalloutBox(text, content_width,
                                styles['SlideCalloutText'], TEAL, VERY_LIGHT_BLUE))
        story.append(Spacer(1, 2*mm))

    # ============================================================
    # TITLE PAGE
    # ============================================================
    story.append(Spacer(1, 55*mm))

    # Logo centred
    if os.path.exists(LOGO_PATH):
        logo = Image(LOGO_PATH, width=90*mm, height=90*mm * (174/813))
        logo.hAlign = 'CENTER'
        story.append(logo)
        story.append(Spacer(1, 12*mm))

    story.append(Paragraph(
        'Turning residential property from an illiquid asset<br/>'
        'into sustainable retirement income',
        styles['TitlePageTag']))
    story.append(Spacer(1, 6*mm))
    story.append(GradientBar(content_width * 0.4, 2))
    story.append(Spacer(1, 6*mm))
    story.append(Paragraph(
        'Investor Pitchdeck  |  March 2026  |  Confidential',
        styles['TitlePageSub']))

    story.append(Spacer(1, 30*mm))

    # Contact block at bottom
    story.append(Paragraph(
        'John R Innes  |  Co-Founder & Executive Director<br/>'
        'john.innes@futureprooffinancial.co  |  +61 (0)408 306 235',
        styles['TitlePageSub']))

    # Switch to content template for subsequent pages
    from reportlab.platypus.doctemplate import NextPageTemplate
    story.append(NextPageTemplate('content'))
    story.append(PageBreak())

    # ============================================================
    # TABLE OF CONTENTS PAGE
    # ============================================================
    story.append(Paragraph('Contents', styles['SlideTitle']))
    story.append(SectionDivider(content_width))
    story.append(Spacer(1, 4*mm))

    toc_items = [
        ('1', 'Title Slide'),
        ('2', 'The Problem'),
        ('3', 'The Market Gap'),
        ('4', 'The Solution'),
        ('5', 'How It Works'),
        ('6', 'Why It Works — The Core Insight', True),
        ('7', 'Risk Architecture', True),
        ('8', 'Platform Demo'),
        ('9', 'Traction & Partners'),
        ('10', 'Market Sizing'),
        ('11', 'Business Model'),
        ('12', 'Unit Economics & Market Rollout'),
        ('13', 'Competitive Landscape'),
        ('14', 'Go-To-Market Strategy'),
        ('15', 'Capital Flows & Securitisation'),
        ('16', 'Why Now'),
        ('17-18', 'Team'),
        ('19', 'The Ask'),
        ('20', 'Contact'),
    ]
    toc_data = [['Slide', 'Title', '']]
    for item in toc_items:
        is_new = len(item) > 2 and item[2] == True
        toc_data.append([item[0], item[1], 'NEW' if is_new else ''])

    toc_style = [
        ('BACKGROUND', (0, 0), (-1, 0), HEADER_BG),
        ('TEXTCOLOR', (0, 0), (-1, 0), WHITE),
        ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 0), (-1, 0), 8),
        ('FONTNAME', (0, 1), (0, -1), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 1), (-1, -1), 8.5),
        ('TEXTCOLOR', (0, 1), (0, -1), TEAL),
        ('FONTNAME', (1, 1), (1, -1), 'Helvetica'),
        ('TEXTCOLOR', (1, 1), (1, -1), NAVY),
        ('FONTNAME', (2, 1), (2, -1), 'Helvetica-Bold'),
        ('FONTSIZE', (2, 1), (2, -1), 7),
        ('TEXTCOLOR', (2, 1), (2, -1), GREEN),
        ('ALIGN', (0, 0), (0, -1), 'CENTER'),
        ('ALIGN', (2, 0), (2, -1), 'CENTER'),
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ('GRID', (0, 0), (-1, -1), 0.2, HexColor('#DEE2E6')),
        ('TOPPADDING', (0, 0), (-1, -1), 3),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 3),
        ('LEFTPADDING', (0, 0), (-1, -1), 6),
    ]
    for i in range(1, len(toc_data)):
        if (i - 1) % 2 == 1:
            toc_style.append(('BACKGROUND', (0, i), (-1, i), ROW_ALT))
    toc_table = Table(toc_data, colWidths=[18*mm, content_width - 33*mm, 15*mm])
    toc_table.setStyle(TableStyle(toc_style))
    story.append(toc_table)

    story.append(Spacer(1, 6*mm))
    story.append(Paragraph(
        'All financial claims validated against FutureProof EPM v14a Monte Carlo model '
        '(50,000 paths, seed=42). Slides marked NEW have been added in this version.',
        styles['SlideNote']))

    story.append(PageBreak())

    # ============================================================
    # SLIDE 1: TITLE (content version)
    # ============================================================
    slide_header('1', 'Title Slide', 'Cover page')
    story.append(Paragraph(
        '<b>futureproof</b>', styles['SlideBody']))
    callout(
        'Turning residential property from an illiquid asset into '
        'sustainable retirement income — without selling, depleting equity, '
        'or sharing appreciation.')
    story.append(Spacer(1, 3*mm))
    story.append(Paragraph(
        'John R Innes<br/>'
        'Co-Founder &amp; Executive Director<br/>'
        'john.innes@futureprooffinancial.co<br/>'
        '+61 (0)408 306 235',
        styles['SlideBody']))
    story.append(Paragraph(
        '\u00a92026 Futureproof Financial Group Limited. Confidential.',
        styles['SlideNote']))
    slide_note('Keep the existing visual design. Replace tagline with the above — '
               'it\'s more specific and immediately communicates the value proposition.')

    story.append(PageBreak())

    # ============================================================
    # SLIDE 2: THE PROBLEM
    # ============================================================
    slide_header('2', 'The Problem',
        '36M American retirees have no fit-for-purpose financial product')
    story.append(Paragraph(
        '<b>Heading:</b> "The world\'s largest unserved financial market"',
        styles['SlideBody']))
    story.append(Spacer(1, 2*mm))
    story.append(Paragraph('Key facts (with sources):', styles['SubHead']))
    bullet('<b>$25 trillion</b> in home equity held by retirees across US, UK, and Australia — '
           'the world\'s largest asset class, almost entirely illiquid')
    bullet('<b>36 million</b> US homeowner retirees are under-funded for retirement, '
           'with housing representing 50%+ of net worth')
    bullet('<b>65%</b> of retirees will never purchase an annuity, guaranteed income product, '
           'or investment product — they have no viable alternative')
    bullet('<b>Zero innovation</b> in retirement mortgage products for 35 years — '
           'reverse mortgages (1989) remain the only option, and they deplete equity')

    story.append(Spacer(1, 3*mm))
    story.append(Paragraph(
        'The only products available — reverse mortgages and shared appreciation mortgages — '
        'are expensive for borrowers (compound interest erodes equity), high-risk for lenders '
        '(difficult to fund, near-impossible to securitise), and carry reputational risk '
        'for the financial institutions that offer them.',
        styles['SlideBody']))

    slide_note('Use the existing 2-panel visual (homeowners / retirees) but add source citations. '
               'Remove "suffering" — too emotive for institutional investors. '
               'Replace with "underserved".')

    story.append(PageBreak())

    # ============================================================
    # SLIDE 3: MARKET GAP
    # ============================================================
    slide_header('3', 'The Market Gap',
        'No fit-for-purpose product exists for asset-rich, cash-poor retirees')
    story.append(Paragraph(
        '<b>Heading:</b> "35 years and no one has solved this"',
        styles['SlideBody']))
    story.append(Spacer(1, 2*mm))
    story.append(Paragraph(
        'Two visual panels:', styles['SubHead']))
    story.append(Paragraph(
        '<b>Left panel (35% — blue):</b> 19M cash-rich retirees served by traditional '
        'investment, insurance, and annuity products.<br/><br/>'
        '<b>Right panel (65% — purple):</b> 36M asset-rich, cash-poor retirees. '
        'Current options: reverse mortgages (equity depletion), shared appreciation mortgages '
        '(equity sharing), or nothing.<br/><br/>'
        '<b>Bottom callout:</b> "No US, UK, or Australian financial institution has '
        'introduced a new retirement mortgage product since 1989."',
        styles['SlideBody']))

    slide_note('Keep existing visual structure. Replace "Equity-Eroding Mortgage Products" '
               'with more specific language about what\'s wrong with current options.')

    story.append(PageBreak())

    # ============================================================
    # SLIDE 4: THE SOLUTION
    # ============================================================
    slide_header('4', 'The Solution',
        'A new index-linked mortgage that preserves equity and generates income')
    story.append(Paragraph(
        '<b>Heading:</b> "The Equity Preservation Mortgage\u00ae — a breakthrough retirement mortgage"',
        styles['SlideBody']))
    story.append(Spacer(1, 2*mm))

    story.append(Paragraph('Four-stakeholder value diagram (keep existing layout):', styles['SubHead']))

    stakeholder_data = [
        ['Stakeholder', 'Value Proposition'],
        ['Borrower', 'Tax-free retirement income. Home equity fully preserved.\n'
                     'No repayments. No equity sharing. No sale required.'],
        ['Lender / Product Issuer', 'Non-commoditised product with higher margins.\n'
                          'Lifetime customer retention. Fully insured mortgage.'],
        ['Wholesale Funder', 'Liquid, securitisable mortgage book.\n'
                            'Long-duration, insured assets with predictable cash flows.'],
        ['Regulator', 'Well-understood risks, fully insured and reinsured.\n'
                     'Consumer protections preserved. No systemic risk introduced.'],
    ]
    story.append(make_table(stakeholder_data, col_widths=[35*mm, content_width - 35*mm]))

    story.append(Spacer(1, 3*mm))
    story.append(Paragraph(
        '<b>CHANGE from v2:</b> "Systemically safe / No new risks" \u2192 '
        '"Well-understood risks, fully insured and reinsured." A regulator will '
        'challenge "no new risks" because the index-linked structure is novel. '
        'The accurate claim is that risks are identified and mitigated.',
        styles['SlideNote']))

    story.append(PageBreak())

    # ============================================================
    # SLIDE 5: HOW IT WORKS
    # ============================================================
    slide_header('5', 'How It Works',
        'The product mechanics in plain language')
    story.append(Paragraph(
        '<b>Heading:</b> "A new index-linked mortgage referenced to the S&P 500"',
        styles['SlideBody']))

    story.append(Paragraph('Visual flow: Home Equity \u2192 EPM \u2192 Outcome', styles['SubHead']))
    story.append(Paragraph(
        '<b>Left box (Home Equity):</b><br/>'
        '\u2022 No sale required<br/>'
        '\u2022 No equity depletion<br/>'
        '\u2022 No shared appreciation<br/><br/>'
        '<b>Centre (EPM):</b><br/>'
        '\u2022 Linked to S&P 500 via passive ETFs<br/>'
        '\u2022 30-year term, 80% LTV<br/><br/>'
        '<b>Right box (Outcome):</b><br/>'
        '\u2022 ~1.25% of home value p.a. as tax-free income<br/>'
        '\u2022 Paid for 10 years (with inflation-indexing option)<br/>'
        '\u2022 Home equity fully preserved at maturity',
        styles['SlideBody']))

    story.append(Spacer(1, 3*mm))
    story.append(Paragraph('Key Product Innovations (updated):', styles['SubHead']))
    bullet('Interest paid on behalf of borrower — zero serviceability risk')
    bullet('Traditional credit risk replaced by long-term index risk — '
           'S&P 500 has never delivered negative returns over any 30-year period')
    bullet('Mortgage capital held in segregated offset account invested in passive index ETFs')
    bullet('Built-in volatility buffer (80-120% collar) with annual repricing')
    bullet('Mortgage insurance removes residual lender risk; portfolio reinsurance covers tail risk')
    bullet('Principal &amp; Interest variant amortises mortgage to zero — '
           'Probability of Claim under 5%')

    story.append(Spacer(1, 3*mm))
    story.append(Paragraph(
        '<b>CHANGES from v2:</b><br/>'
        '\u2022 "Up to 2% of Home Value p.a." \u2192 "~1.25% of home value p.a." '
        '(validated by v14a model: $25K/yr on $2M property)<br/>'
        '\u2022 "10-20 Years" \u2192 "10 years" (the model\'s annuity term)<br/>'
        '\u2022 "continuous dynamic hedging" \u2192 "volatility buffer (80-120% collar) '
        'with annual repricing" (accurate description of mechanism)<br/>'
        '\u2022 Added PI amortisation as a key innovation',
        styles['SlideNote']))

    story.append(PageBreak())

    # ============================================================
    # SLIDE 6: WHY IT WORKS (NEW SLIDE)
    # ============================================================
    slide_header('6', 'Why It Works — The Core Insight',
        'NEW SLIDE: The actuarial case for the EPM')
    story.append(Paragraph(
        '<b>Heading:</b> "30-year equity returns reliably exceed mortgage costs — '
        'the EPM captures this spread"',
        styles['SlideBody']))

    callout(
        'This is the most important slide in the deck. It explains why the EPM works '
        'at a fundamental level, and it\'s what separates FutureProof from a hand-wavy '
        'financial product pitch.')

    story.append(Paragraph('The Math:', styles['SubHead']))
    math_data = [
        ['Component', 'Rate', 'Source'],
        ['S&P 500 long-term return', '~10% p.a.', '95-year historical average'],
        ['Total mortgage cost', '~6.4% p.a.', 'Cash rate 4.4% + wholesale 2% + retail 0.7%'],
        ['Gross spread', '~3.6% p.a.', 'Available to fund annuity + surplus'],
        ['Volatility buffer cost', '~0.1% p.a.', '80-120% collar (net income from selling upside)'],
        ['Net available spread', '~3.5% p.a.', 'After hedging, before annuity'],
    ]
    story.append(make_table(math_data, col_widths=[40*mm, 25*mm, content_width - 65*mm]))

    story.append(Spacer(1, 3*mm))
    story.append(Paragraph('Why the risk is manageable:', styles['SubHead']))
    bullet('<b>Duration:</b> Over 30 years, compounding smooths annual volatility. '
           'The S&P 500 has never delivered negative total returns over any 30-year period.')
    bullet('<b>Buffer collar:</b> Annual returns are capped at +20% and floored at -20%, '
           'eliminating extreme tail events in any single year.')
    bullet('<b>Holiday mechanism:</b> If the investment account drops below threshold, '
           'interest charges are suspended and deferred, preventing forced liquidation.')
    bullet('<b>Insurance + Reinsurance:</b> LMI covers 90% of any mortgage deficit; '
           'portfolio reinsurance covers the remaining tail risk.')
    bullet('<b>PI Amortisation (optimised model):</b> Mortgage amortises to zero over '
           '20 years post-annuity, eliminating end-of-term balance risk. '
           'PoC: 4.94% (50,000-path Monte Carlo, independently validated).')

    slide_note('Visual suggestion: a simple line chart showing the spread between '
               'S&P 500 cumulative returns and cumulative mortgage costs over 30 years, '
               'with the shaded area representing surplus available for annuity payments.')

    story.append(PageBreak())

    # ============================================================
    # SLIDE 7: RISK ARCHITECTURE (NEW SLIDE)
    # ============================================================
    slide_header('7', 'Risk Architecture',
        'NEW SLIDE: Five layers of protection')
    story.append(Paragraph(
        '<b>Heading:</b> "Five layers of risk mitigation — PoC under 5%"',
        styles['SlideBody']))

    story.append(Paragraph(
        'Visual: Concentric circles or waterfall diagram showing 5 layers:',
        styles['SubHead']))

    risk_data = [
        ['Layer', 'Mechanism', 'Effect'],
        ['1. Volatility\nBuffer', '80-120% annual collar on S&P 500 returns',
         'Eliminates single-year extreme outcomes'],
        ['2. Holiday\nMechanism', 'Interest charges suspended when investment < threshold',
         'Prevents drawdown cascade in adverse markets'],
        ['3. PI\nAmortisation', 'Mortgage repaid linearly over 20 years (Year 11-30)',
         'Eliminates end-of-term balance risk'],
        ['4. Mortgage\nInsurance', 'LMI covers 90% of individual mortgage deficit',
         'Transfers residual lender risk to insurer'],
        ['5. Portfolio\nReinsurance', 'Reinsurance covers worst 10% tail risk',
         'Removes catastrophic portfolio loss scenario'],
    ]
    story.append(make_table(risk_data, col_widths=[38*mm, 55*mm, content_width - 93*mm]))

    story.append(Spacer(1, 3*mm))
    story.append(Paragraph('Result:', styles['SubHead']))

    result_data = [
        ['Metric', 'Individual Mortgage', 'Portfolio Level'],
        ['Probability of Claim (Year 30)', '4.94%', '< 1% (after cross-subsidisation)'],
        ['Monte Carlo Paths', '50,000', '50,000'],
        ['Mean Surplus at Maturity', '$1,440,000', 'Net positive across all scenarios'],
        ['P5 Surplus (95th percentile safe)', '$8,600 (positive)', 'Strongly positive'],
        ['Insurance Premium (fair + 50%)', '$12,500 per mortgage', 'Portfolio-priced'],
    ]
    story.append(make_table(result_data, col_widths=[45*mm, (content_width - 45*mm)/2, (content_width - 45*mm)/2]))

    story.append(Spacer(1, 3*mm))
    story.append(Paragraph(
        'This slide is critical for institutional investors, reinsurers, and bank product teams. '
        'It demonstrates that FutureProof has done the actuarial work to a professional standard, '
        'not just the product design.',
        styles['SlideNote']))

    story.append(PageBreak())

    # ============================================================
    # SLIDE 8: DEMO
    # ============================================================
    slide_header('8', 'Platform Demo',
        'Live product — calculator in alpha release')
    story.append(Paragraph(
        '<b>Heading:</b> "Live platform — annuity calculator now in alpha testing"',
        styles['SlideBody']))
    story.append(Paragraph(
        'Keep the existing screenshot of the calculator. Update the displayed numbers '
        'to match the model: $2M home value \u2192 $2,083/month ($25,000/year) over 10 years.',
        styles['SlideBody']))
    story.append(Paragraph(
        'Add a line below: "Full SaaS platform includes: borrower portal, lender dashboard, '
        'application processing, document management, AI-powered support, and real-time '
        'risk monitoring — all built and in testing."',
        styles['SlideBody']))
    slide_note('This is a proof point — the tech is built, not vapourware. '
               'The link to the live calculator should work and be impressive.')

    story.append(PageBreak())

    # ============================================================
    # SLIDE 9: TRACTION
    # ============================================================
    slide_header('9', 'Traction & Partners',
        'Building a global institutional ecosystem')
    story.append(Paragraph(
        '<b>Heading:</b> "Institutional partners across legal, consulting, investment, '
        'and reinsurance"',
        styles['SlideBody']))
    story.append(Paragraph(
        'Keep the existing partner logo layout but add clarity on the nature of each '
        'relationship:', styles['SubHead']))

    traction_data = [
        ['Category', 'Partners', 'Status'],
        ['Global Business Partner', 'Accenture', 'Approved Business Intermediary'],
        ['Global Legal', 'Jones Day', 'Engaged'],
        ['Product Co-Design', 'PwC, BlackRock, Spiderock, Atlas SP/Apollo', 'Completed'],
        ['Regulatory (In-Country)', 'EY, Colin Biggers & Paisley, Dentons', 'Engaged'],
        ['Reinsurance', 'Munich Re, Gallagher Re, Lockton Re, Asia Insurance', 'In Negotiation'],
        ['Capital Markets', 'PIMCO, Macquarie', 'In Negotiation'],
        ['Product Issuer Pipeline', '12 financial institutions (AU, Asia, UK, US)', 'Pipeline'],
    ]
    story.append(make_table(traction_data, col_widths=[35*mm, 70*mm, content_width - 105*mm]))

    story.append(Spacer(1, 3*mm))
    story.append(Paragraph(
        '<b>Key distinction:</b> Clearly label which relationships are "completed engagement", '
        '"active negotiation", and "pipeline/exploratory". Sophisticated investors will ask, '
        'and pre-empting the question builds credibility.',
        styles['SlideNote']))

    story.append(PageBreak())

    # ============================================================
    # SLIDE 10: MARKET SIZING
    # ============================================================
    slide_header('10', 'Market Sizing',
        'Bottom-up, not just top-down')
    story.append(Paragraph(
        '<b>Heading:</b> "A $25T addressable market with a proven capture path"',
        styles['SlideBody']))
    story.append(Spacer(1, 2*mm))

    story.append(Paragraph('TAM / SAM / SOM (corrected):', styles['SubHead']))
    market_data = [
        ['Level', 'Value', 'Definition'],
        ['TAM', '$25T', 'Total home equity in target markets (US, UK, AU), growing ~4% p.a.'],
        ['SAM', '$5T', 'Home equity held by retirees with unencumbered property in target markets'],
        ['SOM (5-Year)', '$4B', '20 Product Issuers \u00d7 ~100 mortgages each \u00d7 $2M average = '
         '$4B mortgage book generating ~$20M ARR'],
    ]
    story.append(make_table(market_data, col_widths=[22*mm, 18*mm, content_width - 40*mm]))

    story.append(Spacer(1, 3*mm))
    story.append(Paragraph(
        '<b>CHANGES from v2:</b><br/>'
        '\u2022 SAM reduced from $55B (potential revenue) to $5T (addressable equity) — '
        'these are different measures and the v2 mixing them caused confusion<br/>'
        '\u2022 SOM is now a bottom-up buildout from the Product Issuer rollout plan, '
        'not the current reverse mortgage market<br/>'
        '\u2022 Removed $1B ARR claim — replaced with $20M ARR (realistic from 20 issuers '
        'at ~100 mortgages each, scaling over time)<br/>'
        '\u2022 The $1B ARR is the long-term vision (10-15 years) as portfolio compounds, '
        'not a 5-year target',
        styles['SlideNote']))

    story.append(PageBreak())

    # ============================================================
    # SLIDE 11: BUSINESS MODEL
    # ============================================================
    slide_header('11', 'Business Model',
        '5 recurring revenue streams over 30-year mortgage life')
    story.append(Paragraph(
        '<b>Heading:</b> "SaaS fintech with 5 revenue layers — every mortgage generates '
        '30 years of recurring revenue"',
        styles['SlideBody']))

    story.append(Paragraph('Revenue streams (keep existing visual, update numbers):', styles['SubHead']))

    bm_data = [
        ['#', 'Revenue Stream', 'Mechanism', 'Per Mortgage (30yr)'],
        ['1', 'Embedded SaaS Fee', '25bps annual margin, life-of-loan', '~$140K'],
        ['2', 'Profit Share', '20% of surplus drawn every 3 years', '~$1,290K'],
        ['3', 'End-of-Term Surplus', '50% share at mortgage maturity', '~$700K'],
        ['4', 'Capital Markets', 'Arranging, warehousing, securitisation fees', 'Variable'],
        ['5', 'Insurance', 'Captive insurer commissions + retained risk', 'Variable'],
    ]
    story.append(make_table(bm_data, col_widths=[8*mm, 35*mm, content_width - 73*mm, 30*mm]))

    story.append(Spacer(1, 2*mm))
    story.append(Paragraph(
        'Total estimated lifetime revenue per mortgage: <b>~$2.3M</b> (streams 1-3, from model). '
        'NPV at 4.4%: <b>~$1.2M</b>. Streams 4-5 are incremental.',
        styles['SlideBody']))

    story.append(Spacer(1, 3*mm))
    story.append(Paragraph(
        '<b>CHANGES from v2:</b><br/>'
        '\u2022 "25-50 bps" \u2192 "25bps" (actual FP margin from model)<br/>'
        '\u2022 "50% share of market-linked upside" \u2192 "50% share at mortgage maturity" '
        '(surplus is after all costs, not raw market upside)<br/>'
        '\u2022 Added per-mortgage dollar estimates from the validated model<br/>'
        '\u2022 "Up to 20% retained underwriting risk" — consider adding: '
        '"capped at $X per mortgage" to quantify maximum exposure',
        styles['SlideNote']))

    story.append(PageBreak())

    # ============================================================
    # SLIDE 12: UNIT ECONOMICS
    # ============================================================
    slide_header('12', 'Unit Economics & Market Rollout',
        'Bottom-up revenue build')
    story.append(Paragraph(
        '<b>Heading:</b> "Each Product Issuer generates $1.2M NPV per mortgage originated"',
        styles['SlideBody']))

    story.append(Paragraph('Customer Unit Economics (per B2B customer):', styles['SubHead']))

    ue_data = [
        ['Metric', 'Value', 'Basis'],
        ['Revenue per mortgage (lifetime)', '$2.3M', 'Undiscounted, 30-year'],
        ['Revenue per mortgage (NPV)', '$1.2M', 'Discounted at 4.4% stochastic cash rate'],
        ['Mortgages per issuer (Year 1)', '~50', 'Conservative: existing customer base'],
        ['5-Year value per issuer (NPV)', '$60M', '50 mortgages/yr \u00d7 5 years \u00d7 $1.2M NPV \u00d7 scaling'],
        ['Customer Acquisition Cost', '$1.5M', 'Sales, legal, regulatory, onboarding'],
        ['LTV:CAC (5-year, NPV)', '40:1', 'Conservative; increases with scale'],
    ]
    story.append(make_table(ue_data, col_widths=[45*mm, 22*mm, content_width - 67*mm]))

    story.append(Spacer(1, 3*mm))
    story.append(Paragraph('Market Rollout:', styles['SubHead']))
    rollout_data = [
        ['Market', '2026', '2027', '2028', '2029', '2030', '5yr Total'],
        ['AU / NZ', '1', '2', '2', '2', '2', '9'],
        ['UK', '', '1', '1', '2', '2', '6'],
        ['USA', '', '1', '2', '3', '4', '10'],
        ['Total Issuers', '1', '4', '5', '7', '8', '25'],
    ]
    rcw = content_width / 7
    story.append(make_table(rollout_data, col_widths=[rcw]*7))

    story.append(Spacer(1, 3*mm))
    story.append(Paragraph(
        '<b>CHANGES from v2:</b><br/>'
        '\u2022 "$114M long-term value" \u2192 "$60M 5-year NPV" (more defensible)<br/>'
        '\u2022 "LTV:CAC = 65:1" \u2192 "40:1" (using NPV, not undiscounted; still extraordinary)<br/>'
        '\u2022 "$1B ARR by Year 5" removed — replaced with bottoms-up rollout table<br/>'
        '\u2022 Added NZ to the rollout (platform already supports it)<br/>'
        '\u2022 Increased total issuers to 25 (more realistic geographic spread)',
        styles['SlideNote']))

    story.append(PageBreak())

    # ============================================================
    # SLIDE 13: COMPETITIVE LANDSCAPE
    # ============================================================
    slide_header('13', 'Competitive Landscape',
        'No direct competitor exists')
    story.append(Paragraph(
        '<b>Heading:</b> "The only retirement mortgage that preserves 100% of home equity"',
        styles['SlideBody']))
    story.append(Paragraph(
        'Keep the existing 2x2 matrix visual — it\'s effective. Add a text callout:',
        styles['SlideBody']))
    story.append(Spacer(1, 2*mm))

    comp_data = [
        ['Product Type', 'Equity Impact', 'Borrower Cost', 'Fundability'],
        ['Reverse Mortgage', 'Depletes equity\n(compound interest)', 'High (5-8% APR\ncompounding)', 'Difficult to\nsecuritise'],
        ['Shared Appreciation', 'Gives away equity\n(20-40% of gains)', 'High (equity\nsharing)', 'Near-impossible\nto fund'],
        ['Home Equity Line', 'Monthly repayments\nrequired', 'Medium (variable\nrate)', 'Standard\nmortgage funding'],
        ['EPM', 'Equity fully\npreserved', 'Zero borrower\ncost', 'Liquid,\nsecuritisable'],
    ]
    story.append(make_table(comp_data, col_widths=[30*mm, 38*mm, 35*mm, content_width - 103*mm]))

    story.append(Spacer(1, 3*mm))
    callout(
        'The key differentiator: Reverse mortgages and shared appreciation mortgages require the '
        'borrower to give up equity. The EPM preserves 100% of equity and 100% of future '
        'property appreciation. No competitor offers this.')

    story.append(PageBreak())

    # ============================================================
    # SLIDE 14: GTM STRATEGY
    # ============================================================
    slide_header('14', 'Go-To-Market Strategy',
        'B2B distribution through institutional partners')
    story.append(Paragraph(
        '<b>Heading:</b> "Two distribution channels — partner and direct"',
        styles['SlideBody']))
    story.append(Paragraph(
        'Keep the existing dual-channel visual. Update the examples to current pipeline:',
        styles['SubHead']))

    story.append(Paragraph(
        '<b>Partner Channel (Accenture):</b> Top-tier bank and insurance clients — '
        'Macquarie, AMP, Westpac, Barclays, Nationwide, Lloyds. Accenture acts as '
        'Approved Business Intermediary, providing introductions and credibility.<br/><br/>'
        '<b>FutureProof Direct:</b> Mid-tier and specialist lenders — Resimac, PepperMoney, '
        'Heartland Bank, Allianz Life, Aegon, Aviva, AIA, community banks, credit unions, '
        'non-bank lenders. Lower CAC, faster onboarding.',
        styles['SlideBody']))

    story.append(Spacer(1, 3*mm))
    story.append(Paragraph(
        'Add: "Initial market launch in Australia (Q3 2026) provides proof-of-concept for '
        'UK (Q2 2027) and US (Q4 2027) expansion. The SaaS platform is already multi-jurisdiction — '
        'AU, NZ, UK, and US regions are live in the platform."',
        styles['SlideNote']))

    story.append(PageBreak())

    # ============================================================
    # SLIDE 15: CAPITAL FLOWS
    # ============================================================
    slide_header('15', 'Capital Flows & Securitisation',
        'Unlocking $25T in residential property as a new asset class')
    story.append(Paragraph(
        '<b>Heading:</b> "Creating a new, securitisable asset class from residential property"',
        styles['SlideBody']))
    story.append(Paragraph(
        'Keep the existing capital flows diagram but add a key insight:',
        styles['SlideBody']))
    story.append(Spacer(1, 2*mm))
    story.append(Paragraph(
        'The EPM creates mortgages that are fundamentally different from reverse mortgages for '
        'securitisation purposes:<br/><br/>'
        '\u2022 <b>Predictable cash flows</b> — investment returns generate regular income; '
        'no reliance on property sale timing<br/>'
        '\u2022 <b>Insured</b> — LMI and reinsurance transfer tail risk to rated counterparties<br/>'
        '\u2022 <b>Rated reference asset</b> — S&P 500 index ETFs, not individual property values<br/>'
        '\u2022 <b>Term certain</b> — 30-year maturity (not mortality-dependent like reverse mortgages)<br/><br/>'
        'This makes EPM mortgages candidates for RMBS tranching in a way that '
        'reverse mortgages have never been.',
        styles['SlideBody']))

    story.append(PageBreak())

    # ============================================================
    # SLIDE 16: WHY NOW
    # ============================================================
    slide_header('16', 'Why Now',
        'What has changed to make this possible')
    story.append(Paragraph(
        '<b>Heading:</b> "Five structural shifts make the EPM possible today — not 10 years ago"',
        styles['SlideBody']))

    story.append(Spacer(1, 2*mm))
    bullet('<b>Buffer ETFs at scale:</b> Products like the iShares Buffer ETF suite now provide '
           'efficient, liquid instruments for implementing the 80-120% collar. These didn\'t exist '
           'at meaningful scale before 2020.')
    bullet('<b>Regulatory maturation:</b> FCA Innovation Sandbox (UK), APRA innovation pathways (AU), '
           'and CFPB innovation programmes (US) now provide structured routes for novel mortgage products.')
    bullet('<b>Reinsurance capacity:</b> Global reinsurers (Munich Re, Swiss Re) have expanded '
           'their appetite for longevity and index-linked risk, driven by the retirement mega-trend.')
    bullet('<b>Fiscal pressure:</b> Dependency ratio now 2:1 (taxpayers to retirees). Governments are '
           'actively shifting to user-pay models for retirement, healthcare, and aged care. '
           'Housing wealth is the largest untapped funding source.')
    bullet('<b>Technology:</b> Cloud-native SaaS enables multi-jurisdiction deployment at '
           'near-zero marginal cost. AI-powered underwriting and monitoring reduce operational burden.')

    story.append(Spacer(1, 3*mm))
    story.append(Paragraph(
        '<b>CHANGE from v2:</b> The existing "Why Now" slide (18) only covered demographics, '
        'which has been true for 20 years. The rewritten version explains what\'s specifically '
        'changed in the enabling infrastructure.',
        styles['SlideNote']))

    story.append(PageBreak())

    # ============================================================
    # SLIDE 17-18: TEAM
    # ============================================================
    slide_header('17-18', 'Team',
        'Leadership + Banking/Insurance + Technical')
    story.append(Paragraph(
        'Keep the existing team slides (15-17) largely unchanged — they\'re strong. '
        'The team is clearly a major asset. Minor suggestions:',
        styles['SlideBody']))
    story.append(Spacer(1, 2*mm))
    bullet('Add a brief "Actuarial Validation" note under John De Ravin and Pavel Shevchenko: '
           '"EPM model independently validated via 50,000-path Monte Carlo simulation by '
           'former Chief Actuary (Munich Re) and former Principal Research Scientist (CSIRO)"')
    bullet('Consider adding a "Technical Moat" callout: "Proprietary actuarial model with '
           '17 calibrated parameters, validated across 50,000 Monte Carlo paths. '
           'Model optimisation reduces PoC from 14% to under 5%."')
    bullet('Fix typo on slide 13: "stotchastic" \u2192 "stochastic"')

    story.append(PageBreak())

    # ============================================================
    # SLIDE 19: THE ASK
    # ============================================================
    slide_header('19', 'The Ask',
        'Raising $5M to launch in-market')
    story.append(Paragraph(
        '<b>Heading:</b> "Raising $5M to close the gap from product to revenue"',
        styles['SlideBody']))
    story.append(Spacer(1, 2*mm))

    story.append(Paragraph(
        '<b>Raise:</b> $5M Late Seed (min. $1M on SAFE)<br/>'
        '<b>Purpose:</b> Sprint-to-market — close first Product Issuer, originate first '
        'mortgages, achieve post-revenue status<br/>'
        '<b>Prior Capital:</b> $3M founders (bootstrapped) + $2M Family Offices/HNW',
        styles['SlideBody']))

    story.append(Spacer(1, 3*mm))
    story.append(Paragraph('Milestones (updated):', styles['SubHead']))

    milestone_data = [
        ['Milestone', 'Target', 'Description', 'Gate'],
        ['SaaS Platform', 'End Q2 2026', 'Complete build, all jurisdictions live', 'Milestone'],
        ['Captive Insurer', 'End Q2 2026', 'Guernsey entity, regulatory approval', 'Milestone'],
        ['First Product Issuer', 'End Q3 2026', 'Signed agreement, AU market', 'Key gate'],
        ['First Mortgages', 'Q3-Q4 2026', '$100M loan book (~50 mortgages)', 'Revenue trigger'],
        ['First Revenue', 'End Q4 2026', '$1M+ realised (SaaS fees + origination)', 'Validation'],
        ['UK Pre-Launch', 'End Q4 2026', 'Partner development, regulatory pathway', 'Milestone'],
        ['US Pre-Launch', 'H1 2027', 'Corporate presence, team, pipeline', 'Milestone'],
    ]
    story.append(make_table(milestone_data, col_widths=[30*mm, 22*mm, content_width - 74*mm, 22*mm]))

    story.append(Spacer(1, 3*mm))
    story.append(Paragraph(
        '<b>CHANGES from v2:</b><br/>'
        '\u2022 "First Product Issuer" added as an explicit milestone — this is the key '
        'de-risking event<br/>'
        '\u2022 Revenue target is "$1M+ realised" not "$5M contracted ($1M realised + $4M unrealised)" — '
        'VCs can\'t value unrealised revenue at seed<br/>'
        '\u2022 $1B ARR removed entirely — the vision is communicated through the unit economics, '
        'not a top-line claim',
        styles['SlideNote']))

    story.append(PageBreak())

    # ============================================================
    # SLIDE 20: THANK YOU / CONTACT
    # ============================================================
    slide_header('20', 'Thank You',
        'Contact details')
    story.append(Paragraph(
        'Keep the existing layout with Fin Accelerate photo. Update contacts as needed.',
        styles['SlideBody']))
    story.append(Spacer(1, 3*mm))

    callout(
        'FutureProof is filling a 35-year product gap in the world\'s largest asset class. '
        'We have the team, the partners, the technology, and the actuarial validation. '
        'We need $5M to close the first Product Issuer and prove it in-market.')

    story.append(Spacer(1, 5*mm))
    story.append(Paragraph(
        '<b>John R Innes</b>  |  Co-Founder &amp; Executive Director<br/>'
        'john.innes@futureprooffinancial.co  |  +61 (0)408 306 235<br/>'
        'futureprooffinancial.co',
        styles['SlideBody']))

    story.append(PageBreak())

    # ============================================================
    # APPENDIX: SUMMARY OF ALL CHANGES
    # ============================================================
    story.append(Paragraph('Appendix: Summary of Changes from v2', styles['SlideTitle']))
    story.append(SectionDivider(content_width))
    story.append(Spacer(1, 3*mm))

    changes = [
        ('Annuity claim', '"Up to 2% of Home Value p.a." \u2192 "~1.25% of home value p.a."',
         'v14a model validates $25K on $2M = 1.25%'),
        ('Revenue projection', '"$1B ARR by Year 5 from 20 issuers" removed',
         'Requires $10-20B per issuer; exceeds entire reverse mortgage market'),
        ('SaaS fee', '"50 bps" \u2192 "25bps"',
         'Actual FP margin from model; 70bps is retail margin (belongs to issuer)'),
        ('Hedging description', '"Continuous dynamic hedging" \u2192 "80-120% buffer collar"',
         'Model uses static collar, not delta-hedging'),
        ('Regulator claim', '"No new risks" \u2192 "Well-understood, fully insured"',
         'Index-linked structure is novel; risks are mitigated, not absent'),
        ('Market sizing', 'TAM/SAM/SOM corrected and inverted',
         'SOM now bottom-up from issuer rollout, not reverse mortgage market'),
        ('Unit economics', '$114M LTV \u2192 $60M (5yr NPV)',
         'Using NPV at 4.4%, consistent with model'),
        ('LTV:CAC', '65:1 \u2192 40:1',
         'Using NPV; still 8x typical SaaS benchmark'),
        ('Revenue per mortgage', '$3M \u2192 $2.3M (model-validated)',
         'Built up from FP margin + profit share + surplus share'),
        ('New: Risk Architecture', 'Added slide showing 5-layer risk mitigation',
         'PoC 4.94% from 50K Monte Carlo paths'),
        ('New: Why It Works', 'Added slide explaining core actuarial insight',
         'Spread between equity returns and mortgage costs'),
        ('New: Why Now (updated)', 'Structural shifts, not just demographics',
         'Buffer ETFs, regulatory pathways, reinsurance capacity'),
        ('Slide order', 'Reordered: Problem \u2192 Solution \u2192 Why Works \u2192 Proof \u2192 Business \u2192 Ask',
         'Leads with proof, not just vision'),
        ('Typo', '"stotchastic" \u2192 "stochastic"', 'Slide 13'),
    ]

    # Wrap cells in Paragraphs so text wraps within columns
    cell_style = ParagraphStyle('ChangeCell', fontSize=7.5, leading=10,
        textColor=NAVY, fontName='Helvetica')
    cell_bold = ParagraphStyle('ChangeCellBold', fontSize=7.5, leading=10,
        textColor=NAVY, fontName='Helvetica-Bold')
    header_cell = ParagraphStyle('ChangeHeader', fontSize=8, leading=10,
        textColor=WHITE, fontName='Helvetica-Bold')

    change_data = [[Paragraph('Item', header_cell),
                    Paragraph('Change', header_cell),
                    Paragraph('Rationale', header_cell)]]
    for item, change, rationale in changes:
        change_data.append([
            Paragraph(item, cell_bold),
            Paragraph(change, cell_style),
            Paragraph(rationale, cell_style),
        ])

    story.append(make_table(change_data, col_widths=[30*mm, 65*mm, content_width - 95*mm]))

    story.append(Spacer(1, 10*mm))
    story.append(Paragraph(
        'All financial claims in this rewrite have been validated against the FutureProof '
        'EPM v14a Monte Carlo model (50,000 paths, seed=42). The optimised PI model '
        '(Principal &amp; Interest amortisation, holiday entry 1.05, profit share 20%/3yr) '
        'is used as the reference configuration.',
        styles['SlideNote']))

    doc.build(story)
    print(f"Pitchdeck rewrite generated: {output}")
    return output


if __name__ == '__main__':
    build_one_pager()
    build_pitchdeck()
