#!/usr/bin/env python3
"""
Generate FutureProof EPM — Stakeholder-Gated Build Plan PDF.

Matplotlib + ReportLab, matching the v14c Optimised actuarial review style.
Embeds five charts:
  1. Stakeholder map (hub-and-spoke)
  2. Gantt / milestone timeline with gates
  3. Dependency graph (DAG)
  4. Cost waterfall per milestone
  5. Operate & Evolve cycle (post-live)

Input:   docs/mvp_build_plan/FutureProof_EPM_Stakeholder_Gated_Build_Plan.md
Output:  docs/pdfs/FutureProof_EPM_Stakeholder_Gated_Build_Plan_Apr2026.pdf
"""

import os
import math
from io import BytesIO

import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import FancyArrowPatch, Circle, FancyBboxPatch, Rectangle
from matplotlib.path import Path as MplPath
from matplotlib.patches import PathPatch

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


# ---- palette (match actuarial PDF) ----
DARK_NAVY = HexColor('#2C3E50')
TEAL = HexColor('#3498A8')
CORAL = HexColor('#C0392B')
MID_GREY = HexColor('#95A5A6')
LIGHT_GREY = HexColor('#ECF0F1')
WHITE = colors.white
HEADER_BG = HexColor('#2C3E50')
ROW_ALT = HexColor('#F8F9FA')
GREEN = HexColor('#27AE60')
AMBER = HexColor('#F39C12')
BLUE_ACCENT = HexColor('#1F618D')

# Matplotlib-facing hex strings
MPL_NAVY = '#2C3E50'
MPL_TEAL = '#3498A8'
MPL_CORAL = '#C0392B'
MPL_GREEN = '#27AE60'
MPL_AMBER = '#F39C12'
MPL_GREY = '#95A5A6'
MPL_LIGHT = '#ECF0F1'
MPL_BLUE = '#1F618D'
MPL_VIOLET = '#8E44AD'
MPL_DARKRED = '#922B21'

STAKEHOLDER_COLORS = {
    'M0 Foundation': MPL_GREY,
    'M1 Wholesale Funder': MPL_NAVY,
    'M2 Lender': MPL_TEAL,
    'M3 Investment Partner': MPL_BLUE,
    'M4 Insurance / Reinsurance': MPL_AMBER,
    'M5 Broker': MPL_VIOLET,
    'M6 Consumer + CS': MPL_GREEN,
    'Admin (cross-cutting)': MPL_DARKRED,
    'Go-Live': MPL_CORAL,
    'Post-Live': '#16A085',
}


def get_styles():
    s = getSampleStyleSheet()
    s.add(ParagraphStyle('ReportTitle', parent=s['Title'],
        fontSize=22, textColor=DARK_NAVY, spaceAfter=6*mm,
        alignment=TA_CENTER, fontName='Helvetica-Bold'))
    s.add(ParagraphStyle('ReportSubtitle', parent=s['Normal'],
        fontSize=13, textColor=TEAL, spaceAfter=4*mm,
        alignment=TA_CENTER, fontName='Helvetica'))
    s.add(ParagraphStyle('Confidential', parent=s['Normal'],
        fontSize=11, textColor=CORAL, spaceAfter=8*mm,
        alignment=TA_CENTER, fontName='Helvetica-Oblique'))
    s.add(ParagraphStyle('SectionHead', parent=s['Heading1'],
        fontSize=18, textColor=DARK_NAVY, spaceBefore=8*mm,
        spaceAfter=4*mm, fontName='Helvetica-Bold'))
    s.add(ParagraphStyle('SubHead', parent=s['Heading2'],
        fontSize=14, textColor=TEAL, spaceBefore=5*mm,
        spaceAfter=3*mm, fontName='Helvetica-Bold'))
    s.add(ParagraphStyle('SubSubHead', parent=s['Heading3'],
        fontSize=11.5, textColor=DARK_NAVY, spaceBefore=3*mm,
        spaceAfter=2*mm, fontName='Helvetica-Bold'))
    s.add(ParagraphStyle('BodyText2', parent=s['Normal'],
        fontSize=10, textColor=DARK_NAVY, spaceAfter=3*mm,
        alignment=TA_JUSTIFY, fontName='Helvetica', leading=14))
    s.add(ParagraphStyle('BulletCustom', parent=s['Normal'],
        fontSize=10, textColor=DARK_NAVY, spaceAfter=1.5*mm,
        fontName='Helvetica', leading=13, leftIndent=15, bulletIndent=5))
    s.add(ParagraphStyle('Callout', parent=s['Normal'],
        fontSize=10, textColor=DARK_NAVY,
        spaceBefore=5*mm, spaceAfter=5*mm,
        fontName='Helvetica', leading=14, leftIndent=10, rightIndent=10,
        borderColor=BLUE_ACCENT, borderWidth=0.8, borderPadding=8,
        backColor=HexColor('#EAF2F8')))
    s.add(ParagraphStyle('KeyFinding', parent=s['Normal'],
        fontSize=11, textColor=DARK_NAVY,
        spaceBefore=5*mm, spaceAfter=5*mm,
        fontName='Helvetica-Bold', leading=15, leftIndent=10, rightIndent=10,
        borderColor=TEAL, borderWidth=1, borderPadding=8))
    s.add(ParagraphStyle('WarningCallout', parent=s['Normal'],
        fontSize=10, textColor=DARK_NAVY,
        spaceBefore=5*mm, spaceAfter=5*mm,
        fontName='Helvetica', leading=14, leftIndent=10, rightIndent=10,
        borderColor=CORAL, borderWidth=0.8, borderPadding=8,
        backColor=HexColor('#FDEDEC')))
    return s


def make_table(headers, rows, col_widths=None, align_first_left=True,
               header_bg=HEADER_BG, first_col_bold=False):
    hdr_style = ParagraphStyle('_h', fontName='Helvetica-Bold', fontSize=9,
                                textColor=WHITE, leading=11, alignment=TA_CENTER)
    hdr_left = ParagraphStyle('_hl', fontName='Helvetica-Bold', fontSize=9,
                               textColor=WHITE, leading=11, alignment=TA_LEFT)
    cell_style = ParagraphStyle('_c', fontName='Helvetica', fontSize=9,
                                 textColor=DARK_NAVY, leading=11,
                                 alignment=TA_CENTER)
    cell_left = ParagraphStyle('_cl', fontName='Helvetica', fontSize=9,
                                textColor=DARK_NAVY, leading=11,
                                alignment=TA_LEFT)
    cell_left_bold = ParagraphStyle('_clb', fontName='Helvetica-Bold',
                                     fontSize=9, textColor=DARK_NAVY,
                                     leading=11, alignment=TA_LEFT)

    wh = [Paragraph(str(h), hdr_left if (i == 0 and align_first_left) else hdr_style)
          for i, h in enumerate(headers)]
    wr = []
    for row in rows:
        built = []
        for i, c in enumerate(row):
            if i == 0 and align_first_left:
                style = cell_left_bold if first_col_bold else cell_left
            else:
                style = cell_style
            built.append(Paragraph(str(c), style))
        wr.append(built)

    data = [wh] + wr
    style = TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), header_bg),
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ('GRID', (0, 0), (-1, -1), 0.5, MID_GREY),
        ('ROWBACKGROUNDS', (0, 1), (-1, -1), [WHITE, ROW_ALT]),
        ('TOPPADDING', (0, 0), (-1, -1), 4),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 4),
        ('LEFTPADDING', (0, 0), (-1, -1), 6),
        ('RIGHTPADDING', (0, 0), (-1, -1), 6),
    ])
    t = Table(data, colWidths=col_widths, repeatRows=1)
    t.setStyle(style)
    return t


def fig_to_image(fig, width=170*mm, height=105*mm):
    buf = BytesIO()
    fig.savefig(buf, format='png', dpi=160, bbox_inches='tight',
                facecolor='white', edgecolor='none')
    plt.close(fig)
    buf.seek(0)
    return Image(buf, width=width, height=height)


def footer(canvas, doc):
    canvas.saveState()
    canvas.setFont('Helvetica', 8)
    canvas.setFillColor(MID_GREY)
    canvas.drawString(25*mm, 12*mm,
                      'FutureProof | Stakeholder-Gated Build Plan | April 2026')
    canvas.drawRightString(A4[0] - 25*mm, 12*mm, f'Page {doc.page}')
    canvas.restoreState()


# ================================================================
# CHARTS
# ================================================================

def chart_stakeholder_map():
    """Hub-and-spoke: FutureProof at centre, 7 stakeholder groups around it."""
    fig, ax = plt.subplots(figsize=(8.2, 7.0))
    ax.set_xlim(-1.5, 1.5)
    ax.set_ylim(-1.5, 1.5)
    ax.set_aspect('equal')
    ax.axis('off')

    nodes = [
        ('Wholesale\nFunder',        MPL_NAVY,    'funding'),
        ('Lender',                    MPL_TEAL,    'origination'),
        ('Investment\nPartner',       MPL_BLUE,    'investment'),
        ('Insurance /\nReinsurance',  MPL_AMBER,   'premium'),
        ('Broker',                    MPL_VIOLET,  'distribution'),
        ('Consumer\n+ CS',            MPL_GREEN,   'customer'),
        ('FutureProof\nAdmin',        MPL_DARKRED, 'ops'),
    ]
    n = len(nodes)
    radius = 1.08
    angles = [math.pi/2 - 2*math.pi*i/n for i in range(n)]
    positions = [(radius*math.cos(a), radius*math.sin(a)) for a in angles]

    # Centre node
    ax.add_patch(Circle((0, 0), 0.27, facecolor=MPL_NAVY,
                        edgecolor='white', linewidth=2.5, zorder=5))
    ax.text(0, 0, 'FutureProof\nEPM', color='white', fontsize=11,
            fontweight='bold', ha='center', va='center', zorder=6)

    # Edges and outer nodes
    for (label, color, flow), (x, y) in zip(nodes, positions):
        ax.annotate(
            '', xy=(x*0.76, y*0.76), xytext=(0, 0),
            arrowprops=dict(arrowstyle='-|>', color=MPL_GREY,
                            lw=1.2, alpha=0.65, mutation_scale=14),
            zorder=1)
        # flow label on edge midpoint
        mx, my = x*0.46, y*0.46
        ax.text(mx, my, flow, fontsize=7.5, color=MPL_GREY,
                ha='center', va='center', style='italic',
                bbox=dict(boxstyle='round,pad=0.2', facecolor='white',
                          edgecolor='none', alpha=0.85), zorder=2)
        ax.add_patch(Circle((x, y), 0.22, facecolor=color,
                            edgecolor='white', linewidth=2, zorder=4))
        ax.text(x, y, label, color='white', fontsize=8.5,
                fontweight='bold', ha='center', va='center', zorder=5)

    ax.set_title('Stakeholder Map — Seven Groups, One Platform',
                 fontsize=13, fontweight='bold', color=MPL_NAVY, pad=10)
    return fig


