# Investor FAQ — Pre-empted Objections

> **How to use:**
> - Read these before every investor meeting. The objections will come; the only question is whether you handle them in 30 seconds (calm, prepared) or 3 minutes (defensive, scrambling).
> - Each answer below is a *starting point* — refine voice and add real numbers.
> - Some answers reference internal docs (model, regulatory letters). Have them ready in the data room.
>
> **Placeholder convention:** `[ ]` = fill in.

---

## Product & structure

### Q1. "Isn't this just a reverse mortgage?"

**Short answer:** No. A reverse mortgage charges compounding interest against the home. EPM doesn't. It's structurally different on every dimension that matters — to the homeowner (no debt accumulation, no monthly payments, lifetime income, surplus split at end of term), to the funder (**mortgage income with equity-style returns** — different from any other home-secured asset class on the wholesale market), and to the regulator (no negative-equity risk by design, not by guarantee top-up).

**Longer answer:**
- Reverse mortgages: homeowner draws lump sum or income, interest compounds, estate is consumed. Funder earns interest spread.
- EPM: homeowner pledges equity, capital is invested, income is paid from investment returns. No interest accrual. Surplus at end of term is split with the homeowner.
- Result: estate is preserved in the majority of scenarios. Funder earns from investment performance, not from estate erosion.
- **Why this matters:** completely different alignment of incentives. Reverse mortgage funders benefit from longer tenure (more interest); EPM funders benefit from better outcomes for both sides.

---

### Q2. "What about No Negative Equity Guarantee (NCG)?"

**Short answer:** EPM is structured so that NCG-equivalent protection is built into the product. The homeowner cannot owe more than the home is worth — by design, not by guarantee top-up.

**Longer answer:**
- NCG is a regulatory requirement in AU reverse mortgage products under NCCP
- Because EPM has no debt that compounds, there's no negative equity risk in the traditional sense
- Investment underperformance is absorbed by the funder; downside is bounded
- We are engaging with ASIC to confirm the regulatory categorisation
- See [ INSERT — regulatory engagement memo in data room ]

---

### Q3. "What if property prices crash?"

**Short answer:** The model doesn't assume property appreciation. It's stress-tested against deterministic flat-to-declining house prices. The product remains viable under those scenarios because returns come from the investment portfolio, not house price growth.

**Longer answer:**
- Futureproof's proprietary financial model (50,000-path Monte Carlo) treats house prices as deterministic by design — equity-house-price correlation 0.20 over 30-year horizon is a *constraint we apply*, not an assumption we depend on
- Stress scenarios include 30% peak-to-trough property declines + slow recovery; 1929 / 1973 / 2008 historical sequences run forward
- **PoC year-30 = 0.03 (3%)** — Probability of portfolio Capital shortfall after Payments Waterfall
- **Per-mortgage PoD year-30 = 7.7%** under v14d Optimised parameters (asymmetric collar + 50,000-path validation)
- This is structurally different from reverse mortgages, which depend on property appreciation outpacing interest accrual
- **The home is collateral, not the return engine.** Returns come from the diversified investment portfolio (GBM, ~9.4% mean / ~17.5% vol stochastic) with asymmetric hedge collar (cap +40% / floor -20%)

---

### Q4. "What if equity markets crash?"

**Short answer:** The portfolio is structured ~70% equity / ~30% fixed income with an asymmetric hedge collar (cap +40% / floor -20%). Sequence-of-returns risk is managed through the hedge structure, the profit-share buffer, and the run-off design. Under historical worst-case sequences (1929, 1973, 2008), PoC remains within tolerance — PoC year-30 = 0.03 (3%).

**Longer answer:**
- 30-year horizon smooths most short-term sequences
- **Asymmetric hedge collar** (cap +40% / floor -20%) is the dominant lever for tail risk: portfolio PoC year-30 = 3%
- Profit share at 3-yr resets (10% to FP) creates a buffer mechanism — good-year returns are partially captured before they can be lost
- Run-off mechanism eliminates prepayment-driven liquidity stress
- Equity / house-price correlation 0.20 over 30-year horizon (per Futureproof constraint set) is consistent with historical data
- Cash rate modelled via Ornstein-Uhlenbeck (long-run mean 2.13%, κ 0.24, σ 1.22%) — captures rate regime changes
- See data room for the 50,000-path Monte Carlo + the multi-scenario fine-grid optimisation runs

