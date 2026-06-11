#!/usr/bin/env python3
"""
Build the FutureProof investor deck — 16:9 widescreen PDF, briefing-deck style.

Each slide is hand-composed in Python (full layout control). Source content
traced to deck_outline.md. Output: docs/capital_raise/pdfs/FutureProof_Deck.pdf

Run:
    python3 docs/capital_raise/pdf_build/build_deck.py
"""

from __future__ import annotations
import base64
import subprocess
from pathlib import Path
from datetime import date

ROOT = Path(__file__).resolve().parents[3]
CR_DIR = ROOT / "docs" / "capital_raise"
BUILD_DIR = CR_DIR / "pdf_build"
OUT_PDF = CR_DIR / "pdfs" / "FutureProof_Deck.pdf"
LOGO_PATH = ROOT / "app" / "assets" / "images" / "futureproof-logo.png"
CSS_PATH = BUILD_DIR / "deck_style.css"
TMP_HTML = BUILD_DIR / "_tmp_deck.html"

CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"


def encode_logo() -> str:
    if not LOGO_PATH.exists():
        return ""
    return f"data:image/png;base64,{base64.b64encode(LOGO_PATH.read_bytes()).decode('ascii')}"


LOGO_URI = encode_logo()
DATE_STR = date.today().strftime("%B %Y")


def slide_furniture(slide_num: int, total: int, footer_text: str = "") -> str:
    """Returns the standard slide footer (logo + page num + copyright)."""
    return f'''
  <div class="confidential-stamp">Commercial-in-Confidence — Restricted Circulation</div>
  <div class="slide-footer">
    <div class="wordmark-mini"><span class="future">future</span><span class="proof">proof</span></div>
    <div class="copyright">©2026 Futureproof Financial Group Limited · All Rights Reserved</div>
    <div class="pagenum">{slide_num} / {total}</div>
  </div>
'''


# ---------------------------------------------------------------------------
# Slide builders
# ---------------------------------------------------------------------------

def slide_cover(num: int, total: int) -> str:
    # The logo image already contains the full futureproof wordmark — no duplicate text needed
    logo_block = f'<img src="{LOGO_URI}" alt="FutureProof" style="max-height: 80px; margin-bottom: 28pt;">' if LOGO_URI else \
        '<div class="wordmark" style="font-size: 48pt; margin-bottom: 28pt;"><span class="future">future</span><span class="proof">proof</span></div>'
    return f'''
<div class="slide cover bg-gradient">
  <div class="confidential-stamp">Commercial-in-Confidence — Restricted Circulation</div>

  <div style="margin-top: 0.4in;">
    {logo_block}

    <div class="tagline">Building the Next-Generation of Retirement Income &amp; Funding Products for Every Life Stage.</div>
    <div class="subtitle">Unlocking $25T of locked-up retiree home equity. AI-native SaaS platform. AUS → UK → USA.</div>

    <div class="meta-row">
      <div>
        <span class="label">Round</span>
        <span class="value">SAFE</span>
      </div>
      <div>
        <span class="label">Stage</span>
        <span class="value">Pre-Series A</span>
      </div>
      <div>
        <span class="label">Domicile</span>
        <span class="value">AU</span>
      </div>
      <div>
        <span class="label">Date</span>
        <span class="value">{DATE_STR}</span>
      </div>
    </div>
  </div>

  {slide_furniture(num, total)}
</div>
'''


def slide_problem(num: int, total: int) -> str:
    return f'''
<div class="slide bg-dots">
  <div class="kicker">The Problem</div>
  <div class="headline">2.7M Australians + 36M Americans are asset-rich and cash-poor — sitting on <span class="accent">$25T</span> of home equity, served by no fit-for-purpose product in 35 years.</div>

  <div class="body">
    <div class="cols-2" style="margin-top: 18pt;">
      <div class="col">
        <div class="col-title"><span class="flag">🇦🇺</span> Australia</div>
        <ul>
          <li>2.7M over-65s asset-rich, cash-poor</li>
          <li>Median home A$900K · Median super A$200K</li>
          <li><strong>Asset disparity = 4.5×</strong></li>
          <li>Told to "downsize" — most refuse (community, health, identity)</li>
        </ul>
      </div>
      <div class="col">
        <div class="col-title"><span class="flag">🇺🇸</span> USA</div>
        <ul>
          <li>36M retirees under-funded for retirement</li>
          <li>Avg net worth $410K · Housing ≥50% of it</li>
          <li><strong>65% of US retirees forced into equity-eroding mortgage products</strong></li>
          <li>$200K–300K avg home equity locked per US retiree</li>
        </ul>
      </div>
    </div>

    <div class="pull-quote" style="margin-top: 14pt;">The same problem on two continents — and a $25T asset class waiting to be unlocked.</div>
  </div>

  {slide_furniture(num, total)}
</div>
'''