def chart_gantt():
    """Milestone timeline with scope/test/build sub-phases and gate markers."""
    # (label, stakeholder_color, start_week, end_week, scope_end, test_end, build_end, gate_week)
    rows = [
        ('M0 Foundation',             STAKEHOLDER_COLORS['M0 Foundation'],        1,  4,  1.5, 2.0, 4,  4),
        ('M1 Wholesale Funder',       STAKEHOLDER_COLORS['M1 Wholesale Funder'],  5, 10,  6.0, 7.0, 10, 10),
        ('M2 Lender',                 STAKEHOLDER_COLORS['M2 Lender'],            8, 14,  9.0, 10.0, 14, 14),
        ('M3 Investment Partner',     STAKEHOLDER_COLORS['M3 Investment Partner'], 11, 18, 12.5, 14.0, 18, 18),
        ('M4 Insurance / Reinsurance', STAKEHOLDER_COLORS['M4 Insurance / Reinsurance'], 14, 20, 15.0, 16.0, 20, 20),
        ('M5 Broker',                 STAKEHOLDER_COLORS['M5 Broker'],            18, 24, 19.0, 20.0, 24, 24),
        ('M6 Consumer + CS',          STAKEHOLDER_COLORS['M6 Consumer + CS'],    20, 28, 21.5, 23.0, 28, 28),
        ('Admin (cross-cutting)',     STAKEHOLDER_COLORS['Admin (cross-cutting)'], 1, 28, None, None, 28, None),
        ('Go-Live',                   STAKEHOLDER_COLORS['Go-Live'],              28, 32, None, None, 32, 32),
        ('Post-Live',                 STAKEHOLDER_COLORS['Post-Live'],            32, 42, None, None, 42, None),
    ]

    fig, ax = plt.subplots(figsize=(10.2, 6.2))
    y = len(rows)
    for label, color, s, e, sc, tc, bc, gw in rows:
        # Main bar (dim)
        ax.barh(y, e - s, left=s, height=0.58, color=color, alpha=0.22,
                edgecolor=color, linewidth=1.2)
        if sc is not None and tc is not None:
            # Scope segment (lightest)
            ax.barh(y, sc - s, left=s, height=0.58, color=color, alpha=0.35,
                    edgecolor='none')
            # Test segment (medium)
            ax.barh(y, tc - sc, left=sc, height=0.58, color=color, alpha=0.60,
                    edgecolor='none')
            # Build segment (solid)
            ax.barh(y, bc - tc, left=tc, height=0.58, color=color, alpha=0.95,
                    edgecolor='white', linewidth=0.5)
        else:
            ax.barh(y, bc - s, left=s, height=0.58, color=color, alpha=0.85,
                    edgecolor='white', linewidth=0.5)
        # Gate diamond
        if gw is not None:
            ax.scatter([gw], [y], marker='D', s=110, color='black',
                       edgecolor='white', linewidth=1.2, zorder=6)
        y -= 1

    ax.set_yticks(range(len(rows), 0, -1))
    ax.set_yticklabels([r[0] for r in rows], fontsize=9)
    ax.set_xlim(0, 42)
    ax.set_ylim(0.4, len(rows) + 0.6)
    ax.set_xlabel('Week', fontsize=10, color=MPL_NAVY)
    ax.set_xticks(list(range(0, 43, 4)))
    ax.grid(True, axis='x', alpha=0.25, linestyle=':')
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)

    # Vertical marker for pilot live
    ax.axvline(x=32, color=MPL_CORAL, linestyle='--', alpha=0.7, linewidth=1.3)
    ax.text(32, len(rows) + 0.35, 'Pilot live',
            color=MPL_CORAL, fontsize=9, ha='center', fontweight='bold')

    # Legend: phases + gate marker
    from matplotlib.patches import Patch
    legend_elems = [
        Patch(facecolor=MPL_NAVY, alpha=0.35, label='Scope'),
        Patch(facecolor=MPL_NAVY, alpha=0.60, label='Test design'),
        Patch(facecolor=MPL_NAVY, alpha=0.95, label='Build'),
        plt.Line2D([0], [0], marker='D', color='w',
                   markerfacecolor='black', markeredgecolor='white',
                   markersize=9, label='Gate'),
    ]
    ax.legend(handles=legend_elems, loc='lower right', fontsize=8.5,
              frameon=True, facecolor='white', edgecolor=MPL_GREY)

    ax.set_title(
        'Build Gantt — Seven Stakeholder Milestones, Admin Cross-Cutting, '
        'Go-Live & Post-Live',
        fontsize=12.5, fontweight='bold', color=MPL_NAVY, pad=12)
    return fig


def chart_dependency_graph():
    """DAG: Foundation -> Wholesale -> Lender -> (Investment ∥ Insurance)
           -> Broker -> Consumer; Admin feeds all; Go-Live after all."""
    fig, ax = plt.subplots(figsize=(9.5, 5.8))
    ax.set_xlim(0, 10)
    ax.set_ylim(0, 6.2)
    ax.set_aspect('equal')
    ax.axis('off')

    # (key, label, x, y, color)
    nodes = {
        'M0':    ('M0\nFoundation',               0.9, 3.0, MPL_GREY),
        'Admin': ('Admin\n(cross-cutting)',       0.9, 5.3, MPL_DARKRED),
        'M1':    ('M1\nWholesale Funder',         2.8, 3.0, MPL_NAVY),
        'M2':    ('M2\nLender',                   4.5, 3.0, MPL_TEAL),
        'M3':    ('M3\nInvestment Partner',       6.2, 4.2, MPL_BLUE),
        'M4':    ('M4\nInsurance/Reinsurance',    6.2, 1.8, MPL_AMBER),
        'M5':    ('M5\nBroker',                   7.9, 3.0, MPL_VIOLET),
        'M6':    ('M6\nConsumer + CS',            9.3, 3.0, MPL_GREEN),
        'Go':    ('Go-Live',                      9.3, 5.3, MPL_CORAL),
    }

    edges = [
        ('M0', 'M1'), ('M1', 'M2'),
        ('M2', 'M3'), ('M2', 'M4'),
        ('M3', 'M5'), ('M4', 'M5'),
        ('M5', 'M6'),
        ('M6', 'Go'),
        ('Admin', 'M1'), ('Admin', 'M2'), ('Admin', 'M3'),
        ('Admin', 'M4'), ('Admin', 'M5'), ('Admin', 'M6'),
        ('M0', 'Admin'),
    ]

    # Draw edges first
    for src, dst in edges:
        _, x1, y1, _ = nodes[src][0], *nodes[src][1:]
        _, x2, y2, _ = nodes[dst][0], *nodes[dst][1:]
        # Trim endpoints to node edge
        dx, dy = x2 - x1, y2 - y1
        dist = math.hypot(dx, dy)
        ux, uy = dx / dist, dy / dist
        r = 0.48
        start = (x1 + ux * r, y1 + uy * r)
        end = (x2 - ux * r, y2 - uy * r)
        is_admin = src == 'Admin' or dst == 'Admin' or src == 'M0' and dst == 'Admin'
        arrow = FancyArrowPatch(
            start, end,
            arrowstyle='-|>', mutation_scale=14,
            color=MPL_DARKRED if src == 'Admin' else MPL_GREY,
            lw=1.3, alpha=0.7 if src == 'Admin' else 0.85,
            linestyle=':' if src == 'Admin' else '-',
            zorder=1)
        ax.add_patch(arrow)

    # Draw nodes
    for key, (label, x, y, color) in nodes.items():
        ax.add_patch(Circle((x, y), 0.48, facecolor=color,
                            edgecolor='white', linewidth=2.0, zorder=3))
        ax.text(x, y, label, color='white', fontsize=8.2,
                fontweight='bold', ha='center', va='center', zorder=4)

    # Legend
    from matplotlib.patches import Patch
    legend_elems = [
        plt.Line2D([0], [0], color=MPL_GREY, lw=1.5,
                   label='Build dependency'),
        plt.Line2D([0], [0], color=MPL_DARKRED, lw=1.3, linestyle=':',
                   label='Admin feeds every milestone'),
    ]
    ax.legend(handles=legend_elems, loc='lower center', fontsize=8.5,
              frameon=False, ncol=2)

    ax.set_title('Milestone Dependency Graph',
                 fontsize=13, fontweight='bold', color=MPL_NAVY, pad=10)
    return fig


def chart_cost_waterfall():
    """Stacked bar per milestone showing cost components + total line."""
    milestones = ['M0', 'M1', 'M2', 'M3', 'M4', 'M5', 'M6',
                  'Go-Live', 'Contingency']
    # components: CTO, BA, actuary, security, hw, infra, tooling, audit, cont.
    # Approximate allocation per milestone (AUD '000). Roughly sums to ~AUD 285k.
    data = {
        'CTO (engineer)': [12, 16, 15, 19, 12,  8, 10,  0,  0],
        'BA / Programmer':[ 7, 13, 14, 15, 11,  8, 10,  0,  0],
        'External actuary':[0,  0,  0,  6,  6,  0,  0,  4,  6],
        'Security / audit':[0,  0,  0,  0,  0,  0,  0, 33,  0],
        'Hardware':       [12,  0,  0,  0,  0,  0,  2,  1,  0],
        'Infrastructure': [ 2,  1,  1,  1,  0,  0,  0,  0,  0],
        'Tooling / AI':   [ 3,  1,  1,  1,  1,  1,  1,  0,  0],
        'Auditor retainer':[0,  0,  0,  0,  0,  0,  0,  8,  0],
        'Contingency':    [ 0,  0,  0,  0,  0,  0,  0,  0, 37],
    }

    component_colors = {
        'CTO (engineer)':    MPL_NAVY,
        'BA / Programmer':   MPL_TEAL,
        'External actuary':  MPL_BLUE,
        'Security / audit':  MPL_CORAL,
        'Hardware':          '#7F8C8D',
        'Infrastructure':    MPL_GREY,
        'Tooling / AI':      MPL_VIOLET,
        'Auditor retainer':  MPL_GREEN,
        'Contingency':       MPL_DARKRED,
    }

    fig, ax = plt.subplots(figsize=(10.2, 5.8))
    bottoms = np.zeros(len(milestones))
    x = np.arange(len(milestones))

    for comp, values in data.items():
        vals = np.array(values)
        ax.bar(x, vals, bottom=bottoms, color=component_colors[comp],
               edgecolor='white', linewidth=0.8, label=comp)
        bottoms += vals

    # Milestone totals on top
    for xi, total in zip(x, bottoms):
        if total > 0:
            ax.text(xi, total + 1.2, f'${int(total)}k',
                    ha='center', fontsize=9, fontweight='bold',
                    color=MPL_NAVY)

    # Cumulative line ("waterfall total")
    cum = np.cumsum(bottoms)
    ax.plot(x, cum, color=MPL_CORAL, linewidth=2.2, marker='o',
            markersize=7, zorder=5, label='Cumulative total')
    for xi, ci in zip(x, cum):
        ax.text(xi, ci + 6, f'${int(ci)}k', fontsize=8,
                color=MPL_CORAL, ha='center', fontweight='bold')

    ax.set_xticks(x)
    ax.set_xticklabels(milestones, fontsize=9)
    ax.set_ylabel('Cost (AUD $000)', fontsize=10, color=MPL_NAVY)
    ax.set_title('Cost Waterfall — Build Budget by Milestone '
                 '(Total ≈ AUD 285k inc. contingency; legal budgeted '
                 'separately)',
                 fontsize=12.5, fontweight='bold', color=MPL_NAVY, pad=10)
    ax.legend(loc='upper left', fontsize=8, frameon=True,
              facecolor='white', edgecolor=MPL_GREY, ncol=2)
    ax.set_ylim(0, max(cum) * 1.18)
    ax.grid(True, axis='y', alpha=0.3, linestyle=':')
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    return fig


