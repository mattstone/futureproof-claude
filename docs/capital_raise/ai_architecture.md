# FutureProof — AI Architecture One-Pager

> **Audience:** VC partner technical / diligence questions on slide 9.
> **Use:** Send post-first-meeting if a partner asks for depth on the AI claims. Sit alongside the data room.
> **Tone rule:** Honest about what's live, building, and aspirational. The believable claim is more valuable than the maximal claim.

---

## The thesis (one paragraph)

We are leaning hard into AI as the lever that lets a small disciplined team operate a regulated financial-services business at software-company cost structure. **By Year 5: 38 FTE running multi-region, multi-billion AUM operations.** **We are not a lender** — we are the AI-native SaaS platform that turns home equity into guaranteed retirement income, licensing banks, insurers, and non-bank lenders to issue the EPM. AI doesn't make our actuarial science better — Futureproof's proprietary financial model does that. AI is what lets a small disciplined team **operate the platform efficiently**, while *raising* customer-service quality through 24/7 region-aware support that no comparable specialty insurer offers. This document spells out exactly where AI is doing work today, where the infrastructure is built and waiting, what's on the 12-month roadmap, and the regulated-decision boundary AI never crosses.

---

## Status at a glance

```
┌─────────────────────────────────────────────────────────────────────┐
│  REGULATED-DECISION BOUNDARY ── ❌ AI never crosses                  │
│  (credit underwriting · compliance sign-off · investment policy)     │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│   ┌──────────────────────────┐    ┌──────────────────────────┐    │
│   │  ✅ WORKING PROTOTYPE     │    │  ✅ INFRASTRUCTURE BUILT  │    │
│   │  Customer-facing chat    │    │  Agent orchestration      │    │
│   │  ("Akane") · 4 regions  │    │  Claude · tool use        │    │
│   │  Knowledge-grounded      │    │  Prompt caching           │    │
│   │  Guardrails · escalation │    │                           │    │
│   └──────────────────────────┘    └──────────────────────────┘    │
│                                                                     │
│   ┌──────────────────────────────────────────────────────────────┐ │
│   │  🟡 ROADMAP — next 12 months (budgeted in Financial Model)   │ │
│   │  • Application triage (LLM-augmenting rule-based service)    │ │
│   │  • Internal ops admin agents (review packs, exceptions)      │ │
│   │  • Multi-region marketing content generation                 │ │
│   │  • Customer-service triage at scale                          │ │
│   │  • Investment-ops workflow (rebalancing alerts, reporting)   │ │
│   └──────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────┘
            │                                │
            ▼                                ▼
   Human-in-the-loop                Regulated decisions
   review for any                   stay with licensed
   non-trivial action               humans (forever)
```

---

## ✅ Working prototype today

### 1. Customer-facing AI agent — "Akane"

- **Code:** `app/services/customer_support_service.rb` (331 lines), `app/services/claude_chat_service.rb`
- **Model:** Claude (Anthropic), with prompt caching on system blocks
- **Coverage:** 4 regions (AU / US / NZ / UK) — each region's regulatory framing built into responses
- **Capabilities:**
  - Product Q&A (what is EPM, how it works, vs reverse mortgage, NNEG, term-end)
  - Eligibility (age, property types, regions, joint applications)
  - Process (timeline, documents, cooling-off, hardship)
  - Lender / funder Q&A
  - Support escalation triggers
- **Guardrails (non-trivial — these are why the system can ship):**
  - `PROPRIETARY_PATTERNS` regex set blocks discussion of Monte Carlo, surplus split, run-off, PoD/PoC, S&P portfolio details, actuarial mechanics, pricing model — anything that could leak product IP or constitute regulated advice
  - `ABUSE_PATTERNS` blocks abusive input with a calm de-escalation response
  - `OFF_TOPIC_RESPONSE` redirects non-EPM questions
  - `should_escalate?` triggers human handoff when confidence drops or the user asks for a human
- **Architecture:** Pattern-match-first (deterministic, fast, audit-trailed) with Claude fallback for novel queries
- **What this gives us in opex terms:** 24/7 first-line support across 4 regions without 24-hour-staffed call centres. A specialty insurer at our planned AUM would carry 30-50 first-line support staff per region.