def slide_why_now(num: int, total: int) -> str:
    return f'''
<div class="slide bg-dots">
  <div class="kicker">Why Now</div>
  <div class="headline">The Retirement Income Covenant just made this Australia's most important regulated tailwind.</div>

  <div class="body">
    <ul style="margin-top: 14pt;">
      <li><strong>2022:</strong> Every super fund <strong>legally required</strong> to have a retirement income strategy</li>
      <li><strong>2020 Callaghan Review:</strong> explicitly endorsed home equity release as a retirement tool</li>
      <li><strong>A$3.5T</strong> in super now needs retirement-phase infrastructure</li>
      <li>1 in 4 Australians over 65 by 2050</li>
      <li><strong>4 years post-Covenant, most super funds still lack a credible solution.</strong> That is our window.</li>
    </ul>

    <div class="timeline" style="margin-top: 24pt;">
      <div class="timeline-step">
        <div class="timeline-dot"></div>
        <div class="timeline-year">2020</div>
        <div class="timeline-label">Callaghan Review</div>
      </div>
      <div class="timeline-step">
        <div class="timeline-dot"></div>
        <div class="timeline-year">2022</div>
        <div class="timeline-label">RIC enacted</div>
      </div>
      <div class="timeline-step">
        <div class="timeline-dot"></div>
        <div class="timeline-year">2026</div>
        <div class="timeline-label">FutureProof launches AU</div>
      </div>
      <div class="timeline-step">
        <div class="timeline-dot"></div>
        <div class="timeline-year">2030</div>
        <div class="timeline-label">Demographic peak</div>
      </div>
    </div>
  </div>

  {slide_furniture(num, total)}
</div>
'''


def slide_solution(num: int, total: int) -> str:
    return f'''
<div class="slide bg-dots">
  <div class="kicker">The Solution</div>
  <div class="headline">The Equity Preservation Mortgage<sup style="font-size:60%;">®</sup> — a <span class="accent">breakthrough fit-for-purpose</span> retirement mortgage, embedded in an AI-native SaaS platform.</div>
  <div class="subheadline">We are not a lender. We are the platform that turns home equity into guaranteed retirement income — and licenses banks, insurers, and non-bank lenders to issue the product.</div>

  <div class="body">
    <ul>
      <li>Retiree pledges home equity at up to 80% LTV — <strong>no monthly repayments, no compound interest, no estate erosion</strong></li>
      <li>Capital invested in a structured portfolio (~70% equity ETFs / ~30% fixed income), hedged with an asymmetric collar (cap +40% / floor -20%) per v14d Optimised</li>
      <li>Tax-free annuity income to the retiree of <strong>1.50% of home value p.a.</strong> (10-year term) → <strong>1.05%</strong> (30-year term); <strong>10% FP profit share</strong> at 3-yearly resets; 50/50 split at 30-year maturity</li>
    </ul>
  </div>

  <div class="footnote">Per Futureproof's proprietary EPM model parameters.</div>
  {slide_furniture(num, total)}
</div>
'''


def slide_vs_reverse(num: int, total: int) -> str:
    return f'''
<div class="slide bg-dots">
  <div class="kicker">Why Better Than Reverse Mortgages</div>
  <div class="headline">Reverse mortgages eat the estate. <span class="accent">EPM preserves it.</span></div>

  <div class="body">
    <table style="margin-top: 8pt;">
      <thead>
        <tr><th></th><th>Traditional reverse mortgage</th><th>EPM</th></tr>
      </thead>
      <tbody>
        <tr><td><strong>Interest accrual</strong></td><td>Compounds against the estate</td><td>None — no debt</td></tr>
        <tr><td><strong>Payment to homeowner</strong></td><td>Lump sum or drawdown</td><td>Lifetime guaranteed income</td></tr>
        <tr><td><strong>End of term</strong></td><td>Estate often consumed</td><td>Surplus split with homeowner</td></tr>
        <tr><td><strong>Funder economics</strong></td><td>Interest spread</td><td><strong>Mortgage income with equity-style returns</strong></td></tr>
        <tr><td><strong>Alignment</strong></td><td>Misaligned (longer = better for funder)</td><td>Aligned (better outcome = better for both)</td></tr>
      </tbody>
    </table>

    <div class="pull-quote" style="margin-top: 10pt;">Reverse mortgages address ~5% of the addressable retiree population. EPM is structured for the other 95% — the people who say no to reverse mortgages on principle.</div>
  </div>

  <div class="footnote">Mean per-mortgage surplus at year-30: <strong>$1.17M (mean) / $4.10M (99%-ile)</strong>. Source: 50,000-path Monte Carlo (Futureproof's proprietary financial model, v14d Optimised parameters).</div>
  {slide_furniture(num, total)}
</div>
'''