def chart_money_flow():
    """Money-flow map: who pays whom, with origination vs ongoing styles."""
    fig, ax = plt.subplots(figsize=(9.6, 6.8))
    ax.set_xlim(0, 12)
    ax.set_ylim(0, 8)
    ax.set_aspect('equal')
    ax.axis('off')

    # (key, label, x, y, color)
    nodes = {
        'Customer':  ('Customer',            1.2, 4.0, MPL_GREEN),
        'FP':        ('FutureProof\nEPM',    5.2, 4.0, MPL_NAVY),
        'Lender':    ('Lender\n(trust a/c)', 3.2, 6.5, MPL_TEAL),
        'Funder':    ('Wholesale\nFunder',   5.2, 7.3, MPL_BLUE),
        'Invest':    ('Investment\nPartner', 8.2, 6.5, MPL_VIOLET),
        'LMI':       ('LMI',                 8.2, 2.0, MPL_AMBER),
        'Reins':     ('Reinsurer',          10.8, 2.0, MPL_CORAL),
        'Broker':    ('Broker',              1.2, 1.2, MPL_DARKRED),
    }

    # (src, dst, label, style) — style: 'origination' (solid) or 'ongoing' (dashed)
    edges = [
        ('Funder',   'Lender',   'capital drawdown', 'origination'),
        ('Lender',   'Invest',   'portfolio buy',    'origination'),
        ('Customer', 'LMI',      'upfront premium',  'origination'),
        ('LMI',      'Reins',    'cession premium',  'origination'),
        ('FP',       'Broker',   'commission',       'origination'),
        ('Lender',   'Customer', 'monthly annuity',  'ongoing'),
        ('Invest',   'Lender',   'NAV + income',     'ongoing'),
        ('Customer', 'FP',       'retail margin 0.75%', 'ongoing'),
        ('Lender',   'Funder',   'wholesale interest', 'ongoing'),
        ('FP',       'Broker',   'trail 0.15%',      'ongoing'),
        ('LMI',      'Lender',   'claim (if deficit)', 'maturity'),
        ('Customer', 'Lender',   'redemption + split', 'maturity'),
    ]

    style_for = {
        'origination': dict(color=MPL_NAVY, lw=1.4, ls='-',  alpha=0.85),
        'ongoing':     dict(color=MPL_TEAL, lw=1.3, ls='--', alpha=0.85),
        'maturity':    dict(color=MPL_CORAL, lw=1.2, ls=':', alpha=0.85),
    }

    # Draw edges with slight arc so bidirectional flows do not overlap
    seen = {}
    for src, dst, label, style in edges:
        _, x1, y1, _ = nodes[src][0], *nodes[src][1:]
        _, x2, y2, _ = nodes[dst][0], *nodes[dst][1:]
        dx, dy = x2 - x1, y2 - y1
        dist = math.hypot(dx, dy)
        ux, uy = dx / dist, dy / dist
        r = 0.50
        start = (x1 + ux * r, y1 + uy * r)
        end = (x2 - ux * r, y2 - uy * r)
        # Arc direction varies by pair so reciprocal arrows don't overlap
        pair = tuple(sorted([src, dst]))
        seen[pair] = seen.get(pair, 0) + 1
        rad = 0.18 if seen[pair] == 1 else -0.18
        s = style_for[style]
        ax.add_patch(FancyArrowPatch(
            start, end,
            arrowstyle='-|>', mutation_scale=12,
            connectionstyle=f'arc3,rad={rad}',
            color=s['color'], lw=s['lw'], linestyle=s['ls'],
            alpha=s['alpha'], zorder=2))
        # Label at midpoint, nudged perpendicular
        mx = (x1 + x2) / 2 - uy * rad * 2.2
        my = (y1 + y2) / 2 + ux * rad * 2.2
        ax.text(mx, my, label, fontsize=6.8, color=s['color'],
                ha='center', va='center', style='italic',
                bbox=dict(boxstyle='round,pad=0.15', facecolor='white',
                          edgecolor='none', alpha=0.9), zorder=3)

    # Draw nodes
    for key, (label, x, y, color) in nodes.items():
        ax.add_patch(Circle((x, y), 0.50, facecolor=color,
                            edgecolor='white', linewidth=2.2, zorder=5))
        ax.text(x, y, label, color='white', fontsize=8.5,
                fontweight='bold', ha='center', va='center', zorder=6)

    # Legend
    legend_elems = [
        plt.Line2D([0], [0], color=MPL_NAVY, lw=1.5, linestyle='-',
                   label='At origination'),
        plt.Line2D([0], [0], color=MPL_TEAL, lw=1.5, linestyle='--',
                   label='Ongoing (monthly / quarterly)'),
        plt.Line2D([0], [0], color=MPL_CORAL, lw=1.5, linestyle=':',
                   label='At maturity / claim'),
    ]
    ax.legend(handles=legend_elems, loc='lower center', fontsize=8.5,
              frameon=True, ncol=3, facecolor='white', edgecolor=MPL_GREY)

    ax.set_title('Money-Flow Map — Origination, Ongoing, and Maturity',
                 fontsize=13, fontweight='bold', color=MPL_NAVY, pad=10)
    return fig


def chart_operate_evolve_cycle():
    """Circular flow: monitor -> backlog -> scope -> test -> build
       -> gate -> release -> monitor."""
    fig, ax = plt.subplots(figsize=(8.2, 7.0))
    ax.set_xlim(-1.6, 1.6)
    ax.set_ylim(-1.6, 1.6)
    ax.set_aspect('equal')
    ax.axis('off')

    stages = [
        ('Monitor',  MPL_TEAL),
        ('Backlog',  MPL_BLUE),
        ('Scope',    MPL_NAVY),
        ('Test',     MPL_VIOLET),
        ('Build',    MPL_AMBER),
        ('Gate',     MPL_CORAL),
        ('Release',  MPL_GREEN),
        ('Incident\n(if)', MPL_DARKRED),
    ]
    n = len(stages)
    radius = 1.08
    angles = [math.pi/2 - 2*math.pi*i/n for i in range(n)]
    pos = [(radius*math.cos(a), radius*math.sin(a)) for a in angles]

    # Centre label
    ax.add_patch(Circle((0, 0), 0.34, facecolor=MPL_LIGHT,
                        edgecolor=MPL_NAVY, linewidth=1.8, zorder=3))
    ax.text(0, 0.05, 'Operate\n& Evolve', color=MPL_NAVY, fontsize=11,
            fontweight='bold', ha='center', va='center', zorder=4)
    ax.text(0, -0.20, 'post-live loop', color=MPL_GREY, fontsize=8,
            style='italic', ha='center', va='center', zorder=4)

    # Arrow between consecutive stages
    for i in range(n):
        x1, y1 = pos[i]
        x2, y2 = pos[(i + 1) % n]
        # Trim
        dx, dy = x2 - x1, y2 - y1
        dist = math.hypot(dx, dy)
        ux, uy = dx/dist, dy/dist
        r = 0.23
        start = (x1 + ux * r, y1 + uy * r)
        end = (x2 - ux * r, y2 - uy * r)
        ax.add_patch(FancyArrowPatch(
            start, end, arrowstyle='-|>', mutation_scale=14,
            color=MPL_NAVY, lw=1.5, alpha=0.8, zorder=1))

    # Stage nodes
    for (label, color), (x, y) in zip(stages, pos):
        ax.add_patch(Circle((x, y), 0.23, facecolor=color,
                            edgecolor='white', linewidth=2, zorder=4))
        ax.text(x, y, label, color='white', fontsize=8.8,
                fontweight='bold', ha='center', va='center', zorder=5)

    ax.set_title('Post-Live Operate & Evolve Cycle',
                 fontsize=13, fontweight='bold', color=MPL_NAVY, pad=10)
    return fig


def chart_pr_pipeline():
    """Horizontal swim-lane: stakeholder brief -> acceptance tests ->
       AI-drafted code -> CTO review -> CI -> staging gate ->
       production gate -> release. Red cross-back arrow for rejection."""
    fig, ax = plt.subplots(figsize=(10.5, 4.6))
    ax.set_xlim(0, 16)
    ax.set_ylim(-1.8, 3.2)
    ax.set_aspect('auto')
    ax.axis('off')

    stages = [
        (0.2,  'Stakeholder\nbrief signed',   MPL_NAVY,    'human'),
        (2.3,  'Acceptance\ntests authored',  MPL_NAVY,    'human'),
        (4.4,  'AI-drafted\ncode + tests',    MPL_VIOLET,  'ai'),
        (6.5,  'CTO review\n(line-by-line)',  MPL_BLUE,    'human'),
        (8.6,  'CI pipeline\n(unit, contract,\nfidelity, security)',
               MPL_TEAL,    'auto'),
        (10.9, 'Staging\ngate G1–G3',         MPL_AMBER,   'auto'),
        (13.1, 'Production\ngate G4–G6',      MPL_CORAL,   'auto'),
        (15.2, 'Release',                     MPL_GREEN,   'auto'),
    ]

    box_w = 1.8
    box_h = 1.2
    y_box = 1.2

    # Draw boxes + arrows between them
    for i, (x, label, color, kind) in enumerate(stages):
        ax.add_patch(FancyBboxPatch(
            (x - box_w/2, y_box - box_h/2), box_w, box_h,
            boxstyle='round,pad=0.04,rounding_size=0.12',
            facecolor=color, edgecolor='white', linewidth=1.4, zorder=3))
        ax.text(x, y_box, label, color='white', fontsize=8.2,
                fontweight='bold', ha='center', va='center', zorder=4)

        # kind tag
        tag = {'human': 'human', 'ai': 'AI', 'auto': 'automated'}[kind]
        ax.text(x, y_box - box_h/2 - 0.22, tag, color=MPL_GREY,
                fontsize=7.5, style='italic', ha='center', va='top',
                zorder=4)

        if i < len(stages) - 1:
            nx = stages[i+1][0]
            ax.add_patch(FancyArrowPatch(
                (x + box_w/2 + 0.03, y_box),
                (nx - box_w/2 - 0.03, y_box),
                arrowstyle='-|>', mutation_scale=12,
                color=MPL_NAVY, lw=1.3, zorder=2))

    # Red "fail" loop-back from CI / staging / production back to AI-draft box
    failures = [(8.6, 'CI fails'),
                (10.9, 'staging gate fails'),
                (13.1, 'production gate fails')]
    ai_x = 4.4
    for src_x, label in failures:
        # Curved arrow down and back
        curve = MplPath(
            [(src_x, y_box - box_h/2),
             (src_x, -1.1),
             (ai_x, -1.1),
             (ai_x, y_box - box_h/2)],
            [MplPath.MOVETO, MplPath.CURVE4, MplPath.CURVE4, MplPath.CURVE4])
        ax.add_patch(PathPatch(curve, facecolor='none',
                               edgecolor=MPL_CORAL, lw=1.1,
                               linestyle='--', zorder=1))
        ax.annotate('', xy=(ai_x, y_box - box_h/2 - 0.05),
                    xytext=(ai_x + 0.4, -1.0),
                    arrowprops=dict(arrowstyle='-|>',
                                    color=MPL_CORAL, lw=1.1,
                                    linestyle='--'),
                    zorder=1)
        ax.text(src_x, -0.4, label, color=MPL_CORAL, fontsize=7.2,
                ha='center', va='center', style='italic', zorder=2)

    ax.text(ai_x, -1.5, 'On any red: rework the draft — never the gate.',
            color=MPL_CORAL, fontsize=8.4, ha='center', va='center',
            fontweight='bold', zorder=2)

    # Legend block: coloured dots for human / AI / automated
    legend_y = 2.7
    legend_items = [
        (0.3, MPL_BLUE,  'human step'),
        (3.5, MPL_VIOLET,'AI-generated step'),
        (7.1, MPL_TEAL,  'automated check'),
        (10.7, MPL_CORAL,'rejection path'),
    ]
    for x, color, text in legend_items:
        ax.add_patch(Circle((x, legend_y), 0.13, facecolor=color,
                            edgecolor='white', linewidth=1, zorder=3))
        ax.text(x + 0.28, legend_y, text, color=MPL_NAVY,
                fontsize=8.6, va='center', zorder=3)

    ax.set_title('PR → Deployment Pipeline: every change, every time',
                 fontsize=12.5, fontweight='bold', color=MPL_NAVY,
                 pad=12, loc='left')
    return fig


# ================================================================
# CONTENT BUILDERS
# ================================================================

def p(styles, text, style='BodyText2'):
    return Paragraph(text, styles[style])


def bullets(styles, items, style='BulletCustom'):
    out = []
    for item in items:
        out.append(Paragraph('• ' + item, styles[style]))
    return out


def build_cover(styles):
    story = []
    story.append(Spacer(1, 30*mm))
    story.append(Paragraph('FutureProof EPM', styles['ReportTitle']))
    story.append(Paragraph('Stakeholder-Gated Build Plan',
                           styles['ReportSubtitle']))
    story.append(Spacer(1, 6*mm))
    story.append(Paragraph('Seven Stakeholder Gates · ~30 Weeks to Pilot · '
                           '~AUD 285k Build · ~AUD 700k Capital Ask',
                           styles['ReportSubtitle']))
    story.append(Spacer(1, 10*mm))
    story.append(Paragraph('For Stakeholder Distribution — April 2026',
                           styles['Confidential']))

    story.append(Spacer(1, 30*mm))
    meta = [
        ['Document', 'Stakeholder-Gated Build Plan v1.0'],
        ['Prepared for', 'Stakeholder meeting (Tuesday pack)'],
        ['Team', '2 people, AI-first (CTO + BA/Programmer)'],
        ['Duration', '~30 weeks to pilot-live + Post-Live phase'],
        ['Budget (build)', 'AUD 285k with contingency (legal separate)'],
        ['Run-rate (post-live)', '~AUD 325–360k / year'],
        ['Capital ask', 'AUD 700k (build + 12 mo post-live + migration '
                        'reserve + buffer)'],
        ['Infrastructure', 'Fly.io Sydney (pilot) → AWS ap-southeast-2 '
                           '(triggered, not time-based)'],
    ]
    tbl = Table(meta, colWidths=[55*mm, 110*mm])
    tbl.setStyle(TableStyle([
        ('FONTNAME', (0, 0), (0, -1), 'Helvetica-Bold'),
        ('FONTNAME', (1, 0), (1, -1), 'Helvetica'),
        ('FONTSIZE', (0, 0), (-1, -1), 9.5),
        ('TEXTCOLOR', (0, 0), (0, -1), DARK_NAVY),
        ('TEXTCOLOR', (1, 0), (1, -1), DARK_NAVY),
        ('TOPPADDING', (0, 0), (-1, -1), 5),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 5),
        ('LINEBELOW', (0, 0), (-1, -1), 0.3, MID_GREY),
        ('LEFTPADDING', (0, 0), (-1, -1), 8),
    ]))
    story.append(tbl)
    story.append(PageBreak())
    return story