---

## ✅ Infrastructure built (production-grade, awaiting LLM activation)

### 2. Agent orchestration framework

- **Code:** `app/services/claude_chat_service.rb`
- Tool use loop with iteration cap (`MAX_TOOL_ITERATIONS = 3`)
- Prompt caching on system blocks (cost reduction at scale)
- Token-usage tracking for unit-economics reporting

### 3. AI agent data model

- **Models:** `ChatAgent`, `ChatConversation`, `ChatMessage`, `AgentTask`, `AgentAction`, `AgentPerformance`, `AiAgent`
- 3 agent types defined and validated: `applications`, `backoffice`, `investment`
- Agent performance tracking (`AgentPerformance.ai_agents` scope) — per-agent metrics, not aggregate
- Lifecycle service (`agent_lifecycle_service.rb`, 497 lines) handles agent provisioning, state transitions, monitoring

### 4. Application evaluation infrastructure

- **Code:** `app/services/agent_decision_service.rb` (250 lines)
- **Status today:** Rule-based (LVR caps, age flags, property bounds, risk score thresholds)
- **Why it matters for AI roadmap:** Header comment states *"Currently rule-based; structured for future LLM integration."* The `Result` struct (decision, confidence, reasoning, flags, next_action) is shaped exactly for LLM-augmented evaluation. Drop in an LLM call, keep the rule layer as the deterministic safety net.

---

## 🟡 Roadmap — next 12 months (budgeted in the Financial Model)

Each item has a budget line in the Financial Model (AI Cost Detail). Not aspirational — funded.

| Item | What it does | Operational impact |
|---|---|---|
| Application triage | LLM augments `AgentDecisionService` for first-pass evaluation; humans review escalations only | -40% backoffice headcount per A$ AUM |
| Ops admin agents | Draft summaries, flag exceptions, prepare review packs for human sign-off | -30% G&A overhead at scale |
| Marketing content | Multi-region content generation tailored to each jurisdiction's regulatory framing | No per-region marketing teams |
| CS triage at scale | Sentiment / priority / routing for inbound across all channels | Sub-2-min first-response time |
| Investment-ops workflow | Rebalancing alerts, anomaly detection, reporting-pack generation | Investment ops team cap at 4 FTE for any AUM |

**Important framing:** AI augments the team, it doesn't replace customer-quality moments. Hardship calls, complaints, complex applications, advice gateways — all stay human. The roadmap *raises* customer service quality through faster response and 24/7 availability, while letting headcount scale sub-linearly with AUM.

---

## ❌ Never — the regulated-decision boundary

These are off-limits to AI by design. Stating them explicitly is part of the credibility:

- **Credit underwriting decisions** — humans only, audit-trailed
- **Compliance sign-off** (KYC/AML adjudication, AFCA matters, regulator engagement)
- **Investment policy** (asset allocation, hedge structure, rebalancing rules) — set by humans, executed by code
- **Investment alpha generation** — none claimed; portfolio is rules-based, transparent, auditable
- **Regulated advice** — gated to qualified humans before any product issuance

If it's a decision that an ASIC or FCA examiner will ask "who made this?", the answer is a named licensed human, not an LLM.

---

## Operating leverage quantified

> See the Financial Model (AI Cost Detail).

### FTE per A$1B AUM (Likely case)

| Year | FutureProof FTE/$1B AUM | Specialty insurer benchmark | AI-absorbed FTE-equivalents |
|---|---|---|---|
| Y1 | ~8 | 200 | ~390 |
| Y3 | ~1 | 200 | ~6,800 |
| Y5 | ~0.3 | 200 | ~29,000 |

> *Read: at Y3 in the Likely case, the AI-ops layer is absorbing ~6,800 FTE-equivalents of work that a comparable specialty insurer would carry at our AUM. The benchmark of 200 FTE per A$1B AUM is the public-comparable for specialty annuity / equity-release providers.*

### Opex per A$ AUM (Likely case)

| Year | Opex/AUM (bps) | Comp benchmark |
|---|---|---|
| Y1 | ~65 bps | — |
| Y3 | ~14 bps | 50–80 bps |
| Y5 | ~7 bps | 50–80 bps |

