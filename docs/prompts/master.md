# Master prompt — FutureProof platform (the shared core)

Load this first, then the relevant `constituents/<x>.md` and/or `agents/<y>.md`. This file is the **single source** for the non-negotiables and the shared scaffolding every domain reuses — defined once here, referenced (not restated) elsewhere. When a rule or pattern changes, change it **here**.

Depth lives in two narrative companions — `PLATFORM_BUILD_BRIEF.md` (platform) and `AI_BUILD_SPEC.md` (agents) — but **these prompt files are the canonical build spec**: build from them.

---

## 1. What we're building
One platform, owned by FutureProof, that runs the EPM product. **Licensed lenders run on it — one or several per market** — white-labelled, under their own licence. Two planes: the **control plane** (product brain, funding, agent models, governance — FutureProof owns and runs) and the **execution plane** (the lenders/tenants). A **market** is a jurisdiction (AU/NZ/UK/US); a **lender** is a tenant within a market.

## 2. The product (get this right)
A **mortgage that pays the homeowner**. The customer receives a guaranteed income and **makes no payments** — no repayments, no interest out of pocket. An **investment account** (funded at origination, ~70% S&P 500 ETFs / ~30% fixed income) pays the income and services the mortgage interest. Principal settles at end of term from sale or refinance. Customer-facing name: **Guaranteed Income Plan**; internal/partner name: **EPM**.

## 3. Non-negotiables (never violate)
- **Terminology.** It is a **mortgage**, never a "loan." No repayment schedule, no **arrears**, no collections. If you are modelling repayment or arrears, stop — you've misread the product. The portfolio metric is **Investment Health** / **Holiday %**, never arrears. Say **AI-guided advice**, never "robo-advice." The five agent names are **internal** — a customer never hears them.
- **The advice wall.** Inform, explain, operate. **Never** tell a specific customer the product suits *them* and they should take it — that is personal advice (an AFSL + Statement of Advice in AU; a qualified human adviser in the UK). "Recommend the product to this customer" is not a function that exists.
- **Tenant isolation.** A request, job or agent acts within **one lender**. Isolate per lender (schema/DB per lender); each market's data stays resident in its jurisdiction. No code path or prompt may cross tenants.
- **A human holds every consequential call** until an action type earns autonomy (the staircase, §8).
- **Compliance is jurisdictional.** KYC + AML are required in every market before approval; data stays resident in-jurisdiction; the regulator, licence and consumer-protection framework differ per market (see `constituents/lenders.md` → Markets). **NNEG:** the mortgage never exceeds property value — 100% of the homeowner's equity is preserved. Business rules live in the constituent files; the product/pricing parameters live in the versioned product-model config (the product brain is the source of truth, not application code).

## 4. Architecture
- **Modular monolith.** Bounded contexts as Packwerk packages under `app/domains/<context>/`. A context exposes **one public facade** (a service module); everything else in the package is private. No cross-context model access, no raw SQL, no reaching into another context's tables — go through the facade.
- **Two record base classes:**
  - `CentralRecord` — the shared control-plane schema: `tenants`, `markets`, `tenant_domains`, `product_versions`, the central `audit_events` index. **Holds no customer PII.**
  - `TenantRecord` — a lender's own schema: all business data (applicants, applications, quotes, mortgages, investment accounts, …).
- **Stack:** Rails 8.x, Ruby 3.4, PostgreSQL, Stimulus/Hotwire, custom CSS design system, Solid Queue, Solid Cache, Fly.io. No microservices / Kafka / premature certifications.

## 5. Tenancy runtime (every request and job uses this)
- `Current` (`ActiveSupport::CurrentAttributes`): `Current.tenant`, `Current.market`, `Current.config`, `Current.actor`.
- **Resolver:** Rack middleware maps `request.host` → `TenantDomain` → `Tenant`, sets `Current.tenant`, opens the tenant connection for the request's life. Unknown host → 404.
- **Connection switching:** schema-per-lender via the connection's `search_path` (a promoted/contract-bound lender gets its own database via `connects_to`). Helper: `Tenancy.with(tenant) { ... }` sets and restores.
- **Jobs** carry the tenant id explicitly and re-establish `Current.tenant` + the connection before running.
- **Invariant:** a `TenantRecord` query with no resolved tenant **raises** (never silently returns central or cross-tenant rows). Proven by a mandatory test (§9).

