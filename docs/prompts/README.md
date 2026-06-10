# Build & agent prompts

Layered, composable prompts for building FutureProof and running its agents. This is the concrete form of the prompt architecture in `AI_BUILD_SPEC.md` and the "refresh the prompt" step of the dev loop.

**These prompt files are the canonical build spec.** `PLATFORM_BUILD_BRIEF.md` and `AI_BUILD_SPEC.md` are the narrative companions; build from here.

## The layers
1. **`master.md`** — the shared core + concrete scaffolding every domain reuses: the non-negotiables (advice wall, tenant isolation, terminology), the tenancy runtime (`Current`, resolver, connection switching), the domain-interface and audit conventions, the AI gateway contract, testing/dashboard/data-safety conventions, the dev loop, the build order. Inherited by everything; defined once here.
2. **`constituents/`** — one per domain (`lenders`, `wholesale-funders`, `investments`, `customers`, `brokers`). Each is a **deep build spec**: concrete domain model (tables/fields/state machines), interface signatures, rules/invariants, ordered build slices with **testable acceptance criteria**, file/module layout, edge cases, the dashboard visualisations.
3. **`agents/`** — one per agent (`akane`, `misato`, `rie`, `yumi`, `motoko`). Each is a **runnable system prompt**: identity & voice, tools with schemas, the advice-wall behaviour with examples, refusal/escalation rules, output format, few-shots, and the capability step per action type.

## How to use
- **Building a domain:** context = `master.md` + `constituents/<domain>.md`.
- **Building or running an agent:** context = `master.md` + `agents/<agent>.md` (+ the constituent's audience notes if it serves one).
- That composition **is** "refresh the prompt" (dev loop, step 1).

## The one rule
The non-negotiables — the **advice wall**, **tenant isolation**, **terminology** — live **only in `master.md`**. Never restate them in a constituent or agent file. Duplicated rules drift, and a drifted advice wall is a compliance failure, not a style nit. Change the core in one place.

## Keep current
These are working context, not archives. When the architecture changes, update `master.md`; when a domain or agent changes, update its file. Depth lives in `PLATFORM_BUILD_BRIEF.md` and `AI_BUILD_SPEC.md` — link to them, don't copy.

## Build order
Spine first (Lenders/tenancy + product brain + governance) → a thin end-to-end **walking skeleton** → deepen by constituent. See `master.md` → Order, and `PLATFORM_BUILD_BRIEF.md` §15.
