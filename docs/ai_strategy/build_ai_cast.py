#!/usr/bin/env python3
"""
Build the FutureProof AI Cast — visual reference of the named AI agents in the
FP product family and what each is responsible for.

A4 landscape, 4 pages:
  P1  Overview — the five agents at a glance + Motoko callout
  P2  Customer-facing agents — Akane (acquisition) & Misato (communications)
  P3  Behind-the-scenes agents — Rie (back-office) & Yumi (investment)
  P4  Motoko (the master agent) + the customer-journey map it powers

Two product agents per page → each gets room to breathe (readable fonts, calm
rhythm, colour used as accent not fill). Compliance: Akane gives GENERAL advice
only; personal advice requires the licensed human adviser (an AI cannot hold a
licence).

Output: docs/ai_strategy/FutureProof_AI_Cast.pdf
Run:    python3 docs/ai_strategy/build_ai_cast.py
"""

from __future__ import annotations
import base64
import subprocess
from pathlib import Path
from datetime import date

ROOT = Path(__file__).resolve().parents[2]
AI_DIR = ROOT / "docs" / "ai_strategy"
OUT_PDF = AI_DIR / "FutureProof_AI_Cast.pdf"
LOGO_PATH = ROOT / "app" / "assets" / "images" / "futureproof-logo.png"
TMP_HTML = AI_DIR / "_tmp_ai_cast.html"

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
    --gray-50: #F7F9FC;
    --gray-100: #F2F5F9;
    --gray-200: #E3E8F0;
    --gray-500: #8896AB;
    --gray-700: #4A5568;
    --gray-900: #1A202C;
    --akane:  #C0392B;   /* deep red — external/umbrella */
    --misato: #6B4FA0;   /* purple — communications */
    --rie:    #2C7A7B;   /* teal — back-office ops */
    --yumi:   #B8860B;   /* dark gold — investment/lifetime */
    --motoko: #1F3864;   /* navy — master engineering/ops (different class) */
}

body {
    margin: 0; padding: 0;
    font-family: 'Avenir Next', 'Helvetica Neue', system-ui, -apple-system, sans-serif;
    color: var(--gray-900);
    -webkit-print-color-adjust: exact;
    print-color-adjust: exact;
}

.page {
    width: 297mm;
    height: 210mm;
    padding: 8mm 11mm 7mm 11mm;
    position: relative;
    background: white;
    page-break-after: always;
    display: flex;
    flex-direction: column;
}
.page:last-child { page-break-after: auto; }

/* ===== Header ===== */
.header {
    border-bottom: 1.5pt solid var(--navy);
    padding-bottom: 2.5mm;
    margin-bottom: 4mm;
    display: flex;
    justify-content: space-between;
    align-items: flex-end;
    flex: none;
}
.header-left .doc-title { font-size: 15pt; font-weight: 700; color: var(--navy); line-height: 1.05; margin-top: 1mm; }
.header-left .doc-subtitle { font-size: 8.5pt; color: var(--gray-700); margin-top: 0.8mm; font-style: italic; }
.header-right { text-align: right; font-size: 8pt; color: var(--gray-500); line-height: 1.4; }
.header-right .stamp { background: var(--blue-light); color: var(--navy); padding: 1.2mm 2.5mm; font-weight: 600;
    font-size: 7.5pt; letter-spacing: 0.3pt; text-transform: uppercase; border-radius: 1.5mm; display: inline-block; margin-bottom: 1mm; }

/* ===== Intro page (P1) ===== */
.intro-hero { margin-top: 14mm; text-align: center; flex: none; }
.intro-hero .eyebrow { font-size: 10pt; font-weight: 700; color: var(--akane); text-transform: uppercase; letter-spacing: 1.2pt; margin-bottom: 4mm; }
.intro-hero .big-title { font-size: 36pt; font-weight: 700; color: var(--navy); line-height: 1; margin-bottom: 6mm; letter-spacing: -0.4pt; }
.intro-hero .lede { font-size: 13pt; color: var(--gray-700); line-height: 1.45; max-width: 205mm; margin: 0 auto 14mm auto; }
.intro-hero .lede strong { color: var(--navy); font-weight: 600; }