def slide_validation(num: int, total: int) -> str:
    return f'''
<div class="slide bg-dots">
  <div class="kicker">Model Validation</div>
  <div class="headline">Validated against 50,000-path Monte Carlo. Hard constraints C1–C6 satisfied across all sequences.</div>

  <div class="body">
    <div class="big-number-row" style="margin-top: 14pt;">
      <div class="big-number">
        <div class="num">0.03</div>
        <div class="label"><strong>PoC year-30</strong> — Portfolio Probability of Capital shortfall after Payments Waterfall (the headline risk metric)</div>
      </div>
      <div class="big-number">
        <div class="num navy">7.7%</div>
        <div class="label"><strong>Per-mortgage PoD year-30</strong> — under v14d Optimised parameters (asymmetric collar + multi-scenario fine-grid optimisation)</div>
      </div>
    </div>

    <ul style="margin-top: 14pt;">
      <li><strong>Run-off mechanism eliminates prepayment risk</strong> to funders (no liquidity stress)</li>
      <li>Stress-tested against 1929, 1973, 2008 historical sequences and forward GBM stochastic scenarios</li>
    </ul>
  </div>

  <div class="footnote">Source: Futureproof's proprietary financial model. 50,000-path GBM (mean ~9.4%, vol ~17.5%) with Ornstein-Uhlenbeck cash rate (long-run 2.13%, κ 0.24, σ 1.22%), asymmetric hedge collar (cap +40% / floor -20%), 30-year horizon.</div>
  {slide_furniture(num, total)}
</div>
'''


def slide_market_size(num: int, total: int) -> str:
    return f'''
<div class="slide bg-dots">
  <div class="kicker">Market Sizing</div>
  <div class="headline">Homeowners of any age with unencumbered residential property.</div>

  <div class="body">
    <div style="display:grid; grid-template-columns: 1.2fr 1fr; gap: 30pt; margin-top: 18pt; align-items: center;">
      <div>
        <div class="big-number" style="margin-bottom: 18pt;">
          <div class="num">$25T</div>
          <div class="label"><strong>TAM:</strong> Home equity in target markets (USA, UK, Australia). Growing 4% YoY.</div>
        </div>
        <div class="big-number" style="margin-bottom: 18pt;">
          <div class="num navy">$55B</div>
          <div class="label"><strong>SAM:</strong> Futureproof's potential market revenues estimated.</div>
        </div>
        <div class="big-number">
          <div class="num" style="color: var(--teal);">$20B</div>
          <div class="label"><strong>SOM:</strong> Current reverse mortgage market.</div>
        </div>
      </div>

      <div class="market-circles">
        <div class="market-circle market-tam">TAM</div>
        <div class="market-circle market-sam">SAM</div>
        <div class="market-circle market-som">SOM</div>
      </div>
    </div>
  </div>

  {slide_furniture(num, total)}
</div>
'''


def slide_distribution(num: int, total: int) -> str:
    return f'''
<div class="slide bg-dots">
  <div class="kicker">Distribution</div>
  <div class="headline">B2B distribution: we license banks, insurers, and non-bank lenders as Product Issuers.</div>

  <div class="body">
    <div class="cols-2" style="margin-top: 14pt;">
      <div class="col">
        <div class="col-title">Partner Channels (via Accenture)</div>
        <div style="font-size: 11pt; color: var(--gray-700);">Top-tier financial-institution clients in the Accenture ecosystem.</div>
        <div style="font-size: 10.5pt; color: var(--gray-700); margin-top: 8pt; line-height: 1.5;">
          Macquarie Bank · AMP Bank · Westpac · Barclays · Nationwide Building Society · Lloyds · SCB Bank (Thailand) · HSBC Private Wealth · Suncorp Insurance
        </div>
      </div>
      <div class="col">
        <div class="col-title">FutureProof Direct</div>
        <div style="font-size: 11pt; color: var(--gray-700);">Mid-tier institutions and lenders outside the Accenture ecosystem.</div>
        <div style="font-size: 10.5pt; color: var(--gray-700); margin-top: 8pt; line-height: 1.5;">
          Resimac · PepperMoney · Heartland Bank · US Bank · Allianz Life · Aegon · Aviva · AIA Insurance · Butterfield Private Bank · Hong Kong Mortgage Corp · FWD Insurance
        </div>
      </div>
    </div>

    <div class="pull-quote" style="margin-top: 18pt;">"Mortgage income with equity-style returns" — what we offer the wholesale capital that funds the EPM book. Long-duration, insured, securitisable, with profit-share upside from S&amp;P appreciation.</div>
  </div>

  {slide_furniture(num, total)}
</div>
'''


