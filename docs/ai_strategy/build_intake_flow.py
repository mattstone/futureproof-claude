#!/usr/bin/env python3
"""
Build the Akane Intake Flow document — state machine for the customer-facing
conversation, from greeting through adviser handoff.

A4 landscape, single page. Designed as the build brief input for the engineering
team and as a reference for compliance / legal / actuarial review.

Output: docs/ai_strategy/FutureProof_Akane_Intake_Flow.pdf

Run:
    python3 docs/ai_strategy/build_intake_flow.py
"""

from __future__ import annotations
import base64
import subprocess
from pathlib import Path
from datetime import date

ROOT = Path(__file__).resolve().parents[2]
AI_DIR = ROOT / "docs" / "ai_strategy"
OUT_PDF = AI_DIR / "FutureProof_Akane_Intake_Flow.pdf"
LOGO_PATH = ROOT / "app" / "assets" / "images" / "futureproof-logo.png"
TMP_HTML = AI_DIR / "_tmp_intake_flow.html"

CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"


def encode_logo() -> str:
    if not LOGO_PATH.exists():
        return ""
    return f"data:image/png;base64,{base64.b64encode(LOGO_PATH.read_bytes()).decode('ascii')}"


LOGO_URI = encode_logo()
DATE_STR = date.today().strftime("%B %Y")


CSS = """
@page { size: A4 landscape; margin: 0; }
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
    width: 297mm;
    height: 210mm;
    padding: 6mm 10mm 5mm 10mm;
    position: relative;
    background: white;
    page-break-after: always;
}

.header {
    border-bottom: 1.5pt solid var(--navy);
    padding-bottom: 2mm;
    margin-bottom: 2.5mm;
    display: flex;
    justify-content: space-between;
    align-items: flex-end;
}

.header-left .doc-title {
    font-size: 13pt;
    font-weight: 700;
    color: var(--navy);
    line-height: 1.05;
    margin-top: 1mm;
}

.header-left .doc-subtitle {
    font-size: 8.5pt;
    color: var(--gray-700);
    margin-top: 0.8mm;
    font-style: italic;
}

.header-right {
    text-align: right;
    font-size: 8.5pt;
    color: var(--gray-500);
    line-height: 1.5;
}

.header-right .stamp {
    background: var(--blue-light);
    color: var(--navy);
    padding: 1.5mm 3mm;
    font-weight: 600;
    font-size: 8pt;
    letter-spacing: 0.3pt;
    text-transform: uppercase;
    border-radius: 1.5mm;
    display: inline-block;
    margin-bottom: 1.5mm;
}

table {
    width: 100%;
    border-collapse: collapse;
    font-size: 7.5pt;
    line-height: 1.3;
}

table thead {
    background: var(--navy);
    color: white;
}

table thead th {
    text-align: left;
    padding: 1.5mm 2mm;
    font-weight: 600;
    font-size: 7pt;
    text-transform: uppercase;
    letter-spacing: 0.3pt;
}

table tbody tr {
    border-bottom: 1pt solid var(--gray-200);
}

table tbody tr:nth-child(even) {
    background: var(--gray-100);
}

table tbody td {
    padding: 1.4mm 2mm;
    vertical-align: top;
}

table tbody td.state {
    font-weight: 700;
    color: var(--navy);
    width: 11%;
}

table tbody td.state .num {
    display: inline-block;
    width: 5mm;
    height: 5mm;
    background: var(--blue);
    color: white;
    border-radius: 50%;
    text-align: center;
    line-height: 5mm;
    font-size: 7pt;
    margin-right: 1mm;
    vertical-align: middle;
}

table tbody td.prompt {
    width: 24%;
    color: var(--gray-900);
}

table tbody td.ui {
    width: 22%;
    color: var(--gray-700);
    font-size: 7pt;
}

table tbody td.captured {
    width: 22%;
    color: var(--gray-700);
    font-size: 7pt;
}

table tbody td.next {
    width: 21%;
    color: var(--gray-700);
    font-size: 7pt;
}

.notes {
    margin-top: 2.5mm;
    padding: 2mm 3mm;
    background: var(--blue-light);
    border-left: 2pt solid var(--blue);
    font-size: 7.5pt;
    line-height: 1.35;
    color: var(--gray-700);
}

.notes strong { color: var(--navy); }

.footer {
    position: absolute;
    bottom: 5mm;
    left: 11mm;
    right: 11mm;
    font-size: 7.5pt;
    color: var(--gray-500);
    display: flex;
    justify-content: space-between;
    border-top: 1pt solid var(--gray-200);
    padding-top: 2mm;
}
"""