.intro-grid { display: grid; grid-template-columns: repeat(4, 1fr); gap: 9mm; padding: 0 6mm; flex: none; }
.intro-card { text-align: center; padding: 6mm 4mm; border-radius: 4mm; background: white; border: 1pt solid var(--gray-200); border-top-width: 4pt; }
.intro-card.akane  { border-top-color: var(--akane); }
.intro-card.misato { border-top-color: var(--misato); }
.intro-card.rie    { border-top-color: var(--rie); }
.intro-card.yumi   { border-top-color: var(--yumi); }
.intro-avatar { width: 26mm; height: 26mm; border-radius: 50%; margin: 0 auto 5mm auto; display: flex; align-items: center; justify-content: center; color: white; font-weight: 700; font-size: 34pt; }
.intro-avatar.akane  { background: var(--akane); }
.intro-avatar.misato { background: var(--misato); }
.intro-avatar.rie    { background: var(--rie); }
.intro-avatar.yumi   { background: var(--yumi); }
.intro-name { font-size: 22pt; font-weight: 700; color: var(--navy); line-height: 1; margin-bottom: 2mm; }
.intro-role { font-size: 11pt; font-weight: 600; color: var(--gray-900); margin-bottom: 2mm; line-height: 1.25; }
.intro-tag { font-size: 9pt; color: var(--gray-700); line-height: 1.4; font-style: italic; }

.intro-callout { margin-top: 13mm; border: 0.5pt solid var(--gray-200); border-left: 4pt solid var(--motoko);
    border-radius: 6pt; background: var(--gray-50); padding: 11pt 15pt; display: flex; align-items: center; gap: 14pt; }
.intro-callout .ic-avatar { width: 38pt; height: 38pt; border-radius: 50%; background: var(--motoko); color: #fff;
    display: flex; align-items: center; justify-content: center; font-size: 17pt; flex: none; }
.intro-callout div:last-child { font-size: 10.5pt; line-height: 1.5; color: var(--gray-700); }

/* ===== Persona stack (P2, P3, P4) ===== */
.cast-stack { display: flex; flex-direction: column; gap: 6mm; flex: 1; min-height: 0; }

.persona {
    background: white;
    border: 1pt solid var(--gray-200);
    border-left: 5pt solid var(--gray-500);
    border-radius: 3mm;
    padding: 6mm 7mm;
    display: flex;
    gap: 9mm;
    align-items: flex-start;
    flex: 1;
    min-height: 0;
}
.persona.akane  { border-left-color: var(--akane); }
.persona.misato { border-left-color: var(--misato); }
.persona.rie    { border-left-color: var(--rie); }
.persona.yumi   { border-left-color: var(--yumi); }
.persona.motoko { border-left-color: var(--motoko); }