def slide_ai_native(num: int, total: int) -> str:
    return f'''
<div class="slide bg-dots">
  <div class="kicker">AI-Native Operating Model</div>
  <div class="headline">38 FTE running a multi-region, multi-billion AUM platform — by Year 5.</div>
  <div class="subheadline">Leaning hard into AI to drive operating cost down without compromising customer service.</div>

  <div class="body">
    <table class="status-table" style="margin-top: 6pt;">
      <thead>
        <tr>
          <th class="live" style="width:25%;">✅ Working prototype</th>
          <th class="built" style="width:25%;">✅ Infrastructure built</th>
          <th class="road" style="width:30%;">🟡 Roadmap (next 12 months)</th>
          <th class="never" style="width:20%;">❌ Never (regulated)</th>
        </tr>
      </thead>
      <tbody>
        <tr>
          <td>Customer-facing chat agent ("Akane") — Claude, 4 regions, proprietary-content guardrails</td>
          <td>AI agent orchestration framework — tool use + prompt caching</td>
          <td>Application triage (LLM-augmenting current rule-based service)</td>
          <td>Underwrite credit decisions</td>
        </tr>
        <tr>
          <td>Knowledge-grounded responses, escalation triggers, abuse detection</td>
          <td>Agent task tracking, performance metrics, lifecycle management</td>
          <td>Internal ops admin agents (review packs, exceptions)</td>
          <td>Replace compliance sign-off</td>
        </tr>
        <tr>
          <td>Region-aware content for AU/US/NZ/UK</td>
          <td>3 agent types: applications, backoffice, investment</td>
          <td>Multi-region marketing content; CS triage at scale; Investment-ops workflow</td>
          <td>Generate investment alpha; shorten regulatory licensing</td>
        </tr>
      </tbody>
    </table>

    <div class="big-number-row" style="margin-top: 14pt;">
      <div class="big-number">
        <div class="num">~14 bps</div>
        <div class="label"><strong>Opex per AUM at Y3 (Likely).</strong> Y5: ~7 bps.</div>
      </div>
      <div class="big-number">
        <div class="num navy">50–80 bps</div>
        <div class="label"><strong>Comparable specialty insurer.</strong> AI-ops layer absorbs ~250 FTE-equivalents at Y3.</div>
      </div>
    </div>
  </div>

  {slide_furniture(num, total)}
</div>
'''


def slide_traction(num: int, total: int) -> str:
    return f'''
<div class="slide bg-dots">
  <div class="kicker">Traction</div>
  <div class="headline">Building a global ecosystem of top-tier institutional partners.</div>

  <div class="body">
    <ul style="margin-top: 8pt;">
      <li><strong>Accenture</strong> — US Global Collaboration Partner &amp; Approved Business Intermediary</li>
      <li><strong>Jones Day</strong> — US Global Legal Partner</li>
      <li><strong>Product co-design</strong>: BlackRock · SpiderRock · Atlas SP / Apollo · Lockton · PWC</li>
      <li><strong>Regulatory partners</strong> (non-US): EY · Colin Biggers &amp; Paisley · Dentons</li>
      <li><strong>In active negotiation</strong>: Lockton Reinsurance · Gallagher Re · PIMCO (US); Munich Re · Macquarie · Asia Insurance Co (non-US)</li>
      <li><strong>Product</strong>: Multi-region calculation engine live (AU, NZ, UK, US); Annuity &amp; Mortgage Calculator in <strong>alpha release</strong>; 382 integration tests passing</li>
      <li><strong>AI</strong>: Customer-facing AI agent ("Akane") working prototype with proprietary-content guardrails (multi-region)</li>
      <li><strong>Recognition</strong>: Silicon Valley Fintech Accelerator (FinAccelerate, powered by Jones Day) — 2023 cohort</li>
      <li><strong>Market launch</strong>: AUS Q4/2026 → UK Q2/2027 → USA Q4/2027</li>
    </ul>
  </div>

  {slide_furniture(num, total)}
</div>
'''


