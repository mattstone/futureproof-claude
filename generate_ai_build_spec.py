#!/usr/bin/env python3
"""FutureProof — AI Architecture & Build Spec.

Renders the PDF *from* AI_BUILD_SPEC.md (single source of truth): edit the .md,
re-run this, the PDF follows. Same parser/house-style engine as
generate_platform_build_brief.py. Body parsing starts after the
`<!-- pdf:body-start -->` sentinel; a level-1 heading (`# `) starts a new page
only if little room remains (CondPageBreak).
"""
import os
import re
from reportlab.lib.pagesizes import A4
from reportlab.lib.units import mm
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.enums import TA_JUSTIFY, TA_CENTER, TA_LEFT
from reportlab.lib.colors import HexColor, white
from reportlab.platypus import (SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle,
                                PageBreak, CondPageBreak, Preformatted, KeepTogether)

NAVY = HexColor('#2C3E50'); TEAL = HexColor('#3498A8')
CHIP = HexColor('#EAF3F5'); TILE = HexColor('#F4F6F7'); ROW_ALT = HexColor('#F8F9FA')
GREY = HexColor('#95A5A6'); CODE = HexColor('#1B2B36')

SRC = 'AI_BUILD_SPEC.md'
OUT = os.path.join('docs', 'pdfs', 'FutureProof_AI_Architecture_Build_Spec_Jun2026.pdf')
USABLE = 170 * mm


def styles():
    s = getSampleStyleSheet()
    s.add(ParagraphStyle('Body', parent=s['BodyText'], fontSize=10, leading=14.5,
                         alignment=TA_JUSTIFY, spaceAfter=7))
    s.add(ParagraphStyle('H1', parent=s['Heading1'], fontSize=17, textColor=NAVY,
                         spaceBefore=14, spaceAfter=9, keepWithNext=1))
    s.add(ParagraphStyle('H2', parent=s['Heading2'], fontSize=12.5, textColor=TEAL,
                         spaceBefore=11, spaceAfter=4, keepWithNext=1))
    s.add(ParagraphStyle('H3', parent=s['Heading3'], fontSize=10.5, textColor=NAVY,
                         spaceBefore=8, spaceAfter=2, keepWithNext=1))
    s.add(ParagraphStyle('Bul', parent=s['BodyText'], fontSize=10, leading=14,
                         leftIndent=14, bulletIndent=2, spaceAfter=4))
    s.add(ParagraphStyle('Bul2', parent=s['BodyText'], fontSize=10, leading=14,
                         leftIndent=28, bulletIndent=16, spaceAfter=3))
    s.add(ParagraphStyle('Num', parent=s['BodyText'], fontSize=10, leading=14,
                         leftIndent=16, spaceAfter=4))
    s.add(ParagraphStyle('Call', parent=s['BodyText'], fontSize=10, leading=14.5,
                         alignment=TA_LEFT, backColor=CHIP, borderColor=TEAL,
                         borderWidth=0.6, borderPadding=11, spaceBefore=16, spaceAfter=16,
                         textColor=NAVY))
    s.add(ParagraphStyle('Mono', parent=s['BodyText'], fontName='Courier', fontSize=7.8,
                         leading=10, textColor=white))
    s.add(ParagraphStyle('TitleBig', parent=s['Title'], fontSize=27, textColor=NAVY,
                         alignment=TA_CENTER))
    s.add(ParagraphStyle('Sub', parent=s['Title'], fontSize=15, textColor=TEAL,
                         alignment=TA_CENTER, spaceAfter=2))
    s.add(ParagraphStyle('SubL', parent=s['Title'], fontSize=11, textColor=GREY,
                         alignment=TA_CENTER, spaceAfter=2, fontName='Helvetica'))
    s.add(ParagraphStyle('Cell', parent=s['BodyText'], fontSize=8.5, leading=11))
    s.add(ParagraphStyle('CellH', parent=s['BodyText'], fontSize=8.5, leading=11,
                         textColor=white, fontName='Helvetica-Bold'))
    return s