def build_exec_summary(styles):
    story = []
    story.append(Paragraph('Executive Summary', styles['SectionHead']))
    story.append(p(styles,
        'An Australian-first Equity Preservation Mortgage, built to pilot-'
        'live in <b>thirty weeks</b> by a two-person AI-first team and '
        'gated, one stakeholder at a time, by the people whose money and '
        'reputation sit on the platform: the wholesale funder, the lender, '
        'the investment partner, the reinsurer, the broker, the consumer. '
        'Every stakeholder signs their own scope, watches their own tests '
        'go green, and countersigns their own gate before we move on. '
        'Nothing ships on trust.'))
    story.append(p(styles,
        'The capital ask is <b>AUD 700k</b>: a <b>AUD 285k</b> build '
        'through to pilot, a funded Year-1 Post-Live runway, a named '
        'reserve for the Fly.io → AWS migration when a counterparty '
        'first demands it, and an operational contingency buffer. External '
        'legal spend (contracts, PDS, broker accreditation, funder '
        'agreements, AFSL / ACL work) is funded from a separate legal '
        'budget and is not included in this ask. The output is a launched '
        'product, countersigned integration reports from every '
        'counterparty, a clean pen test, a filed PDS, and a live pilot '
        'cohort — not a prototype.'))

    story.append(Paragraph('Headline points', styles['SubHead']))
    story.extend(bullets(styles, [
        '<b>Stakeholder-gated ceremony.</b> Formal scope → tests → build '
        'loop per stakeholder group; binary pass/fail at each gate. '
        'No stakeholder is surprised at pilot — each has signed their '
        'own milestone.',
        '<b>Funding-first sequencing.</b> Supply side (funder, lender, '
        'investment partner, reinsurer) gated before demand side (broker, '
        'consumer). The capital table is proven before the first customer '
        'walks in.',
        '<b>Investment partner has a Plan-B.</b> BlackRock is the working '
        'assumption; the Investment Partner Interface abstraction allows a '
        'domestic managed-account provider to be substituted on ~4 weeks '
        'of work if needed.',
        '<b>AI-first with guardrails.</b> Claude writes the first draft of '
        'most code, tests and briefs; acceptance tests, deploy gates '
        '(G1–G6) and contract / model-fidelity tests contain AI '
        'weaknesses. No AI output bypasses the gate.',
        '<b>AI cuts ~AUD 285k / yr from back-office run-rate</b> across '
        'finance, operations, customer support and marketing — the reason '
        'Post-Live is a two-person team rather than five.',
        '<b>Explicit Post-Live phase.</b> Release cadence, incident model, '
        'security re-certification, model recalibration and an '
        'event-triggered infrastructure migration are all named and '
        'budgeted — day one, not day ninety.',
        '<b>Fly.io verdict.</b> Fit for pilot; migrate to AWS Sydney when '
        'the first counterparty due-diligence questionnaire asks for IRAP '
        'or APRA CPS 234 — not before, not later.',
    ]))

    story.append(Spacer(1, 3*mm))
    story.append(fig_to_image(chart_stakeholder_map(),
                              width=155*mm, height=135*mm))
    story.append(PageBreak())
    return story


def build_vs_budget(styles):
    # Retained as no-op to avoid renumbering call sites; returns empty story.
    return []


def build_team_section(styles):
    story = []
    story.append(Paragraph('1. Team & Working Model', styles['SectionHead']))
    story.append(p(styles, 'Two people. Both can code.'))
    story.extend(bullets(styles, [
        '<b>CTO</b> — architecture, CI/CD, deploy gates, on-call, partner '
        'API integrations. Owns the release branch.',
        '<b>BA / Programmer</b> — stakeholder management, requirements '
        'briefs, acceptance-test authoring, and production-grade code '
        'generation via Claude prompts (AI-augmented). The BA is not a '
        'note-taker; they ship.',
    ]))

    story.append(Paragraph('BA working loop', styles['SubHead']))
    story.extend(bullets(styles, [
        'Meet stakeholder, capture the scope verbally.',
        'Write the one-page scope brief. Get stakeholder sign-off.',
        'Convert the brief into executable acceptance tests.',
        'Drive Claude prompts to generate the implementation against those '
        'tests.',
        'CTO reviews, lands, and promotes through the gate.',
    ]))

    story.append(Paragraph(
        'Velocity assumption: AI-first 2-person team ≈ 1.8× pre-AI 2-person '
        'team. Documented honestly. Not 5×. Not 10×. The BA\'s bottleneck '
        'is stakeholder-facing work; AI helps, it does not replace.',
        styles['Callout']))

    story.append(Paragraph('1.1 AI-first — with explicit guardrails',
                           styles['SubHead']))
    story.append(p(styles,
        'We take an AI-first approach to delivery. Claude drafts most '
        'code, tests and stakeholder briefs. We also accept openly that '
        'AI is not perfect — it hallucinates APIs, drifts on long '
        'context, and produces plausible-looking but subtly wrong code in '
        'regulated-finance domains. Our delivery process is built to '
        'contain those weaknesses rather than pretend they are absent.'))

    story.append(fig_to_image(chart_pr_pipeline(),
                              width=175*mm, height=78*mm))

    story.append(p(styles,
        'The pipeline above is how every change ships — AI-drafted or '
        'not. Humans set the intent (signed stakeholder brief, authored '
        'acceptance tests). AI drafts the implementation. Humans review '
        'line-by-line. Automation then enforces the rules: CI runs unit, '
        'contract and model-fidelity tests against the locked v14c '
        'Optimised actuarial output; staging gates G1–G3 and production '
        'gates G4–G6 run on every release. On any red, the rework lands '
        'on the draft — never on the gate. That is the whole point: AI '
        'buys us throughput per person, not ceremony skipped.'))
    return story


def build_commercial_assumptions_section(styles):
    story = []
    story.append(PageBreak())
    story.append(Paragraph('2. Working Commercial Assumptions',
                           styles['SectionHead']))
    story.append(p(styles,
        'The table below is the planning baseline for each stakeholder '
        'group. These are <i>assumptions</i>, not commitments — the final '
        'number for every line is signed off as part of its milestone '
        'scope brief and can move during commercial negotiation. They are '
        'published here so the stakeholder reading this plan can see '
        'their own economics at a glance rather than discovering them '
        'milestone by milestone.'))

    rows = [
        ['Wholesale funder', 'Wholesale rate',
         'BBSW + 2.5%', 'Final rate set at M1 gate; range 2.0–3.0%'],
        ['Wholesale funder', 'Concentration limit',
         '3% of facility per single mortgage',
         'Funder policy standard'],
        ['Lender', 'Origination fee (customer-paid)',
         '1.5% of facility', 'v14c Optimised input'],
        ['Lender', 'Servicing fee',
         '0.25% p.a. of outstanding',
         'Lender commercial standard'],
        ['Investment Partner', 'Management fee (BlackRock)',
         '0.15% p.a. on portfolio',
         'iShares indicative; negotiated at M3'],
        ['Investment Partner', 'Custody fee',
         '0.05% p.a.', 'Ditto'],
        ['LMI', 'Upfront premium (typical $750k facility)',
         '~AUD 9,600',
         'v14c: $4,863 fair + $4,737 load'],
        ['Reinsurer', 'Attachment point',
         'P20 of deficit distribution',
         'v14c actuarial review'],
        ['Reinsurer', 'Cession rate above attachment',
         '70%', 'Working assumption; negotiated at M4'],
        ['Broker', 'Upfront commission',
         '0.65% of facility', 'Industry standard; 2-yr clawback'],
        ['Broker', 'Trail commission',
         '0.15% p.a. of outstanding', 'Industry standard'],
        ['FutureProof', 'Retail margin',
         '0.75% p.a. on portfolio',
         'v14c Optimised input'],
        ['FutureProof', 'Surplus split (customer share at maturity)',
         '80%', 'v14c Optimised input'],
    ]
    story.append(make_table(
        ['Stakeholder', 'Assumption', 'Value', 'Source / status'],
        rows, col_widths=[34*mm, 50*mm, 40*mm, 46*mm]))

    story.append(Paragraph(
        'All figures are AUD unless noted. The v14c Optimised actuarial '
        'review underpins the FutureProof, LMI, and reinsurer lines; '
        'every other line is a working commercial assumption until its '
        'milestone gate closes.', styles['Callout']))
    story.append(PageBreak())
    return story


def build_gantt_section(styles):
    story = []
    story.append(Paragraph('3. Milestone Timeline', styles['SectionHead']))
    story.append(p(styles,
        'Each milestone runs the scope → test → build loop with a named '
        'gate. Admin is cross-cutting: M0 ships the skeleton, every '
        'subsequent milestone adds a surface. Go-Live is a four-workstream '
        'phase running in parallel.'))
    story.append(fig_to_image(chart_gantt(), width=172*mm, height=106*mm))

    story.append(Spacer(1, 4*mm))
    story.append(Paragraph('Dependency graph', styles['SubHead']))
    story.append(p(styles,
        'Funding-first. Foundation unblocks Wholesale Funder; Wholesale '
        'unblocks Lender; Lender unblocks both Investment Partner and '
        'Insurance/Reinsurance in parallel; Broker joins after both; '
        'Consumer is last. Admin evolves alongside every milestone.'))
    story.append(fig_to_image(chart_dependency_graph(),
                              width=168*mm, height=102*mm))
    story.append(PageBreak())
    return story


