## 🔴 CRITICAL RULES

### Data Safety (ZERO TOLERANCE)
- **NEVER:** `rails db:drop`, `rails db:reset`, delete/truncate records without explicit permission
- **ALWAYS:** Ask before any schema change, data operation, or seeds that overwrite

### Deployment Safety
```bash
fly auth whoami    # Verify correct account
fly status         # Verify correct app
fly deploy --remote-only  # Only after above 2 pass
```

### CSP Compliance (STRICT)
- ❌ NO inline styles, scripts, event handlers
- ✅ All CSS in `/app/assets/stylesheets/`, all JS in `/app/javascript/`
- ✅ Use Stimulus `data-action` for interactivity
- Run `bin/rails csp:report` before every commit

### CSS Framework (100% CUSTOM)
- ❌ NO Tailwind, Bootstrap, or external framework classes
- ✅ Use custom classes from `/app/assets/stylesheets/admin.css` and `design_system.css`
- ✅ Design system: `fp-btn`, `fp-card`, `fp-input`, `fp-badge`, `fp-alert`
- ✅ Admin: `admin-form-*`, `admin-table`, `status-badge`

### Architecture Rules
- ✅ **Stimulus only** for UI (drag/drop, animations, toggles)
- ❌ **No AJAX/Turbo** for business logic
- ✅ All business logic server-side (Rails controllers/services)

---

## 📋 PROJECT CONTEXT

**Stack:** Rails 8.1.2 | Ruby 3.4.8 | PostgreSQL | Stimulus | Custom CSS  
**Dev Server:** http://localhost:3001  
**Production:** https://www.futureprooffinancial.co  
**Regions:** US (default /), AU (/au), NZ (/nz), UK (/uk)  

### Key Files
- `config/regions.yml` — Region configuration (currency, LTV, regulators)
- `app/helpers/region_helper.rb` — Region detection and utilities
- `app/services/calculation_engine.rb` — Multi-region EPM calculator
- `app/services/quote_service.rb` — Tom + Pavel financial models
- `app/services/ai_agent_router.rb` — Chat agent routing
- `app/assets/stylesheets/design_system.css` — Apple HIG design system
- `app/assets/stylesheets/mobile.css` — Responsive breakpoints
- `docs/CAPABILITIES.md` — VC-ready system overview
- `docs/DECISIONS.md` — Design decisions with rationale
- `docs/DEPLOYMENT_CHECKLIST.md` — Pre/post deploy steps

### Key Models
- `User`, `Application`, `Contract`, `Mortgage`
- `Lender`, `WholesaleFunder`, `FunderPool`
- `ChatAgent`, `ChatConversation`, `ChatMessage`
- `AgentPerformance`, `AgentTask`
- `EmailTemplate`, `EmailWorkflow`

### Common Commands
```bash
export PATH="/opt/homebrew/opt/ruby@3.4/bin:/opt/homebrew/lib/ruby/gems/3.4.0/bin:$PATH"
bundle exec rails server -p 3001    # Dev server
bundle exec rails test               # All tests (382 passing)
bundle exec rails test test/services/calculation_engine_test.rb  # Specific
bundle exec brakeman                  # Security audit
bundle exec rubocop                   # Style guide
```

---

## 🧮 FINANCIAL MODEL (EPM)

- **LTV:** Up to 80% | **Terms:** 10, 15, 20, 25, 30 years
- **Investment:** ~70% S&P 500 ETFs, ~30% fixed income
- **Income:** ~1.5% of property value p.a. (Pavel model)
- **Models:** `:tom` (lookup table) and `:pavel` (Monte Carlo validated)
- **Spreadsheet:** `data/Copy of FutureProofCalculator_Pavel_v10.xlsm`

---

## 🧪 TESTING (MANDATORY 7-STEP)

1. Write integration test
2. Run test locally
3. Test actual URL (curl/browser)
4. Verify HTML renders
5. Test user interactions
6. Run full suite
7. Only then claim success

**Current:** 1175+ tests, 0 failures, 0 errors

### Console (post-merge, MANDATORY)
`bin/console-verify` — checks pending migrations, hard-restarts the dev
server (stale schema caches caused live 500s the suite can't see), and
crawls every console route with an authenticated session. Run after every
merge to master before claiming anything works.

---

## 📐 DESIGN PRINCIPLES

See `DESIGN_SYSTEM.md` for full component reference.
See `.claude-on-rails/context.md` for admin styling standards.
