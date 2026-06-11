#!/usr/bin/env python3
"""
Build investor-ready PDFs from the capital_raise markdown artefacts.

Pipeline: markdown → (pandoc) → HTML body → wrap in styled template → (Chrome headless) → PDF.

Output goes to docs/capital_raise/pdfs/.

Usage:
    python3 docs/capital_raise/pdf_build/build_pdfs.py            # build all
    python3 docs/capital_raise/pdf_build/build_pdfs.py teaser     # build just teasers
"""

from __future__ import annotations
import base64
import os
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
CR_DIR = ROOT / "docs" / "capital_raise"
BUILD_DIR = CR_DIR / "pdf_build"
OUT_DIR = CR_DIR / "pdfs"
LOGO_PATH = ROOT / "app" / "assets" / "images" / "futureproof-logo.png"
CSS_PATH = BUILD_DIR / "style.css"

CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
PANDOC = "/opt/homebrew/bin/pandoc"


# ---------------------------------------------------------------------------
# Document specs — drive both layout (one-pager vs document) and metadata.
# ---------------------------------------------------------------------------

@dataclass
class DocSpec:
    src: str                    # markdown filename in docs/capital_raise/
    out: str                    # output filename in docs/capital_raise/pdfs/
    layout: str                 # "one-pager" | "document"
    kicker: str                 # e.g. "Investor Teaser · FO"
    title: str                  # main title for the doc
    subtitle: str               # subtitle / tagline
    skip_h1: bool = True        # whether to skip the first H1 from md (we handle it ourselves)


SPECS = [
    DocSpec(
        src="teaser.md",
        out="FutureProof_Teaser_FO.pdf",
        layout="one-pager",
        kicker="Investor Teaser · Family Office",
        title="Building the Next-Generation of Retirement Income & Funding Products for Every Life Stage.",
        subtitle="Unlocking $25T of locked-up retiree home equity. AI-native SaaS platform. AUS → UK → USA.",
    ),
    DocSpec(
        src="teaser_vc.md",
        out="FutureProof_Teaser_VC.pdf",
        layout="one-pager",
        kicker="Investor Teaser · Venture Capital",
        title="Building the Next-Generation of Retirement Income & Funding Products for Every Life Stage.",
        subtitle="Unlocking $25T of locked-up retiree home equity. AI-native SaaS platform. Regulated tailwind. AUS → UK → USA.",
    ),
    DocSpec(
        src="ai_architecture.md",
        out="FutureProof_AI_Architecture.pdf",
        layout="document",
        kicker="Diligence Pack · AI Architecture",
        title="AI Architecture One-Pager",
        subtitle="Live · Built · Roadmap · Never. The honest breakdown of where AI does work in the FutureProof platform.",
    ),
    DocSpec(
        src="faq.md",
        out="FutureProof_FAQ.pdf",
        layout="document",
        kicker="Diligence Pack · Investor FAQ",
        title="Investor FAQ",
        subtitle="The 26 questions every partner asks — answered up front.",
    ),
    DocSpec(
        src="PLAN.md",
        out="FutureProof_PLAN.pdf",
        layout="document",
        kicker="Internal · Capital-Raise Master Plan",
        title="Equity Raise Plan",
        subtitle="Dual-Track: US-Led + AU Family Offices + Fintech VCs. USD $5M priced equity round.",
    ),
    DocSpec(
        src="target_list.md",
        out="FutureProof_TargetList.pdf",
        layout="document",
        kicker="Internal · Outreach Target List",
        title="Capital-Raise Target List",
        subtitle="Tier 1–4 named targets · Pre-existing institutional relationships · Outreach cadence rules.",
    ),
    DocSpec(
        src="outreach_pack.md",
        out="FutureProof_OutreachPack.pdf",
        layout="document",
        kicker="Internal · Outreach Playbook",
        title="Outreach Pack",
        subtitle="Copy-paste-ready VC emails · Family Office emails · Phone scripts · Q&A drill · Operational notes.",
    ),
    DocSpec(
        src="valuation_analysis.md",
        out="FutureProof_ValuationAnalysis.pdf",
        layout="document",
        kicker="Claude AI · Company Valuation Analysis · Multiple Valuation Methodologies",
        title="Independent Valuation Analysis",
        subtitle="Six-lens present-day valuation + Year 5 forward exit & SAFE return profile: Revenue-based · IP standalone · Comparable businesses · Other methodologies · Strategic-acquirer reservation · Market-cleared price · Y5 exit valuation. Triangulated.",
    ),
]


# ---------------------------------------------------------------------------
# HTML template
# ---------------------------------------------------------------------------

