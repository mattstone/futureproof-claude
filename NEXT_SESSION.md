# NEXT_SESSION.md — Broker Feature Handoff

**Session:** 15 Complete (2026-03-08 16:07-18:01 AEST)  
**Status:** ✅ READY FOR PHASE 1: Broker Model + Auth  
**Context:** 55% token usage — safe to start new session  

---

## What We Just Completed (Session 14-15)

### Admin System Restoration + Refactoring
1. ✅ Fixed critical CSS/layout corruption from Session 13
2. ✅ Standardized country codes (ISO 3166-1 alpha-2: AU, US, NZ, UK)
3. ✅ Wired jurisdiction filtering throughout platform
4. ✅ Refactored lenders admin (index + show/edit/new pages)
5. ✅ 10 clean commits shipped

**Key Commits (latest first):**
- `a9ed7d8` — Compact lenders show/edit/new pages
- `c54f05f` — Apply wholesale funders summary pattern to lenders index
- `75da0e0` — Standardize on ISO 3166-1 country codes
- `fe70966` — Update jurisdiction filtering (multiple formats)
- `85bf092` — Simplify lenders admin + add jurisdiction filtering
- `3dd2f09` — Wire up jurisdiction filtering in dashboard
- `992f9ac` — Include AdminHelper in controller
- `358fe1b` — Make set_jurisdiction a public action
- `b247e81` — Consistent admin layout + jurisdiction switcher
- `eddf899` — Merge admin_dashboard.css into admin.css

### Database Migration Ready
- Migration created: `20260308170530_standardize_country_codes.rb`
- **NOT YET RUN** — do this before starting Broker work
- Converts lowercase country codes to uppercase (AU, US, NZ, UK)

---

## Broker Feature — Requirements (LOCKED IN)

### 1. Broker Portal Visibility
**Brokers see:** Their applications + EPM performance  
**Control:** Lender decides what each broker can see  
**Borrower info:** YES (brokers need to know their customers)

### 2. Lender Dashboard
**Shows:** Which broker sourced each application  
**Reports:** Broker performance (applications, conversion, avg deal size, EPM health)  
**Tracking:** Full broker sourced attribution

### 3. Data Model
```ruby
# Broker table
- id, email, name, country, contact_telephone, contact_telephone_country_code
- Devise auth (encrypted password, etc.)
- timestamps

# BrokerLender join table (many-to-many)
- broker_id, lender_id
- active: boolean (lender controls visibility)
- timestamps

# Applications changes
- Add broker_id (nullable, references brokers)
```

---

## NEXT STEPS — Broker Phase 1 (20-30 mins)

### Task 1: Run Country Code Migration
```bash
cd /Users/zen/projects/futureproof/futureproof
rails db:migrate
```

### Task 2: Create Broker Model + Auth
1. Generate Broker model:
   ```bash
   rails generate model Broker name:string email:string country:string \
     contact_telephone:string contact_telephone_country_code:string
   ```

2. Generate Devise setup for Broker:
   ```bash
   rails generate devise Broker
   ```

3. Add Broker to Devise config (`config/initializers/devise.rb`)

4. Create BrokerLender join table:
   ```bash
   rails generate model BrokerLender broker:references lender:references active:boolean
   ```

5. Add associations to models:
   - `Broker` → has_many :broker_lenders, has_many :lenders through :broker_lenders, has_many :applications
   - `Lender` → has_many :broker_lenders, has_many :brokers through :broker_lenders
   - `Application` → belongs_to :broker (optional)

6. Add validations to Broker model:
   ```ruby
   validates :name, :email, :country, presence: true
   validates :country, inclusion: { in: Lender::VALID_COUNTRY_CODES }
   validates :email, uniqueness: true
   ```

7. Run migrations:
   ```bash
   rails db:migrate
   ```

8. Verify:
   - Broker model generated
   - Devise tables created
   - Associations work in console
   - `Broker.create(...)` works

### Task 3: Broker Routing + Controller
1. Add to `config/routes.rb`:
   ```ruby
   devise_for :brokers
   
   namespace :broker do
     root "dashboard#index"
     resources :applications, only: [:index, :show]
   end
   ```

2. Create BrokerDashboardController:
   ```ruby
   # app/controllers/broker/dashboard_controller.rb
   class Broker::DashboardController < ApplicationController
     before_action :authenticate_broker!
     
     def index
       @applications = current_broker.applications.includes(:user, :lender)
       @total_applications = @applications.count
       @active_applications = @applications.where(status: :accepted).count
     end
   end
   ```

3. Create basic view: `app/views/broker/dashboard/index.html.erb`

### Task 4: Seed Data
Add to `db/seeds.rb`:
```ruby
# Create test broker
broker = Broker.create!(
  name: "Elite Mortgage Brokers",
  email: "broker@example.com",
  country: "AU",
  contact_telephone: "0412345678",
  contact_telephone_country_code: "+61",
  password: "password123",
  password_confirmation: "password123"
)

# Link broker to Futureproof lender
futureproof = Lender.find_by(name: "Futureproof")
BrokerLender.create!(broker: broker, lender: futureproof, active: true)

puts "Created broker: #{broker.email}"
```

---

## Verification Checklist (Phase 1 Success)

- [ ] Migration run successfully (country codes uppercase)
- [ ] `rails console`: Broker model loads, has associations
- [ ] `rails console`: `BrokerLender` model loads
- [ ] Broker can be created: `Broker.create!(...)`
- [ ] Broker can login via `/brokers/sign_in`
- [ ] Broker dashboard route exists: `/broker`
- [ ] Broker dashboard shows "0 applications" (no data yet)
- [ ] Lender can link to broker via BrokerLender
- [ ] Application can be tagged with broker_id
- [ ] No errors in rails test suite

---

## What NOT to Do (Common Mistakes)

❌ Don't create complex dashboard yet (leave for Phase 2)  
❌ Don't add broker performance reporting (Phase 3)  
❌ Don't add lender visibility controls yet (Phase 3)  
❌ Don't create admin broker management UI (Phase 2)  
❌ Don't forget to run the country code migration first

---

## Files to Review Before Starting

1. `/Users/zen/projects/futureproof/futureproof/app/models/lender.rb` — See VALID_COUNTRY_CODES pattern
2. `/Users/zen/projects/futureproof/futureproof/app/models/application.rb` — See how it's structured
3. `/Users/zen/projects/futureproof/futureproof/config/routes.rb` — See devise + namespace patterns

---

## Session Time Estimate

- Migration + model generation: 5 min
- Devise setup: 10 min
- Associations + validations: 5 min
- Controller + view: 10 min
- Testing + verification: 5 min
- **Total: 35 min** (well under budget)

---

## Key Principles for Next Session

1. **Read this file first** — don't infer from memory
2. **Run migration before anything else**
3. **Test in console after each step** — don't assume it works
4. **Commit after Task 4 (seed data)**
5. **Don't add UI complexity** — save for Phase 2

---

## Questions Already Answered

These don't need re-asking:

1. **Broker visibility:** Brokers see their own apps + EPM perf; lenders control what they see
2. **Borrower info:** YES, brokers see full customer details
3. **Lender reporting:** YES, lenders see which broker sourced each app + performance metrics

---

**End of Handoff. Ready to continue in fresh session.**