MILESTONES = [
    {
        'title': 'M0 — Foundation (weeks 1–4, ~AUD 22k)',
        'stakeholder': 'FutureProof internal. Signs off: CTO.',
        'scope': 'Harden the platform for production operation. Deliver '
                 'the stakeholder-gate framework as a first-class piece of '
                 'code so M1–M6 inherit it. Cloudflare in front of Fly.io '
                 'Sydney; WAF on; rate limiting on; secrets out of the '
                 'repo; database with point-in-time recovery; observability '
                 '(Sentry + health checks + structured logs).',
        'tests': 'Unit and integration suite baselined and grown past 600 '
                 'tests by end of M0; static security scanning and '
                 'dependency-vulnerability checks; content-security-policy '
                 'scan; smoke suite that runs post-deploy against staging.',
        'build': 'CI/CD pipeline with five stages (lint / test / '
                 'model-fidelity / security / artefact); deploy gate '
                 'framework (G1–G6 as inheritable Actions jobs); Admin '
                 'skeleton (authenticated, audit-logged, role-based); '
                 'Fly.io production hardened.',
        'gate': 'All five pipeline stages green on main for 14 consecutive '
                'days. Staging deploys automatic on merge. Production '
                'deploys behind a signed release tag.',
        'risk': 'Under-investing here leaves every subsequent milestone '
                'slower. Mitigation: M0 is not compressed; it takes as long '
                'as it takes inside the 4-week window.',
    },
    {
        'title': 'M1 — Wholesale Funder (weeks 5–10, ~AUD 42k)',
        'stakeholder': 'Non-bank wholesale funder. Signs off: funding '
                       'agreement, wholesale rate, drawdown mechanics, '
                       'reconciliation spec, security controls.',
        'scope': 'Define the funding leg end-to-end. What triggers a '
                 'drawdown, what data is exchanged, how reconciliations run, '
                 'how disputes escalate, how incident communication works. '
                 'One-page scope brief written week 5 by the BA and signed '
                 'by the funder before any code is written.',
        'tests': 'Contract tests (Pact-style) against the funder\'s API '
                 'spec; reconciliation fidelity tests (daily files match '
                 'general ledger); drawdown mechanics (pre-approved limits, '
                 'concentration rules, haircut logic); tabletop for a '
                 'funder-side outage.',
        'build': 'In-repo fake funder (built first — unblocks M2 and M3); '
                 'real sandbox integration against the funder\'s development '
                 'environment; production connector with TLS-pinned mTLS. '
                 'Admin surface: funder dashboard (positions, drawdowns, '
                 'reconciliation state, dispute log).',
        'gate': 'Reconciliation matches for 14 consecutive days across '
                'fake → sandbox → production, and the funder countersigns '
                'the integration test report.',
        'risk': 'No funder signed by week 5. Mitigation: approach 3 funders '
                'in parallel from week 1 (the BA\'s job). Fake-first '
                'architecture means build continues in parallel with the '
                'commercial negotiation.',
    },
    {
        'title': 'M2 — Lender (weeks 8–14, ~AUD 44k)',
        'stakeholder': 'Retail lender (AFSL holder). Signs off: origination '
                       'rules, credit decision engine, servicing workflow, '
                       'lender operational dashboard.',
        'scope': 'The rule matrix — who gets approved, under what LVR, '
                 'with what income, under what property type. The servicing '
                 'workflow — how statements are produced, how missed '
                 'payments are handled, how redraws work, how the payment '
                 'waterfall is triggered. All codified, all acceptance-'
                 'tested.',
        'tests': 'Rule-matrix tests (one test per approval pathway, one '
                 'per rejection reason); servicing-workflow tests; AFSL '
                 'responsible-lending compliance tests; stakeholder-'
                 'walkthrough with the lender operations team (recorded).',
        'build': 'Credit decision engine as a deterministic service; '
                 'servicing workflow as controllers + background jobs; '
                 'lender dashboard (applications in flight, approvals, '
                 'rejections, servicing events).',
        'gate': 'Lender-ops signs the rule matrix and the servicing '
                'runbook. Tests pass clean. Dependencies: M1 gate-green.',
        'risk': 'Rule matrix churns as the lender discovers edge cases '
                'late. Mitigation: tests are authored by the BA during '
                'scope; changes require re-sign. Budget three rounds of '
                'iteration into the 6 weeks.',
    },
    {
        'title': 'M3 — Investment Partner (weeks 11–18, ~AUD 56k)',
        'stakeholder': 'BlackRock (working assumption — no commercial '
                       'agreement exists at plan start). Signs off: '
                       'portfolio construction, rebalancing policy, custody '
                       'reporting, API contract, sandbox reconciliation.',
        'scope': 'The investment leg. What portfolio is constructed (≈70% '
                 'equity ETF / ≈30% fixed income per the actuarial review); '
                 'who holds custody; how rebalancing is triggered '
                 '(band-based, time-based, or event-based); how NAV and '
                 'position reporting is delivered; what data is returned '
                 'daily and in what format.',
        'tests': 'Contract tests against the Aladdin-adjacent sandbox '
                 '(portfolio construction, order placement, position and '
                 'NAV retrieval); iShares pricing feed tests; model-fidelity '
                 'tests (against v14c golden vectors); stakeholder-'
                 'walkthrough with BlackRock technical; tabletop for '
                 'BlackRock-side outage.',
        'build': 'Investment connector behind an abstraction (the '
                 '"Investment Partner Interface"). Concrete implementation '
                 'against BlackRock; a second implementation against the '
                 'fake. Admin surface: portfolio positions, NAV trajectory, '
                 'rebalance events, daily BlackRock reconciliation.',
        'gate': 'Sandbox reconciliations clean for 14 consecutive days. '
                'BlackRock countersigns the integration test report. '
                'Dependencies: M1, M2 gate-green.',
        'risk': '<b>Primary unknown.</b> BlackRock does not sign in the '
                'plan window. Plan B: the Investment Partner Interface '
                'abstraction allows substitution of a domestic '
                'managed-account provider (Macquarie, Mason Stevens, '
                'Netwealth) on ~4 weeks of additional work. The abstraction '
                'is built regardless of partner choice.',
    },
    {
        'title': 'M4 — Insurance / Reinsurance (weeks 14–20, ~AUD 38k)',
        'stakeholder': 'LMI provider + tail-risk reinsurer. Signs off: '
                       'policy binding terms, claim notification, premium '
                       'remittance schedule, attachment point (currently '
                       'P20 of deficit distribution per v14c actuarial '
                       'review).',
        'scope': 'LMI layer and tail-risk reinsurance layer defined '
                 'separately. Premium calculation, upfront charge '
                 'mechanics, claim notification on deficit events at '
                 'maturity, reinsurer attachment and cession terms.',
        'tests': 'Attachment-point tests (P20 of deficit distribution '
                 'correctly identified per v14c); premium calculation '
                 'tests (match the actuarial review\'s $9,600 upfront + '
                 '$4,863 fair loaded for the Optimised base); policy '
                 'lifecycle tests; stakeholder walkthrough with LMI + '
                 'reinsurer.',
        'build': 'Policy binding workflow; premium remittance ledger; '
                 'claim notification pipeline; admin surface: in-force '
                 'policies, premium history, claim events, reinsurer '
                 'cession ledger.',
        'gate': 'LMI provider and reinsurer both countersign the '
                'integration test report. Claim notification tested '
                'end-to-end against synthetic deficit cases.',
        'risk': 'Reinsurer capacity at the attachment point. Mitigation: '
                'present the v14c Optimised actuarial review to the '
                'reinsurer early (week 14) and iterate on attachment if '
                'challenged.',
    },
    {
        'title': 'M5 — Broker (weeks 18–24, ~AUD 34k)',
        'stakeholder': 'Pilot brokers. Signs off: broker accreditation '
                       'process, commission structure, broker portal UX, '
                       'application handoff mechanics.',
        'scope': 'Distribution. Broker accreditation (who can introduce '
                 'business), commission accrual and payment schedule, '
                 'portal for broker-lodged applications, handoff mechanics '
                 'between broker-initiated and direct-initiated '
                 'applications.',
        'tests': 'Accreditation-flow tests; commission-calculation tests '
                 '(including clawback rules); portal journey tests; '
                 'stakeholder walkthrough with pilot brokers.',
        'build': 'Broker portal (consistent with the rest of the platform '
                 'CSS framework); accreditation workflow; commission '
                 'ledger; broker-scoped admin views.',
        'gate': 'Pilot brokers sign the portal acceptance checklist. '
                'Commission calculations reconcile against test scenarios. '
                'Dependencies: M2, M3 gate-green.',
        'risk': 'Broker accreditation process is regulatorily sensitive. '
                'Mitigation: legal review before build (week 18); '
                'accreditation rules are acceptance-tested, not free-form.',
    },
    {
        'title': 'M6 — Consumer + Customer Support (weeks 20–28, ~AUD 44k)',
        'stakeholder': 'Pilot customers + CS operator(s). Signs off: '
                       'application journey, quote calculator, e-sign '
                       'flow, statements, dispute flow, support case '
                       'triage.',
        'scope': 'The end-to-end customer experience. Application, quote, '
                 'e-sign, statement view, dispute submission, support case. '
                 'Plus the CS console: case queue, triage, response '
                 'templates, escalation to actuary or legal.',
        'tests': 'Customer-journey tests (quote → application → '
                 'underwriting → contract → e-sign → settlement); '
                 'accessibility tests (WCAG 2.1 AA); CS console tests; '
                 'dispute-flow tests; stakeholder walkthrough with pilot '
                 'customers (5–10) and CS operators.',
        'build': 'Customer application surface; quote calculator (using '
                 'the locked v14c Optimised model); e-sign integration; '
                 'statement renderer; dispute and support case flows; '
                 'CS console.',
        'gate': '10 pilot customer intents successfully completed through '
                'the journey in staging. Pilot CS operator signs the '
                'console acceptance checklist. Dependencies: M1–M5 '
                'gate-green.',
        'risk': 'E-sign and ID verification vendor integration. '
                'Mitigation: vendor selection in M0; vendor APIs wrapped '
                'behind a thin abstraction to allow substitution.',
    },
]


def build_milestones_section(styles):
    story = []
    story.append(Paragraph('4. Stakeholder Milestones (M0–M6)',
                           styles['SectionHead']))
    story.append(p(styles,
        'For each milestone: stakeholder and sign-off, scope artefacts, '
        'tests built first, build deliverable, gate criterion, key risk. '
        'Each block below is a single gated loop — scope is signed, tests '
        'are authored, build lands against tests, gate closes.'))

    for m in MILESTONES:
        block = [
            Paragraph(m['title'], styles['SubHead']),
            Paragraph('<b>Stakeholder · sign-off.</b> ' + m['stakeholder'],
                      styles['BodyText2']),
            Paragraph('<b>Scope.</b> ' + m['scope'], styles['BodyText2']),
            Paragraph('<b>Tests first.</b> ' + m['tests'],
                      styles['BodyText2']),
            Paragraph('<b>Build.</b> ' + m['build'], styles['BodyText2']),
            Paragraph('<b>Gate.</b> ' + m['gate'], styles['BodyText2']),
            Paragraph('<b>Key risk.</b> ' + m['risk'], styles['BodyText2']),
            Spacer(1, 3*mm),
        ]
        story.append(KeepTogether(block))

    story.append(Paragraph('Admin — cross-cutting (weeks 1–28)',
                           styles['SubHead']))
    story.append(p(styles,
        'FutureProof Admin is not a single milestone. It evolves through '
        'every milestone: M0 ships the skeleton, M1 adds funder views, M2 '
        'adds lender views, M3 adds investment views, M4 adds insurance, '
        'M5 adds broker, M6 adds customer + CS console. Admin is '
        'authenticated, audit-logged, role-based. Every stakeholder group '
        'sees their own data; only FutureProof ops sees everything.'))
    story.append(PageBreak())
    return story


def build_money_flow_section(styles):
    story = []
    story.append(Paragraph('5. Money-Flow Map', styles['SectionHead']))
    story.append(p(styles,
        'Who pays whom, when. The diagram below shows the three stages of '
        'capital movement through the platform: at origination, ongoing, '
        'and at maturity / claim. Every arrow here corresponds to a '
        'reconciliation test in the milestone it is introduced; nothing '
        'in this diagram exists in the code without a test that proves '
        'the dollars end up on the right balance sheet.'))

    story.append(fig_to_image(chart_money_flow(),
                              width=172*mm, height=122*mm))

    story.append(Paragraph('At origination (day 0)', styles['SubHead']))
    story.extend(bullets(styles, [
        'Wholesale funder draws down the facility amount to the lender\'s '
        'trust account. Reconciliation runs same-day.',
        'Lender invests the drawn-down capital with the Investment '
        'Partner — initial portfolio constructed per the ≈70% equity ETF '
        '/ ≈30% fixed-income mix.',
        'Customer pays the upfront LMI premium directly to the LMI '
        'provider (not to FutureProof). LMI cedes a portion of the '
        'premium to the tail-risk reinsurer per the cession agreement.',
        'FutureProof remits the broker\'s upfront commission from its '
        'margin line, not from the customer.',
    ]))

    story.append(Paragraph('Ongoing (monthly / quarterly)',
                           styles['SubHead']))
    story.extend(bullets(styles, [
        'Investment Partner returns NAV and income to the lender — daily '
        'reconciliation, quarterly formal statement.',
        'Lender pays the customer the contracted monthly annuity.',
        'FutureProof accrues its 0.75% p.a. retail margin on the '
        'portfolio; debited monthly.',
        'Lender pays the wholesale funder monthly interest on the '
        'drawn-down facility.',
        'FutureProof accrues broker trail commission (0.15% p.a.) from '
        'its own margin.',
    ]))

    story.append(Paragraph('At maturity / on claim', styles['SubHead']))
    story.extend(bullets(styles, [
        'Term maturity: property is sold or the customer redeems. '
        'Principal returned to the wholesale funder; any surplus split '
        '80/20 between customer and FutureProof (per the Optimised model).',
        'Deficit scenario: LMI claim triggered against the deficit up to '
        'the LMI limit; excess above the LMI limit triggers a reinsurer '
        'claim at the P20 attachment point.',
        'Every path above has an acceptance test in M1 (funder), M3 '
        '(investment), or M4 (insurance/reinsurance). The test pack is '
        'authoritative over this narrative.',
    ]))
    story.append(PageBreak())
    return story