HTML_DOC_TEMPLATE = """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>{title}</title>
<style>{css}</style>
</head>
<body>

<div class="cover">
  <div class="cover-top-meta">Commercial-in-Confidence — Restricted Circulation</div>
  <div class="cover-spacer"></div>

  {logo_html}

  <div class="cover-doc-type">{kicker}</div>
  <div class="cover-tagline">{title}</div>
  <div class="cover-subtitle">{subtitle}</div>

  <div class="cover-meta">
    <span class="label">Round</span> USD $5M priced equity · AU-domiciled<br>
    <span class="label">Date</span> {date}
  </div>

  <div class="cover-bottom">
    <div class="geo">HONG KONG · SYDNEY · SAN FRANCISCO · LONDON · CHANNEL ISLANDS</div>
    <div>©2026 Futureproof Financial Group Limited · All Rights Reserved</div>
  </div>
</div>

<div class="document-body">
{body}
</div>

</body>
</html>
"""

HTML_ONEPAGER_TEMPLATE = """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>{title}</title>
<style>{css}

@page {{
  size: Letter;
  margin: 0.45in 0.6in 0.5in 0.6in;
  @bottom-left   {{ font-size: 7pt; }}
  @bottom-center {{ font-size: 7pt; }}
  @bottom-right  {{ content: none; }}
}}

@page :first {{
  margin: 0.45in 0.6in 0.5in 0.6in;
}}

body {{ font-size: 8.5pt; line-height: 1.4; }}
.one-pager .wordmark {{ font-size: 22pt; margin-bottom: 4pt; }}
.one-pager .tagline {{ font-size: 12pt; margin-bottom: 3pt; }}
.one-pager .subtitle {{ font-size: 9pt; margin-bottom: 6pt; }}
.one-pager .rule {{ margin: 0 0 7pt 0; height: 1pt; }}
h1 {{ font-size: 14pt; margin: 6pt 0 3pt 0; }}
h2 {{ font-size: 10.5pt; margin: 6pt 0 3pt 0; }}
h3 {{ font-size: 9pt; margin: 4pt 0 2pt 0; }}
p, ul, ol {{ margin: 0 0 4pt 0; }}
ul {{ padding-left: 14pt; }}
ul li {{ margin-bottom: 1.5pt; line-height: 1.35; }}
ul li::before {{ width: 3.5pt; height: 3.5pt; left: -10pt; top: 5pt; }}
ol {{ padding-left: 14pt; }}
strong {{ font-weight: 600; }}
table {{ font-size: 8pt; margin: 4pt 0; }}
th, td {{ padding: 3pt 5pt; }}
.contact-block {{ padding: 6pt 10pt; margin-top: 6pt; }}
hr {{ margin: 5pt 0; }}
blockquote {{ margin: 4pt 0; padding: 5pt 8pt; font-size: 8pt; }}

/* Hide the trailing footnote-style content */
hr + p:has(em) {{ display: none; }}

/* Strong section labels (bold paragraphs) */
p > strong:first-child {{
  color: #1F3864;
  font-size: 9pt;
  text-transform: none;
  letter-spacing: 0;
}}
</style>
</head>
<body>

<div class="one-pager">
  <div style="display:flex;justify-content:space-between;align-items:flex-end;margin-bottom:6pt;">
    <div style="flex:1;">
      {logo_html_inline}
      <div class="tagline">{title}</div>
      <div class="subtitle">{subtitle}</div>
    </div>
    <div style="text-align:right;font-size:7.5pt;font-weight:600;color:#1E88E5;text-transform:uppercase;letter-spacing:0.18em;padding-bottom:4pt;">{kicker}</div>
  </div>
  <hr class="rule">

  {body}
</div>

</body>
</html>
"""


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def encode_logo() -> str:
    """Read logo file, base64-encode, return data URI."""
    if not LOGO_PATH.exists():
        return ""
    data = LOGO_PATH.read_bytes()
    b64 = base64.b64encode(data).decode("ascii")
    return f"data:image/png;base64,{b64}"


def logo_html_cover() -> str:
    """Cover-page logo: large image + wordmark fallback."""
    logo_uri = encode_logo()
    if logo_uri:
        return f'<img src="{logo_uri}" class="cover-logo" alt="FutureProof">'
    return '<div class="cover-wordmark"><span class="future">future</span><span class="proof">proof</span></div>'


def logo_html_onepager() -> str:
    """One-pager: small inline logo (saves vertical space)."""
    logo_uri = encode_logo()
    if logo_uri:
        return f'<img src="{logo_uri}" alt="FutureProof" style="max-width:170px; max-height:36px; display:block; margin-bottom:6pt;">'
    return '<div class="wordmark"><span class="future">future</span><span class="proof">proof</span></div>'