def inline(t):
    t = t.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')
    t = re.sub(r'`([^`]+)`', lambda m: '<font face="Courier" size="9">' + m.group(1) + '</font>', t)
    t = re.sub(r'\*\*(.+?)\*\*', r'<b>\1</b>', t)
    t = re.sub(r'\*(.+?)\*', r'<i>\1</i>', t)
    t = t.replace('—', '&mdash;').replace('–', '&ndash;').replace('→', '-&gt;')
    return t


def esc_code(t):
    return t  # Preformatted renders text literally; no pre-escaping


def col_widths(rows):
    ncol = max(len(r) for r in rows)
    w = [4] * ncol
    for r in rows:
        for i, cell in enumerate(r):
            w[i] = max(w[i], len(cell))
    widths = [max(16 * mm, USABLE * x / sum(w)) for x in w]
    scale = USABLE / sum(widths)
    return [x * scale for x in widths]


def make_table(s, rows):
    header, body = rows[0], rows[1:]
    data = [[Paragraph(inline(c), s['CellH']) for c in header]]
    for r in body:
        r = r + [''] * (len(header) - len(r))
        data.append([Paragraph(inline(c), s['Cell']) for c in r])
    t = Table(data, colWidths=col_widths(rows), repeatRows=1)
    t.setStyle(TableStyle([
        ('GRID', (0, 0), (-1, -1), 0.4, GREY), ('VALIGN', (0, 0), (-1, -1), 'TOP'),
        ('TOPPADDING', (0, 0), (-1, -1), 4), ('BOTTOMPADDING', (0, 0), (-1, -1), 4),
        ('LEFTPADDING', (0, 0), (-1, -1), 5), ('RIGHTPADDING', (0, 0), (-1, -1), 5),
        ('BACKGROUND', (0, 0), (-1, 0), NAVY),
        ('ROWBACKGROUNDS', (0, 1), (-1, -1), [white, ROW_ALT])]))
    return t


def make_code(s, lines):
    pre = Preformatted('\n'.join(esc_code(l) for l in lines), s['Mono'])
    t = Table([[pre]], colWidths=[USABLE])
    t.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, -1), CODE), ('BOX', (0, 0), (-1, -1), 0.5, NAVY),
        ('LEFTPADDING', (0, 0), (-1, -1), 9), ('RIGHTPADDING', (0, 0), (-1, -1), 9),
        ('TOPPADDING', (0, 0), (-1, -1), 7), ('BOTTOMPADDING', (0, 0), (-1, -1), 7)]))
    return KeepTogether(t)


SEP_RE = re.compile(r'^\|[\s:|-]+\|?\s*$')
TABLE_RE = re.compile(r'^\s*\|')
HEAD_RE = re.compile(r'^(#{1,3})\s+(.*)$')
BUL_RE = re.compile(r'^(\s*)[-*]\s+(.*)$')
NUM_RE = re.compile(r'^(\s*)(\d+)\.\s+(.*)$')