def slide_business_model(num: int, total: int) -> str:
    return f'''
<div class="slide bg-dots">
  <div class="kicker">Business Model</div>
  <div class="headline">Five revenue streams. Software-margin economics on a regulated-finance asset base.</div>

  <div class="body">
    <table style="margin-top: 6pt; font-size: 10.5pt;">
      <thead>
        <tr><th style="width:36%;">Revenue stream</th><th>Source</th><th style="width:11%;">Y3 (USD)</th><th style="width:11%;">Y5 (USD)</th></tr>
      </thead>
      <tbody>
        <tr><td><strong>1. Onboarding tech fee</strong></td><td>$1.5M per licensee, one-off</td><td>~$4.5M</td><td>~$6M</td></tr>
        <tr><td><strong>2. SaaS recurring (FP margin)</strong></td><td>50 bps × cumulative book</td><td>~$115M</td><td>~$455M</td></tr>
        <tr><td><strong>3. Profit share at 3-yr resets</strong></td><td>10% of running surplus</td><td>$0 <em>(first reset Y4)</em></td><td>~$170M</td></tr>
        <tr><td><strong>4. Capital markets arranger</strong></td><td>20% × 75bps × $100M new lines / licensee / yr</td><td>~$1M</td><td>~$2M</td></tr>
        <tr><td><strong>5. Other</strong> (interest, captive insurance)</td><td>—</td><td>~$0.4M</td><td>~$0.8M</td></tr>
        <tr><td><strong>Total revenue (Likely)</strong></td><td></td><td><strong>~$121M</strong></td><td><strong>~$633M</strong></td></tr>
        <tr><td><strong>EBITDA margin (Likely, recurring / blended)</strong></td><td></td><td><strong>~74% / 74%</strong></td><td><strong>~85% / 89%</strong></td></tr>
      </tbody>
    </table>

    <div style="display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 20pt; margin-top: 12pt;">
      <div class="big-number"><div class="num" style="font-size:32pt; color: var(--gray-500);">$162M</div><div class="label"><strong>Conservative</strong> Y5 revenue</div></div>
      <div class="big-number"><div class="num" style="font-size:32pt;">$633M</div><div class="label"><strong>Likely</strong> Y5 revenue</div></div>
      <div class="big-number"><div class="num navy" style="font-size:32pt;">$2.46B</div><div class="label"><strong>Optimistic</strong> Y5 revenue</div></div>
    </div>
  </div>

  <div class="footnote">All figures USD. Source: Financial Model (P&amp;L_Likely / Summary_3Case). Pricing inputs aligned to v14d Optimised EPM product spec.</div>
  {slide_furniture(num, total)}
</div>
'''


def slide_competition(num: int, total: int) -> str:
    return f'''
<div class="slide bg-dots">
  <div class="kicker">Competitive Landscape</div>
  <div class="headline">The AU competitive landscape — and why we win.</div>

  <div class="body">
    <div class="quad-grid">
      <div class="quad-cell">
        <strong>Household Capital, Heartland</strong>
        Reverse mortgages. Interest-bearing, eat estate. Address ~5% of retiree market. We don't compete; we serve the other 95%.
      </div>
      <div class="quad-cell">
        <strong>Challenger annuities</strong>
        Annuitise super, not home equity. Different problem, different share-of-wallet. Possible strategic partner, not competitor.
      </div>
      <div class="quad-cell">
        <strong>Pension Boost (Pension Loans Scheme)</strong>
        Government-rate-capped, drawdown-only, limited.
      </div>
      <div class="quad-cell">
        <strong>Banks</strong>
        APRA capital rules under APS 112 make originating these uneconomic for ADIs.
      </div>
    </div>

    <div class="pull-quote" style="margin-top: 16pt;">Why we win: product structure (no compounding debt), regulatory tailwind (Covenant), AI-native distribution-first model, and a 6× larger addressable market because we serve the 95% who reject reverse mortgages.</div>
  </div>

  {slide_furniture(num, total)}
</div>
'''


def slide_team(num: int, total: int) -> str:
    return f'''
<div class="slide bg-dots">
  <div class="kicker">The Team</div>
  <div class="headline">Founder + senior actuaries — the credibility anchor.</div>

  <div class="body">
    <div class="team-section">
      <div class="section-label">Founder &amp; Senior Actuaries</div>
      <div class="team-grid">
        <div class="team-card">
          <div class="name">John R Innes</div>
          <div class="role">Co-Founder &amp; Executive Director</div>
          <div class="bio">30+ yrs insurance/insurtech (APAC, USA). Former Head of Product, AU's largest insurer. Co-founded, scaled &amp; exited a leading digital insurer. Ex-Allianz NCM ($750M+ premium portfolio).</div>
        </div>
        <div class="team-card">
          <div class="name">Dr Pavel Shevchenko</div>
          <div class="role">Senior Actuary, Quantitative Risk</div>
          <div class="bio">Author of Futureproof's proprietary financial model. Professor (Actuarial Studies &amp; Business Analytics) Macquarie U. Ex-Principal Research Scientist CSIRO. Director, Centre for Financial Risk.</div>
        </div>
        <div class="team-card">
          <div class="name">John De Ravin</div>
          <div class="role">Senior Actuary, Insurance Risk</div>
          <div class="bio">Ex-Director Swiss Re. Ex-Chief Actuary Munich Re. Senior actuary roles at CommInsure &amp; MLC Life. Ex-member Australian Government Actuary.</div>
        </div>
      </div>
    </div>

    <div class="team-section">
      <div class="section-label">Leadership</div>
      <div class="team-grid">
        <div class="team-card">
          <div class="name">Wesley Chow</div>
          <div class="role">CFO</div>
          <div class="bio">30+ yrs CFO / Finance Director. Ex-KPMG, BEA Systems, CustomWare.</div>
        </div>
        <div class="team-card">
          <div class="name">Matt Stone</div>
          <div class="role">CTO</div>
          <div class="bio">20+ yrs regulated financial systems. Former CTO across fintech &amp; trading platforms (London, LA, Tokyo, Sydney).</div>
        </div>
      </div>
    </div>

    <div class="team-section">
      <div class="section-label">Banking, Insurance &amp; Advisory · Quant &amp; Data</div>
      <div class="team-grid" style="grid-template-columns: 1fr 1fr 1fr 1fr;">
        <div class="team-card">
          <div class="name">James Huey</div>
          <div class="role">Chairman</div>
          <div class="bio">Ex-Westpac Head Retail/Commercial Banking. 15-yr Director Resimac (AU's first RMBS issuer).</div>
        </div>
        <div class="team-card">
          <div class="name">Dr Peter Langkamp OAM</div>
          <div class="role">AU Platform/Product</div>
          <div class="bio">Ex-Director Accenture (Banking &amp; Government). Ex-CEO Novare. Ex-Director Acxiom.</div>
        </div>
        <div class="team-card">
          <div class="name">Ian Holt</div>
          <div class="role">UK Insurance/Reinsurance</div>
          <div class="bio">Ex-Head of Europe, Aviva. Ex-Senior Leader Accenture Insurance.</div>
        </div>
        <div class="team-card">
          <div class="name">Dr Tom Neilsen</div>
          <div class="role">Data Scientist</div>
          <div class="bio">Ex-Director OpenBrain AI. Ex-Research Associate Harvard Medical School. Owns the LLM agent + ML roadmap.</div>
        </div>
      </div>
    </div>
  </div>

  {slide_furniture(num, total)}
</div>
'''