def md_to_html_body(md_path: Path, skip_h1: bool = True, strip_intro_meta: bool = True) -> str:
    """Use pandoc to convert markdown to HTML. Strip cover-style content that the template renders."""
    # NOTE: -f gfm-tex_math_dollars disables Pandoc's TeX math-mode interpretation
    # of $...$ pairs. Without this, two $ signs on the same line (e.g. "$106M ... $20M")
    # cause Pandoc to render everything between them as math, jumbling the text.
    proc = subprocess.run(
        [PANDOC, "-f", "gfm-tex_math_dollars", "-t", "html", str(md_path)],
        capture_output=True, text=True, check=True
    )
    html = proc.stdout

    # Strip the first H1 (we render the title in the cover/header instead)
    if skip_h1:
        html = re.sub(r'^\s*<h1[^>]*>.*?</h1>\s*', '', html, count=1, flags=re.IGNORECASE | re.DOTALL)

    if strip_intro_meta:
        # Iteratively strip leading "internal" content blocks: blockquotes (notes), HRs, the H2 "FutureProof"
        # title, the H3 tagline, and the italic/em subtitle paragraph — all rendered by the template.
        prev = None
        while html != prev:
            prev = html
            # Leading blockquote (Note / How-to-use / Length target / Use / Audience / Placeholders)
            html = re.sub(
                r'^\s*<blockquote>.*?</blockquote>\s*',
                '', html, count=1, flags=re.IGNORECASE | re.DOTALL
            )
            # Leading HR
            html = re.sub(r'^\s*<hr\s*/?>\s*', '', html, count=1, flags=re.IGNORECASE)
            # Leading H2 (the "## FutureProof" header)
            html = re.sub(r'^\s*<h2[^>]*>.*?</h2>\s*', '', html, count=1, flags=re.IGNORECASE | re.DOTALL)
            # Leading H3 (the "### Tagline" header)
            html = re.sub(r'^\s*<h3[^>]*>.*?</h3>\s*', '', html, count=1, flags=re.IGNORECASE | re.DOTALL)
            # Leading <p><em>...</em></p> subtitle line
            html = re.sub(
                r'^\s*<p>\s*<em>.*?</em>\s*</p>\s*',
                '', html, count=1, flags=re.IGNORECASE | re.DOTALL
            )

    return html


def render_pdf(html_path: Path, pdf_path: Path) -> None:
    """Run Chrome headless to print HTML to PDF."""
    cmd = [
        CHROME,
        "--headless=new",
        "--disable-gpu",
        "--no-pdf-header-footer",
        "--no-sandbox",
        "--virtual-time-budget=2000",
        "--run-all-compositor-stages-before-draw",
        f"--print-to-pdf={pdf_path}",
        f"file://{html_path.absolute()}",
    ]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0 or not pdf_path.exists():
        print(f"  Chrome stderr:\n    {result.stderr[:500]}")
        raise RuntimeError(f"Chrome failed for {pdf_path}")


def build_one(spec: DocSpec) -> None:
    src_path = CR_DIR / spec.src
    pdf_path = OUT_DIR / spec.out
    tmp_html_path = BUILD_DIR / f"_tmp_{spec.out.replace('.pdf', '.html')}"

    print(f"[{spec.layout}] {spec.src} → {spec.out}")

    if not src_path.exists():
        print(f"  ! source not found: {src_path}")
        return

    body_html = md_to_html_body(src_path, skip_h1=spec.skip_h1)
    css = CSS_PATH.read_text()

    if spec.layout == "one-pager":
        html = HTML_ONEPAGER_TEMPLATE.format(
            title=spec.title,
            subtitle=spec.subtitle,
            kicker=spec.kicker,
            css=css,
            logo_html_inline=logo_html_onepager(),
            body=body_html,
        )
    else:
        from datetime import date
        html = HTML_DOC_TEMPLATE.format(
            title=spec.title,
            subtitle=spec.subtitle,
            kicker=spec.kicker,
            css=css,
            logo_html=logo_html_cover(),
            body=body_html,
            date=date.today().strftime("%B %Y"),
        )

    tmp_html_path.write_text(html)
    render_pdf(tmp_html_path, pdf_path)

    # Cleanup
    tmp_html_path.unlink(missing_ok=True)

    if pdf_path.exists():
        size_kb = pdf_path.stat().st_size / 1024
        print(f"    ✓ {size_kb:.0f} KB")


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    filt = sys.argv[1].lower() if len(sys.argv) > 1 else None
    for spec in SPECS:
        if filt and filt not in spec.src.lower() and filt not in spec.out.lower():
            continue
        try:
            build_one(spec)
        except Exception as e:
            print(f"  ! failed: {e}")

    print(f"\nOutput: {OUT_DIR}")


if __name__ == "__main__":
    main()