---

### Q5. "How is this different from Household Capital or Heartland?"

**Short answer:** They're reverse mortgage providers. Same comparison as Q1. We're a different product category.

**Add:**
- Household Capital and Heartland have done valuable work educating the AU market — we benefit from that
- They prove the demand exists; we offer a structurally better product to meet it
- Reverse mortgages address ~5% of the addressable retiree market because the interest-accrual mechanic deters most. EPM is designed for the other 95%.

---

### Q6. "Why hasn't a bank done this?"

**Short answer:** APRA capital treatment makes this uneconomic for ADIs (banks). The capital charge against an EPM-style instrument is too high for the spread on offer. Non-bank originators with wholesale facilities can do this. That's our window.

**Longer answer:**
- Banks must hold material capital against any home-secured exposure under APS 112
- The investment portfolio component compounds the capital cost
- Non-banks operate outside APRA capital rules — they can match-fund through wholesale facilities and structured vehicles
- Several banks have explored EPM-equivalent products and abandoned them on capital grounds — that's a moat for us, not a threat

---

## Regulatory

### Q7. "Regulatory risk?"

**Short answer:** The regulatory path in AU is clearer than for any other jurisdiction. Reverse mortgage precedent under NCCP, explicit Callaghan Review endorsement, Retirement Income Covenant tailwind. We're in active engagement with ASIC and have [ INSERT — pre-engagement letter / approvals / scope ].

**Add:**
- The product is novel but the regulatory framework it sits within is mature
- Post-Hayne scrutiny on retirement products is a feature for us, not a bug — it raises the bar for new entrants and validates careful operators
- Worst case: classification as a regulated credit product → operate under existing NCCP licensing (we have a path mapped)
- See [ INSERT — regulatory memo in data room ]

---

### Q8. "Mis-selling risk post-Hayne Royal Commission?"

**Short answer:** Distribution is the highest-attention risk area. We've designed for it: institutional distribution (super funds, qualified advisers), no commission-based retail selling, mandatory financial advice gate before any product issuance. Post-Hayne we'd rather lose deals than mis-sell.

**Add:**
- Compliance framework includes [ INSERT — mandatory advice, cooling-off period, AFCA membership, complaints process ]
- We've consciously chosen not to sell direct without advice — that's a revenue choice in service of regulatory durability
- See [ INSERT — distribution governance framework in data room ]

---

## Market & competition

### Q9. "Why won't super funds just build this themselves?"

**Short answer:** Speed, capability, and capital. Super funds are pension administrators, not product manufacturers. The Retirement Income Covenant deadline pressure means most need partners, not multi-year internal builds. Our distribution thesis is exactly this.

**Add:**
- Funds we've spoken to: [ INSERT — names or general descriptions, e.g. "two top-10 funds in active discussion" ]
- Build-vs-buy economics: a fund would need to build origination, servicing, regulatory permissions, and a Monte Carlo-validated model — 3+ years and tens of millions
- The few funds attempting in-house solutions have publicly missed timelines
- This is the same dynamic that drove super funds to use external annuity providers (Challenger) rather than build internally

---

### Q10. "Won't Challenger crush you the moment they decide to enter?"

**Short answer:** Maybe — and that's why our parallel track is to be the partner Challenger acquires or licenses, not the competitor they crush. Their core capability is annuity manufacturing. EPM is a different product mechanic. The strategic conversation is open.

**Add:**
- Challenger has publicly acknowledged home equity release as a gap in their offering
- Their capability stack (longevity, balance sheet) complements ours (origination, technology, regulatory permissions)
- We're in [ INSERT — exploratory dialogue / NDA / formal discussions ] with their strategy team
- Even adversarially: their core distribution is super funds, who are also our distribution. They'd prefer a partner over a competitor.

---

### Q11. "Who is the actual customer? Is there real demand?"

