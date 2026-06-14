# AI Model Governance

**Status:** operating standard (AI_BUILD_SPEC §14.2). **Owner:** Compliance + Engineering.
**Purpose:** how FutureProof governs its use of AI/LLMs as a regulated lender — so every agent is accountable, monitored, and documented to the standard a regulator (ASIC, FCA, CFPB, FMA/NZ) or a funder's risk team would expect.

This is the model-risk discipline applied to LLM agents: the **SR 11-7 mindset** (develop → validate → monitor → document, with effective challenge) and the structure of the **NIST AI RMF** (Govern / Map / Measure / Manage). It folds into the Regional Regulatory Readiness work.

---

## 1. Framework alignment

| NIST AI RMF function | How we meet it |
|----------------------|----------------|
| **Govern** | This document + AI_BUILD_SPEC §14 standards; named owners; the advice wall (§1); change control via git (CTO publishes). |
| **Map** | The agent inventory below — purpose, data, capability level, and risk per agent and per action type. |
| **Measure** | The eval harness (`test/evals/`, gating CI) + production quality signals (escalation/override rates, drift); the audit trail. |
| **Manage** | Capability staircase (§6), human-in-the-loop gate, kill switch, incident runbook, model-upgrade playbook. |

---

## 2. Agent inventory (configuration of record)

Each agent has: an owner, a documented purpose, the data it may touch, its capability level **per action type**, its model tier, and its eval set. Customer-facing agents carry the advice wall.

| Agent | Role | Live today | Data accessed | Tools | Eval set |
|-------|------|-----------|---------------|-------|----------|
| **Akane** | Customer acquisition / support L1–L3 | **Yes** (support chat) | Authenticated user's own applications (read-only) | `get_user_region`, `get_user_applications`, `get_application_status` — all read-only, ownership-scoped | `test/evals/customer_support_eval_test.rb` |
| **Misato** | Customer comms / service | Provisioned | TBD (per gateway phase) | — | TBD |
| **Rie** | Back-office operations | Provisioned | TBD | — | TBD |
| **Yumi** | Investment manager | Provisioned | TBD | — | TBD |
| **Motoko** | Master engineering / ops agent | Dev workflows | Codebase / CI (not customer PII) | dev tooling | — |

As agents move from provisioned to live, this table is updated **in the same PR** that wires them up — it is the register of what's in production.

## 3. Lifecycle controls

- **Prompts are versioned in git** (`docs/prompts/runtime/*`); a change is a reviewed PR and the CTO's merge is the publish. The serving content of every response is recorded (`prompt_slots` sha in `ChatMessage` metadata).
- **Model of record + upgrade playbook.** Each agent's model tier is pinned. On any version bump: re-run the eval suite, re-tune effort/thinking, watch for drift, promote only on green (AI_BUILD_SPEC §14.1). The model that served each response is recorded in the audit trail.
- **Evals gate change.** `test/evals` runs in CI on every PR; promotion up the capability staircase is evidence-led against the agent's eval bar (§8).
- **Capability staircase.** Each action type sits at: always-human → human-on-exception → human-sets-guardrails. Movement is earned on eval evidence and reversible (§6).
- **Advice wall.** Customer-facing agents inform, never give personal financial advice; breaches are S1 incidents.

## 4. Monitoring

- **Audit trail:** every AI response persists `model`, `source` (claude vs deterministic fallback), `usage` (tokens), `prompt_slots`, and `tool_calls` on the `ChatMessage`.
- **Quality signals (maturing):** escalation rate, human-override rate, complaint correlation, eval pass-rate over time, drift alerts (AI_BUILD_SPEC §14.2).
- **Incidents:** handled per `docs/AI_INCIDENT_RUNBOOK.md`; every confirmed incident becomes a permanent eval case.

## 5. Data governance

- **Minimisation:** only the data a turn needs enters the prompt; tools are read-only and scoped to the authenticated user.
- **Residency:** model calls run in the tenant's region; no customer PII transits out of jurisdiction (AI_BUILD_SPEC §2.2).
- **Retention:** conversation transcripts retained under the platform retention policy; metadata kept for audit.
- **No training on customer data:** the Anthropic API does not train on submitted data by default; this is the documented assurance.

## 6. Roles & review cadence

- **Engineering (Motoko team):** prompts, tools, evals, kill switch, model upgrades.
- **Compliance:** advice-wall policy, regulatory notification, redress decisions, this register.
- **CTO:** publishes prompt/model changes (merge = publish).
- **Cadence:** agent register and eval bars reviewed each time an agent's capability changes, and on a standing periodic review as volume grows.

## 7. Regulator mapping

| Region | Regulator | Complaints body |
|--------|-----------|-----------------|
| AU | ASIC | AFCA |
| UK | FCA | FOS |
| US | CFPB | CFPB |
| NZ | FMA / CCCFA | FOS (NZ) |

Customer transparency: customers are told when they are interacting with AI and always have a path to a human (the escalation control) — consistent with the advice wall and our standing avoidance of "robo-advice" framing.

---

_See also: AI_BUILD_SPEC.md (architecture + §14 standards), docs/AI_INCIDENT_RUNBOOK.md (incident loop)._
