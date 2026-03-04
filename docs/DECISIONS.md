# Design Decisions Log

Decisions made during refactoring where business requirements were ambiguous.

## Business Logic Decisions

| # | Decision | Reasoning | Revisit? |
|---|----------|-----------|----------|
| 1 | **Max LTV: 80% all regions** | Standard across AU/NZ/UK/US to simplify. UK could support higher but consistency preferred for MVP. | Yes — may need region-specific LTV |
| 2 | **Min property: $500K (US/AU/NZ), £300K (UK)** | UK property values lower on average; $500K USD/AUD/NZD is reasonable floor. | Yes — market research needed |
| 3 | **Max property: $10M all regions** | Upper bound for MVP; no reason to cap lower. | Maybe — ultra-high-net-worth may need different product |
| 4 | **Age range: 18+, no upper limit** | Key EPM differentiator vs reverse mortgages. No actuarial reason to cap. | No — this is a feature |
| 5 | **Income rate: 1.5% base (Pavel model)** | Conservative; validated by Monte Carlo with ~11% deficit probability at Year 30. | No — model-validated |
| 6 | **All regions launch simultaneously** | Per business requirement. Contracts created for all 4 regions from day one. | No — explicit requirement |
| 7 | **Primary residence + investment property eligible** | Both types accepted; broadens market. | Yes — may need separate risk profiles |
| 8 | **S&P 500 as primary investment** | Pavel model calibrated to S&P 500 returns. Could diversify later. | Yes — post-launch portfolio expansion |

## Technical Decisions

| # | Decision | Reasoning |
|---|----------|-----------|
| 1 | **Shared legal partials, not 24 separate files** | DRY principle. Region-specific content injected via helper. 4 shared partials + 24 thin wrappers. |
| 2 | **Mock agent responses, not LLM** | MVP speed. Pre-built responses cover 90% of common questions. Easy to swap for real LLM later. |
| 3 | **Agent performance mock data seeded** | VC demo needs realistic data. 8 agents × 50 tasks = 400 completed tasks, spread over 30 days. |
| 4 | **Stimulus for live dashboard, not WebSocket** | Simpler. 8-second polling via Stimulus controller gives "real-time" impression without ActionCable complexity. |
| 5 | **CSS variables for design system** | Maximum flexibility. All colours, spacing, typography controlled from one `:root` block. |
| 6 | **Region detection: URL path > subdomain > session > default** | URL path (/au, /nz, /uk) is most explicit and SEO-friendly. Subdomain fallback for custom domains. |
| 7 | **US as default region (root URL)** | Largest addressable market. All other regions require explicit path prefix. |
| 8 | **Ruby 3.4.8 (not 3.4.4)** | Homebrew had 3.4.8 available; newer is better. No compatibility issues found. |

## Compliance Decisions

| # | Decision | Reasoning |
|---|----------|-----------|
| 1 | **Cooling-off periods by region** | AU: 10 business days, NZ: 5 working days, UK: 14 calendar days, US: 3 business days. Based on consumer credit legislation. |
| 2 | **UK GDPR data portability + restriction rights** | UK privacy policy includes additional rights (portability, restriction, objection) not required in other regions. |
| 3 | **AFCA for AU disputes** | Australian Financial Complaints Authority is the correct external dispute body for financial services. |
| 4 | **FOS for UK disputes** | Financial Ombudsman Service is the correct UK body. |
| 5 | **AAA arbitration for US disputes** | American Arbitration Association is standard for US financial contracts. |
