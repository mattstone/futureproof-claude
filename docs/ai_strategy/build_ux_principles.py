#!/usr/bin/env python3
"""
Build the Akane UX Principles 1-pager.

Single A4 portrait, briefing-deck style — designed to be inherited by the
senior AI product hire and to live as the design reference for the build.

Output: docs/ai_strategy/FutureProof_Akane_UX_Principles.pdf

Run:
    python3 docs/ai_strategy/build_ux_principles.py
"""

from __future__ import annotations
import base64
import subprocess
from pathlib import Path
from datetime import date

ROOT = Path(__file__).resolve().parents[2]
AI_DIR = ROOT / "docs" / "ai_strategy"
OUT_PDF = AI_DIR / "FutureProof_Akane_UX_Principles.pdf"
LOGO_PATH = ROOT / "app" / "assets" / "images" / "futureproof-logo.png"
TMP_HTML = AI_DIR / "_tmp_ux_principles.html"

CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"


def encode_logo() -> str:
    if not LOGO_PATH.exists():
        return ""
    return f"data:image/png;base64,{base64.b64encode(LOGO_PATH.read_bytes()).decode('ascii')}"


LOGO_URI = encode_logo()
DATE_STR = date.today().strftime("%B %Y")


CSS = """
@page { size: A4 portrait; margin: 0; }
* { box-sizing: border-box; }

:root {
    --navy: #1F3864;
    --blue: #1E88E5;
    --blue-light: #E8F0FB;
    --gray-100: #F7F9FC;
    --gray-200: #E8ECF2;
    --gray-500: #8896AB;
    --gray-700: #4A5568;
    --gray-900: #1A202C;
}

body {
    margin: 0;
    padding: 0;
    font-family: 'Avenir Next', 'Helvetica Neue', system-ui, -apple-system, sans-serif;
    color: var(--gray-900);
    -webkit-print-color-adjust: exact;
    print-color-adjust: exact;
}

.page {
    width: 210mm;
    height: 297mm;
    padding: 9mm 13mm 8mm 13mm;
    position: relative;
    background: white;
    page-break-after: always;
}

.header {
    border-bottom: 1.5pt solid var(--navy);
    padding-bottom: 3mm;
    margin-bottom: 3mm;
    display: flex;
    justify-content: space-between;
    align-items: flex-end;
}

.header-left .doc-title {
    font-size: 16pt;
    font-weight: 700;
    color: var(--navy);
    line-height: 1.05;
    margin-top: 1mm;
}

.header-left .doc-subtitle {
    font-size: 9pt;
    color: var(--gray-700);
    margin-top: 1mm;
    font-style: italic;
}

.header-right {
    text-align: right;
    font-size: 9pt;
    color: var(--gray-500);
    line-height: 1.5;
}

.header-right .stamp {
    background: var(--blue-light);
    color: var(--navy);
    padding: 2mm 4mm;
    font-weight: 600;
    font-size: 8.5pt;
    letter-spacing: 0.3pt;
    text-transform: uppercase;
    border-radius: 2mm;
    display: inline-block;
    margin-bottom: 2mm;
}

.intro {
    font-size: 8.5pt;
    line-height: 1.4;
    color: var(--gray-900);
    margin-bottom: 3mm;
}

.intro strong { color: var(--navy); }

.principles {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 3mm 4mm;
}

.principle {
    page-break-inside: avoid;
}

.principle h3 {
    font-size: 9pt;
    font-weight: 700;
    color: var(--navy);
    margin: 0 0 1mm 0;
    text-transform: uppercase;
    letter-spacing: 0.3pt;
    border-bottom: 1pt solid var(--gray-200);
    padding-bottom: 0.6mm;
}

.principle ul {
    font-size: 8.5pt;
    line-height: 1.35;
    margin: 0;
    padding-left: 3.5mm;
    color: var(--gray-900);
}

.principle ul li {
    margin-bottom: 0.7mm;
}

.principle ul li strong {
    color: var(--navy);
}

.frameworks {
    margin-top: 3mm;
    padding: 2.5mm 3.5mm;
    background: var(--gray-100);
    border-left: 2pt solid var(--blue);
    font-size: 8pt;
    line-height: 1.35;
    color: var(--gray-700);
}

.frameworks strong {
    color: var(--navy);
}

.footer {
    position: absolute;
    bottom: 7mm;
    left: 14mm;
    right: 14mm;
    font-size: 8pt;
    color: var(--gray-500);
    display: flex;
    justify-content: space-between;
    border-top: 1pt solid var(--gray-200);
    padding-top: 2.5mm;
}
"""