# State machine — each state: (name, prompt, ui_elements, captured, next/branching)
STATES = [
    ("1 · Entry",
     "Akane introduces herself, sets capability boundary, asks user to opt-in to text or voice. \"I'll ask 10 questions, ~10 min, then show you what I'd recommend.\"",
     "Persona block (avatar + name) · Two CTAs: 'Start (text)' / 'Start (voice)' · Always-visible 'Talk to a human'",
     "Channel choice · session ID · jurisdiction inferred from URL/IP",
     "→ State 2"),

    ("2 · Demographics",
     "Age. Retired or planning to retire? Dependants? Life-expectancy view (optional, sensitively framed).",
     "Numeric input (age) · Date picker (retire date) · Dropdown (dependants count)",
     "Age, retirement status, dependants",
     "→ State 3 · Branch: if age &lt; 50 → soft exit with general info"),

    ("3 · Home",
     "Home value. Mortgage outstanding? Property location (region for jurisdiction).",
     "Currency input with slider · Address lookup (auto-fill region) · Yes/No + currency for mortgage",
     "Home value, region, outstanding mortgage",
     "→ State 4 · Branch: if region not supported → adviser-only path"),

    ("4 · Other assets",
     "Super / pension balance. Other investments (shares, ETFs, property). Cash on hand.",
     "Currency inputs grouped · 'Skip' allowed for any line",
     "Super balance, investments, cash",
     "→ State 5"),

    ("5 · Income needs",
     "Monthly income desired. Lump-sum needs (e.g. renovation, family). Time horizon (years of income).",
     "Slider for income · Optional fields for lump sum · Slider or dropdown for horizon",
     "Income target, lump sum, term",
     "→ State 6"),

    ("6 · Priorities",
     "Estate vs income trade-off. Risk tolerance. Family considerations.",
     "Slider (estate ↔ income) · Multi-select for risk · Free-text for family notes",
     "Estate priority weight, risk tolerance, qualitative notes",
     "→ State 7"),

    ("7 · Synthesis",
     "Akane calls the calculation engine. Visible thinking state: \"Calculating 50,000 scenarios for your situation…\".",
     "Progress indicator · Inputs ledger visible alongside",
     "(recommendation generated; 3 alternatives ranked)",
     "→ State 8"),

    ("8 · Recommendation",
     "Primary recommendation card with mini-chart of estate distribution. Two alternatives shown as smaller cards. \"Why this one?\" expandable.",
     "Recommendation card (metrics + chart) · Alternative cards · Expandable reasoning",
     "User reads · Akane logs presentation event",
     "→ State 9 (or skip to 10 if user clicks 'Book adviser now')"),

    ("9 · Exploration",
     "Free-form conversation. \"What if I want $25K/yr instead?\" / \"What about my kids' inheritance?\" Akane re-runs scenarios in real time.",
     "Chat input · Inline sliders to adjust inputs · Scenarios update without page reload",
     "Iteration log: every input change + Akane's response",
     "→ State 10 when user signals satisfaction (\"book the meeting\" / explicit CTA)"),

    ("10 · Compliance gate",
     "Akane states explicitly: \"This is general guidance based on what you've told me. A licensed adviser must confirm before any product issuance.\"",
     "Acknowledgement check (non-skippable) · Audit trail visible · Disclosure language per jurisdiction",
     "Acknowledgement timestamp + IP",
     "→ State 11"),

    ("11 · Handoff",
     "Akane offers next available adviser slots. Books the meeting. Sends conversation summary to the adviser AND to the customer's email.",
     "Calendar widget (3 slots + 'more times') · Email confirmation · Optional family-share toggle",
     "Slot booked, contact details captured, summary emailed",
     "→ Done · Adviser pre-briefed before meeting"),
]


def build_html() -> str:
    rows = []
    for state, prompt, ui, captured, nxt in STATES:
        num = state.split(" ·")[0]
        name = state.split("·")[1].strip() if "·" in state else state
        rows.append(f'''
        <tr>
          <td class="state"><span class="num">{num}</span>{name}</td>
          <td class="prompt">{prompt}</td>
          <td class="ui">{ui}</td>
          <td class="captured">{captured}</td>
          <td class="next">{nxt}</td>
        </tr>''')

    rows_html = "\n".join(rows)

    return f'''<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Akane Intake Flow</title>
<style>{CSS}</style>
</head>
<body>
<div class="page">

  <div class="header">
    <div class="header-left">
      <div class="doc-title">Akane — Intake Flow (State Machine)</div>
      <div class="doc-subtitle">Customer-facing conversation: greeting → recommendation → adviser handoff</div>
    </div>
    <div class="header-right">
      <div class="stamp">Internal · Build Reference</div>
      <div>{DATE_STR}</div>
      <div>FutureProof Financial Group</div>
    </div>
  </div>

  <table>
    <thead>
      <tr>
        <th>State</th>
        <th>Prompt / what Akane does</th>
        <th>UI elements</th>
        <th>What's captured</th>
        <th>Next state · Branching</th>
      </tr>
    </thead>
    <tbody>
{rows_html}
    </tbody>
  </table>

  <div class="notes">
    <strong>Cross-cutting design rules.</strong> Every state must support: <strong>Save &amp; resume</strong> (state persisted to user account or anonymous session) · <strong>'Talk to a human' 1-click escape</strong> · <strong>Edit prior inputs</strong> (intake ledger visible throughout) · <strong>Visible compliance status</strong> (recording notice + jurisdiction-correct disclosures).<br/>
    <strong>Compliance gating.</strong> States 1–9 generate guidance. State 10 is a hard gate — Akane cannot recommend product issuance without acknowledgement and adviser handoff. <strong>Audit trail</strong> captures: every input change, every recommendation presented, the acknowledgement timestamp, and the booking confirmation.<br/>
    <strong>Localisation.</strong> States 2–6 accept jurisdiction-aware inputs (super for AU, workplace pension for UK, 401(k) / IRA for US). State 8 produces a recommendation in the local product-spec variant of EPM. State 10 uses the local regulatory disclosure language. State 11 books advisers from the local network.
  </div>

  <div class="footer">
    <div>Internal — Build Reference</div>
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

    print(f"Composed intake flow → {TMP_HTML}")
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
