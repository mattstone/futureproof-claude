#!/usr/bin/env python3
"""
Build the FutureProof AI Agent Plan management briefing (16:9 deck).

Grounded rewrite (May 2026): concrete, measurable, declarative ("telling, not
asking"). Real Stage-1 deliverables, numeric gates, the build-vs-buy
(Mac Studio vs outsource) analysis, the data/legal position, and honest
"real now vs option later". Five agents: Akane / Misato / Rie / Yumi (product) +
Motoko (master engineering & ops).

Output: docs/ai_strategy/FutureProof_AI_Strategy_Mgmt.pdf
Run:    python3 docs/ai_strategy/build_deck.py
"""

from __future__ import annotations
import base64
import subprocess
from pathlib import Path
from datetime import date

ROOT = Path(__file__).resolve().parents[2]
AI_DIR = ROOT / "docs" / "ai_strategy"
OUT_PDF = AI_DIR / "FutureProof_AI_Strategy_Mgmt.pdf"
LOGO_PATH = ROOT / "app" / "assets" / "images" / "futureproof-logo.png"
CSS_PATH = ROOT / "docs" / "capital_raise" / "pdf_build" / "deck_style.css"
TMP_HTML = AI_DIR / "_tmp_deck.html"

CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"


def encode_logo() -> str:
    if not LOGO_PATH.exists():
        return ""
    return f"data:image/png;base64,{base64.b64encode(LOGO_PATH.read_bytes()).decode('ascii')}"


LOGO_URI = encode_logo()
DATE_STR = date.today().strftime("%B %Y")


def badge(text: str, color: str) -> str:
    return (f'<span style="background:{color};color:#fff;padding:1.5pt 7pt;border-radius:3pt;'
            f'font-size:8.5pt;font-weight:600;white-space:nowrap;">{text}</span>')


B_LIVE = "#2EBFA5"; B_FIRST = "#1E88E5"; B_LATER = "#6B7280"; B_INTERNAL = "#7C5CBF"


def slide_furniture(slide_num: int, total: int) -> str:
    return f'''
  <div class="confidential-stamp">Internal — AI Agent Plan</div>
  <div class="slide-footer">
    <div class="wordmark-mini"><span class="future">future</span><span class="proof">proof</span></div>
    <div class="copyright">©2026 Futureproof Financial Group Limited · Internal</div>
    <div class="pagenum">{slide_num} / {total}</div>
  </div>
'''


# ---------------------------------------------------------------------------
# Slides
# ---------------------------------------------------------------------------

def slide_cover(num: int, total: int) -> str:
    logo_block = (f'<img src="{LOGO_URI}" alt="FutureProof" style="max-height: 80px; margin-bottom: 28pt;">'
                  if LOGO_URI else
                  '<div class="wordmark" style="font-size: 48pt; margin-bottom: 28pt;"><span class="future">future</span><span class="proof">proof</span></div>')
    return f'''
<div class="slide cover bg-gradient">
  <div class="confidential-stamp">Internal — AI Agent Plan</div>
  <div style="margin-top: 0.4in;">
    {logo_block}
    <div class="tagline">AI Agent Plan</div>
    <div class="subtitle">What we're building, how we'll measure it, and what it costs</div>
    <div class="meta-row">
      <div><span class="label">Audience</span><span class="value">Management</span></div>
      <div><span class="label">Presented by</span><span class="value">Matt Stone, CTO</span></div>
      <div><span class="label">Status</span><span class="value">Plan</span></div>
      <div><span class="label">Date</span><span class="value">{DATE_STR}</span></div>
    </div>
  </div>
  {slide_furniture(num, total)}
</div>
'''


def slide_plan_in_one(num: int, total: int) -> str:
    return f'''
<div class="slide bg-dots">
  <div class="kicker">The plan, in one slide</div>
  <div class="headline">We are building AI agents on our existing model — <span class="accent">staged, gated, and measurable.</span></div>
  <div class="body" style="margin-top: 14pt;">
    <ul style="font-size: 12.5pt; line-height: 1.6;">
      <li><strong>Five agents</strong> — four across the customer lifecycle, plus a master engineering agent (Motoko) that builds and runs the platform and is <strong>already delivering today</strong>.</li>
      <li><strong>Stage 1 first</strong> — the customer-acquisition chat (Akane), an API so other AIs can call our EPM calculator, and the engineering agent. We commit Stage 1 only; the rest is earned at hard gates.</li>
      <li><strong>Build vs buy</strong> — rent frontier intelligence for the customer-facing surface; own one Mac Studio for sensitive and internal data.</li>
      <li><strong>Why now</strong> — customers increasingly start financial decisions with an AI assistant, and being callable by those assistants is becoming table stakes. We act on that, but commit only to what is provable.</li>
    </ul>
    <div class="pull-quote" style="margin-top: 16pt;">Real deliverables, real costs, real metrics, and a clear build-vs-buy decision — not an ecosystem land-grab we cannot yet evidence.</div>
  </div>
  {slide_furniture(num, total)}
</div>
'''