def build_golive_section(styles):
    story = []
    story.append(Paragraph('6. Go-Live Phase (weeks 28–32, ~AUD 35k)',
                           styles['SectionHead']))
    story.append(p(styles,
        'Security, UAT, regulator, pilot. Four workstreams running in '
        'parallel. All four must be clean before the Go-Live gate closes.'))

    story.extend(bullets(styles, [
        '<b>External pen test</b> — independent firm, scoped to authenticated '
        '+ unauthenticated app surface + partner integrations. Two weeks. '
        'AUD 15k. Remediation plan signed before gate.',
        '<b>Code audit + SOC 2 gap analysis</b> — external security '
        'consultant reviews the repo, CI, secrets, access controls. '
        'Documents the SOC 2 Type I gap (we will not be SOC 2 certified at '
        'pilot, but we need to know the gap). AUD 10k.',
        '<b>APRA / IRAP gap analysis</b> — documents the gap to APRA CPS '
        '234 and IRAP readiness. Required for the Post-Live migration '
        'trigger decision. AUD 8k.',
        '<b>Stakeholder UAT</b> — one formal UAT round per stakeholder '
        'group. Fail criteria documented; pass criteria documented; '
        'sign-off is written.',
        '<b>Regulatory pack</b> — PDS, TMD, responsible-lending policy, '
        'disclosure documents. Filed.',
        '<b>Pilot cohort origination</b> — 5–10 mortgages through the live '
        'system. Paired origination (CTO + BA each oversees every case). '
        'Monthly reporting established.',
    ]))

    story.append(Paragraph(
        '<b>Go-Live Gate:</b> all seven stakeholder milestones gate-green, '
        'all four workstreams clean, board signs pilot go/no-go in writing. '
        'Any red is no-go.', styles['KeyFinding']))

    story.append(Paragraph('6.1 Pilot success KPIs', styles['SubHead']))
    story.append(p(styles,
        '"Pilot live" is not the same as "pilot successful." The board, '
        'wholesale funder, investment partner, and reinsurer each want '
        'numbers, not adjectives, on the pilot\'s performance. The table '
        'below is the pilot scorecard — measured monthly for the first '
        'six months post-Go-Live and reported back to every stakeholder '
        'group on a standing monthly cadence.'))

    rows = [
        ['Origination volume', '5–10 mortgages in first 6 months',
         'Admin origination ledger'],
        ['Application → quote funnel',
         '≥ 30% of quotes progress to formal application',
         'Funnel analytics in Admin'],
        ['Quote calculator P90 latency', '< 5 seconds customer-facing',
         'Infra monitoring (Sentry / health checks)'],
        ['Underwriting turnaround', '< 5 business days, application to decision',
         'Lender ops dashboard'],
        ['E-sign completion rate',
         '≥ 80% of customers who start e-sign complete',
         'E-sign vendor telemetry'],
        ['RG 271 complaint rate',
         '< 5% of pilot cohort raise a formal complaint',
         'IDR register'],
        ['Funder reconciliation breaks',
         '0 material breaks across the pilot',
         'Daily funder reconciliation job'],
        ['Investment-partner reconciliation breaks',
         '0 material breaks across the pilot',
         'Daily NAV / position reconciliation'],
        ['P1 incidents (money-flow)', '0',
         'Incident register'],
        ['P2 incidents (stakeholder-facing)',
         '< 2 per month across the pilot',
         'Incident register'],
        ['Customer-facing uptime', '≥ 99.5% monthly',
         'Synthetic + real-user monitoring'],
        ['Actuarial model-fidelity CI pass rate',
         '100% on every production deploy',
         'CI model-fidelity stage vs v14c golden vectors'],
    ]
    story.append(make_table(
        ['Metric', 'Target', 'Measurement'],
        rows, col_widths=[56*mm, 64*mm, 50*mm]))
    story.append(Paragraph(
        'A single red KPI does not kill the pilot — but two or more red '
        'in the same month triggers a board review, and three consecutive '
        'red months on any money-flow KPI triggers an automatic pause on '
        'new origination until resolved.', styles['Callout']))
    story.append(PageBreak())
    return story


def build_postlive_section(styles):
    story = []
    story.append(Paragraph('7. Post-Live — Operate & Evolve',
                           styles['SectionHead']))
    story.append(p(styles,
        'The plan does not end at pilot origination. The Post-Live phase is '
        'named, budgeted, and governed. Run-rate ~AUD 200–240k / year for '
        'the 2-person team plus external retainers and infrastructure.'))

    story.append(fig_to_image(chart_operate_evolve_cycle(),
                              width=150*mm, height=130*mm))

    story.append(Paragraph('5.1 Release cadence', styles['SubHead']))
    story.extend(bullets(styles, [
        '<b>Monthly release</b> — the default. All non-emergency feature '
        'work, bug fixes, stakeholder-requested changes. Lane cadence: '
        '3 weeks build + 1 week release (soak on staging, gate checks, '
        'release tag, deploy, smoke).',
        '<b>Emergency hotfix</b> — the exception. Used only for security '
        'or money-flow defects. Expedited gate path (G1–G5 still mandatory, '
        'G6 sign-off compressed to same-day). On-call engineer authors the '
        'fix; second person (CTO or BA, whoever is not on-call) signs.',
    ]))

    story.append(Paragraph('5.2 Feature pipeline', styles['SubHead']))
    story.append(p(styles,
        'New feature requests from any stakeholder go through the same '
        'scope → test → build loop as the original build. Features are '
        'sized by stakeholder group, prioritised quarterly by the board, '
        'and budgeted against the Post-Live run-rate. No stakeholder '
        'feature enters build without a signed scope brief. This is how '
        'the discipline of the stakeholder-gated MVP is preserved after '
        'go-live.'))

    story.append(Paragraph('5.3 Change control for partner contracts',
                           styles['SubHead']))
    story.append(p(styles,
        'BlackRock, the lender, the reinsurer, and the e-sign vendor each '
        'have API contracts. When a partner announces a breaking change:'))
    story.extend(bullets(styles, [
        'Partner announces deprecation (typically 90 days notice).',
        'Engineer builds against the new contract in a feature branch. '
        'Fake is updated in lock-step.',
        'Contract tests green on the new contract; old contract tests '
        'still green until cutover.',
        'Cutover scheduled in the monthly release lane, coordinated with '
        'partner.',
    ]))

    story.append(Paragraph('5.4 Model recalibration cycle',
                           styles['SubHead']))
    story.append(p(styles,
        'The v14c Optimised actuarial model has specific parameter '
        'assumptions (μ=9.2%, σ=16.6%, κ=0.163). Those parameters are '
        're-estimated annually via MLE on the latest index-return data. '
        'Re-estimation runs as a Python job against the '
        'monte_carlo_v14c_optimised.py simulator. The actuary countersigns '
        'the re-estimated parameters before they are adopted in the '
        'production pricing engine. Cycle: January each year. Actuary '
        'retainer: ~AUD 8k per cycle.'))

    story.append(Paragraph('5.5 Security re-certification',
                           styles['SubHead']))
    story.extend(bullets(styles, [
        '<b>Annual external pen test</b> — same firm ideally (continuity). '
        'AUD 15k per cycle.',
        '<b>Quarterly dependency refresh</b> — automated vulnerability '
        'scanning across all dependency managers. Clean or patched before '
        'the next monthly release.',
        '<b>Quarterly access review</b> — who has production access, who '
        'has partner-API credentials, who has admin role. Documented, '
        'signed by CTO.',
        '<b>Annual SOC 2 re-gap</b> — track the gap closing quarter by '
        'quarter. Full certification is a Series-A project, not Post-Live.',
    ]))

    story.append(Paragraph('5.6 Incident model for a 2-person team',
                           styles['SubHead']))
    story.append(p(styles,
        'Paired on-call. One primary, one secondary, rotated weekly. '
        'External incident escalation retainer with a security consultant '
        '(AUD 5k / year). PagerDuty or equivalent for alerts. Runbook '
        'maintained alongside the code — a deploy without a runbook '
        'update for a new surface fails CI.'))
    story.extend(bullets(styles, [
        '<b>P1 (money-flow)</b> — funder drawdown fails, investment order '
        'fails, payment missed. Same-day response. Both engineers on the '
        'incident.',
        '<b>P2 (stakeholder-facing)</b> — customer cannot complete '
        'application, broker cannot lodge, admin cannot view. Same-day '
        'response.',
        '<b>P3 (internal)</b> — observability gap, non-urgent defect, '
        'documentation drift. Next-release response.',
    ]))

    story.append(Paragraph('5.7 Infrastructure migration trigger',
                           styles['SubHead']))
    story.append(Paragraph(
        '<b>Fly.io → AWS ap-southeast-2 is event-triggered, not '
        'time-triggered.</b> The event is the first wholesale-funder or '
        'reinsurer due-diligence questionnaire that requests IRAP '
        'attestation or APRA CPS 234 alignment evidence. That questionnaire '
        'typically lands after the first 20–50 mortgages are live and the '
        'counterparty is scaling its exposure. Until that point, Fly.io + '
        'Cloudflare is fit for purpose.', styles['KeyFinding']))
    story.append(p(styles,
        'Migration is a named Post-Live project: ~6–8 weeks, ~AUD 45k '
        '(engineer time + AWS setup + IRAP-aligned architecture review + '
        'DNS cutover). Budgeted separately from the run-rate, triggered on '
        'the event. See section 11 for the full Fly.io assessment.'))

    story.append(Paragraph('7.8 Scale-up path post-pilot', styles['SubHead']))
    story.append(p(styles,
        'Pilot is 5–10 mortgages. The plan does not assume the team or '
        'the architecture stays two-person forever. The triggers below '
        'are volume-based, not calendar-based — they fire when book '
        'volume crosses the threshold.'))

    rows = [
        ['10 → 50 mortgages', 'No new hires',
         'Partner reconciliation frequency doubles (daily → hourly at '
         '50+). Post-Live pack rolls forward unchanged.'],
        ['50 → 200', '+ CS operator (full-time)',
         'Broker accreditation extended to 20+ brokers. Second lender '
         'signed for geographic diversity. External actuary to quarterly '
         'review cadence.'],
        ['200 → 500', '+ Finance / ops lead',
         'Second wholesale funder signed. AWS migration triggered (if '
         'not already). Automated APRA / ASIC reporting stood up.'],
        ['500 → 1,000', '+ Compliance / legal lead',
         'SOC 2 Type I certification project. Broker network to 100+. '
         'Own AFSL + ACL application tabled at board.'],
        ['1,000+', '+ Second CTO (or CTO split)',
         'Platform begins to look like a traditional non-bank lender. '
         'Series-B fundraise territory. Own licences live.'],
    ]
    story.append(make_table(
        ['Book size', 'Hiring trigger', 'Other changes'],
        rows, col_widths=[30*mm, 42*mm, 98*mm]))

    story.append(Paragraph('7.9 Business continuity & key-person',
                           styles['SubHead']))
    story.append(p(styles,
        'A 2-person team is a concentrated bus-factor risk. The '
        'containment is not a slogan; it is a documented set of '
        'controls that the board reviews annually.'))
    story.extend(bullets(styles, [
        '<b>Source-code escrow</b> with an AU-licensed escrow provider '
        '(e.g., NCC Group, Escrow Associates). Quarterly deposit of the '
        'main branch + build artefacts + runbooks. Release triggers: '
        'board resolution plus 30-day cure period.',
        '<b>Runbook coverage rule.</b> Every production surface must '
        'have a runbook that a non-author can execute in under one hour. '
        'Deploy of a new surface without an updated runbook fails CI. '
        'No exceptions.',
        '<b>Credential split.</b> CTO and BA each hold half of the '
        'privileged credentials (partner APIs, cloud roots, secrets '
        'manager). Neither can unilaterally lock out the other. On any '
        'departure, all credentials rotate within 24 hours.',
        '<b>Actuarial model handover.</b> The v14c Optimised Monte Carlo '
        'simulator + golden vectors live in-repo; reproducible from a '
        'clean checkout. No key-person dependency on the actuarial side.',
        '<b>Replacement lead-time assumption.</b> CTO replacement 3–6 '
        'months; BA 2–3 months. Board-approved retainer with a specialist '
        'financial-services tech recruiter shrinks the window to ~6–8 '
        'weeks on activation.',
        '<b>Fractional-CTO contingency.</b> If CTO departs mid-build, BA '
        'continues build and escalates architectural / partner-integration '
        'work to a fractional CTO retainer budgeted at AUD 20k for a '
        '12-week bridge.',
        '<b>Cyber + professional indemnity insurance.</b> AUD 5M cyber '
        'cover + AUD 10M PI cover, policies maintained from Go-Live. '
        'Premium estimated at AUD 12k / yr, included in Post-Live run-'
        'rate under tooling / legal.',
    ]))
    story.append(PageBreak())
    return story