> The Y3 and Y5 numbers are the venture-scale punchline. Conservative case: ~19 bps Y3 → ~10 bps Y5. Even the downside is materially below comp.

### AI infrastructure cost (Likely case)

| Year | AI infra spend (USD) | % of total opex |
|---|---|---|
| Y0 | $180,000 | ~3% |
| Y1 | $270,000 | ~3% |
| Y3 | $610,000 | ~3% |
| Y5 | $1,370,000 | ~3% |

> Includes LLM API spend (Anthropic Claude), AI engineering tooling, agent monitoring infrastructure. Held at ~3% of opex by design — keeps unit economics honest.

---

## Questions sharp partners will ask, with the honest answer

### "Show me one production AI workflow."

Open the customer-facing chat at futureproof.com.au. Ask Akane about EPM eligibility. The system uses Claude with knowledge-base grounding, jurisdiction-aware response framing, and proprietary-content guardrails. It will *not* answer a question about Monte Carlo, surplus split, or PoD — that's by design.

### "What % of your headcount plan depends on AI working?"

Y1-Y2 ramp is rule-based + human-led; AI is supplementary. Y3+ headcount plan **does** assume the roadmap items ship. If they don't, headcount plan needs to be ~50% higher to maintain quality — opex/AUM rises from 14 bps to ~21 bps. Still better than the comp set, but the venture-scale margin compresses.

### "What if Anthropic raises prices 10×?"

We will experiment with self-hosted models after launch — that's the strategic plan to reduce LLM provider dependency. The architecture isolates the LLM call site, so we can swap providers (or move to self-hosted) without re-engineering the agent layer.

### "What's your AI failure mode?"

The customer-facing agent has three failure modes mapped: (1) hallucination on novel questions → handled by pattern-match-first then Claude with KB grounding; (2) jailbreak attempts to extract proprietary content → handled by `PROPRIETARY_PATTERNS`; (3) abusive input → handled by `ABUSE_PATTERNS`. Open code, audit-trailed. We log every interaction.

### "Is the AI claim a moat?"

No. We are explicit about this in the deck (slide E1, item 7; slide E4). AI is operating leverage. The moat is regulatory permissions + super-fund integrations + Futureproof's proprietary financial model — all of which compound. AI lets us realise the unit economics; it doesn't lock anyone out.

### "Why won't a competitor copy this in 12 months?"

The model has taken years of financial and legal engineering. A competitor copying the AI layer in 12 months still wouldn't have Futureproof's proprietary financial model, the regulatory permissions stack, or the institutional partner ecosystem (Accenture, Jones Day, BlackRock, Lockton, Atlas SP / Apollo, EY, Dentons) — those are the moat, and they don't compress under AI pressure.

---

## Code references (data room)

- `app/services/customer_support_service.rb` — Live customer-facing AI (331 lines)
- `app/services/claude_chat_service.rb` — Claude API orchestration with tool use + caching
- `app/services/agent_decision_service.rb` — Application evaluation (rule-based; LLM-ready)
- `app/services/agent_lifecycle_service.rb` — Agent provisioning / state management (497 lines)
- `app/services/admin_agent_metrics_service.rb` — Agent performance metrics
- `app/models/ai_agent.rb` — AI agent model with type validation (applications/backoffice/investment)
- `app/models/chat_agent.rb`, `chat_conversation.rb`, `chat_message.rb` — Conversation persistence
- `app/models/agent_task.rb`, `agent_action.rb`, `agent_performance.rb` — Action audit & metrics

For diligence: we will demo the customer-facing AI live, walk through the guardrails in code, and show the Financial Model (AI Cost Detail). The roadmap items show in the model as budget lines tied to specific quarters.

---

## What's NOT in this document (and why)

- **Specific prompts** — those are operational IP and live in the codebase, not in pitch material
- **Agent inventory in detail beyond what's listed** — happy to walk through under NDA in second meeting
- **Vendor lock-in analysis** — short answer: architecture isolates the LLM call; we can swap providers in days, not months. Long answer in second meeting.
- **Failure-mode telemetry / monitoring approach** — production-engineering depth, second-meeting topic
