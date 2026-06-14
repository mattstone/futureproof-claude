# AI Incident Response & Redress Runbook

**Status:** operating standard (AI_BUILD_SPEC §14.2). **Owner:** Engineering (Motoko team) + Compliance.
**Scope:** any incident where an AI agent (Akane, Misato, Rie, Yumi, Motoko) behaves outside its intended bounds — wrong/misleading answer, leaked proprietary or another customer's data, prompt-injection success, an unapproved or incorrect action, advice-wall breach, or sustained quality degradation.

This is the AI-decision-error runbook. It complements the general outage runbook — an AI incident may not be an outage (the system is "up" and confidently wrong).

---

## 0. The loop

```
Detect → Contain → Remediate → Redress → Post-mortem → Prevent
```

Every AI incident runs this loop. The last step is non-negotiable: a confirmed incident becomes a permanent eval case so it cannot recur silently.

---

## 1. Severity

| Sev | Definition | Examples |
|-----|-----------|----------|
| **S1** | Customer harm, data leak, or regulatory exposure | Another customer's data revealed; proprietary model leaked; advice-wall breach (gave personal financial advice); a wrong consequential action executed |
| **S2** | Customer-facing error, no data/regulatory breach | Materially wrong answer about eligibility/process; repeated mis-escalation; terminology breach ("loan") at scale |
| **S3** | Quality degradation / near-miss | Eval regression in CI; drift-signal alert; an injection probe that got further than expected but didn't leak |

S1 pages Engineering + Compliance immediately. S2 same business day. S3 tracked to the backlog.

---

## 2. Detect

Signals that open an incident:
- **Eval failure** — `test/evals` red in CI, or a live-eval breach (`RUN_LLM_EVALS=1 bin/rails evals:support`).
- **Drift / volume signals** — escalation-rate or human-override-rate spike, complaint correlation (AI_BUILD_SPEC §14.2 monitoring).
- **Direct report** — customer complaint, staff report, or an item surfaced in the support/console queues.
- **Audit review** — `ChatMessage` metadata (`model`, `source`, `usage`, `prompt_slots`, `tool_calls`) flags an anomalous response.

## 3. Contain (stop the bleeding first)

Order of escalation, least to most disruptive:

1. **Global kill switch** — set `AI_ASSISTANT_DISABLED=1` in the Fly environment. Every live model call falls back to the deterministic path (the support knowledge base) instantly, no deploy. Use this for any S1, or any incident you can't immediately scope.
   ```
   fly secrets set AI_ASSISTANT_DISABLED=1   # verify app + account first
   ```
2. **Per-agent disable** — set the agent's `is_active = false` (Console → Development → Agent configuration) to take one agent offline while others keep running.
3. **Capability rollback** — drop the affected action type down the capability staircase (back to "always human") so the agent proposes but no longer acts (AI_BUILD_SPEC §6).
4. **Prompt revert** — if a prompt change caused it, revert the PR that changed `docs/prompts/runtime/*` (git is the ledger; revert = republish).

Record the containment action and timestamp in the incident note.

## 4. Remediate

- Reproduce with the smallest input that triggers it (add it to a scratch eval first).
- Fix at the right layer: prompt rule, tool scope, guardrail regex, capability level, or code.
- Re-enable only when the fix is verified (the new eval case passes) — re-enable in reverse order of containment (prompt → capability → per-agent → clear the global kill switch).

## 5. Redress (customer-facing)

- Identify affected customers from the audit trail (`ChatConversation` / `ChatMessage`).
- Correct the record and proactively contact anyone given materially wrong information.
- For S1 (data leak / advice breach): follow the complaints path the agent itself quotes — acknowledge within 5 business days, full response within 30 — and assess regulatory-notification duties per region (ASIC/AFCA in AU, FCA/FOS in UK, CFPB in US, FOS/CCCFA in NZ). Compliance owns this call.

## 6. Post-mortem (within 5 business days of resolution)

Blameless. Capture:
- Timeline (detect → contain → remediate → redress).
- Root cause and the layer it lived at.
- Why existing guardrails/evals didn't catch it.
- Customer impact and redress taken.
- Actions, each with an owner.

## 7. Prevent — feed the eval set

The incident is not closed until:
- A **permanent eval case** reproducing it is added to `test/evals/customer_support_eval_test.rb` (or the relevant agent's suite) and is green. This is what stops recurrence — the gate now fails if the regression returns.
- Any prompt/guardrail/tool change ships via PR (git ledger), and the model-upgrade or change is noted in `docs/AI_MODEL_GOVERNANCE.md` if it affects an agent's configuration of record.

---

## Quick reference

| Action | How |
|--------|-----|
| Kill all live AI now | `fly secrets set AI_ASSISTANT_DISABLED=1` |
| Take one agent offline | Console → Development → Agent configuration → set inactive |
| Roll back a capability | Drop the action type to "always human" (staircase) |
| Revert a prompt | Revert the `docs/prompts/runtime/*` PR |
| Run the evals | `bin/rails evals:support` (`RUN_LLM_EVALS=1` for the live tier) |
| Find affected customers | Audit trail: `ChatConversation` / `ChatMessage` metadata |