def slide_agents(num: int, total: int) -> str:
    return f'''
<div class="slide bg-dots">
  <div class="kicker">The agents</div>
  <div class="headline">Five agents: <span class="accent">four run the business, one builds it.</span></div>
  <div class="body" style="margin-top: 10pt;">
    <table class="status-table" style="width:100%; border-collapse:collapse;">
      <tr><td style="width:14%;"><strong>Akane</strong></td><td>Customer acquisition — web chat (EPM FAQs, eligibility), structured intake → compliance gate → handoff to a licensed human adviser.</td><td style="width:16%;">{badge("Build first", B_FIRST)}</td></tr>
      <tr><td><strong>Misato</strong></td><td>Customer communications &amp; service — status, statements and support for active customers.</td><td>{badge("Later stage", B_LATER)}</td></tr>
      <tr><td><strong>Rie</strong></td><td>Back-office &amp; operations — document verification, settlement, reconciliation, internal queries.</td><td>{badge("Partial · internal", B_INTERNAL)}</td></tr>
      <tr><td><strong>Yumi</strong></td><td>Investment account — setup, monitoring, end-of-life settlement.</td><td>{badge("Partial · internal", B_INTERNAL)}</td></tr>
      <tr><td><strong>Motoko</strong></td><td><strong>Engineering &amp; operations — the master agent.</strong> Builds and runs the platform and the four product agents above. Human-supervised.</td><td>{badge("Live today", B_LIVE)}</td></tr>
    </table>
    <div class="footnote" style="margin-top: 10pt;">Codenames are internal only — customers always see "the FutureProof assistant". Motoko is a different class from the four product agents: it builds and operates them, and is not part of the customer journey.</div>
  </div>
  {slide_furniture(num, total)}
</div>
'''


def slide_where_we_are(num: int, total: int) -> str:
    return f'''
<div class="slide bg-dots">
  <div class="kicker">Where we are today</div>
  <div class="headline">Honestly: <span class="accent">one agent live, two partial, two to build.</span></div>
  <div class="body" style="margin-top: 12pt;">
    <div class="cols-2">
      <div>
        <div style="font-weight:700;color:var(--navy);margin-bottom:6pt;">Working today</div>
        <ul style="font-size:11.5pt;line-height:1.55;">
          <li>The EPM calculation engine and actuarial model</li>
          <li>Chat infrastructure in the app (channels, message store)</li>
          <li><strong>Motoko</strong> — the engineering/ops agent is already delivering on this codebase</li>
        </ul>
      </div>
      <div>
        <div style="font-weight:700;color:var(--navy);margin-bottom:6pt;">Partial / internal &amp; not yet built</div>
        <ul style="font-size:11.5pt;line-height:1.55;">
          <li><strong>Rie</strong> and <strong>Yumi</strong> — internal tooling exists, not productionised</li>
          <li><strong>Akane</strong> (customer chat) — to build (Stage 1)</li>
          <li><strong>Misato</strong> (customer comms) — later stage</li>
          <li>The agent-to-agent API (EPM schema) — to build (Stage 1)</li>
        </ul>
      </div>
    </div>
    <div class="footnote" style="margin-top: 8pt;">No vapourware: the slide above is the real state of the codebase, not a roadmap of intentions.</div>
  </div>
  {slide_furniture(num, total)}
</div>
'''


def slide_stage1_build(num: int, total: int) -> str:
    return f'''
<div class="slide bg-dots">
  <div class="kicker">Stage 1 — what we build</div>
  <div class="headline">Three concrete deliverables, on what we already have.</div>
  <div class="body" style="margin-top: 12pt;">
    <div class="quad-grid">
      <div class="quad-cell"><strong>1 · Akane Layer 1 — customer chat</strong><br/>Web chat on the existing calculation engine: EPM FAQs, eligibility, and a structured intake → compliance gate → handoff to a licensed human adviser. Runs on a frontier model in an AU region, identifiers minimised.</div>
      <div class="quad-cell"><strong>2 · The EPM API (Layer 2)</strong><br/>Publish an MCP + OpenAPI spec for the EPM calculator so other AI assistants can find and call it. Modest, concrete, and the foundation for any future ecosystem position.</div>
      <div class="quad-cell"><strong>3 · The engineering agent (Motoko)</strong><br/>Continue and formalise the engineering/ops agent already delivering — the most proven, measurable AI leverage we have today.</div>
      <div class="quad-cell" style="background:var(--blue-light, #E8F0FB);"><strong>Not in Stage 1</strong><br/>Misato (customer comms), the L3 ecosystem partnerships, and any autonomous production changes. These come later, behind gates — or are treated as options to earn.</div>
    </div>
  </div>
  {slide_furniture(num, total)}
</div>
'''