## 6. Domain-interface convention
- Each context's facade is a module of stateless methods that return **value objects** or a `Result` — `Result.ok(value)` / `Result.failure(code, message)`. Never return raw ActiveRecord relations across a context boundary.
- Method signatures are defined in each constituent file. **Agents call only these facades** (exposed as tools, §8).

## 7. Audit (`AuditEvent`)
Every consequential write logs one:
```
AuditEvent { actor, action, subject_type, subject_id, before:, after:, request_id, occurred_at }
```
Central index (`CentralRecord`) + per-tenant detail. The trail must explain **why** anything happened (for agents: + model id, prompt version, context hash).

## 8. AI gateway tool-call contract (for agents)
A **tool** = a domain facade method exposed with a JSON schema. The gateway runs, per turn:
`assemble tenant-scoped context → Claude call → proposed tool call(s) → guardrail check (advice wall + per-agent allow-list) → capability gate (human approval per staircase step) → execute via the facade → audit`.
**Staircase** (per agent, *per action type*): 0 rules · 1 draft (human approves) · 2 decide (human on exceptions) · 3 anticipate (human sets guardrails). Start every action type at step 1. Full detail: `AI_BUILD_SPEC.md`.

## 9. Testing conventions
- Integration-first, then the real path in a browser. The seven-step protocol in `CLAUDE.md` is the standard.
- **Mandatory tenant-isolation test:** tenant A cannot read tenant B; an unresolved-tenant `TenantRecord` query raises. Highest-priority test class.
- **Fixtures** stand up one market + two lenders + representative applicants/properties/quotes.
- **ProductBrain golden-master:** fixed inputs + product version → exact expected quote (reproducibility).
- **CI gates** on every change: full suite, Brakeman (security), RuboCop (style), CSP report. Nothing ships on a red suite.

## 10. Frontend, design & UX
Server-rendered ERB + **Stimulus only** (no SPA; no business logic in JS); **CSP strict** (no inline styles / scripts / handlers); custom CSS only (no Tailwind/Bootstrap); responsive (`mobile.css` breakpoints).

### Design system & tokens
Built on **Apple Human Interface Guidelines**. Custom CSS in `app/assets/stylesheets/design_system.css` (reference: `DESIGN_SYSTEM.md`). **Use the system; don't reinvent components.**
- **Tokens:** colours `--fp-primary #007AFF`, `--fp-success #34C759`, `--fp-warning #FF9500`, `--fp-error #FF3B30`, text `#1D1D1F`/`#636366`, bg `#FFFFFF`/`#F5F5F7`. Type: SF Pro / `-apple-system`; scale xs 11 → 4xl 40. Spacing: 8px grid (4/8/16/24/32/48). Radius 8px.
- **Components:** `fp-btn` (+ primary/secondary/success/danger/outline/sm/lg), `fp-card` / `fp-card-header` / `fp-card-title`, `fp-form-group` / `fp-label` / `fp-input` / `fp-form-hint`, `fp-badge` (+ states), `fp-alert`, `fp-container` / `fp-grid`. Admin: `admin-form-*`, `admin-table`, `status-badge`.

### Theming (white-label per lender)
A per-tenant theme = brand tokens (colour, logo, type, copy) applied as CSS custom properties **over the same components** — one component set, many skins, never per-tenant CSS forks. See `constituents/lenders.md`.

### UX patterns
- **Application journey** — a staged wizard: one decision per step, visible progress, save-and-resume, plain-language microcopy, lead with "what you'll get" (the guaranteed income), never debt framing.
- **Quote / results** — lead with the guaranteed income figure + a clear projection; explain, don't sell (advice wall).
- **Forms** — label + input + hint; inline validation; single column; 44px targets.
- **Cards / grids** — `fp-card` in `fp-grid`; proportional spacing; components don't span full width or "shout."
- **States** — always design empty / loading / error / success; alerts are width-constrained (≈24px side margins), not full-bleed.
- **Status** — `fp-badge` / `status-badge`; EPM-correct labels (good standing / investment holiday), never arrears.