/* Left "nameplate" */
.nameplate { width: 58mm; flex: none; display: flex; flex-direction: column; }
.nameplate .avatar { width: 16mm; height: 16mm; border-radius: 50%; display: flex; align-items: center; justify-content: center;
    color: #fff; font-weight: 700; font-size: 21pt; margin-bottom: 3.5mm; }
.nameplate .avatar.akane  { background: var(--akane); }
.nameplate .avatar.misato { background: var(--misato); }
.nameplate .avatar.rie    { background: var(--rie); }
.nameplate .avatar.yumi   { background: var(--yumi); }
.nameplate .avatar.motoko { background: var(--motoko); }
.nameplate .name { font-size: 23pt; font-weight: 700; color: var(--navy); line-height: 1; margin-bottom: 2mm; }
.nameplate .role { font-size: 9.5pt; font-weight: 600; color: var(--gray-900); line-height: 1.3; margin-bottom: 1.5mm; }
.nameplate .ref { font-size: 8pt; color: var(--gray-500); font-style: italic; line-height: 1.3; margin-bottom: 3mm; }
.nameplate .status { align-self: flex-start; padding: 1.1mm 3mm; border-radius: 9pt; font-size: 7.5pt; font-weight: 700;
    letter-spacing: 0.3pt; text-transform: uppercase; margin-bottom: 3.5mm; }
.nameplate .status.live    { background: #E0F5EA; color: #1B7C4F; }
.nameplate .status.build   { background: #FFF4E5; color: #B26A00; }
.nameplate .status.partial { background: #E8F0FB; color: #1E4F8A; }
.nameplate .status.livenow { background: #D6F5EE; color: #137A68; }
.nameplate .channel { margin-top: auto; font-size: 8.5pt; color: var(--gray-700); line-height: 1.4;
    border-top: 1pt solid var(--gray-200); padding-top: 3mm; }
.nameplate .channel .clabel { display: block; font-weight: 700; color: var(--navy); text-transform: uppercase;
    letter-spacing: 0.4pt; font-size: 7pt; margin-bottom: 1mm; }

/* Right body */
.pbody { flex: 1; min-width: 0; display: flex; flex-direction: column; }
.pbody h3 { font-size: 9pt; font-weight: 700; color: var(--navy); text-transform: uppercase; letter-spacing: 0.4pt; margin: 0 0 2.5mm 0; }
.pbody ul { font-size: 9.5pt; line-height: 1.5; margin: 0 0 3mm 0; padding-left: 5mm; color: var(--gray-900); }
.pbody ul li { margin-bottom: 1.4mm; }
.pbody ul li:last-child { margin-bottom: 0; }
.pbody ul li strong { color: var(--navy); }
.pbody .boundary { margin-top: auto; background: #FFF8E1; border-left: 2.2pt solid #FFA000; padding: 2.2mm 3mm;
    font-size: 8.5pt; line-height: 1.4; color: var(--gray-700); border-radius: 0 2mm 2mm 0; }
.pbody .boundary strong { color: #B26A00; }
.pbody .boundary em { font-style: italic; color: var(--gray-900); }

/* ===== Customer journey (P4) ===== */
.journey { background: var(--gray-50); border: 1pt solid var(--gray-200); border-radius: 3mm; padding: 4mm 5mm; flex: none; }
.journey h3 { font-size: 9.5pt; font-weight: 700; color: var(--navy); text-transform: uppercase; letter-spacing: 0.4pt; margin: 0 0 3mm 0; }
.journey-flow { display: flex; align-items: stretch; gap: 0; }
.flow-step { flex: 1; background: white; border: 1pt solid var(--gray-200); border-radius: 2mm; padding: 2.5mm 3mm; font-size: 8.5pt; line-height: 1.35; }
.flow-step .label { font-weight: 700; color: var(--navy); font-size: 9pt; margin-bottom: 1mm; }
.flow-step .agent { display: inline-block; padding: 0.6mm 2.2mm; border-radius: 7pt; font-size: 7.5pt; font-weight: 600; color: white; margin-bottom: 1.5mm; }
.flow-step .agent.akane  { background: var(--akane); }
.flow-step .agent.misato { background: var(--misato); }
.flow-step .agent.rie    { background: var(--rie); }
.flow-step .agent.yumi   { background: var(--yumi); }
.flow-step .agent.human  { background: var(--navy); }
.flow-arrow { display: flex; align-items: center; justify-content: center; color: var(--gray-500); font-size: 14pt; width: 5mm; flex-shrink: 0; }
.journey-note { margin-top: 3.5mm; font-size: 9.5pt; color: var(--gray-700); line-height: 1.4; border-left: 3pt solid var(--motoko); padding-left: 10pt; }
.journey-note strong { color: var(--motoko); }

.footer { position: absolute; bottom: 4mm; left: 11mm; right: 11mm; font-size: 7pt; color: var(--gray-500);
    display: flex; justify-content: space-between; border-top: 1pt solid var(--gray-200); padding-top: 1.5mm; }
"""


def persona_card(slug: str, kanji: str, name: str, role: str, ref: str,
                 status_label: str, status_class: str, owns_head: str,
                 bullets: list[str], channel: str, boundary: str) -> str:
    bullets_html = "\n        ".join(f"<li>{b}</li>" for b in bullets)
    return f'''
    <div class="persona {slug}">
      <div class="nameplate">
        <div class="avatar {slug}">{kanji}</div>
        <div class="name">{name}</div>
        <div class="role">{role}</div>
        <div class="ref">{ref}</div>
        <div class="status {status_class}">{status_label}</div>
        <div class="channel"><span class="clabel">Channel</span>{channel}</div>
      </div>
      <div class="pbody">
        <h3>{owns_head}</h3>
        <ul>
        {bullets_html}
        </ul>
        <div class="boundary"><strong>⚠ Boundary:</strong> {boundary}</div>
      </div>
    </div>'''


AKANE = persona_card(
    "akane", "茜", "Akane", "Customer Acquisition · the entire pre-customer surface",
    "Internal codename — never spoken to the customer", "To build", "build",
    "What Akane owns",
    [
        'Public-site chat: EPM mechanics, eligibility, FAQs, "is this for me?"',
        "Structured intake → <strong>general</strong> recommendation → compliance gate → adviser handoff",
        "Hands the prospect (full transcript &amp; recommendation) to a licensed human adviser, who provides any personal advice",
        "Spans three layers: <strong>L1</strong> the chat surface · <strong>L2</strong> MCP/OpenAPI plumbing so other assistants can hand a prospect to FP · <strong>L3</strong> partnerships &amp; marketplace position",
    ],
    "Public web chat &amp; voice · multi-region",
    "Akane gives <em>general advice only</em> — personal advice requires the licensed human adviser (an AI cannot hold a licence). Once a product is issued, Akane is done: comms → Misato, processing → Rie, the account → Yumi.",
)

MISATO = persona_card(
    "misato", "美", "Misato", "Customer Communications · post-issuance &amp; ongoing",
    "Internal codename — never spoken to the customer", "Realigning", "partial",
    "What Misato owns — every comm with a paying customer",
    [
        "Status updates, notifications, scheduled comms (statements, reviews, milestones)",
        "Inbound support questions from customers with active mortgages",
        "In-app chat &amp; email for logged-in customers · multi-region",
        "Triages to a human when the question is outside her remit",
    ],
    "Customer portal chat, email, in-app notifications",
    "Not prospects (Akane), not processing (Rie), not the investment account (Yumi). Misato is the <em>voice</em> of the existing relationship.",
)

RIE = persona_card(
    "rie", "理", "Rie", "Back-Office &amp; Business Operations",
    "Internal codename — never customer-facing", "Internal · partial", "partial",
    "What Rie owns — everything inside the business",
    [
        "Application processing: document verification, eligibility checks, settlement",
        "Business-operations workflows: reporting, reconciliation, audit, compliance ops",
        "Internal queries from staff, brokers, and partners",
        "Surfaces decisions &amp; exceptions to humans for confirmation",
    ],
    "Internal admin / staff dashboard · agent_type <code>backoffice</code>",
    "Rie does not talk to customers — ever. If a customer needs to be told something, it routes through Misato.",
)

YUMI = persona_card(
    "yumi", "弓", "Yumi", "Investment Manager · account lifecycle",
    "Internal codename — never spoken to the customer", "Internal · partial", "partial",
    "What Yumi owns — the investment account, end to end",
    [
        "<strong>Setup:</strong> account opening once an adviser has issued the product",
        "<strong>Manage:</strong> portfolio monitoring, rebalancing, performance tracking",
        "<strong>End-of-life:</strong> final settlement, residual handling, account closure",
        "Provides the data Misato uses to talk to the customer",
    ],
    "Investment-management system · agent_type <code>investment</code>",
    "Yumi runs the account but does not talk to the customer directly — customer-facing communication goes via Misato using Yumi's data.",
)

MOTOKO = persona_card(
    "motoko", "素", "Motoko", "Engineering &amp; Operations · the master agent",
    "Internal — a different class from the four product agents", "Live today", "livenow",
    "What Motoko owns — the platform and the agents themselves",
    [
        "Builds and runs the codebase, infrastructure, and the four product agents",
        "Engineering velocity, deployments, monitoring, incident response",
        "Human-supervised: mandatory review, no autonomous production changes, full audit log",
        "The most proven, measurable AI leverage we have today — delivering now",
    ],
    "Internal engineering &amp; ops tooling · human-in-the-loop",
    "Motoko is not part of the customer journey and never talks to customers. It builds and operates the platform the four product agents run on.",
)


def header(subtitle: str) -> str:
    return f'''
  <div class="header">
    <div class="header-left">
      <div class="doc-title">FutureProof's AI Cast</div>
      <div class="doc-subtitle">{subtitle}</div>
    </div>
    <div class="header-right">
      <div class="stamp">Internal · Reference</div>
      <div>{DATE_STR}</div>
    </div>
  </div>'''


def footer(page_no: int) -> str:
    return f'''
  <div class="footer">
    <div>Internal — Reference · Names are codenames used by the team only. Customers never see them.</div>
    <div>©2026 Futureproof Financial Group Limited</div>
    <div>{page_no} of 4</div>
  </div>'''


def build_html() -> str:
    return f'''<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>FutureProof AI Cast</title>
<style>{CSS}</style>
</head>
<body>

<!-- ============== PAGE 1 — Overview ============== -->
<div class="page">
  {header("Internal reference · Page 1 of 4")}

  <div class="intro-hero">
    <div class="eyebrow">Meet the cast</div>
    <div class="big-title">Five agents — four product, one master.</div>
    <div class="lede">
      <strong>Four product agents</strong> each own one phase of the customer lifecycle, with zero overlap. A fifth — <strong>Motoko</strong> — is a different class: it builds and runs the platform and the other four.<br/>
      The names are <strong>internal codenames</strong> — customers may never hear them.
    </div>
  </div>

  <div class="intro-grid">
    <div class="intro-card akane">
      <div class="intro-avatar akane">茜</div>
      <div class="intro-name">Akane</div>
      <div class="intro-role">Customer Acquisition</div>
      <div class="intro-tag">Brings them in</div>
    </div>
    <div class="intro-card misato">
      <div class="intro-avatar misato">美</div>
      <div class="intro-name">Misato</div>
      <div class="intro-role">Customer Communications</div>
      <div class="intro-tag">Talks to them</div>
    </div>
    <div class="intro-card rie">
      <div class="intro-avatar rie">理</div>
      <div class="intro-name">Rie</div>
      <div class="intro-role">Back-Office &amp; Business Ops</div>
      <div class="intro-tag">Runs the business</div>
    </div>
    <div class="intro-card yumi">
      <div class="intro-avatar yumi">弓</div>
      <div class="intro-name">Yumi</div>
      <div class="intro-role">Investment Manager</div>
      <div class="intro-tag">Runs investments</div>
    </div>
  </div>

  <div class="intro-callout">
    <div class="ic-avatar">素</div>
    <div>
      <strong style="color: var(--motoko);">Motoko — the master agent</strong> · Engineering &amp; Operations · <em>builds and runs the platform and the four product agents above</em>. Human-supervised, internal only, and the most proven AI leverage we have today — <strong>live now</strong>. A different class from the four: not a step in the customer journey.
    </div>
  </div>

  {footer(1)}
</div>


<!-- ============== PAGE 2 — Customer-facing agents ============== -->
<div class="page">
  {header("Customer-facing agents · Akane &amp; Misato · Page 2 of 4")}
  <div class="cast-stack">
    {AKANE}
    {MISATO}
  </div>
  {footer(2)}
</div>


<!-- ============== PAGE 3 — Behind-the-scenes agents ============== -->
<div class="page">
  {header("Behind-the-scenes agents · Rie &amp; Yumi · Page 3 of 4")}
  <div class="cast-stack">
    {RIE}
    {YUMI}
  </div>
  {footer(3)}
</div>


<!-- ============== PAGE 4 — Motoko + journey ============== -->
<div class="page">
  {header("The master agent &amp; the journey it powers · Page 4 of 4")}
  <div class="cast-stack" style="flex: none; margin-bottom: 6mm;">
    {MOTOKO}
  </div>

  <div class="journey">
    <h3>How a customer journey moves between them — clean handoffs, no overlap</h3>
    <div class="journey-flow">
      <div class="flow-step">
        <div class="label">1 · Arrives &amp; explores</div>
        <span class="agent akane">Akane</span><br/>
        Public-site chat: "What's an EPM?" "Am I eligible?" — and structured intake when they want a general recommendation.
      </div>
      <div class="flow-arrow">→</div>
      <div class="flow-step">
        <div class="label">2 · Adviser handoff</div>
        <span class="agent human">Human adviser</span><br/>
        Akane hands across full transcript &amp; recommendation. Adviser provides personal advice, confirms &amp; issues.
      </div>
      <div class="flow-arrow">→</div>
      <div class="flow-step">
        <div class="label">3 · Processing</div>
        <span class="agent rie">Rie</span><br/>
        Internal: documents, settlement, business operations.
      </div>
      <div class="flow-arrow">→</div>
      <div class="flow-step">
        <div class="label">4 · Account opened</div>
        <span class="agent yumi">Yumi</span><br/>
        Investment account set up &amp; running.
      </div>
      <div class="flow-arrow">→</div>
      <div class="flow-step">
        <div class="label">5 · Active life</div>
        <span class="agent misato">Misato</span> + <span class="agent yumi">Yumi</span><br/>
        Misato talks to the customer; Yumi runs the account behind her.
      </div>
      <div class="flow-arrow">→</div>
      <div class="flow-step">
        <div class="label">6 · End-of-life</div>
        <span class="agent yumi">Yumi</span><br/>
        Final settlement, residual to estate, account closure.
      </div>
    </div>
    <div class="journey-note">
      <strong>Motoko</strong> sits behind every step — it builds and runs the platform this whole journey lives on. It is not a step in the journey itself.
    </div>
  </div>

  {footer(4)}
</div>

</body>
</html>
'''


def main():
    html = build_html()
    TMP_HTML.write_text(html)

    print(f"Composed AI Cast → {TMP_HTML}")
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