def build_html() -> str:
    return f'''<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Akane UX Principles</title>
<style>{CSS}</style>
</head>
<body>
<div class="page">

  <div class="header">
    <div class="header-left">
      <div class="doc-title">Akane — UX Principles</div>
      <div class="doc-subtitle">Design reference for the customer-facing layer</div>
    </div>
    <div class="header-right">
      <div class="stamp">Internal · Reference</div>
      <div>{DATE_STR}</div>
      <div>FutureProof Financial Group</div>
    </div>
  </div>

  <div class="intro">
    <strong>Purpose.</strong> Design principles guiding Akane's customer-facing surface (Layer 1). To be inherited by the senior AI product lead and used as the reference for design and engineering decisions.
  </div>

  <div class="principles">

    <div class="principle">
      <h3>1 · Conversation structure</h3>
      <ul>
        <li><strong>Hybrid state machine</strong> — Akane drives a structured intake flow but accepts conversational divergence (questions, what-ifs). Not free-form chat. Not a wizard.</li>
        <li><strong>Progressive disclosure</strong> — never dump everything at once. "Want to see the math?" / "Show me alternatives" reveals complexity on demand.</li>
        <li><strong>Visible intake ledger</strong> — small sidebar showing what's been answered. All inputs editable in place.</li>
      </ul>
    </div>

    <div class="principle">
      <h3>2 · Mixed UI</h3>
      <ul>
        <li><strong>Text spine, rich UI moments</strong> — chat as the backbone; sliders, charts, comparison cards, calendar widgets at key decision points.</li>
        <li><strong>Show, don't paragraph</strong> — 67-year-olds shouldn't parse blocks of figures. Visualise distributions, ranges, trade-offs.</li>
        <li><strong>Inline interactivity</strong> — change an input, see the answer update in seconds. Don't make customers re-submit a form.</li>
      </ul>
    </div>

    <div class="principle">
      <h3>3 · Trust &amp; transparency</h3>
      <ul>
        <li><strong>Show your work</strong> — every recommendation links back to the inputs that produced it ("based on what you told me…").</li>
        <li><strong>Confidence + range, not point estimates</strong> — "$0.6M – $1.7M expected estate (median $1.1M)", never just "$1.1M".</li>
        <li><strong>Visible thinking state</strong> — when Akane is calling the calc engine, show "Calculating 50,000 scenarios for your situation…" not a silent spinner.</li>
        <li><strong>Cite the actuarial source</strong> — "Recommendation based on Pavel Shevchenko's Monte Carlo validated model" reinforces credibility.</li>
      </ul>
    </div>

    <div class="principle">
      <h3>4 · Compliance-aware language</h3>
      <ul>
        <li><strong>"Based on what you've told me", not "definitively"</strong> — Akane recommends; she never directs.</li>
        <li><strong>Mandatory adviser handoff</strong> for any product issuance — non-skippable, built into the flow, not a side door.</li>
        <li><strong>Audit trail visible</strong> to user: "This conversation is recorded for compliance" — once, prominently, not hidden in the footer.</li>
      </ul>
    </div>

    <div class="principle">
      <h3>5 · Continuity &amp; memory</h3>
      <ul>
        <li><strong>Persistent memory with explicit opt-in</strong> — resume sessions across devices, not just within a single browser tab.</li>
        <li><strong>Family-share option</strong> — adult child can pick up where a retiree left off (with consent). The decision is often a family one.</li>
        <li><strong>Warm handoff to the human adviser</strong> — adviser sees the full conversation summary <em>before</em> the meeting, doesn't restart from zero.</li>
      </ul>
    </div>

    <div class="principle">
      <h3>6 · Voice &amp; multilingual</h3>
      <ul>
        <li><strong>Phone option for older customers</strong> — same intake flow, voice-driven. Materially relevant for 60–75 demographic. Text-first MVP, voice as fast follower.</li>
        <li><strong>Multilingual per region</strong> — AU (CN, VN, IN), UK (PL, HI, UR), US (ES, ZH). Localised, not translated.</li>
      </ul>
    </div>

    <div class="principle">
      <h3>7 · Escape hatches</h3>
      <ul>
        <li><strong>"Talk to a human" 1-click from any screen</strong> — never buried.</li>
        <li><strong>"Save and continue later"</strong> at every stage. No lost state.</li>
        <li><strong>"Restart" available</strong> if the customer feels stuck or wants to re-explore.</li>
      </ul>
    </div>

    <div class="principle">
      <h3>8 · Scenario exploration as a first-class feature</h3>
      <ul>
        <li><strong>The recommendation is a starting point, not a verdict</strong> — let customers probe.</li>
        <li><strong>"What if I want $25K/yr?" → updated answer in 2 seconds</strong>. "What about my kids?" → estate impact visualised.</li>
        <li><strong>Make trade-offs visible</strong> — income vs estate, term vs flexibility, certainty vs upside.</li>
      </ul>
    </div>

  </div>

  <div class="frameworks">
    <strong>Recommended reading before design work.</strong> Microsoft HAX Toolkit (cheat-sheet for guidelines) · Google PAIR Guidebook (mental models, explainability, errors) · Apple HIG for ML (short, tactical) · Anthropic "Building Effective Agents" (agent vs workflow distinction) · OpenAI "A Practical Guide to Building Agents" 2026 (agent design patterns + handoffs). Hands-on competitor reviews: Wealthfront (onboarding), Bank of America Erica (chat finance), Khan Academy Khanmigo (hybrid conversational tutor).
  </div>

  <div class="footer">
    <div>Internal — Reference Document</div>
    <div>©2026 Futureproof Financial Group Limited</div>
    <div>1 of 1</div>
  </div>

</div>
</body>
</html>
'''


def main():
    html = build_html()
    TMP_HTML.write_text(html)

    print(f"Composed UX principles → {TMP_HTML}")
    print("Rendering PDF...")

    OUT_PDF.parent.mkdir(parents=True, exist_ok=True)
    cmd = [
        CHROME,
        "--headless=new",
        "--disable-gpu",
        "--no-pdf-header-footer",
        "--no-sandbox",
        "--virtual-time-budget=4000",
        "--run-all-compositor-stages-before-draw",
        f"--print-to-pdf={OUT_PDF}",
        f"file://{TMP_HTML.absolute()}",
    ]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0 or not OUT_PDF.exists():
        print(f"Chrome stderr:\n{result.stderr[:1000]}")
        raise RuntimeError("Chrome failed")

    size_kb = OUT_PDF.stat().st_size / 1024
    print(f"✓ {OUT_PDF.name} — {size_kb:.0f} KB")
    TMP_HTML.unlink(missing_ok=True)


if __name__ == "__main__":
    main()
