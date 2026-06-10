#!/usr/bin/env python3
"""
Build the Akane Implementation Plan — staged plan to deliver Layers 1, 2, and 3.

A4 portrait, 2 pages. Designed as the primary planning artefact for the build
phase: workstreams, sequencing, resourcing, dependencies, gate criteria.

Output: docs/ai_strategy/FutureProof_Akane_Implementation_Plan.pdf

Run:
    python3 docs/ai_strategy/build_implementation_plan.py
"""

from __future__ import annotations
import base64
import subprocess
from pathlib import Path
from datetime import date

ROOT = Path(__file__).resolve().parents[2]
AI_DIR = ROOT / "docs" / "ai_strategy"
OUT_PDF = AI_DIR / "FutureProof_Akane_Implementation_Plan.pdf"
LOGO_PATH = ROOT / "app" / "assets" / "images" / "futureproof-logo.png"
TMP_HTML = AI_DIR / "_tmp_implementation_plan.html"

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
    --l1: #1ABC9C;
    --l2: #1E88E5;
    --l3: #1F3864;
    --gate: #FFA000;
}

body {
    margin: 0; padding: 0;
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
    margin-bottom: 3.5mm;
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

/* Timeline visual */
.timeline {
    margin-bottom: 4mm;
}

.timeline-bars {
    display: grid;
    grid-template-columns: 0.7fr 1.4fr 1.4fr 2fr 0.4fr;
    gap: 1.5mm;
    margin-top: 1.5mm;
}

.bar {
    padding: 2mm 3mm;
    border-radius: 2mm;
    color: white;
    font-size: 8.5pt;
    line-height: 1.25;
    position: relative;
}

.bar .lbl { font-weight: 700; font-size: 8pt; text-transform: uppercase; letter-spacing: 0.3pt; display: block; margin-bottom: 0.8mm; }
.bar .when { display: block; font-size: 7.5pt; opacity: 0.85; }

.bar.pre { background: var(--gray-500); }
.bar.s1 { background: var(--blue); }
.bar.s2 { background: #2D6CDF; }
.bar.s3 { background: var(--navy); }
.bar.gate { background: var(--gate); display: flex; align-items: center; justify-content: center; font-weight: 700; font-size: 9pt; }

/* Stage cards */
.stage-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 2.5mm;
}

.stage {
    background: var(--gray-100);
    border-radius: 2.5mm;
    padding: 2.5mm 3.5mm;
    page-break-inside: avoid;
}

.stage.full { grid-column: 1 / -1; }

.stage h3 {
    font-size: 9pt;
    font-weight: 700;
    color: var(--navy);
    margin: 0 0 1.2mm 0;
    text-transform: uppercase;
    letter-spacing: 0.3pt;
    border-bottom: 1pt solid var(--gray-200);
    padding-bottom: 0.8mm;
}

.stage h3 .when {
    font-weight: 400;
    color: var(--gray-700);
    text-transform: none;
    letter-spacing: 0;
    margin-left: 2mm;
    font-size: 8pt;
    font-style: italic;
}

.layer-block {
    margin-bottom: 1.2mm;
    font-size: 7.8pt;
    line-height: 1.35;
}

.layer-block .layer-tag {
    display: inline-block;
    padding: 0.3mm 1.5mm;
    border-radius: 1.5mm;
    color: white;
    font-size: 6.5pt;
    font-weight: 700;
    letter-spacing: 0.3pt;
    margin-right: 1.5mm;
}

.layer-tag.l1 { background: var(--l1); }
.layer-tag.l2 { background: var(--l2); }
.layer-tag.l3 { background: var(--l3); }
.layer-tag.val { background: var(--gray-500); }

.stage ul {
    font-size: 7.8pt;
    line-height: 1.32;
    margin: 0.3mm 0 1mm 0;
    padding-left: 3.5mm;
    color: var(--gray-900);
}

.stage ul li { margin-bottom: 0.2mm; }
.stage ul li strong { color: var(--navy); }

.gate-criteria {
    background: #FFF8E1;
    border-left: 2pt solid var(--gate);
    padding: 1.2mm 2.5mm;
    margin-top: 1.5mm;
    font-size: 7.5pt;
    line-height: 1.3;
    color: var(--gray-700);
}

.gate-criteria strong { color: #B26A00; }

/* Page 2 */
table.resources {
    width: 100%;
    border-collapse: collapse;
    font-size: 7.5pt;
    line-height: 1.3;
    margin-top: 1mm;
}

table.resources thead {
    background: var(--navy);
    color: white;
}

table.resources thead th {
    text-align: left;
    padding: 1.2mm 1.8mm;
    font-weight: 600;
    font-size: 7pt;
    text-transform: uppercase;
    letter-spacing: 0.3pt;
}

table.resources tbody tr {
    border-bottom: 1pt solid var(--gray-200);
}

table.resources tbody tr:nth-child(even) { background: var(--gray-100); }

table.resources tbody td {
    padding: 1.1mm 1.8mm;
    vertical-align: top;
}

table.resources tbody td.role { font-weight: 700; color: var(--navy); width: 26%; }
table.resources tbody td.source { width: 30%; color: var(--gray-700); }
table.resources tbody td.when { width: 23%; color: var(--gray-700); font-size: 7pt; }
table.resources tbody td.notes { width: 21%; color: var(--gray-700); font-size: 7pt; }

.section-h {
    font-size: 9pt;
    font-weight: 700;
    color: var(--navy);
    text-transform: uppercase;
    letter-spacing: 0.3pt;
    margin: 2mm 0 1mm 0;
    padding-bottom: 0.5mm;
    border-bottom: 1.5pt solid var(--navy);
}

.deps-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 3mm;
}

.deps {
    background: var(--gray-100);
    border-radius: 2.5mm;
    padding: 2.5mm 3.5mm;
}

.deps h4 {
    font-size: 8.5pt;
    font-weight: 700;
    color: var(--navy);
    margin: 0 0 1.2mm 0;
    text-transform: uppercase;
    letter-spacing: 0.3pt;
}

.deps ul, .deps ol {
    font-size: 8pt;
    line-height: 1.35;
    margin: 0;
    padding-left: 3.5mm;
    color: var(--gray-900);
}

.deps ul li, .deps ol li { margin-bottom: 0.4mm; }
.deps strong { color: var(--navy); }

.principles {
    background: var(--blue-light);
    border-left: 2pt solid var(--blue);
    padding: 2mm 3mm;
    margin-top: 2.5mm;
    font-size: 8pt;
    line-height: 1.35;
    color: var(--gray-700);
}

.principles strong { color: var(--navy); }

.footer {
    position: absolute;
    bottom: 5mm;
    left: 13mm;
    right: 13mm;
    font-size: 7.5pt;
    color: var(--gray-500);
    display: flex;
    justify-content: space-between;
    border-top: 1pt solid var(--gray-200);
    padding-top: 2mm;
}
"""


def build_html() -> str:
    return f'''<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Akane Implementation Plan</title>
<style>{CSS}</style>
</head>
<body>

<!-- ========== PAGE 1 ========== -->
<div class="page">

  <div class="header">
    <div class="header-left">
      <div class="doc-title">Akane — Implementation Plan</div>
      <div class="doc-subtitle">Staged build of Layers 1, 2, and 3 — workstreams, sequencing, gates</div>
    </div>
    <div class="header-right">
      <div class="stamp">Internal · Build Plan</div>
      <div>{DATE_STR}</div>
    </div>
  </div>

  <!-- Timeline visual -->
  <div class="timeline">
    <div style="font-size: 9.5pt; font-weight: 700; color: var(--navy); text-transform: uppercase; letter-spacing: 0.3pt;">Stage timeline</div>
    <div class="timeline-bars">
      <div class="bar pre"><span class="lbl">Stage 0</span><span class="when">Wks 0–8 · Validate</span></div>
      <div class="bar s1"><span class="lbl">Stage 1 · Build</span><span class="when">Months 0–6</span></div>
      <div class="bar s2"><span class="lbl">Stage 2 · Launch</span><span class="when">Months 6–12</span></div>
      <div class="bar s3"><span class="lbl">Stage 3 · Scale</span><span class="when">Y2–Y3 · UK + US</span></div>
      <div class="bar gate">★</div>
    </div>
    <div style="font-size: 8pt; color: var(--gray-500); margin-top: 1.5mm; line-height: 1.3;">
      Each stage has explicit go / no-go criteria. We commit only the next stage. ★ = future Series A funded scale.
    </div>
  </div>

  <!-- Stage 0 -->
  <div class="stage-grid">

    <div class="stage full">
      <h3>Stage 0 — Validate &amp; Set Up <span class="when">Weeks 0–8 · Pre-build</span></h3>
      <div class="layer-block">
        <span class="layer-tag val">VALIDATION</span>
        <ul>
          <li><strong>Regulatory pathway</strong> (4 wks, external counsel) — own AFSL vs partnership vs general-advice scenario tool. Decision unblocks compliance build.</li>
          <li><strong>Vendor spike</strong> (2 wks, internal eng) — voice stack (Vapi vs Bland vs Twilio+Deepgram); confirm pricing &amp; SLAs.</li>
          <li><strong>Partner appetite check</strong> (6 wks, BD) — sound out Iress, Intelliflo, Envestnet + 2–3 super funds. Yes / no signal on Layer 3 thesis.</li>
          <li><strong>Recommendation engine API spec</strong> + actuarial review (2 wks, Pavel + Tom) — signs off what Akane can / can't say about EPM.</li>
          <li><strong>Senior AI Product Lead hire</strong> — start search now; offer ideally accepted by week 8.</li>
        </ul>
      </div>
      <div class="gate-criteria">
        <strong>Gate to Stage 1:</strong> regulatory model decided · vendor selected · partner appetite signal received · actuarial sign-off · product hire accepted (or strong shortlist). All five required to commit Stage 1 budget.
      </div>
    </div>

    <!-- Stage 1 -->
    <div class="stage">
      <h3>Stage 1 — Build <span class="when">Months 0–6</span></h3>
      <div class="layer-block">
        <span class="layer-tag l1">LAYER 1</span> — parallel workstreams
        <ul>
          <li><strong>L1.1 Conversation engine</strong> — state-machine intake (per Intake Flow doc). 1 sr eng, 8 wks.</li>
          <li><strong>L1.2 Recommendation engine</strong> — wraps existing calc engine. Eng + Tom review. 6 wks.</li>
          <li><strong>L1.3 Web UI</strong> — chat + sliders / charts / cards. Frontend eng + UX designer. 8 wks parallel.</li>
          <li><strong>L1.4 Voice integration</strong> — Vapi (or chosen). 1 eng + voice contractor. 6 wks after core.</li>
          <li><strong>L1.5 Compliance &amp; audit</strong> — disclosure, audit trail, adviser handoff. 1 eng + legal. 4 wks.</li>
          <li><strong>L1.6 Persistent memory</strong> — sessions, resume, family-share. 2 wks.</li>
          <li><strong>L1.7 Observability</strong> — analytics, drop-off, recommendation quality dashboard. 2 wks.</li>
          <li><strong>L1.8 Closed alpha</strong> (50 users, friends &amp; family). 4 wks.</li>
        </ul>
      </div>
      <div class="layer-block">
        <span class="layer-tag l2">LAYER 2</span> — smaller team, parallel
        <ul>
          <li><strong>L2.1 MCP server</strong> + core tools. 1 sr eng, 4 wks.</li>
          <li><strong>L2.2 OpenAPI spec</strong>, schema, auth, rate limiting, docs. 1 wk parallel.</li>
        </ul>
      </div>
      <div class="gate-criteria">
        <strong>Gate to Stage 2:</strong> alpha NPS strong, conversion lift demonstrated, no compliance breaches, MCP server stable, schema published, Pavel / Tom sign-off on rec logic.
      </div>
    </div>

    <!-- Stage 2 -->
    <div class="stage">
      <h3>Stage 2 — Launch <span class="when">Months 6–12</span></h3>
      <div class="layer-block">
        <span class="layer-tag l1">LAYER 1</span>
        <ul>
          <li>L1.10 GA launch (AU) · L1.11 Voice channel · L1.12 Multilingual (CN, VN)</li>
          <li>L1.13 Continuous A/B testing of message variants &amp; rec logic</li>
          <li>L1.14 Family-share feature · L1.15 Production-data iteration</li>
        </ul>
      </div>
      <div class="layer-block">
        <span class="layer-tag l2">LAYER 2</span>
        <ul>
          <li>L2.7 Anthropic MCP marketplace · L2.8 OpenAI plugin store · L2.9 Google A2A directory</li>
        </ul>
      </div>
      <div class="layer-block">
        <span class="layer-tag l3">LAYER 3 — kicks in</span>
        <ul>
          <li>L3.1 First partnership push — Iress / Intelliflo (most-likely first integrations)</li>
          <li>L3.2 Co-marketing with Anthropic on MCP launch</li>
          <li>L3.3 Schema authority — engage FSC working group · L3.4 Conferences (RIC, AI in FS)</li>
        </ul>
      </div>
      <div class="gate-criteria">
        <strong>Gate to Stage 3:</strong> Akane GA stable · ≥ 2 partner LOIs · material agent-attributed customer acquisition · MCP traffic emerging.
      </div>
    </div>

    <!-- Stage 3 -->
    <div class="stage full">
      <h3>Stage 3 — Scale <span class="when">Year 2 → Year 3 · UK + US</span></h3>
      <div class="layer-block">
        <span class="layer-tag l1">LAYER 1</span> — multi-region rollout
        <ul>
          <li>L1.20 UK launch (Q2/2027) — localised regulator (FCA Consumer Duty), currency (GBP), product spec.</li>
          <li>L1.21 US launch (Q4/2027) — localised regulator (SEC + state RIA), currency (USD), product spec.</li>
          <li>L1.22 Continuous learning loop matures — actuarial recalibration based on production data.</li>
          <li>L1.23 <strong>Akane v2 rebuild</strong> (months 18–24) — leveraging compounded data; Layer 1 depreciates and we reset.</li>
        </ul>
      </div>
      <div class="layer-block">
        <span class="layer-tag l3">LAYER 3</span> — ecosystem maturity
        <ul>
          <li>L3.10 Partnership scale across regions — target multiple integrations across adviser tools, super / pension fund AI, consumer assistants.</li>
          <li>L3.11 Standards working group seats (FSC, AFA, AIST · UK PFS · US CFP Board) · L3.12 Thought leadership in agentic-FS space.</li>
        </ul>
      </div>
      <div class="gate-criteria">
        <strong>Continuous gate:</strong> agent-attributed customer acquisition tracking to plan · live partner integrations across regions · schema authority recognised in industry references. Stage 3 funded from future Series A.
      </div>
    </div>

  </div>

  <div class="footer">
    <div>Internal — Build Plan</div>
    <div>©2026 Futureproof Financial Group Limited</div>
    <div>1 of 2</div>
  </div>

</div>

<!-- ========== PAGE 2 ========== -->
<div class="page">

  <div class="header">
    <div class="header-left">
      <div class="doc-title">Akane — Implementation Plan (cont.)</div>
      <div class="doc-subtitle">Resourcing · Critical path · Discipline</div>
    </div>
    <div class="header-right">
      <div class="stamp">Internal · Build Plan</div>
      <div>{DATE_STR}</div>
    </div>
  </div>

  <div class="section-h">Resourcing</div>
  <table class="resources">
    <thead>
      <tr><th>Role</th><th>Source</th><th>When</th><th>Notes</th></tr>
    </thead>
    <tbody>
      <tr><td class="role">Senior AI Product Lead</td><td class="source">New hire</td><td class="when">Stage 0 (accept by wk 8)</td><td class="notes">Owns L1 product direction; inherits UX + Flow docs.</td></tr>
      <tr><td class="role">Senior full-stack engineers (×2)</td><td class="source">Existing or new</td><td class="when">Stage 1+</td><td class="notes">Conversation engine, UI, voice.</td></tr>
      <tr><td class="role">AI / ML engineer</td><td class="source">Tom Neilsen + 1 hire</td><td class="when">Stage 1+</td><td class="notes">Rec logic, evals, feedback loop.</td></tr>
      <tr><td class="role">UX designer</td><td class="source">Contractor / hire</td><td class="when">Stage 1+ (initial 8 wks)</td><td class="notes">Mixed UI — sliders, charts, cards.</td></tr>
      <tr><td class="role">Voice integration specialist</td><td class="source">Contractor</td><td class="when">Stage 1 (L1.4)</td><td class="notes">Vapi / Twilio, voice flow.</td></tr>
      <tr><td class="role">Backend engineer (Layer 2)</td><td class="source">Existing or contractor</td><td class="when">Stage 1 (part-time)</td><td class="notes">MCP, OpenAPI, schema, marketplace.</td></tr>
      <tr><td class="role">Compliance &amp; legal counsel</td><td class="source">External (AU AFSL counsel)</td><td class="when">Stage 0+</td><td class="notes">Regulatory pathway + audit + locales.</td></tr>
      <tr><td class="role">Pavel + Tom (actuarial)</td><td class="source">Existing</td><td class="when">Stage 0 + ongoing</td><td class="notes">Sign off rec logic; recalibrate.</td></tr>
      <tr><td class="role">Partnership / BD lead</td><td class="source">Mike + Max → dedicated hire</td><td class="when">Stage 0 → Stage 2+</td><td class="notes">Adviser tools, funds, marketplaces.</td></tr>
      <tr><td class="role">CMO / Marketing</td><td class="source">Margaret Rochford (existing)</td><td class="when">Stage 2+</td><td class="notes">Co-marketing, conferences, content.</td></tr>
      <tr><td class="role">Senior US distribution lead</td><td class="source">New hire (in plan)</td><td class="when">Stage 3 (Q4/2027)</td><td class="notes">Per existing capital raise plan.</td></tr>
    </tbody>
  </table>

  <div class="section-h">Critical path &amp; dependencies</div>
  <div class="deps-grid">
    <div class="deps">
      <h4>Hard dependencies (block downstream work)</h4>
      <ol>
        <li><strong>Regulatory pathway decision</strong> blocks L1.5 (compliance infrastructure design) and the customer-facing language Akane uses.</li>
        <li><strong>Recommendation engine spec sign-off</strong> (Pavel / Tom) blocks L1.2 build — we don't write logic before the actuarial team approves it.</li>
        <li><strong>Senior product hire</strong> blocks L1 design leadership — current team can build, but product direction needs dedicated owner.</li>
        <li><strong>Vendor selection</strong> (voice stack) blocks L1.4 — different vendors need different integration patterns.</li>
        <li><strong>L2 schema definition</strong> must precede L3 partner integrations — partners integrate against the schema, not against working code.</li>
      </ol>
    </div>
    <div class="deps">
      <h4>Watch-points &amp; soft dependencies</h4>
      <ol>
        <li><strong>Partner appetite signal</strong> — if Stage 0 sounds out comes back weak across all partners, scale Layer 3 ambition back, double down on Layer 1 differentiation alone.</li>
        <li><strong>Anthropic MCP marketplace policies</strong> may evolve — keep the OpenAPI surface as a parallel path so we're not exclusively dependent on one platform.</li>
        <li><strong>The feedback loop</strong> requires usage volume — first 6 months of GA in AU will be sparse data. Don't over-tune early.</li>
        <li><strong>Akane v2 rebuild (month 18–24)</strong> is intentional — Layer 1 is a depreciating asset. Plan for it; don't be surprised by it.</li>
      </ol>
    </div>
  </div>

  <div class="section-h">Discipline &amp; decision points</div>
  <div class="deps-grid">
    <div class="deps">
      <h4>Discipline (every stage)</h4>
      <ul>
        <li><strong>Optionality, not features.</strong> Stage 1 choices preserve our ability to swap vendors, protocols, agents — without re-architecting L2/L3.</li>
        <li><strong>Stage gates are non-negotiable.</strong> Failed criteria = kill or de-scope, never "push through".</li>
        <li><strong>Quarterly AI landscape review</strong> — sr product lead + CTO + external advisor; calendared.</li>
        <li><strong>Layer 1 depreciates; Layers 2 &amp; 3 compound.</strong> Invest accordingly.</li>
        <li><strong>Every conversation captured</strong> — outcomes feed back to the rec engine.</li>
        <li><strong>Compliance is built in Day 1</strong>, not bolted on at GA.</li>
      </ul>
    </div>
    <div class="deps">
      <h4>Decision moments management owns</h4>
      <ol>
        <li><strong>Week 8</strong> — Stage 0 gate. Commit Stage 1 budget?</li>
        <li><strong>Month 6</strong> — Stage 1 gate. Move to Stage 2 (GA + first partnerships)?</li>
        <li><strong>Month 12</strong> — Stage 2 gate. Move to Stage 3 (UK + US scale)? Usually contingent on Series A close.</li>
        <li><strong>Month 18</strong> — Akane v2 rebuild scoping. What survives, what gets rebuilt?</li>
        <li><strong>Quarterly throughout</strong> — AI landscape review. Does our plan still fit reality?</li>
      </ol>
    </div>
  </div>

  <div class="footer">
    <div>Internal — Build Plan</div>
    <div>©2026 Futureproof Financial Group Limited</div>
    <div>2 of 2</div>
  </div>

</div>
</body>
</html>
'''


def main():
    html = build_html()
    TMP_HTML.write_text(html)

    print(f"Composed implementation plan → {TMP_HTML}")
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