def slide_ask(num: int, total: int) -> str:
    return f'''
<div class="slide bg-dots">
  <div class="kicker">The Ask · Investor Terms — Pre-Series A SAFE</div>
  <div class="headline">Post-money SAFE · Uncapped · 30% discount to Series A 2028.</div>

  <div class="body">
    <div class="big-number-row" style="margin-top: 14pt;">
      <div class="big-number">
        <div class="num">$1M</div>
        <div class="label"><strong>Minimum investment</strong> · USD-denominated · AU-domiciled corporate</div>
      </div>
      <div class="big-number">
        <div class="num navy">30%</div>
        <div class="label"><strong>Discount</strong> to Qualifying Round (Series A Growth Equity, scheduled 2028) · reduces progressively as each SAFE issued</div>
      </div>
      <div class="big-number">
        <div class="num">∞</div>
        <div class="label"><strong>Uncapped</strong> valuation · pricing event is Series A 2028</div>
      </div>
    </div>

    <div style="margin-top: 18pt;">
      <div class="kicker" style="margin-bottom: 6pt;">Other Terms</div>
      <ul style="font-size: 11pt; line-height: 1.5;">
        <li><strong>Side letter</strong> for follow-on investment to maintain equity position · <strong>MFN terms</strong> · <strong>No lead</strong> · <strong>Rolling close</strong></li>
        <li><strong>ESOP at Series A</strong> = 5% issue of new shares + 5% purchase of founder shares</li>
        <li>Use of funds — <strong>AUS launch (Q4/2026)</strong> · <strong>AI roadmap delivery</strong> · <strong>Working capital + key hires</strong> (~18mo runway to Series A 2028)</li>
      </ul>
    </div>
  </div>

  <div class="footnote">ESVCLP allocation available for qualifying AU investors via parallel AUD sub-tranche on the same SAFE terms (10% offset + CGT exemption). Main USD SAFE open to global investors regardless of ESVCLP status.</div>
  {slide_furniture(num, total)}
</div>
'''


def slide_close(num: int, total: int) -> str:
    return f'''
<div class="slide cover bg-gradient">
  <div class="confidential-stamp">Commercial-in-Confidence — Restricted Circulation</div>

  <div style="margin-top: 0.4in;">
    <div class="tagline" style="font-size: 22pt; margin-bottom: 12pt;">In 10 years, every retiree across the AUS / UK / USA target markets should have a credible answer to <em>"how do I turn my home into income without losing it."</em></div>
    <div class="subtitle" style="font-size: 13pt; margin-bottom: 22pt;">We're building that answer. The regulator agrees it should exist. The demographics make it inevitable. The AI-native SaaS platform makes it operable at scale by a small disciplined team. <strong style="color: var(--navy); font-style: normal;">The question is who builds it first.</strong></div>

    <div class="contact-grid">
      <div class="contact-col">
        <div class="contact-label">US Capital Raise</div>
        <div class="contact-name">Mike Spidaliere</div>
        <div class="contact-role">FTFC</div>
        <div class="contact-detail"><a href="mailto:mike@ftfc.co">mike@ftfc.co</a></div>

        <div class="contact-name" style="margin-top: 10pt;">Max Goldberg</div>
        <div class="contact-role">Gold Capital Consulting</div>
        <div class="contact-detail"><a href="mailto:max@goldcapitalconsulting.com">max@goldcapitalconsulting.com</a></div>
      </div>

      <div class="contact-col">
        <div class="contact-label">AU / Global · Founder</div>
        <div class="contact-name">John R Innes</div>
        <div class="contact-role">Co-Founder &amp; Executive Director</div>
        <div class="contact-detail"><a href="mailto:john.innes@futureprooffinancial.co">john.innes@futureprooffinancial.co</a></div>
        <div class="contact-detail">+61 (0)408 306 235</div>
        <div class="contact-detail"><a href="https://www.futureprooffinancial.co">https://www.futureprooffinancial.co</a></div>
      </div>
    </div>

    <div class="geo-strip">HONG KONG · SYDNEY · SAN FRANCISCO · LONDON · CHANNEL ISLANDS</div>
  </div>

  {slide_furniture(num, total)}
</div>
'''