**Short answer:** Two customer layers. Layer 1 — institutional product issuers (banks, insurers, super funds) who need a Retirement Income Covenant solution; pipeline includes Macquarie, AMP, Westpac, Barclays, Lloyds, HSBC Private Wealth, Suncorp via Accenture's relationship, plus direct conversations with Resimac, PepperMoney, Heartland Bank, US Bank, Allianz Life, Aegon, Aviva, AIA, Butterfield Private Bank, Hong Kong Mortgage Corp, FWD Insurance. Layer 2 — end retiree borrowers; **Annuity & Mortgage Calculator now in alpha release for user testing** ahead of AUS market launch Q4/2026.

**Add:**
- Demographic fit (US framing): 36M asset-rich homeowner retirees forced into equity-eroding products; total US retiree cohort 55M; $20T in locked-up home equity
- Demographic fit (AU framing): 2.7M Australians over 65; cash-poor, asset-rich, home owned outright or near-outright
- Existing reverse-mortgage demand (Household Capital, Heartland Bank, Finance of America) proves home-equity-release demand exists; EPM addresses the structural reasons the other ~95% still don't engage
- **Distribution-led**, not customer-acquisition-led. Layer-1 institutional partners surface end customers; we don't pay direct CAC. The ~75 bps direct-to-consumer margin is optional / B2C revenue, not the core thesis.
- Market launch sequence: AUS Q4/2026 → UK Q2/2027 → USA Q4/2027

---

## Financial model

### Q12. "What are the unit economics?"

**Short answer:** Five revenue streams, all aligned to Futureproof's proprietary EPM economics:
1. Onboarding tech fee: $1.5M USD per licensee (one-off; cost recovery)
2. SaaS recurring: 50 bps annual FP margin × cumulative AUM
3. Profit share at 3-yr resets: 10% of running surplus
4. Capital markets arranger commission: 20% of 75bps on $100M new lines per licensee per year
5. Other (interest on cash, captive insurance)

**Likely-case 5-year ramp (USD):** Y3 total revenue ~$121M (~74% recurring EBITDA margin); Y5 total revenue ~$633M (~89% blended EBITDA margin). DCF Enterprise Value: ~$5.97B (WACC 14%, terminal g 3%).

**3-case Y5 spread:** Conservative $162M / Likely $633M / Optimistic $2.46B. **DCF Enterprise Value:** $1.46B / $5.97B / $27.5B. All three cases use the v14d Optimised EPM product spec; differentiation comes from sales velocity and equity-return assumptions (6% / 8% / 10% LT respectively).

**Add:**
- We don't warehouse loans — fees on funder capital → SaaS-like margin profile despite financial-services asset base
- Profit share at 3-yr resets means Y4 sees first surplus realisation (Y1-vintage); Y5 sees Y2-vintage realisation
- Mean per-mortgage FP revenue over full 30-year EPM life (validated MC): ~$1.04M USD
- Unit economics improve materially with super-fund distribution (CAC drops to channel partnership level, not direct acquisition)
- See the Financial Model (P&L_Likely / Summary_3Case / AI_Cost_Detail) for full traceability

---

### Q13. "What's the path to profitability?"

**Short answer:** EBITDA-positive in **Year 2** across all three cases (per the Financial Model). Likely case Y2 EBITDA recurring = ~$18M USD on ~$36M revenue (44% margin). The path is AUM-driven, not customer-acquisition-spend driven.

**Add:**
- Y2 break-even is achieved on **recurring** EBITDA (ex-surplus realisation) — we don't depend on the Y5 first-cycle profit share to be profitable
- Operating leverage steps up sharply as the AI roadmap items ship (Y3 onwards) — opex/AUM drops from ~65 bps Y1 to ~14 bps Y3 to ~7 bps Y5 in the Likely case
- Wholesale facility structure means we don't carry the balance sheet — we earn fees on the funder's capital
- Path depends on distribution velocity (super-fund partnerships) more than direct customer acquisition
- Conservative case: Y2 EBITDA recurring = ~$4M (still positive). Even the downside crosses zero in Y2.
- See the Financial Model (Runway vs Raise) for full burn/runway trace

---

### Q14. "Who manages the investment portfolio?"

**Short answer:** **Product co-design with BlackRock and SpiderRock.** BlackRock for the passive index ETF allocation (the equity reference asset); SpiderRock for the dynamic hedging collar execution. Portfolio policy is **rules-based and transparent** — not actively managed for alpha. We do not take portfolio-management discretionary risk on our balance sheet.