def slide_gates(num: int, total: int) -> str:
    return f'''
<div class="slide bg-dots">
  <div class="kicker">How we'll know it worked</div>
  <div class="headline">Stage 2 proceeds <span class="accent">only if all of these hold</span> — otherwise we de-scope or kill.</div>
  <div class="body" style="margin-top: 12pt;">
    <div class="quad-grid">
      <div class="quad-cell"><strong>≥ 40%</strong> intake completion (of engaged visitors)</div>
      <div class="quad-cell"><strong>≥ 4/5</strong> adviser-rated handoff quality</div>
      <div class="quad-cell">cost per qualified lead <strong>&lt; current channel</strong></div>
      <div class="quad-cell"><strong>&lt; 5s</strong> p50 customer response time</div>
      <div class="quad-cell"><strong>zero</strong> compliance breaches in pilot</div>
      <div class="quad-cell">engineering cycle-time <strong>down ≥ 25%</strong></div>
    </div>
    <div class="footnote" style="margin-top: 10pt;">These are the Stage-1 targets; exact thresholds are calibrated against current-channel baselines before the pilot. Every gate has a kill criterion as well as a go criterion.</div>
  </div>
  {slide_furniture(num, total)}
</div>
'''


def slide_infra_compare(num: int, total: int) -> str:
    return f'''
<div class="slide bg-dots">
  <div class="kicker">Infrastructure — build vs buy</div>
  <div class="headline">Outsource frontier intelligence, or run large models ourselves?</div>
  <div class="body" style="margin-top: 10pt;">
    <div class="cols-2">
      <div>
        <div style="font-weight:700;color:var(--navy);margin-bottom:5pt;">Outsource — frontier API (Claude / GPT / Gemini)</div>
        <ul style="font-size:10.5pt;line-height:1.5;">
          <li><strong>Quality/safety:</strong> frontier-class — best for a customer advice-adjacent surface</li>
          <li><strong>Cost:</strong> ~$0.30–1.50 per conversation → ~$1–2k/mo at launch volume</li>
          <li><strong>Latency:</strong> 3–6s responses</li>
          <li><strong>Data:</strong> leaves the building — mitigable (AU region, zero-retention, identifier-minimisation)</li>
          <li><strong>Ops:</strong> none; live in weeks</li>
        </ul>
      </div>
      <div>
        <div style="font-weight:700;color:var(--navy);margin-bottom:5pt;">Own — Mac Studio + open model</div>
        <ul style="font-size:10.5pt;line-height:1.5;">
          <li><strong>Hardware:</strong> 96GB (~A$8k) runs 70B-class; 512GB (~A$15k) only for the largest open models</li>
          <li><strong>Quality:</strong> below the latest frontier for hard reasoning &amp; guardrails</li>
          <li><strong>Latency:</strong> ~15–20s for a full reply; a handful of concurrent sessions per machine</li>
          <li><strong>Data:</strong> never leaves the building — strongest compliance story</li>
          <li><strong>Ops:</strong> we run the stack, uptime, updates</li>
        </ul>
      </div>
    </div>
  </div>
  {slide_furniture(num, total)}
</div>
'''


def slide_infra_decision(num: int, total: int) -> str:
    return f'''
<div class="slide bg-dots">
  <div class="kicker">Infrastructure — the decision</div>
  <div class="headline">Rent intelligence, <span class="accent">own the sensitive tier.</span></div>
  <div class="body" style="margin-top: 12pt;">
    <div class="cols-2">
      <div class="quad-cell"><strong>Customer-facing → frontier API</strong><br/>AU region, zero-retention / no-training, identifiers minimised before the call. Best quality and safety; ~$1–2k/mo at launch — far cheaper than self-hosting at this stage.</div>
      <div class="quad-cell" style="border-left:4pt solid var(--navy);"><strong>Sensitive / internal → one Mac Studio</strong><br/>A local 70B-class model for raw-PII workloads, internal documents, batch and fine-tuning. Data never leaves the building; doubles as the dev box and a compliance hedge.</div>
    </div>
    <div style="margin-top: 12pt; font-size: 11pt; line-height: 1.5;">
      <strong>Crossover (defined, not religion):</strong> revisit local-for-customer-facing only if sustained API spend exceeds <strong>~$8–10k/month</strong> (≈ tens of thousands of conversations/month) <strong>and</strong> an open model passes our evaluation bar. Reviewed quarterly.
    </div>
  </div>
  {slide_furniture(num, total)}
</div>
'''


