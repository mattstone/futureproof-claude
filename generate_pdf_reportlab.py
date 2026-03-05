#!/usr/bin/env python3
"""Generate FutureProof EPM Technical Architecture PDF using ReportLab"""

from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import inch
from reportlab.lib.enums import TA_LEFT, TA_CENTER, TA_JUSTIFY
from reportlab.platypus import SimpleDocTemplate, Table, TableStyle, Paragraph, Spacer, PageBreak, Image
from reportlab.lib import colors
import re
from datetime import datetime

# Read markdown file
with open('FutureProof_EPM_Technical_Architecture.md', 'r') as f:
    md_content = f.read()

# Create PDF
pdf_file = 'FutureProof_EPM_Technical_Architecture.pdf'
doc = SimpleDocTemplate(pdf_file, pagesize=A4,
                       rightMargin=0.75*inch, leftMargin=0.75*inch,
                       topMargin=0.75*inch, bottomMargin=0.75*inch)

# Container for PDF elements
elements = []

# Define styles
styles = getSampleStyleSheet()

# Custom styles
title_style = ParagraphStyle(
    'CustomTitle',
    parent=styles['Heading1'],
    fontSize=24,
    textColor=colors.HexColor('#0066CC'),
    spaceAfter=6,
    fontName='Helvetica-Bold'
)

heading_style = ParagraphStyle(
    'CustomHeading',
    parent=styles['Heading2'],
    fontSize=14,
    textColor=colors.HexColor('#0066CC'),
    spaceAfter=10,
    spaceBefore=12,
    fontName='Helvetica-Bold'
)

subheading_style = ParagraphStyle(
    'CustomSubHeading',
    parent=styles['Heading3'],
    fontSize=12,
    textColor=colors.HexColor('#333333'),
    spaceAfter=6,
    spaceBefore=8,
    fontName='Helvetica-Bold'
)

body_style = ParagraphStyle(
    'CustomBody',
    parent=styles['BodyText'],
    fontSize=10,
    alignment=TA_JUSTIFY,
    spaceAfter=8,
    leading=12,
    textColor=colors.HexColor('#333333')
)

# Parse markdown and build elements
lines = md_content.split('\n')
i = 0

while i < len(lines):
    line = lines[i]
    
    # Title (h1)
    if line.startswith('# '):
        title_text = line.replace('# ', '').strip()
        elements.append(Paragraph(title_text, title_style))
        elements.append(Spacer(1, 0.1*inch))
        i += 1
        continue
    
    # Heading (h2)
    if line.startswith('## '):
        heading_text = line.replace('## ', '').strip()
        elements.append(Paragraph(heading_text, heading_style))
        i += 1
        continue
    
    # Subheading (h3)
    if line.startswith('### '):
        subheading_text = line.replace('### ', '').strip()
        elements.append(Paragraph(subheading_text, subheading_style))
        i += 1
        continue
    
    # Horizontal rule
    if line.startswith('---'):
        elements.append(Spacer(1, 0.15*inch))
        i += 1
        continue
    
    # Table
    if line.startswith('|'):
        table_lines = []
        while i < len(lines) and lines[i].startswith('|'):
            table_lines.append(lines[i])
            i += 1
        
        # Parse table
        table_data = []
        for tline in table_lines:
            cells = [cell.strip() for cell in tline.split('|') if cell.strip()]
            if cells:
                table_data.append(cells)
        
        # Remove separator row
        if len(table_data) > 1 and all('-' in cell or len(cell.replace('-', '')) == 0 for cell in table_data[1]):
            table_data.pop(1)
        
        if table_data:
            elements.append(Spacer(1, 0.08*inch))
            
            # Create table with styling
            table = Table(table_data, colWidths=[doc.width / len(table_data[0])] * len(table_data[0]))
            table.setStyle(TableStyle([
                ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor('#0066CC')),
                ('TEXTCOLOR', (0, 0), (-1, 0), colors.whitesmoke),
                ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
                ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
                ('FONTSIZE', (0, 0), (-1, 0), 10),
                ('BOTTOMPADDING', (0, 0), (-1, 0), 12),
                ('TOPPADDING', (0, 0), (-1, 0), 12),
                ('BACKGROUND', (0, 1), (-1, -1), colors.HexColor('#F9F9F9')),
                ('ROWBACKGROUNDS', (0, 1), (-1, -1), [colors.HexColor('#FFFFFF'), colors.HexColor('#F9F9F9')]),
                ('GRID', (0, 0), (-1, -1), 1, colors.HexColor('#CCCCCC')),
                ('FONTNAME', (0, 1), (-1, -1), 'Helvetica'),
                ('FONTSIZE', (0, 1), (-1, -1), 9),
                ('TOPPADDING', (0, 1), (-1, -1), 8),
                ('BOTTOMPADDING', (0, 1), (-1, -1), 8),
                ('VALIGN', (0, 0), (-1, -1), 'TOP'),
            ]))
            elements.append(table)
            elements.append(Spacer(1, 0.1*inch))
        continue
    
    # Empty line
    if not line.strip():
        i += 1
        continue
    
    # Bullet points and regular text
    if line.strip():
        if line.startswith('- ') or line.startswith('* '):
            # Bullet point
            text = line.lstrip('- *').strip()
            elements.append(Paragraph('• ' + text, body_style))
        else:
            # Regular paragraph
            elements.append(Paragraph(line, body_style))
    
    i += 1

# Build PDF
doc.build(elements)
print(f'✅ PDF generated: {pdf_file}')