**Add:**
- Portfolio composition: ~70% equity (passive S&P 500 index ETFs) / ~30% fixed income (mandate-driven, not discretionary)
- Hedging mechanic: asymmetric collar (cap +40% / floor -20%) per v14d Optimised. SpiderRock provides the platform for continuous dynamic hedging execution. This is the dominant lever for tail risk — not active management.
- We don't claim alpha — the product economics work on long-horizon beta with hedging
- Sub-advisory separation means investment management *execution* risk sits with a qualified manager (BlackRock for ETF allocation, SpiderRock for collar execution); portfolio *policy* sits with FP under a documented investment policy statement
- This separation is intentional: simplifies our regulatory profile, reduces operational complexity, and makes the model defensible under examination
- Mortgage insurance + portfolio reinsurance discussions in active negotiation with Lockton Reinsurance, Gallagher Re, Munich Re for tail-risk transfer

---

## Operations & team

### Q15. "Who services the loans?"

**Short answer:** Servicing sits with the licensed Product Issuer (the bank, insurer, or non-bank lender — e.g. Resimac, PepperMoney, Heartland Bank, Macquarie, AMP). FutureProof provides the SaaS platform that runs the servicing workflows; we don't directly service end-customer accounts. This is intentional — keeps regulatory load with the licensed entity and lets us scale across many issuers.

**Add:**
- Day-1 servicing capacity comes from the issuer's existing infrastructure (e.g. Resimac is AU's first RMBS originator with decades of servicing experience)
- FutureProof platform handles the EPM-specific workflow layer: hedge accounting, reset calculations, surplus distribution, regulatory reporting per jurisdiction
- AFCA / FOS / CFPB complaints handling and annual servicing review sits with the issuer; FutureProof provides supporting data and audit trails

---

### Q16. "What's missing on the team?"

**Short answer:** **Senior US distribution lead** post-USA launch (Q4/2027). The Accenture relationship gives us channel access; we need an in-market lead to manage the cohort of US Product Issuers (Allianz Life, Aegon, US Bank, AIA, etc.). Hiring brief is drafted; use-of-funds carves a budget line for this role to land Q1/2027.

