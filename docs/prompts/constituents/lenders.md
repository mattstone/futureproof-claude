# Constituent: Lenders (the tenant foundation — the spine)

Inherit: `../master.md`. Build this **first** — every other constituent runs inside a resolved tenant.

A lender is a **tenant**: a branded, isolated instance running on the platform under its own licence. One or several per market. This file owns the multi-tenancy machinery; other contexts consume it via `Tenancy.*` and `Current.tenant`.

---

## Domain model

**Central schema (`CentralRecord`) — the registry:**

```
Market               (PK code)
  code            string   # 'AU' | 'NZ' | 'UK' | 'US'
  currency        string   # 'AUD' ...
  regulator       string
  ltv_ceiling     decimal  # e.g. 0.80
  distribution_modes string[] # ['self_service'] | ['adviser_led'] | both
  residency_region string  # cluster/region the tenant DBs live in
  allowed_product_versions string[]
  config_bounds   jsonb    # min/max/enum for each tenant-tunable key

Tenant   (a lender)
  id              uuid
  market_code     fk -> Market.code
  name            string
  slug            string   unique
  status          enum     # provisioning | active | suspended | closed
  schema_name     string   unique         # e.g. "lender_acme_au"
  database_url    string   nullable        # set only when promoted to own DB
  licence_ref     string
  theme           jsonb    # brand tokens (colour, logo url, type, copy)
  config          jsonb    # tenant overrides, validated vs Market.config_bounds
  has_many :tenant_domains

TenantDomain
  tenant_id       fk
  host            string  unique           # "acme.com.au"
  primary         boolean
```

**No business tables in the central schema.** Applicants, applications, quotes, mortgages, etc. live in each tenant's own schema (owned by the other constituents, created as `TenantRecord`).

## Interfaces (the `Tenancy` facade)
```
Tenancy.resolve!(host)                      -> Tenant            # raises UnknownTenant (404)
Tenancy.with(tenant) { ... }                -> yields with Current.tenant + connection set
Tenancy.provision(market:, name:, slug:,
                  domains:, licence:, theme:) -> Result(Tenant)
Tenancy.config(tenant)                      -> Config            # market defaults + validated overrides
Tenancy.set_config(tenant, key, value)      -> Result            # rejects out-of-bounds (Market.config_bounds)
Tenancy.migrate_all                         -> Result            # run tenant migrations across every schema/DB
```

## Rules & invariants
- A `TenantRecord` query with **no resolved tenant raises** (never returns central or cross-tenant rows).
- `set_config` validates against `Market.config_bounds` at write time; a value outside bounds is rejected, not clamped.
- Pricing / actuarial / business rules are **not** tenant config — they live in the product brain. Tenant config = branding, domains, language, contact, distribution mode, and market-permitted toggles only.
- A `suspended` tenant resolves but is read-only to customers; `provisioning` is not yet customer-reachable.

## Business rules (markets & config)
Each `Market` carries the jurisdiction's rules; a lender configures only within these bounds. (Source: `config/regions.yml`, `EpmJurisdictionService`.)

| Market | Currency | LTV ceiling | Property value | Min age | Regulator / licence | Data & consumer framework |
|---|---|---|---|---|---|---|
| AU | AUD | 80% | $500k–$10m | 55 | ASIC / AFSL | Privacy Act 1988; NCCP Act 2009 |
| US | USD | 80% | $500k–$10m | 62 | CFPB / NMLS | State privacy (CCPA…); TILA/RESPA/Dodd-Frank |
| NZ | NZD | 80% | $500k–$10m | 60 | FMA / FAP | Privacy Act 2020; CCCFA 2003 |
| UK | GBP | 80% | £300k–£10m | 55 | FCA / FCA authorisation | UK GDPR/DPA 2018; FCA Consumer Duty |