# ---------- Extension slides ----------

def slide_e1_disclosure(num: int, total: int) -> str:
    return f'''
<div class="slide bg-dots">
  <div class="kicker">VC Extension · Honest Disclosure</div>
  <div class="headline">Why this might not be your fund — and why we want you to say so on the first call, not the fourth.</div>

  <div class="body">
    <ol style="font-size: 12pt; line-height: 1.55; padding-left: 24pt;">
      <li><strong>Fund-return math.</strong> Specialty insurance / asset management economics, not SaaS. Path to 10–50× equity is platform AUM growth + strategic / IPO exit, not ARR multiple expansion.</li>
      <li><strong>Time to outcome.</strong> 7–10 years to exit. Doesn't fit a 5-year-from-investment exit assumption.</li>
      <li><strong>Capital intensity.</strong> We don't warehouse risk, but we depend on wholesale funder partners. Closer to fintech-marketplace + capital-markets than to pure software.</li>
      <li><strong>Regulatory surface area.</strong> ASIC (AU), FCA-equivalent in expansion markets. The Covenant tailwind doesn't shorten licensing timelines.</li>
      <li><strong>Mixed comp set.</strong> UK equity-release names (Just Group, Pure Retirement) have bumpy public histories. Product structure is fundamentally different — but a 5-minute pattern-match goes against us.</li>
      <li><strong>Market education burden.</strong> Borrowers AND super funds need education. Sales cycle is quarters for super-fund integration. Not a viral / PLG curve.</li>
      <li><strong>AI is operating leverage, not a moat we claim.</strong> AI gives us no credit-underwriting edge, no regulatory shortcut, no investment alpha.</li>
    </ol>

    <div class="pull-quote" style="margin-top: 14pt;">If any of the above is a hard veto for your fund, please say so on the first call. We're raising from people for whom these tradeoffs are features, not bugs.</div>
  </div>

  {slide_furniture(num, total)}
</div>
'''


def slide_e2_exit(num: int, total: int) -> str:
    return f'''
<div class="slide bg-dots">
  <div class="kicker">VC Extension · Exit Path</div>
  <div class="headline">Realistic exit window: 7–10 years. <span class="accent">Three credible buyer types.</span></div>

  <div class="body">
    <div style="display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 18pt; margin-top: 12pt;">
      <div class="quad-cell" style="background: var(--blue-light);">
        <strong style="color: var(--navy); font-size: 12pt;">1. Super fund consolidator / aggregator</strong>
        <div style="font-size: 9.5pt; color: var(--blue); margin-bottom: 4pt; font-weight: 600;">Most likely</div>
        <div style="font-size: 11pt; line-height: 1.45;">Retirement Income Covenant compliance + member retention. Buying turnkey is faster than building.</div>
      </div>
      <div class="quad-cell">
        <strong style="color: var(--navy); font-size: 12pt;">2. Life insurer / annuity provider</strong>
        <div style="font-size: 9.5pt; color: var(--gray-600); margin-bottom: 4pt; font-weight: 600;">Challenger · TAL · MLC Life · Generation Life</div>
        <div style="font-size: 11pt; line-height: 1.45;">EPM is the home-equity counterpart to the annuity. Strategic gap, publicly acknowledged.</div>
      </div>
      <div class="quad-cell">
        <strong style="color: var(--navy); font-size: 12pt;">3. IPO at scale</strong>
        <div style="font-size: 9.5pt; color: var(--gray-600); margin-bottom: 4pt; font-weight: 600;">Less likely, longer-dated</div>
        <div style="font-size: 11pt; line-height: 1.45;">AUM-driven specialty finance. Heartland Group is the AU-listed precedent. Trigger is A$XB+ AUM, 3 yrs operating history.</div>
      </div>
    </div>

    <div class="pull-quote" style="margin-top: 18pt;">We don't model around a specific exit. We model around being a durable cash-generative business — the exit options follow from that, not the other way around.</div>
  </div>

  {slide_furniture(num, total)}
</div>
'''