**Add:**
- We deliberately raise into a hiring plan, not over-hire pre-revenue
- Other roles funded by this raise: AI/ML engineering bench (to ship the slide-9 roadmap items — Tom Neilsen leads, hires under him); compliance ops in each jurisdiction post-launch
- Advisor bench compensates for current gaps: Tom Hamilton (UK platform), Ian Holt (UK insurance), Dr Peter Langkamp (AU institutional access via Accenture relationship)
- Founding-team density across **regulated finance** (Innes, Chow, Huey) + **actuarial** (De Ravin ex-Swiss/Munich Re; Shevchenko = author of Futureproof's proprietary financial model) + **AI/ML** (Stone CTO, Neilsen ex-OpenBrain/Harvard) is unusually deep for seed-stage; the gap is in-market US distribution, not technical capability

> **Investors respect honest gap-naming far more than puffed-up team slides. The named gap is real and the timing matches the funding ask.**

---

## The round itself

### Q17. "What's the round structure, and is ESVCLP available?"

**Short answer:** **Pre-Series A SAFE round, AU-domiciled corporate (Futureproof Financial Group Limited), USD-denominated.** Post-money SAFE, **uncapped valuation, 30% discount** to the Qualifying Round (Series A Growth Equity Round, scheduled 2028). **Minimum investment USD $1M.** Discount **reduces progressively** as each SAFE is issued and for any subsequent round — earliest investors capture the full 30%. Side letter for follow-on / pro-rata to maintain equity position. MFN terms. No lead. Rolling close. **ESVCLP allocation is available for qualifying AU investors via a parallel AUD sub-tranche** on the same SAFE terms — 10% non-refundable tax offset + CGT exemption on returns.

**Add:**
- **Why a SAFE** — speed, low legal cost, pricing event is the Series A 2028. Investors get a 30% discount + MFN protection — they convert at 70% of whatever the Series A price clears at, or better if a later SAFE prices on better terms.
- **The decreasing-discount mechanic creates real urgency** — first SAFEs in the door capture the full 30%; later ones get less. There is no separate price tier to negotiate; the term sheet is the term sheet.
- **Uncapped means investors are betting on Series A execution** — there is no floor or ceiling on what the Series A price clears at; the SAFE simply applies a discount to that price.
- **ESOP at Series A** — 5% new shares issued + 5% purchase of founder shares (founders take the dilution to fund post-A hiring). Modelled, not painful.
- ESVCLP eligibility criteria: [ INSERT — current confirmed ESVCLP status ]
- The AUD sub-tranche runs parallel to the USD round on the same SAFE terms — different settlement currency only, to preserve ESVCLP eligibility for AU investors who qualify
- Not all AU investors qualify — accountant should confirm
- See [ INSERT — ATO / accountant briefing in data room ]

---

### Q18. "Why dual-track (family offices + fintech-specialist VCs)?"

**Short answer:** We're running parallel tracks because each adds something different. Family offices give us patient capital that matches the 7–10 year exit window. Fintech-specialist VCs (anchor or co-invest) give us operational signal and Series A optionality. We are *not* running a generalist-VC-led process — wrong product, wrong stage.

**Add:**
- **FO track is the primary route.** AU family-office principals (typically 50–75) have lived this with their parents and recognise the product viscerally in 90 seconds. They're our natural anchor source.
- **Fintech-specialist VC track runs in parallel.** Tier-A targets: Square Peg, AirTree (with the AU institutional angle), Anthemis, QED. We approach with the honest-disclosure block (deck slide E1) on the first call so they can disqualify in 10 minutes if it's not a fit.
- **Generalist VCs deprioritised but not excluded** — only on warm intro, only with a sharpened deck. We will not cold-pitch a generalist fund and burn the relationship.
- ESVCLP allocation (AU sub-tranche) is a useful tax-efficient option for qualifying AU investors, but it's not the leading frame — the USD-denominated SAFE is open to all global investors
- A fintech-specialist VC anchor on this round would materially improve Series A optionality. That's the strategic value, beyond the cheque.
- See `PLAN.md` "Honest disclosure for VCs" section + `target_list.md` Tier 4 for the named-VC list

---

### Q19. "What's the exit?"

**Short answer:** **7–10 year window. Three credible buyer types:**
1. **Super fund consolidator / aggregator** (most likely) — RIC compliance + member retention. Buying turnkey is faster than building.
2. **Life insurer / annuity provider** (Challenger, TAL, MLC Life, Generation Life) — EPM is the home-equity counterpart to the annuity, a publicly acknowledged gap in their offerings.
3. **IPO at scale** (less likely, longer-dated) — Heartland Group is the AU-listed precedent; trigger is A$[ ]B+ AUM with 3 years of operating history.

**Add:**
- Comparable transactions: [ INSERT — 3–5 named deals per buyer type before first VC meeting ]
- We don't model around a specific exit; we model around being a durable cash-generative business. The exit options follow from that, not the other way around.
- Strategic acquirers' interest is *structural* (they need this capability under the Retirement Income Covenant) — not dependent on a specific market window
- Family offices generally prefer durable businesses with optional liquidity over exit-engineered ones; VCs prefer the strategic-acquirer path with an IPO option for upside
- See deck slide E2 for fuller buyer-type breakdown with comp transactions

---

### Q20. "What's the risk that kills this company?"

**Short answer (be honest):** The three biggest:
1. **Regulatory reclassification** that materially changes capital treatment or advice requirements
2. **A major strategic (Challenger or a big-4 bank) launching a competing product** before we secure first super-fund distribution
3. **Distribution velocity falls short** — super-fund procurement cycles drag and we run out of runway before the first 1–2 partnerships are signed

**Add:**
- Regulatory: ongoing ASIC engagement, conservative product design, multiple licensing paths mapped
- Competitive: speed to first super fund partnership is the most important defensive move; the dual-track raise (with a strategic VC anchor option) helps accelerate this
- Distribution velocity: addressed by the SAFE round sizing — covers Y0–Y2 burn in the Likely case with ~6 months buffer (per the Financial Model, Runway vs Raise)
- **Watch list (lower-tier but real):** (a) AI overclaim — if we lean too hard on AI in pitches without delivering the roadmap, credibility erodes; mitigant is the explicit "what AI doesn't do" framing throughout; (b) wholesale funder concentration — if we lock to a single funder we inherit their balance-sheet view; mitigant is multi-funder strategy from Y2; (c) actuarial key-person risk — being addressed in hiring plan
- Mitigants documented in [ INSERT — risk register in data room ]

> **Investors trust founders who name the real risks. They distrust founders who claim there are none. The point of this answer is to demonstrate clarity, not to reassure.**

---

## VC-specific objections

### Q21. "Is your AI capability actually defensible?"

**Short answer:** **No, and we don't claim it is.** AI is operating leverage, not a moat. The moat is regulatory permissions + super-fund integrations + Futureproof's proprietary financial model (years of financial and legal engineering) — all of which compound. AI lets us *realise* the unit economics — it doesn't lock anyone out.

**Add:**
- The AI architecture itself is open and replicable — Claude API, agent orchestration patterns, knowledge-base grounding, all standard in 2026
- What's hard to copy is the *combination*: AI-ops + regulatory permissions + super-fund integrations + actuarial validation. A new entrant in 2027 starts a 24-month build to reach our 2026 starting line.
- Stating "AI is not the moat" is the credibility move. Founders who claim AI is the moat in 2026 get penalised for the inflated framing.
- See `ai_architecture.md` for the live / built / roadmap / never breakdown — and "Why won't a competitor copy this in 12 months?"

---

### Q22. "Won't generalist VCs pattern-match this against the wrong comps?"

**Short answer:** Yes, and that's why we don't pitch generalist VCs at this stage. We pitch fintech / insurtech specialists who already understand regulated-finance economics. Generalists go on the quarterly update list for Series A.

**Add:**
- Tier-A specialist target list: Square Peg (Athena precedent), AirTree, Anthemis (insurtech thesis), QED (lending track record). Named partners, not generic firms.
- Tier-C generalist firms (pure SaaS / consumer-app / Web3-thematic) are explicitly excluded from this round
- The honest-disclosure block on slide E1 / first page of `teaser_vc.md` is designed to qualify out a partner in 10 minutes who would otherwise burn 4 weeks pattern-matching us against SaaS comps
- Comp set we *do* match against: specialty insurance, annuity providers, regulated lending platforms (Athena, Heartland Group, Pure Retirement, Finance of America). Different shape from SaaS — that's the feature not the bug.

---

### Q23. "What unlocks Series A from here?"

**Short answer:** This round is the **Pre-Series A SAFE**. The Series A (Growth Equity Round) is **scheduled 2028**. Three milestones unlock it:
1. **First 1–2 super fund partnership(s) signed** with documented integration roadmaps
2. **USD $50–100M wholesale funding facility executed** with at least one institutional funder (Atlas SP / Apollo / PIMCO conversations active)
3. **AI roadmap items shipping in production** (application triage + ops admin live, not still on roadmap)

**Add:**
- Series A thesis on this base: the company has crossed from "novel product" to "operating platform with regulated permissions and institutional capital flowing through it"
- **Series A timing: scheduled 2028**, post AU launch (Q4/2026) + initial UK / USA traction. The SAFE converts into the Series A price at a 30% discount (or better, per MFN).
- We deliberately don't publish a Series A target valuation — that's for investors to model. The SAFE terms protect them either way: discount + MFN + side letter for pro-rata.
- Lead would naturally be a fintech-specialist VC who can validate the product-market fit signal
- A fintech-specialist on the SAFE cap table materially de-risks Series A — they bridge to their network. That's part of why we're running the dual-track now rather than waiting.

---

### Q24. "What does the cap table look like post-this-round?"

**Short answer:** Under a SAFE, **the cap table doesn't change at SAFE close** — it changes at Series A 2028 when the SAFEs convert. At conversion, each SAFE buys shares at **70% of the Series A price** (or better per MFN). At Series A, **ESOP is set at 5% new shares + 5% from founder shares**. Designed to leave the founder team with meaningful equity post-Series A and the SAFE pool with a clear conversion path.

**Add:**
- Pre-Series A SAFE round, AU-domiciled corporate (Futureproof Financial Group Limited), USD-denominated
- **Post-money SAFE structure** — investor's % at conversion is calculable from their cheque size and the Series A post-money valuation (no surprise dilution from later SAFEs at the same price tier)
- Discount **reduces progressively** as later SAFEs are issued — so the post-conversion ownership for early investors is protected against late-comers getting equal terms
- Side letter granting **follow-on / pro-rata rights** to maintain equity position through Series A and onwards
- **MFN terms** — if a later SAFE has materially better economics, prior SAFEs benefit
- Existing convertible / SAFE notes (USD $10M outstanding at $85M valuation cap from a prior tranche) sit alongside this round; both convert at Series A
- No board seats granted at SAFE stage (standard); board composition revisited at Series A
- ESVCLP allocation available for qualifying AU investors via parallel AUD sub-tranche on the same SAFE terms
- See [ INSERT — SAFE template + cap table doc in data room ] for full structure

---

### Q25. "What about this team specifically makes them right for this?"

**Short answer:** Three benches that rarely sit in one company at this stage — and the founder has built and exited an insurer before, so the path-pattern is known.

**The benches (founder + actuaries first; everything else after):**
1. **Founder + senior actuaries (the credibility anchor).** John R Innes (founder) — 30+ years insurance/insurtech, ex-Head of Product at AU's largest insurer, ex-Allianz NCM ($750M+ portfolio), already built and exited a digital insurer. **Dr Pavel Shevchenko** — Professor (Macquarie U), ex-CSIRO Principal Research Scientist; *author of Futureproof's proprietary financial model + multi-scenario optimisation that validates the product*. The MC numbers we cite throughout (PoC year-30 = 0.03; per-mortgage PoD year-30 = 7.7%) are his work. **John De Ravin** — ex-Director Swiss Re, ex-Chief Actuary Munich Re, ex-member Australian Government Actuary.
2. **Regulated-finance C-suite.** Wesley Chow (CFO) — 30+ yrs CFO. James Huey (Chairman) — ex-Westpac Head of Retail/Commercial Banking + 15-yr Director Resimac (AU's first RMBS issuer).
3. **AI/ML scientific depth (the operating-leverage bench).** Matt Stone (CTO) — 20+ yrs regulated financial systems across London/LA/Tokyo/Sydney. Dr Tom Neilsen — ex-Director OpenBrain AI, ex-Research Associate Harvard Medical School; predictive analytics + computational neuroscience. *Owns the slide-9 AI architecture and the production roadmap.*

**Add:**
- This is unusually rare for seed stage — most teams have 1–2 of these benches; FutureProof has all three plus institutional access via Dr Peter Langkamp (ex-Director, Accenture Banking & Government) which is what makes the Accenture global collaboration partnership credible
- The honest gap is **in-market US distribution leadership** post-USA launch (Q4/2027) — addressed in Q16
- For VCs specifically: the AI/quant bench (Stone + Neilsen + Shevchenko + De Francesco) is what makes the operating-leverage thesis on slide 9 survive partner-meeting scrutiny

> **Honest gap-naming compounds trust. The gap is named (Q16) and the timing matches the use-of-funds.**

---

### Q26. "What if a Cohere/Anthropic-backed AI-first lender enters this space?"

**Short answer:** Welcomed, not feared. AI capability isn't the binding constraint — regulatory permissions, super-fund integrations, and actuarial validation are. An AI-first new entrant would still need 18–36 months to assemble those, by which time we have the first 2–3 super-fund partnerships embedded.

**Add:**
- AI-first competitors will likely emerge in adjacent retail-fintech categories where AI itself is the product (origination automation, customer acquisition). Those aren't our category.
- Our category is "regulated retirement-income infrastructure" — the AI is plumbing for opex, not a customer-facing wedge. A more capable AI competitor doesn't change our customer story (super funds buying compliance solutions, retirees getting income).
- If Anthropic / Cohere themselves invested in a competitor, we'd consider them a strategic partner discussion, not an adversarial one — the AI-leverage story actually validates our approach to regulated-finance VCs.

---

## When you don't know an answer

> **The right answer is always: "I don't know — but I'll come back to you with a real answer by [day]."**
>
> Then do it.
>
> Family office principals can spot a bullshit answer in two seconds and they remember it for years. A "let me come back to you" handled well actually *increases* trust.