- A lender must have a valid market and hold the jurisdiction's licence; only one `futureproof` platform lender entity exists (`Lender`).
- **Config bounds:** a tenant may set branding / domains / language / distribution mode and market-permitted toggles; it may **not** set pricing, an LTV above the ceiling, or anything outside `Market.config_bounds`. Validated at write time.
- **Distribution mode** per market: self-service and/or adviser-led (UK is adviser-led for advice).
- Each market's data stays **resident in its jurisdiction** (master §5).

## Build slices (ordered; each ships behind CI green)

1. **Central registry.** `Market`, `Tenant`, `TenantDomain` models + migrations in the central schema; seed AU market. *Done when:* a Tenant + its market config can be created and read in console.
2. **Tenant resolver + connection switching.** Rack middleware host→tenant; `Current.tenant`; `Tenancy.with`; `TenantRecord` base sets `search_path`. *Done when:* a request to a tenant host runs against that tenant's schema; an unknown host → 404; **the isolation test passes** (tenant A can't see tenant B; unresolved query raises).
3. **Config + white-label theming.** `Tenancy.config` / `set_config` with bounds validation; theme tokens → CSS custom properties; per-tenant layout. *Done when:* two tenants render with different brands from one codebase; an out-of-bounds config write is rejected.
4. **Provisioning operation.** `Tenancy.provision`: create record → `CREATE SCHEMA` → run tenant migrations → seed + theme → register domains/TLS → smoke test (resolve host, render journey, request a quote). *Done when:* one command stands up a new lender and the smoke test passes.
5. **Tenant migration runner.** `Tenancy.migrate_all` iterates schemas (+ promoted DBs); reversible. *Done when:* a new tenant migration applies to all tenants and rolls back cleanly.
6. **Promotion escape hatch.** Move a high-volume/contract-bound tenant to its own database (`database_url`, `connects_to`). *Done when:* a promoted tenant serves traffic with no code change at call sites.

## File / module layout
```
app/domains/tenancy/
  models/        tenant.rb  market.rb  tenant_domain.rb
  services/      tenancy.rb            # the facade
  middleware/    tenant_resolver.rb
  records/       tenant_record.rb  central_record.rb   # base classes (shared via master)
db/central/      # migrations for the registry/control schema
db/tenant/       # migrations applied to every tenant schema
```

## Edge cases & failure modes
- Unknown / unmapped host → 404 (never fall through to a default tenant).
- Background job with no tenant context → must fail loudly, not run against the wrong schema.
- Migration partial failure across N schemas → transactional per schema; runner reports which tenants succeeded/failed and is safe to re-run (idempotent).
- Promoted tenant: the same `Tenancy.with` path works; only the connection target differs.
- Suspended tenant mid-session.

## Dashboard & visualisations
See `master.md` → Dashboards. Per-lender capacity, origination, book health and cost of capital; concentration risk across lenders. Mostly an **FP control-plane** view across lenders; a lender's own portal sees only its slice (tenant-scoped).
- **Lender scorecard table** — per lender: capacity / allocated / available / utilisation % / active + total contracts / weighted cost of capital. *Surfaces:* who's near capacity and what funding costs.
- **Capital-flow Sankey** — funder → pool → lender → status (width = capital). *Surfaces:* how capital reaches each lender and where it's stuck. (Shared with Wholesale Funders; status = EPM states good standing / investment holiday / run-off / settled, **never arrears**.)
- **Concentration index (HHI)** across lenders. *Surfaces:* concentration risk.
- **Origination velocity** — applications / contracts per lender per month. *Surfaces:* who's growing or stalling.
- **Cost-of-capital trend** — weighted cost of capital over time. *Surfaces:* funding-cost drift.

## Tests
The mandatory tenant-isolation class (master §9) lives here. Plus: resolver (host→tenant, unknown→404), config-bounds rejection, provisioning smoke test, migration-runner across two tenants.

## Audience (agents serving lender staff)
Operational, precise, admin-oriented. See `../agents/rie.md`.

Cross-refs: `wholesale-funders.md` (capital that fills a lender's pools), `customers.md` (origination runs inside a tenant), `PLATFORM_BUILD_BRIEF.md` §3.4, §5.
