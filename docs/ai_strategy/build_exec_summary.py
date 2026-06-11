#!/usr/bin/env python3
"""
Build the 1-page Executive Summary for the AI Agent Strategy.

Grounded rewrite (May 2026): concrete, measurable, build-vs-buy explicit. No
"ecosystem moat" hand-waving — real Stage-1 deliverables, numeric go/no-go gates,
the hybrid infrastructure + data-classification decision, the legal position, and
the fifth (internal engineering & ops) agent.

Output: docs/ai_strategy/FutureProof_AI_Strategy_ExecSummary.pdf
Run:    python3 docs/ai_strategy/build_exec_summary.py
"""

from __future__ import annotations
import base64
import subprocess
from pathlib import Path
from datetime import date

ROOT = Path(__file__).resolve().parents[2]
AI_DIR = ROOT / "docs" / "ai_strategy"
OUT_PDF = AI_DIR / "FutureProof_AI_Strategy_ExecSummary.pdf"
LOGO_PATH = ROOT / "app" / "assets" / "images" / "futureproof-logo.png"
TMP_HTML = AI_DIR / "_tmp_exec_summary.html"

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
    --navy: #1F3864; --blue: #1E88E5; --blue-light: #E8F0FB;
    --gray-100: #F7F9FC; --gray-200: #E8ECF2; --gray-500: #8896AB;
    --gray-700: #4A5568; --gray-900: #1A202C; --green: #1E8E5A;
}
body {
    margin: 0; padding: 0;
    font-family: 'Avenir Next', 'Helvetica Neue', system-ui, -apple-system, sans-serif;
    color: var(--gray-900); -webkit-print-color-adjust: exact; print-color-adjust: exact;
}
.page { width: 210mm; height: 297mm; padding: 10mm 14mm 8mm 14mm; position: relative; background: white; }

.header { border-bottom: 1.5pt solid var(--navy); padding-bottom: 3.5mm; margin-bottom: 3mm;
          display: flex; justify-content: space-between; align-items: flex-end; }
.header-left .doc-title { font-size: 18pt; font-weight: 700; color: var(--navy); margin-top: 2mm; line-height: 1.05; }
.header-left .doc-subtitle { font-size: 9.5pt; color: var(--gray-700); margin-top: 1.5mm; font-style: italic; }
.header-right { text-align: right; font-size: 8.5pt; color: var(--gray-500); line-height: 1.5; }
.header-right .stamp { background: var(--blue-light); color: var(--navy); padding: 1.5mm 3.5mm; font-weight: 600;
          font-size: 8pt; letter-spacing: 0.3pt; text-transform: uppercase; border-radius: 2mm;
          display: inline-block; margin-bottom: 1.5mm; }

section { margin-bottom: 2.6mm; }
section h2 { font-size: 9pt; font-weight: 700; color: var(--navy); text-transform: uppercase; letter-spacing: 0.5pt;
          margin: 0 0 1.3mm 0; padding-bottom: 0.7mm; border-bottom: 1pt solid var(--gray-200); }
section p { font-size: 9pt; line-height: 1.4; margin: 0 0 1.3mm 0; color: var(--gray-900); }
section p:last-child { margin-bottom: 0; }
b, strong { color: var(--navy); }

.agents { width: 100%; border-collapse: collapse; margin-top: 0.5mm; font-size: 8.6pt; }
.agents td { padding: 1.1mm 2mm; border-bottom: 0.5pt solid var(--gray-200); vertical-align: top; line-height: 1.28; }
.agents tr:last-child td { border-bottom: none; }
.agents .nm { font-weight: 700; color: var(--navy); white-space: nowrap; }
.agents .st { white-space: nowrap; font-size: 7.8pt; color: var(--gray-500); }
.agents .st.now { color: var(--green); font-weight: 700; }
.agents .st.first { color: var(--blue); font-weight: 700; }

.metrics { font-size: 8.7pt; line-height: 1.5; color: var(--gray-900); }
.metrics .tag { display: inline-block; background: var(--gray-100); border-radius: 1.5mm; padding: 0.3mm 2mm;
          margin: 0.5mm 1mm 0 0; white-space: nowrap; }
.metrics .tag b { color: var(--navy); }

.twocol { display: grid; grid-template-columns: 1fr 1fr; gap: 3mm; margin-top: 0.8mm; }
.twocol .col { background: var(--gray-100); border-left: 3pt solid var(--blue); padding: 1.8mm 2.4mm;
          font-size: 8.4pt; line-height: 1.35; }
.twocol .col.local { border-left-color: var(--navy); background: var(--blue-light); }
.twocol .col .label { font-weight: 700; color: var(--navy); font-size: 8.8pt; margin-bottom: 0.7mm; }

.points { margin: 0.5mm 0 0 0; padding-left: 5mm; font-size: 9pt; line-height: 1.45; }
.points li { margin-bottom: 1.4mm; }
.points li:last-child { margin-bottom: 0; }

.footer { position: absolute; bottom: 7mm; left: 14mm; right: 14mm; font-size: 7.5pt; color: var(--gray-500);
          display: flex; justify-content: space-between; border-top: 1pt solid var(--gray-200); padding-top: 2.5mm; }