### Design principles
- **Clarity over cleverness** — proportional spacing, width constraints, visual integration (complement, don't clash), consistent 8px radius + palette.
- **Built for the audience** — often older homeowners making a major decision: large legible type, generous targets (44px), high contrast, plain language, no jargon, no debt language. **WCAG 2.1 AA**, reduced-motion + high-contrast support, skip-to-content, visible focus (3px outline).
- **Trust & restraint** — calm, precise, Apple-HIG restraint; a component never dominates its container.
- **Honesty (the advice wall, in UI)** — inform and explain; never pressure or imply "you should." No dark patterns.

### Inspiration & initial design
**Initial design v1** (June 2026): `docs/design/initial_design.html` (render: `docs/design/initial_design.png`) — the customer hero/quote screen + component building blocks. **Hero (locked):** two-column — content + the income/calculator card on the **left** (above the fold, usable without scrolling), the home image (`hero-homepage.png`) shown **large on the right**, feathered on white (no mask/crop — its own soft edges blend). Header = centred `futureproof` wordmark + a primary **Calculate** button (matches John's live homepage). The committed direction:
- **Income-first.** The guaranteed monthly figure is the hero; everything reassures around it.
- **Evolved palette** (proposed — supersedes generic Apple-blue once approved; keeps Apple-HIG structure, SF Pro, 8px grid, soft cards, generous space): navy ink `#1d2b36`, trust teal `#2e7d8a` (primary), **positive green `#1e8a5a` reserved for income/growth**, warm-neutral surface `#f6f5f1`, white cards, amber `#b7791f` for gentle attention.
- **Large & calm for 55+:** 18px base type, high contrast, big targets, plain warm copy; the advice wall shown honestly; no pressure / dark patterns.
- **Basis:** Apple HIG (structure) + the FutureProof navy/teal brand.
- _Still to set (yours):_ reference apps / screenshots for onboarding, the live customer "home" view, and the admin dashboards.
- _Anti-patterns:_ generic AI-slop aesthetics; debt/lender visual language; dense enterprise dashboards.

If the palette is approved, fold these tokens into the design-system list above and seed `app/assets/stylesheets/design_system.css`.

### Dashboards
Stimulus controllers — D3 for Sankey / gauges / heatmaps / bubble; hand-rolled CSS bars for allocation & utilisation. Data via `data-*` value attributes (JSON). **Every dashboard visual must answer a trend-or-issue question.** Use **Investment Health / Holiday %**, never arrears. Each constituent lists its own visuals.

## 11. Data safety
Never drop / reset / truncate / overwrite without explicit permission. Migrations are reversible + idempotent and run across **all** tenant schemas (and promoted databases); a migration that can't run cleanly everywhere doesn't ship. Use the safe-migration pattern (forward-compatible, batched backfill, no destructive drop without a separate approved step).

## 12. The dev loop (per component)
1. **Refresh the prompt** — compose `master.md` + the relevant `constituents/<x>.md` (+ `agents/<y>.md`). That is your spec.
2. **Collect test data** — realistic fixtures that become what the tests run on.
3. **Build** — the smallest slice that meets the slice's acceptance criteria. Server-side logic; Stimulus for UI; act through facades.
4. **Test** — integration-first, the real path, full suite green.
5. **Review** — guardrails (terminology, tenant isolation, advice wall, CSP, no over-engineering); run the quality gate.
6. **Deploy** — behind config; verify in the running app. Branch per slice; PR to **master**; CI green.

## 13. Order
**Spine first** (Lenders/tenancy + product brain + governance) → a thin end-to-end **walking skeleton** (one funder → one lender → one customer → one quote → one mortgage → one investment account) → **deepen each constituent**. See `PLATFORM_BUILD_BRIEF.md` §15.

## 14. Reference (narrative depth — these prompts are the build spec)
- `PLATFORM_BUILD_BRIEF.md` — platform narrative.
- `AI_BUILD_SPEC.md` — agent-layer narrative.