def parse_body(s, lines):
    story, para = [], []

    def flush():
        if para:
            story.append(Paragraph(inline(' '.join(para)), s['Body']))
            para.clear()

    i = 0
    while i < len(lines):
        line = lines[i]

        if line.strip().startswith('```'):
            flush()
            i += 1
            buf = []
            while i < len(lines) and not lines[i].strip().startswith('```'):
                buf.append(lines[i]); i += 1
            story.append(make_code(s, buf)); i += 1
            continue

        if line.strip().startswith('<!--'):
            i += 1; continue

        if line.strip() == '---':
            flush(); story.append(Spacer(1, 3 * mm)); i += 1; continue

        m = HEAD_RE.match(line)
        if m:
            flush()
            level = len(m.group(1)); text = m.group(2)
            if level == 1:
                story.append(CondPageBreak(55 * mm))
                story.append(Paragraph(inline(text), s['H1']))
            else:
                story.append(Paragraph(inline(text), s['H'+str(level)]))
            i += 1; continue

        if TABLE_RE.match(line):
            flush()
            rows = []
            while i < len(lines) and TABLE_RE.match(lines[i]):
                raw = lines[i].strip()
                if not SEP_RE.match(raw):
                    cells = [c.strip() for c in raw.strip('|').split('|')]
                    rows.append(cells)
                i += 1
            if rows:
                story.append(make_table(s, rows))
            continue

        if line.startswith('>'):
            flush()
            buf = []
            while i < len(lines) and lines[i].startswith('>'):
                buf.append(lines[i].lstrip('>').strip()); i += 1
            joined = '<br/>'.join(inline(b) for b in buf)
            story.append(KeepTogether(Paragraph(joined, s['Call'])))
            continue

        m = NUM_RE.match(line)
        if m:
            flush()
            story.append(Paragraph('<b>' + m.group(2) + '.</b>&nbsp;&nbsp;' + inline(m.group(3)), s['Num']))
            i += 1; continue

        m = BUL_RE.match(line)
        if m:
            flush()
            lvl = len(m.group(1)) // 2
            sty = s['Bul2'] if lvl >= 1 else s['Bul']
            story.append(Paragraph('<bullet>&bull;</bullet> ' + inline(m.group(2)), sty))
            i += 1; continue

        if line.strip() == '':
            flush(); i += 1; continue

        para.append(line.strip()); i += 1

    flush()
    return story


def cover(s):
    st = []
    st.append(Spacer(1, 46 * mm))
    st.append(Paragraph('FutureProof Financial', s['TitleBig'])); st.append(Spacer(1, 4 * mm))
    st.append(Paragraph('AI Architecture &amp; Build Spec', s['Sub'])); st.append(Spacer(1, 2 * mm))
    st.append(Paragraph('The five agents, the gateway, and the human-in-the-loop model', s['SubL']))
    st.append(Spacer(1, 16 * mm))
    st.append(Paragraph(
        'How we build the AI: the five agents, the gateway they act through, the Claude runtime that powers '
        'them, the guardrails that keep them inside the law, and &mdash; above all &mdash; how the AI and humans '
        'work together. The deep-dive companion to Section 8 of the Platform Strategy &amp; Build Brief: that '
        'section is the summary, this is the build.', s['Call']))
    st.append(Spacer(1, 2 * mm))
    st.append(Paragraph('Five agents. One controlled path. A human on every consequential call.', s['SubL']))
    st.append(Paragraph('Internal &mdash; for the team · June 2026', s['SubL']))
    st.append(PageBreak())
    return st


def footer(canvas, d):
    canvas.saveState()
    canvas.setStrokeColor(GREY); canvas.setLineWidth(0.4)
    canvas.line(20 * mm, 15 * mm, 190 * mm, 15 * mm)
    canvas.setFont('Helvetica', 8); canvas.setFillColor(GREY)
    canvas.drawString(20 * mm, 11 * mm,
                      'FutureProof  |  AI Architecture & Build Spec  |  Internal  |  June 2026')
    canvas.drawRightString(190 * mm, 11 * mm, f'Page {d.page}')
    canvas.restoreState()


if __name__ == '__main__':
    os.chdir(os.path.dirname(os.path.abspath(__file__)))
    with open(SRC, encoding='utf-8') as f:
        text = f.read()
    body = text.split('<!-- pdf:body-start -->', 1)[1]
    s = styles()
    story = cover(s) + parse_body(s, body.splitlines())
    doc = SimpleDocTemplate(OUT, pagesize=A4, topMargin=20 * mm, bottomMargin=22 * mm,
                            leftMargin=20 * mm, rightMargin=20 * mm)
    doc.build(story, onFirstPage=footer, onLaterPages=footer)
    print('Wrote', OUT)