def slide_data_legal(num: int, total: int) -> str:
    return f'''
<div class="slide bg-dots">
  <div class="kicker">Data &amp; legal position</div>
  <div class="headline">A data-classification policy — not "trust the vendor".</div>
  <div class="body" style="margin-top: 12pt;">
    <ul style="font-size: 11.5pt; line-height: 1.6;">
      <li><strong>Accountability stays with us.</strong> Under Privacy Act APP 8 we remain responsible for any offshore handling — sending data to a third party does not offload liability.</li>
      <li><strong>Defensible default:</strong> AU-region processing + enterprise zero-retention / no-training terms + <strong>identifier-minimisation before the call</strong>.</li>
      <li><strong>Strictest classes stay in-house</strong> — raw PII and sensitive financial records route to the local Mac Studio. A classification policy decides what goes where.</li>
      <li><strong>Advice stays compliant</strong> — the human-adviser gate means the agent never issues personal advice on its own.</li>
      <li><strong>Sign-off before go-live</strong> — privacy counsel, and APRA CPS 230 (material service provider) checks if applicable.</li>
    </ul>
    <div class="footnote" style="margin-top: 8pt;">Landscape, not legal advice — the specific obligations (APP 8 / s16C, ACL/AFSL, CPS 230, the 2024 Privacy reforms on automated decisions) are confirmed with counsel.</div>
  </div>
  {slide_furniture(num, total)}
</div>
'''


def slide_stage_plan(num: int, total: int) -> str:
    return f'''
<div class="slide bg-dots">
  <div class="kicker">The stage plan</div>
  <div class="headline">We commit Stage 1; <span class="accent">the rest is earned.</span></div>
  <div class="body" style="margin-top: 10pt;">
    <table class="status-table" style="width:100%; border-collapse:collapse;">
      <tr><td style="width:18%;"><strong>Stage 1</strong><br/><span style="color:var(--gray-500);">Months 0–6 · committed</span></td><td>Akane Layer 1 + the EPM API (Layer 2) + the engineering agent. <br/><em>Gate → Stage 2:</em> the Stage-1 metrics hold (intake, handoff quality, cost/lead, latency, compliance, eng cycle-time).</td></tr>
      <tr><td><strong>Stage 2</strong><br/><span style="color:var(--gray-500);">Months 6–12</span></td><td>Akane to general availability; Misato (customer comms); first partner conversations. <br/><em>Gate → Stage 3:</em> signed partner LOIs + agent-attributed conversion tracking to plan. <em>De-scope</em> to Akane-only if partner appetite is weak.</td></tr>
      <tr><td><strong>Stage 3</strong><br/><span style="color:var(--gray-500);">Year 2–3</span></td><td>Scale (UK/US) and pursue the ecosystem position (an option, not a promise). <em>Continue only</em> on material agent-attributed acquisition.</td></tr>
    </table>
    <div class="footnote" style="margin-top: 10pt;">Quarterly AI-landscape review. Programme commitment grows only as evidence supports it.</div>
  </div>
  {slide_furniture(num, total)}
</div>
'''


def slide_costs(num: int, total: int) -> str:
    return f'''
<div class="slide bg-dots">
  <div class="kicker">What it costs</div>
  <div class="headline">Modest to start; <span class="accent">it scales only as gates pass.</span></div>
  <div class="body" style="margin-top: 14pt;">
    <div class="big-number-row">
      <div class="big-number"><div class="num">~1</div><div class="label">engineer-quarter<br/>(Stage 1 build)</div></div>
      <div class="big-number"><div class="num">~$1–2k</div><div class="label">per month<br/>(frontier API, launch)</div></div>
      <div class="big-number"><div class="num">~A$8k</div><div class="label">one-off<br/>(one Mac Studio, 96GB)</div></div>
    </div>
    <div style="margin-top: 12pt; font-size: 11.5pt; line-height: 1.55;">
      Stage 1 is fundable within the current round. Stages 2–3 are re-costed and re-approved at each gate; we do not pre-commit budget beyond the next stage. Detailed costings sit in the build plan.
    </div>
  </div>
  {slide_furniture(num, total)}
</div>
'''