"""


def build_html() -> str:
    logo_html = (f'<img src="{LOGO_URI}" alt="FutureProof" style="height: 30pt;">'
                 if LOGO_URI else
                 '<div style="font-size:14pt;font-weight:600;color:#1F3864;">futureproof</div>')

    return f'''<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>FutureProof — AI Agent Strategy Executive Summary</title>
<style>{CSS}</style>
</head>
<body>
<div class="page">

  <div class="header">
    <div class="header-left">
      {logo_html}
      <div class="doc-title">AI Agent Plan</div>
      <div class="doc-subtitle">High-Level Roadmap</div>
    </div>
    <div class="header-right">
      <div class="stamp">Internal · Plan</div>
      <div>{DATE_STR}</div>
      <div>Presented by Matt Stone, CTO</div>
    </div>
  </div>

  <section>
    <h2>What we want to achieve</h2>
    <p>AI agents across the customer lifecycle — bringing customers in, serving them, and running the business —
    plus a master engineering agent that builds and operates the platform itself. The aim is a scalable, always-on,
    lower-cost EPM experience, with a licensed human adviser retained where it matters and engineering velocity
    multiplied.</p>
    <table class="agents">
      <tr><td class="nm">Akane</td><td>Customer acquisition — web chat, eligibility, structured intake → handoff to a human adviser.</td><td class="st first">First</td></tr>
      <tr><td class="nm">Misato</td><td>Customer communications &amp; service — status, statements and support for active customers.</td><td class="st">Later</td></tr>
      <tr><td class="nm">Rie</td><td>Back-office &amp; operations — document verification, settlement, reconciliation.</td><td class="st">Internal</td></tr>
      <tr><td class="nm">Yumi</td><td>Investment account — setup, monitoring, end-of-life settlement.</td><td class="st">Internal</td></tr>
      <tr><td class="nm">Motoko</td><td><strong>Engineering &amp; operations — the master agent.</strong> Builds and runs the platform and the four product agents above. Human-supervised.</td><td class="st now">Live today</td></tr>
    </table>
    <p style="font-size:8pt;color:var(--gray-500);margin-top:1mm;">Codenames are internal only — customers always see "the FutureProof assistant". Motoko is a different class from the four product agents: it builds and operates them, and is not part of the customer journey.</p>
  </section>

  <section>
    <h2>The approach</h2>
    <ul class="points">
      <li><strong>Build on what we have</strong> — the agents sit on the existing calculation engine and EPM model, not a new platform.</li>
      <li><strong>Start where value is provable</strong> — the customer-acquisition agent (Akane) and the engineering agent (Motoko, already delivering); expand to communications, operations and investment as each proves out.</li>
      <li><strong>Rent intelligence, own the sensitive tier</strong> — a frontier cloud model for the customer-facing surface; a local model on our own hardware for sensitive and internal data.</li>
      <li><strong>Keep a human in the loop</strong> — a licensed adviser confirms before any advice is issued.</li>
    </ul>
  </section>

  <section>
    <h2>How we mitigate risks</h2>
    <ul class="points">
      <li><strong>Stage-gated</strong> — we commit one stage at a time, each with go and kill criteria; investment grows only as evidence supports it.</li>
      <li><strong>Data &amp; compliance</strong> — sensitive data stays onshore / in-house; customer data flows only through compliant, no-training channels with privacy-counsel sign-off; the human-adviser gate keeps us inside the advice rules.</li>
      <li><strong>Technology &amp; dependency</strong> — the master agent is human-supervised (no autonomous production changes); owning local hardware hedges reliance on any single cloud-AI provider.</li>
      <li><strong>No over-promising</strong> — the broader AI-ecosystem position is treated as upside to earn, not a moat we claim today.</li>
    </ul>
  </section>

  <section>
    <h2>Rough budget</h2>
    <p>Deliberately modest to start: roughly one engineer's time for a quarter, a small monthly cloud-AI bill, and
    one Mac Studio (~A$8k, 96GB) — fundable within the current round. Investment scales only as each stage's gate is
    passed. Detailed costings, success metrics, and the build-vs-buy specifics sit in the companion plan.</p>
  </section>

  <div class="footer">
    <div>Internal — AI Agent Plan</div>
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
    print(f"Composed exec summary → {TMP_HTML}")
    print("Rendering PDF...")
    OUT_PDF.parent.mkdir(parents=True, exist_ok=True)
    cmd = [
        CHROME, "--headless=new", "--disable-gpu", "--no-pdf-header-footer", "--no-sandbox",
        "--virtual-time-budget=4000", "--run-all-compositor-stages-before-draw",
        f"--print-to-pdf={OUT_PDF}", f"file://{TMP_HTML.absolute()}",
    ]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0 or not OUT_PDF.exists():
        print(f"Chrome stderr:\n{result.stderr[:1000]}")
        raise RuntimeError("Chrome failed")
    size_kb = OUT_PDF.stat().st_size / 1024
    print(f"OK {OUT_PDF.name} — {size_kb:.0f} KB")
    TMP_HTML.unlink(missing_ok=True)


if __name__ == "__main__":
    main()