def slide_e3_expansion(num: int, total: int) -> str:
    return f'''
<div class="slide bg-dots">
  <div class="kicker">VC Extension · Expansion Roadmap</div>
  <div class="headline">Sequential market entry. Each market unlocked by validated learning from the prior.</div>

  <div class="body">
    <table style="margin-top: 12pt; font-size: 10.5pt;">
      <thead>
        <tr><th style="width:14%;">Market</th><th style="width:14%;">Launch</th><th>Why</th></tr>
      </thead>
      <tbody>
        <tr><td><strong>AUS</strong></td><td>Q4 2026</td><td><strong>Lead market.</strong> ASIC approvals, NCCP licensing path. 1–2 super fund partnerships. Wholesale facility executed. Multi-region calculation engine already live.</td></tr>
        <tr><td><strong>NZ</strong></td><td>2027</td><td><strong>Lowest-friction expansion.</strong> Similar regime to AU; ~6-month licensing. KiwiSaver providers face equivalent retirement-income pressure.</td></tr>
        <tr><td><strong>UK</strong></td><td>Q2 2027</td><td><strong>Mature equity-release market, different mechanic.</strong> FCA. Equity release is a regulated category. Distribution: equity-release advisers + IFA networks. Comp: Pure Retirement (Sun Life), Just Group, More2Life.</td></tr>
        <tr><td><strong>USA</strong></td><td>Q4 2027</td><td><strong>Largest TAM, different regulation.</strong> State-by-state — handled via licensing partner. Distribution: RIAs + bank wealth platforms.</td></tr>
      </tbody>
    </table>

    <div class="pull-quote" style="margin-top: 16pt;">We don't promise a 4-market business at Series A. We promise AUS at scale + 1 expansion market validated. The other two are optionality the platform already supports.</div>
  </div>

  {slide_furniture(num, total)}
</div>
'''


def slide_e4_moat(num: int, total: int) -> str:
    return f'''
<div class="slide bg-dots">
  <div class="kicker">VC Extension · Architecture &amp; Moat</div>
  <div class="headline">What's defensible, what's not, and why distribution + permissions is the real lock.</div>

  <div class="body">
    <div class="cols-2" style="margin-top: 12pt;">
      <div class="col">
        <div class="col-title" style="color: var(--navy);">Defensible (the moat)</div>
        <ul>
          <li>Regulatory permissions stack (multi-jurisdictional licensing — 18-36 months to replicate)</li>
          <li>Super fund integrations (relationship-driven, slow to build, embed once and load-bearing)</li>
          <li>Futureproof's proprietary financial model + actuarial validation (years of model refinement, hard-constraint compliance C1–C6)</li>
          <li>AI-native operating layer (embedded in workflow, not bolt-on)</li>
          <li>Multi-jurisdictional product structure (single calculation engine across 4 regions)</li>
        </ul>
      </div>
      <div class="col">
        <div class="col-title" style="color: var(--gray-600);">NOT defensible (state explicitly)</div>
        <ul>
          <li>The product mechanic itself — could be copied. <strong>The mechanic is not the moat.</strong></li>
          <li>The technology stack — modern but commodity-ish.</li>
          <li>The team — replicable.</li>
        </ul>
      </div>
    </div>

    <div class="pull-quote" style="margin-top: 14pt;">Distribution + permissions + operational AI layer compound. A copycat needs all three to compete; missing any one and the economics don't work. A new entrant in 2027 starts a 24-month build to reach our 2026 starting line.</div>
  </div>

  {slide_furniture(num, total)}
</div>
'''


# ---------------------------------------------------------------------------
# Compose deck
# ---------------------------------------------------------------------------

def main():
    # Slide order
    slide_fns = [
        slide_cover,
        slide_problem,
        slide_why_now,
        slide_solution,
        slide_vs_reverse,
        slide_validation,
        slide_market_size,
        slide_distribution,
        slide_ai_native,
        slide_traction,
        slide_business_model,
        slide_competition,
        slide_team,
        slide_ask,
        slide_close,
        # VC extension pack
        slide_e1_disclosure,
        slide_e2_exit,
        slide_e3_expansion,
        slide_e4_moat,
    ]
    total = len(slide_fns)

    css = CSS_PATH.read_text()
    slides_html = "\n".join(fn(i + 1, total) for i, fn in enumerate(slide_fns))

    html = f'''<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>FutureProof — Investor Deck</title>
<style>{css}</style>
</head>
<body>
{slides_html}
</body>
</html>
'''
    TMP_HTML.write_text(html)

    print(f"Composed {total} slides → {TMP_HTML}")
    print(f"Rendering PDF...")

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