def slide_risks(num: int, total: int) -> str:
    return f'''
<div class="slide bg-dots">
  <div class="kicker">Risks — and how we contain them</div>
  <div class="headline">Each risk has a concrete mitigation already in the plan.</div>
  <div class="body" style="margin-top: 12pt;">
    <div class="quad-grid">
      <div class="quad-cell"><strong>AI quality / safety on the customer surface</strong><br/>Frontier model + bounded scope + the human-adviser gate before any advice. Pilot before GA.</div>
      <div class="quad-cell"><strong>Data &amp; compliance</strong><br/>Classification policy: AU-region/enterprise terms for de-identified; in-house for sensitive. Counsel + CPS 230 sign-off.</div>
      <div class="quad-cell"><strong>Vendor / dependency</strong><br/>The local Mac Studio is a working hedge; the architecture stays portable across model providers.</div>
      <div class="quad-cell"><strong>Over-investment</strong><br/>Stage gates with explicit kill criteria; commitment never runs ahead of evidence.</div>
    </div>
  </div>
  {slide_furniture(num, total)}
</div>
'''


def slide_real_vs_option(num: int, total: int) -> str:
    return f'''
<div class="slide bg-dots">
  <div class="kicker">The honest cut</div>
  <div class="headline">What's real now — <span class="accent">and what's an option to earn.</span></div>
  <div class="body" style="margin-top: 12pt;">
    <div class="cols-2">
      <div>
        <div style="font-weight:700;color:var(--navy);margin-bottom:6pt;">Real now — shipping value</div>
        <ul style="font-size:11.5pt;line-height:1.55;">
          <li>The engineering/ops agent (Motoko) — delivering today</li>
          <li>Akane Layer 1 — the Stage-1 build, on infrastructure we control</li>
          <li>The EPM API — a concrete, modest deliverable</li>
        </ul>
      </div>
      <div>
        <div style="font-weight:700;color:var(--navy);margin-bottom:6pt;">An option to earn — not a moat we claim</div>
        <ul style="font-size:11.5pt;line-height:1.55;">
          <li>Adoption of the EPM schema by other AI assistants</li>
          <li>Partnerships with adviser AI and super / pension-fund AI</li>
          <li>We pursue this and track it — we do not pitch it as a moat we already hold</li>
        </ul>
      </div>
    </div>
  </div>
  {slide_furniture(num, total)}
</div>
'''


def slide_what_we_are_doing(num: int, total: int) -> str:
    return f'''
<div class="slide bg-gradient">
  <div class="kicker">What we're doing</div>
  <div class="headline">This is the plan we're executing.</div>
  <div class="body" style="margin-top: 14pt;">
    <ul style="font-size: 13pt; line-height: 1.7;">
      <li><strong>Building Stage 1</strong> — Akane Layer 1, the EPM API, and the engineering agent — time-boxed and gated on the metrics shown.</li>
      <li><strong>Adopting the hybrid infrastructure</strong> — frontier API for customer-facing, one Mac Studio for the sensitive/internal tier — with a data-classification policy and counsel sign-off.</li>
      <li><strong>Buying one Mac Studio</strong> (~A$8k, 96GB) for the sensitive-internal tier and development.</li>
      <li><strong>Treating the ecosystem position as an option</strong> — pursued and tracked quarterly, not claimed as a moat.</li>
    </ul>
    <div class="pull-quote" style="margin-top: 18pt;">Commit to what's provable now; earn the rest.</div>
  </div>
  {slide_furniture(num, total)}
</div>
'''


def main():
    slide_fns = [
        slide_cover,
        slide_plan_in_one,
        slide_agents,
        slide_where_we_are,
        slide_stage1_build,
        slide_gates,
        slide_infra_compare,
        slide_infra_decision,
        slide_data_legal,
        slide_stage_plan,
        slide_costs,
        slide_risks,
        slide_real_vs_option,
        slide_what_we_are_doing,
    ]
    total = len(slide_fns)
    css = CSS_PATH.read_text()
    slides_html = "\n".join(fn(i + 1, total) for i, fn in enumerate(slide_fns))

    html = f'''<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>FutureProof — AI Agent Plan (Management Briefing)</title>
<style>{css}</style>
</head>
<body>
{slides_html}
</body>
</html>
'''
    TMP_HTML.write_text(html)
    print(f"Composed {total} slides → {TMP_HTML}")
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
    print(f"OK {OUT_PDF.name} — {size_kb:.0f} KB ({total} slides)")
    TMP_HTML.unlink(missing_ok=True)


if __name__ == "__main__":
    main()