def build_ai_ops_section(styles):
    story = []
    story.append(Paragraph(
        '8. AI Leverage Across Business Operations',
        styles['SectionHead']))
    story.append(p(styles,
        'The same AI-first posture that drives delivery also drives the '
        'back office. Post-live, AI is a cost lever on every non-'
        'engineering function. We do not eliminate any of these functions '
        '— regulation, counterparties, and customers each require a human '
        'accountable — but we staff each function lighter than an '
        'equivalent financial-services business of our volume, because '
        'the human in each seat operates with AI as a force multiplier. '
        'The run-rate numbers in section 12 are calibrated on this '
        'assumption; the numbers below are the <i>implicit saving</i> '
        'versus a conventional staffing model.'))

    story.append(Paragraph('8.1 Finance', styles['SubHead']))
    story.extend(bullets(styles, [
        '<b>Reconciliations drafted by AI, signed by finance.</b> Daily '
        'funder reconciliation, monthly investment-partner NAV '
        'reconciliation, quarterly reinsurer cession reconciliation — each '
        'runs as a scripted pipeline that produces a draft variance '
        'report plus the exceptions-only narrative. Finance spends time '
        'on exceptions, not tabulation.',
        '<b>Month-end pack drafted by AI.</b> P&amp;L, balance sheet, '
        'funder utilisation, investment performance, insurance premium '
        'flow — drafted from the ledger, reviewed by the CFO-contractor '
        'retainer, signed by the CTO.',
        '<b>Budget vs actual variance analysis</b> drafted in minutes, '
        'not days.',
        '<b>Saving vs conventional model:</b> ~0.6 FTE of junior finance '
        '+ ~0.3 FTE of senior finance review displaced by AI draft + '
        'contractor review. Estimated saved run-rate: ~AUD 90k / yr.',
    ]))

    story.append(Paragraph('8.2 Operations', styles['SubHead']))
    story.extend(bullets(styles, [
        '<b>Monitoring triage.</b> Alerts routed through an AI classifier '
        'that summarises the event, cross-references the runbook, and '
        'produces a suggested action before paging a human. Human acks '
        'and acts; AI pre-digest compresses MTTR.',
        '<b>Runbook maintenance.</b> Runbook deltas drafted by AI from '
        'the CI diff, reviewed and merged by the CTO. No deploy lands '
        'without a runbook update; AI removes the tax that usually breaks '
        'this rule.',
        '<b>Vendor contract review.</b> BlackRock, funder, reinsurer, '
        'e-sign, ID verification — contract amendments are triaged by AI '
        '(change summary, risk flags, redline) before legal spends any '
        'billable hours.',
        '<b>Saving vs conventional model:</b> ~0.5 FTE of a dedicated ops '
        'coordinator. Estimated saved run-rate: ~AUD 60k / yr.',
    ]))

    story.append(Paragraph('8.3 Customer Support', styles['SubHead']))
    story.extend(bullets(styles, [
        '<b>AI-first tier-1.</b> Tier-1 responses drafted, routed, and '
        'sent with a human CS operator signing. Complex cases escalated '
        'to actuary or legal with AI precedent search attached.',
        '<b>Case triage.</b> Incoming cases auto-classified (product '
        'question / servicing / dispute / complaint) with suggested '
        'response template; CS operator edits and sends.',
        '<b>Dispute drafting.</b> AI drafts the initial response packet '
        '(customer history, contract terms, actuarial context) for CS to '
        'review, so operators spend time on judgment, not search.',
        '<b>Saving vs conventional model:</b> pilot-phase CS can run with '
        '~0.5 FTE instead of ~1.5 FTE for an equivalent volume. Estimated '
        'saved run-rate: ~AUD 80k / yr.',
    ]))

    story.append(Paragraph('8.4 Marketing &amp; Stakeholder Communications',
                           styles['SubHead']))
    story.extend(bullets(styles, [
        '<b>Stakeholder decks</b> (board updates, funder reports, broker '
        'packs) drafted by AI from the underlying data; the BA edits '
        'the narrative and numbers.',
        '<b>Broker explainer materials</b> — FAQ updates, scenario '
        'walk-throughs, PDS-compliant marketing pages — drafted and '
        'compliance-checked against the legal glossary before human '
        'review.',
        '<b>Content pipeline</b> — blog, LinkedIn, media pitch — drafted '
        'by AI, human sign-off enforced before publish.',
        '<b>Saving vs conventional model:</b> ~0.4 FTE of content / '
        'marketing displaced by AI draft + BA edit. Estimated saved '
        'run-rate: ~AUD 55k / yr.',
    ]))

    story.append(Paragraph('8.5 Where AI is explicitly <i>not</i> the answer',
                           styles['SubHead']))
    story.extend(bullets(styles, [
        'Regulator-facing filings (PDS, TMD, RG 271 compliance '
        'statements) — drafted by legal, not AI.',
        'Underwriting decisions — deterministic rule-matrix; AI has no '
        'role in go/no-go on a specific mortgage.',
        'Model recalibration — actuary signs the parameter update; AI '
        'drafts the commentary only.',
        'Incident P1 communications — human author, human sign, no AI '
        'drafting on money-flow incidents.',
    ]))

    story.append(Paragraph('8.6 Total implied operating saving',
                           styles['SubHead']))
    story.append(Paragraph(
        'At steady state, AI leverage across finance, operations, customer '
        'support and marketing saves approximately '
        '<b>AUD 285k / year</b> versus a conventional staffing posture for '
        'a financial-services business of pilot size. That saving is the '
        'reason the Post-Live run-rate in section 12 is two-person rather '
        'than five-person. It is an <i>assumption</i> until operated; we '
        'commit to revisit the number at month 6 post-live and report the '
        'actual delta to the board.', styles['KeyFinding']))
    story.append(PageBreak())
    return story


def build_regulatory_section(styles):
    story = []
    story.append(Paragraph('9. Regulatory Pathway', styles['SectionHead']))
    story.append(p(styles,
        'FutureProof operates in Australia\'s consumer-credit + financial-'
        'services regulatory perimeter. The pilot runs under an existing '
        'retail lender\'s AFSL + ACL; own licensing is a post-pilot, '
        'volume-triggered decision, not a Day-1 requirement.'))

    story.append(Paragraph('9.1 Licensing posture at pilot',
                           styles['SubHead']))
    story.extend(bullets(styles, [
        'Pilot operates under the retail lender\'s <b>AFSL</b> (financial '
        'services) and <b>ACL</b> (credit). FutureProof is an '
        '<i>authorised representative</i> of the lender for dealing in '
        'the product.',
        'Own AFSL + ACL application is tabled at the board once volume '
        'crosses ~200 mortgages (see section 7.8). Driver is commercial '
        'and cost, not regulatory compulsion.',
        'ASIC notification of authorised-representative arrangement '
        'lodged at Go-Live.',
    ]))

    story.append(Paragraph('9.2 Regulatory Guides that bind us',
                           styles['SubHead']))
    rows = [
        ['RG 271', 'Internal Dispute Resolution',
         '30-day IDR response. IDR register maintained. AFCA reporting '
         'annual. Dispute-flow surface is authored in M6 and is '
         'authoritative.'],
        ['RG 256', 'Client money',
         'Any customer money held in trust is reconciled daily. '
         'Investment-Partner assets are NOT client money (lender holds '
         'legal title; customer has equitable interest).'],
        ['RG 165', 'Licensing: financial advice',
         'FutureProof does NOT provide personal advice. Calculator '
         'outputs are general product information; disclaimers reviewed '
         'by external legal.'],
        ['RG 274', 'Product design and distribution (DDO)',
         'TMD filed with PDS at Go-Live. Annual review; refresh on any '
         'material change. Tabled at the board.'],
        ['RG 274 / NCCP',
         'Responsible lending',
         'Lender holds ACL. Rule matrix (M2) implements lender\'s '
         'responsible-lending framework; tests are ASIC-reviewable on '
         'request.'],
    ]
    story.append(make_table(
        ['Reg. guide', 'Topic', 'How we comply'],
        rows, col_widths=[22*mm, 48*mm, 100*mm]))

    story.append(Paragraph('9.3 AML / CTF (AUSTRAC)', styles['SubHead']))
    story.extend(bullets(styles, [
        'Lender handles KYC / CDD under their existing AUSTRAC-registered '
        'AML programme. FutureProof inherits via the authorised-'
        'representative arrangement; our KYC data flows to the lender\'s '
        'MLRO for SMR triggers.',
        'Own AUSTRAC registration is a post-pilot item, tied to the own-'
        'licensing decision.',
    ]))

    story.append(Paragraph('9.4 Privacy Act + Notifiable Data Breach',
                           styles['SubHead']))
    story.extend(bullets(styles, [
        'APP-aligned privacy policy; external legal drafted and reviewed '
        'at M0.',
        'Consent captured per data purpose at application; revocation '
        'available self-service in customer portal.',
        'Right-to-access and right-to-correct surfaces in M6; 30-day SLA.',
        '<b>Notifiable Data Breach scheme:</b> breach assessment within '
        '30 days; external breach counsel on retainer (tooling budget). '
        'Incident playbook integrated into the runbook.',
    ]))

    story.append(Paragraph('9.5 Consumer Data Right (CDR)',
                           styles['SubHead']))
    story.append(p(styles,
        'Not in scope for pilot. Trigger to reconsider: first customer '
        'request for CDR export, or a counterparty requirement. CDR '
        'data-recipient accreditation is a Series-A project with a '
        '~AUD 80k–120k project budget.'))
    story.append(PageBreak())
    return story


def build_data_governance_section(styles):
    story = []
    story.append(Paragraph('10. Data Governance', styles['SectionHead']))
    story.append(p(styles,
        'The most-asked funder and reinsurer due-diligence topic after '
        '"who is your hosting provider" is "who can see customer data and '
        'under what policy." The answers below are enforced in code and '
        'in runbooks, not just in policy.'))

    story.append(Paragraph('10.1 Data residency', styles['SubHead']))
    story.extend(bullets(styles, [
        'All personal and financial data resides in ap-southeast-2 '
        '(Sydney) — Fly.io <i>syd</i> region at pilot; AWS ap-southeast-2 '
        'post-migration. No data crosses the AU boundary for storage.',
        'Processing is AU-only. AI/LLM calls that might touch regulated '
        'PII are routed through privacy-preserving abstractions (PII '
        'redacted or tokenised before the prompt leaves our VPC).',
    ]))

    story.append(Paragraph('10.2 Encryption', styles['SubHead']))
    story.extend(bullets(styles, [
        'At rest: native database encryption + column-level envelope '
        'encryption for regulated-tier PII (per-row keys, keys managed '
        'in the secrets manager).',
        'In transit: TLS 1.3 on all ingress; mTLS to all counterparty '
        'APIs (funder, Investment Partner, LMI, e-sign, ID verification).',
        'At application: bcrypt / Argon2 for credentials; never '
        'plaintext; never in application logs.',
    ]))

    story.append(Paragraph('10.3 PII tiers', styles['SubHead']))
    rows = [
        ['Public', 'Marketing pages, public PDS',
         'No special controls.'],
        ['Restricted',
         'Customer application data, contact details, contract terms',
         'DB encryption at rest; authenticated access only; audit-logged.'],
        ['Regulated',
         'ID documents, credit history, financial statements',
         'Column-level encryption with per-row keys; every read logged to '
         'the immutable audit trail; access gated by CTO-signed role.'],
    ]
    story.append(make_table(
        ['Tier', 'Examples', 'Controls'],
        rows, col_widths=[28*mm, 62*mm, 80*mm]))

    story.append(Paragraph('10.4 Retention &amp; deletion',
                           styles['SubHead']))
    story.extend(bullets(styles, [
        'Retention: 7 years post-contract-close (ATO and NCCP standard). '
        'Retention clock starts on the later of contract close and last '
        'customer interaction.',
        'Automatic hard-delete scheduler runs annually; deletes '
        'regulated-tier PII past retention; retains anonymised aggregates '
        'for actuarial purposes.',
        'Customer-initiated deletion: processed within 30 days, subject '
        'to overriding legal retention obligations.',
    ]))

    story.append(Paragraph('10.5 Audit log', styles['SubHead']))
    story.append(p(styles,
        'Every read of regulated-tier PII is logged (who, when, from '
        'where, for what stated purpose). Jurisdiction-aware audit '
        'logging is applied uniformly across every PII read-path. Audit '
        'log is append-only, retained for the full retention period, '
        'and queryable only by CTO for incident or regulator response.'))

    story.append(Paragraph('10.6 Data-subject requests', styles['SubHead']))
    story.append(p(styles,
        '30-day SLA for access, correction, and deletion requests. '
        'Self-service for simple access/correction via customer portal; '
        'manual requests handled by CS with CTO sign-off on deletion.'))
    story.append(PageBreak())
    return story


def build_infrastructure_section(styles):
    story = []
    story.append(Paragraph('11. Infrastructure — Fly.io for financial services',
                           styles['SectionHead']))
    story.append(Paragraph(
        '<b>Fly.io is the right partner for the MVP and pilot. It is not '
        'the right partner at scale. The migration trigger is event-based, '
        'not time-based.</b>', styles['KeyFinding']))

    story.append(Paragraph('11.1 Why Fly.io is fine for the MVP',
                           styles['SubHead']))
    story.extend(bullets(styles, [
        'SOC 2 Type II compliant.',
        'Sydney region (syd) available — data residency controllable at '
        'the application level.',
        'Proven at our volume with the web framework and database we run on.',
        'Fast rollback (<font face="Courier">fly releases rollback</font>) — '
        'important for a 2-person team.',
        'Low ops burden — a 2-person team cannot operate a full AWS estate '
        'without dedicated DevOps.',
        'Pricing is transparent and cheap at pilot scale (dozens of '
        'mortgages, not thousands).',
    ]))

    story.append(p(styles, 'Pair with:'))
    story.extend(bullets(styles, [
        '<b>Cloudflare</b> in front of Fly.io for WAF, DDoS, rate-limit, '
        'bot mitigation, and a stable edge IP for partner-allowlisting.',
        '<b>AWS S3</b> (already in use) for backups and document storage '
        '— gives a credible exit ramp.',
        '<b>1Password / Doppler</b> for secret management outside the repo.',
    ]))

    story.append(Paragraph('11.2 Why Fly.io is not right at scale',
                           styles['SubHead']))
    story.extend(bullets(styles, [
        'No APRA CPS 234 attestation.',
        'No IRAP rating.',
        'Wholesale-funder due diligence under APRA CPS 231 (material '
        'outsourcing) will demand enterprise-grade hosting once the book '
        'is material — typically after the first 20–50 mortgages.',
        'Limited enterprise networking primitives (no PrivateLink-'
        'equivalent, limited VPC isolation) vs AWS ap-southeast-2.',
        'Limited data-residency contractual controls compared to AWS\'s '
        'enterprise agreements.',
        'Reinsurer due-diligence is similar — the moment the reinsurer '
        'wants evidence of the underlying hosting\'s compliance posture, '
        'Fly.io becomes the conversation problem, not the technology '
        'problem.',
    ]))

    story.append(Paragraph('11.3 Migration plan (budgeted, not executed at MVP)',
                           styles['SubHead']))
    story.append(p(styles,
        'The migration itself is not difficult. The platform has no '
        'Fly-specific primitives beyond the deploy command and secrets.'))

    rows = [
        ['1. IRAP-aligned architecture review (independent consultant)',
         '1 week', 'AUD 8k'],
        ['2. AWS ap-southeast-2 VPC + ECS/Fargate + managed database + '
         'CloudFront setup', '2 weeks', 'engineer'],
        ['3. Dual-running period with cutover testing on staging',
         '2 weeks', '—'],
        ['4. DNS cutover with rollback plan', '1 day', '—'],
        ['5. Post-cutover monitoring + Fly.io decommission',
         '1 week', '—'],
        ['<b>Total</b>', '<b>6–8 weeks</b>', '<b>~AUD 45k</b>'],
    ]
    story.append(make_table(['Step', 'Duration', 'Cost'],
                            rows, col_widths=[105*mm, 30*mm, 35*mm]))
    story.append(p(styles,
        'Triggered on the first counterparty questionnaire, not on a '
        'calendar date. Named in the Post-Live budget as a separate line.'))
    story.append(PageBreak())
    return story


def build_costs_section(styles):
    story = []
    story.append(Paragraph('12. Costs & Capital Ask', styles['SectionHead']))
    story.append(p(styles,
        'Itemised build cost in AUD. External legal (contracts, PDS, '
        'broker accreditation, funder agreements, AFSL / ACL work) is '
        'governed by a separate legal budget and does not appear here. '
        'Post-Live run-rate, the event-triggered migration reserve, and '
        'an operational buffer are separate lines and are not bundled '
        'into the headline build number.'))

    story.append(fig_to_image(chart_cost_waterfall(),
                              width=172*mm, height=100*mm))

    story.append(Paragraph('12.1 Build budget', styles['SubHead']))
    rows = [
        ['CTO (30 wks @ 160k annualised)', '92,000',
         'Market-rate CTO'],
        ['BA / Programmer (30 wks @ 140k × 0.8 FTE)', '65,000',
         'Scope-test-build per stakeholder is BA-intensive'],
        ['External actuary (4 reviews)', '22,000',
         'M3, M4, Go-Live, Post-Live kickoff'],
        ['Security (pen test + SOC 2 gap + APRA/IRAP gap)', '33,000',
         '15k + 10k + 8k'],
        ['Auditor retainer (pilot period)', '8,000', ''],
        ['Hardware (laptops, dev kit, HSM-grade token)', '15,000',
         '2× dev machines + YubiKeys + ergonomic setup'],
        ['Infrastructure', '5,000',
         'Fly.io + Cloudflare + monitoring + AWS backup'],
        ['Tooling SaaS', '4,000',
         'CI, e-sign, ID verification, error tracking'],
        ['AI / LLM spend (Claude API for BA workflow)', '4,000', ''],
        ['<b>Subtotal</b>', '<b>248,000</b>', ''],
        ['Contingency (15%)', '37,000', ''],
        ['<b>Total with contingency</b>', '<b>285,000</b>',
         '<b>Headline: ~AUD 285k (legal separate)</b>'],
    ]
    story.append(make_table(['Line item', 'AUD', 'Notes'],
                            rows, col_widths=[82*mm, 28*mm, 60*mm]))

    story.append(Paragraph('12.2 Post-Live annualised run-rate',
                           styles['SubHead']))
    rows = [
        ['CTO (full year)', '160,000'],
        ['BA / Programmer (0.8 FTE)', '112,000'],
        ['External actuary (annual recalibration)', '8,000'],
        ['Annual pen test', '15,000'],
        ['Infrastructure', '12,000'],
        ['Tooling SaaS', '8,000'],
        ['AI / LLM spend', '8,000'],
        ['Cyber + PI insurance (see 7.9)', '12,000'],
        ['<b>Total annualised</b>',
         '<b>~335,000 (range 325–360k)</b>'],
    ]
    story.append(make_table(['Line item', 'Annual AUD'],
                            rows, col_widths=[120*mm, 50*mm]))
    story.append(Paragraph(
        '<b>Implied operating saving via AI leverage (section 8): '
        '~AUD 285k / yr</b> versus a conventional staffing model — the '
        'reason the Post-Live line is two-person, not five. Legal '
        'retainer sits in the separate legal budget.',
        styles['Callout']))

    story.append(Paragraph('12.3 Capital ask (build + 12-month runway)',
                           styles['SubHead']))
    story.append(p(styles,
        'The capital ask is layered so the board can see which dollars are '
        'contractual, which are event-triggered, and which are buffer. '
        'Legal spend is funded from the separate legal budget and is '
        'outside this ask.'))
    rows = [
        ['Build budget (this section, row-total)', '285,000',
         '30-week delivery to pilot-live'],
        ['Post-Live — Year 1 run-rate', '335,000',
         'Two-person team + infra + insurance + recertification'],
        ['Infrastructure migration reserve (Fly.io → AWS)', '45,000',
         'Event-triggered; held in reserve, not drawn at day 1 (§11.3)'],
        ['Operational / regulatory contingency buffer', '35,000',
         '~5% of first three lines — covers AUSTRAC onboarding, '
         'unplanned due-diligence rounds'],
        ['<b>Total capital ask</b>', '<b>~700,000</b>',
         '<b>Runway: build + 12 months post-live + migration cover</b>'],
    ]
    story.append(make_table(['Layer', 'AUD', 'Purpose'],
                            rows, col_widths=[70*mm, 28*mm, 72*mm]))
    story.append(Paragraph(
        '<b>Headline capital ask: AUD 700k.</b> Build + one year post-live '
        '+ named migration reserve + buffer. Legal is separately budgeted. '
        'Any Series-A decision is a separate conversation after pilot '
        'completes.', styles['Callout']))
    story.append(PageBreak())
    return story


def build_risks_section(styles):
    story = []
    story.append(Paragraph('13. Risks & Unknowns', styles['SectionHead']))
    rows = [
        ['BlackRock not signed by M3 start (week 11)', 'BA',
         'Plan-B: domestic managed-account provider via the Investment '
         'Partner Interface abstraction. ~4 weeks additional work.'],
        ['Wholesale funder not signed by M1 start (week 5)', 'BA',
         'Approach 3 funders in parallel from week 1. Fake-first '
         'architecture means build continues.'],
        ['Regulatory surprise (PDS, TMD, responsible lending)',
         'BA + Legal',
         'External legal engaged week 1; informal regulator approach '
         'before formal filing.'],
        ['Reinsurer rejects P20 attachment', 'Actuary + BA',
         'Present v14c Optimised actuarial review early (week 14); '
         'iterate on attachment if challenged.'],
        ['Solo-engineer bus factor', 'CTO',
         'BA is a programmer, not just a liaison; paired on-call; external '
         'code review at each gate.'],
        ['Scope creep from signed briefs', 'BA',
         'Signed briefs are immutable; changes require re-sign; budget 3 '
         'rounds per milestone.'],
        ['Infrastructure migration triggered mid-pilot', 'CTO',
         'Named project, pre-priced, pre-scoped. Execute in the 6–8 week '
         'window without blocking new origination.'],
        ['AI code quality regression', 'CTO + BA',
         'CTO reviews every BA-generated PR; contract tests and '
         'acceptance tests are authoritative, not AI suggestions.'],
        ['AI back-office saving does not materialise', 'CTO + BA',
         'Revisit at month 6 post-live; report actual delta to board. '
         'Staffing uplift is a Series-A decision if AI leverage falls '
         'short of the 285k/yr assumption in section 8.'],
    ]
    story.append(make_table(['Risk', 'Owner', 'Mitigation'],
                            rows, col_widths=[60*mm, 25*mm, 85*mm]))
    return story


def build_gono_go_section(styles):
    story = []
    story.append(Paragraph('14. Go / No-Go Criteria for Pilot',
                           styles['SectionHead']))
    story.append(p(styles, '<b>All of:</b>'))
    story.extend(bullets(styles, [
        'All seven stakeholder milestones gate-green.',
        'External pen test clean or remediated.',
        'SOC 2 + APRA/IRAP gap documents filed and reviewed by board.',
        'PDS + TMD filed.',
        '5–10 pilot customer intents signed.',
        'Funder, BlackRock (or Plan-B), LMI, reinsurer, and pilot brokers '
        'all countersigned their integration test reports.',
        'CTO and BA both recommend go in writing.',
        'Board approves in writing.',
    ]))
    story.append(Paragraph(
        '<b>Any red is no-go. No exceptions.</b>',
        styles['WarningCallout']))
    story.append(PageBreak())
    return story


def build_appendices(styles):
    story = []
    story.append(Paragraph('Appendix A — Companion Document',
                           styles['SectionHead']))
    story.extend(bullets(styles, [
        '<b>v14c Optimised Actuarial Review (April 2026)</b> — the model '
        'that pricing, LMI attachment, and reinsurance cession inherit '
        'from. Every model-fidelity test in this plan pins to its '
        'locked output.',
    ]))
    return story


# ================================================================
# MAIN
# ================================================================

def main():
    here = os.path.dirname(os.path.abspath(__file__))
    out_dir = os.path.abspath(os.path.join(here, '..', 'pdfs'))
    os.makedirs(out_dir, exist_ok=True)
    out_path = os.path.join(
        out_dir, 'FutureProof_EPM_Stakeholder_Gated_Build_Plan_Apr2026.pdf')

    styles = get_styles()
    doc = SimpleDocTemplate(
        out_path, pagesize=A4,
        leftMargin=22*mm, rightMargin=22*mm,
        topMargin=20*mm, bottomMargin=20*mm,
        title='FutureProof EPM — Stakeholder-Gated Build Plan',
        author='FutureProof Financial',
    )

    story = []
    story.extend(build_cover(styles))
    story.extend(build_exec_summary(styles))
    story.extend(build_vs_budget(styles))
    story.extend(build_team_section(styles))
    story.extend(build_commercial_assumptions_section(styles))
    story.extend(build_gantt_section(styles))
    story.extend(build_milestones_section(styles))
    story.extend(build_money_flow_section(styles))
    story.extend(build_golive_section(styles))
    story.extend(build_postlive_section(styles))
    story.extend(build_ai_ops_section(styles))
    story.extend(build_regulatory_section(styles))
    story.extend(build_data_governance_section(styles))
    story.extend(build_infrastructure_section(styles))
    story.extend(build_costs_section(styles))
    story.extend(build_risks_section(styles))
    story.extend(build_gono_go_section(styles))
    story.extend(build_appendices(styles))

    doc.build(story, onFirstPage=footer, onLaterPages=footer)

    size_kb = os.path.getsize(out_path) // 1024
    print(f'Generated: {out_path}')
    print(f'Size: {size_kb} KB')


if __name__ == '__main__':
    main()
