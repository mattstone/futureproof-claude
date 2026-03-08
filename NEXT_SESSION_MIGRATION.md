# NEXT SESSION: MIGRATE WORK FROM WRONG PROJECT

**CRITICAL:** Do NOT repeat the amnesia. This document lives in workspace (survives session reset).

---

## What Was Built on WRONG PROJECT
**Location:** `/Users/zen/projects/internetschminternet/future-proof-rails.WRONG_PROJECT/` (renamed to prevent accidents)

**Sessions affected:** 14, 15, 16 (2026-03-08)

**Work summary:**
1. ✅ Broker model + authentication (Devise)
2. ✅ Broker-Lender relationship (join table + access control)
3. ✅ Broker portal (dashboard, application list, EPM tracking)
4. ✅ Lender broker management (add/remove/enable/disable brokers)
5. ✅ Admin broker management (global enable/disable)
6. ✅ Broker performance reporting (lender dashboard)
7. ✅ Lenders admin refactoring (simplified UI, jurisdiction filtering)
8. ✅ Country code standardization (ISO 3166-1 alpha-2)

**Total commits on wrong project:** 26+ commits (all need recreation on `/Users/zen/projects/futureproof/futureproof/`)

---

## What to Migrate to CORRECT PROJECT

### 1. BROKER FEATURE (Sessions 15-16)

**Design Requirements (LOCKED BY MATTHIEU 2026-03-08 18:09):**
1. Brokers see their own applications + EPM performance
2. Lender controls what brokers can see (via BrokerLender permissions)
3. Brokers access customer personal info (name, email, phone, property)
4. Lenders report on broker performance (apps, success rate, EPM value)

**Models to Create:**
```ruby
# app/models/broker.rb
class Broker < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable
  has_many :broker_lenders, dependent: :destroy
  has_many :lenders, through: :broker_lenders
  has_many :applications, dependent: :nullify
  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }
end

# app/models/broker_lender.rb
class BrokerLender < ApplicationRecord
  belongs_to :broker
  belongs_to :lender
  validates :broker_id, uniqueness: { scope: :lender_id }
end

# Modifications to Application model:
# - Add: belongs_to :broker, optional: true
# - Add: scope :by_broker, ->(broker) { where(broker_id: broker.id) }

# Modifications to Lender model:
# - Add: has_many :broker_lenders, dependent: :destroy
# - Add: has_many :brokers, through: :broker_lenders
```

**Migrations to Create:**
```ruby
# db/migrate/TIMESTAMP_devise_create_brokers.rb
# - Create brokers table with Devise fields
# - Add columns: name:string, phone:string, active:boolean (default true)

# db/migrate/TIMESTAMP_create_broker_lenders.rb
# - Create broker_lenders table
# - Add columns: broker_id, lender_id, active:boolean (default true)
# - Add uniqueness constraint on (broker_id, lender_id)
# - Add indexes

# db/migrate/TIMESTAMP_add_broker_to_applications.rb
# - Add broker_id to applications (nullable, foreign key)
```

**Controllers to Create:**
```ruby
# app/controllers/broker/applications_controller.rb
# - Devise authentication (:authenticate_broker!)
# - Index: list broker's applications filtered by assigned lenders
# - Show: display application details + applicant info + distributions
# - Access control: authorize_broker_can_view!(application)

# app/controllers/admin/brokers_controller.rb (if admin dashboard exists)
# - Index, new, create, show, edit, update
# - Toggle active/inactive globally
# - Show which lenders broker is assigned to
```

**Views to Create:**
```erb
# app/views/broker/applications/index.html.erb
# - Stats cards: total apps, pending, approved, rejected
# - Table: applicant names, status, lender, applied date
# - Actions: link to show each app

# app/views/broker/applications/show.html.erb
# - Applicant info: name, email, phone, property
# - EPM performance: equity investment, equity %, term
# - Distribution history: date, amount, status

# app/views/admin/brokers/index.html.erb (optional)
# - List all brokers, stats, enable/disable toggle

# app/views/admin/brokers/show.html.erb (optional)
# - Broker details, assigned lenders
```

**Routes to Configure:**
```ruby
# config/routes.rb
namespace :broker do
  root 'applications#index'
  resources :applications, only: [:index, :show]
end

# Optional admin routes (if admin dashboard exists):
# resources :admin/brokers do
#   member { post :toggle_active }
# end
```

**Services to Create:**
```ruby
# app/services/broker_performance_service.rb
# - Calculates stats for lender dashboard
# - Metrics: applications count, approved count, success rate, EPM value
# - Called by: lender_dashboard#reports (broker report type)
```

**Lender Dashboard Integration:**
```erb
# Add to lender_dashboard/reports view
# New report type: "brokers"
# Shows: broker cards with metrics + sortable table
```

**Seeds to Create:**
```ruby
# db/seeds.rb - append
Broker.create!(
  name: "Broker Alpha",
  email: "alpha@brokers.com",
  password: "SecurePass123!",
  active: true
)

Broker.create!(
  name: "Broker Beta",
  email: "beta@brokers.com",
  password: "SecurePass123!",
  active: true
)

# Assign to lenders
lender = Lender.find_by(name: "Example Lender")
broker_alpha = Broker.find_by(name: "Broker Alpha")
BrokerLender.create!(broker: broker_alpha, lender: lender, active: true)
```

**Verification Checklist:**
- [ ] Broker can sign in at /brokers/sign_in
- [ ] Broker sees /broker/applications with their app list
- [ ] Broker sees applicant personal info (name, contact, property)
- [ ] Broker cannot see other brokers' applications
- [ ] Removing BrokerLender access blocks broker access
- [ ] Lender sees broker performance in dashboard
- [ ] Success rates calculate correctly
- [ ] All migrations ran without errors
- [ ] Seeds created test data

---

### 2. LENDERS REFACTORING (Sessions 14-15)

**What Was Done:**
- Simplified lenders admin UI (removed 1000+ lines, 650+ inline styles)
- Added summary metrics (active lenders, total capital deployed)
- Created compact table layout
- Implemented jurisdiction filtering
- Standardized country codes to ISO 3166-1 alpha-2 (AU, US, NZ, UK)

**Design Pattern Established:**
- Admin index pages: Summary metrics + compact table (reusable pattern)
- Show/edit pages: Compact header + detail cards + related tables
- Jurisdiction filtering: Consistent across all admin pages
- Country codes: Single source of truth (VALID_COUNTRY_CODES constant)

**Files Modified (if exists on correct project):**
- app/views/admin/lenders/index.html.erb
- app/views/admin/lenders/show.html.erb
- app/views/admin/lenders/edit.html.erb
- app/views/admin/lenders/new.html.erb
- app/assets/stylesheets/admin.css (added classes)

**Migrations Needed:**
```ruby
# db/migrate/TIMESTAMP_standardize_country_codes.rb
# UPDATE lenders SET country = UPPER(country) WHERE country != UPPER(country)
```

---

## How to Migrate

### Step 1: Copy Files
```bash
# From WRONG project to CORRECT project
cp /Users/zen/projects/internetschminternet/future-proof-rails.WRONG_PROJECT/app/models/broker.rb \
   /Users/zen/projects/futureproof/futureproof/app/models/

cp /Users/zen/projects/internetschminternet/future-proof-rails.WRONG_PROJECT/app/models/broker_lender.rb \
   /Users/zen/projects/futureproof/futureproof/app/models/

# Controllers
cp /Users/zen/projects/internetschminternet/future-proof-rails.WRONG_PROJECT/app/controllers/broker/ \
   /Users/zen/projects/futureproof/futureproof/app/controllers/ -r

# Views
cp /Users/zen/projects/internetschminternet/future-proof-rails.WRONG_PROJECT/app/views/broker/ \
   /Users/zen/projects/futureproof/futureproof/app/views/ -r

# Services
cp /Users/zen/projects/internetschminternet/future-proof-rails.WRONG_PROJECT/app/services/broker_performance_service.rb \
   /Users/zen/projects/futureproof/futureproof/app/services/
```

### Step 2: Check Schema Compatibility
```ruby
# Verify /Users/zen/projects/futureproof/futureproof has:
# - Lender model with expected fields
# - Application model with expected fields
# - Devise installed for Broker model
```

### Step 3: Create Migrations
```bash
cd /Users/zen/projects/futureproof/futureproof
bundle exec rails generate migration CreateBrokers # Copy from wrong project's migration
bundle exec rails generate migration CreateBrokerLenders
bundle exec rails generate migration AddBrokerToApplications
bundle exec rails db:migrate
```

### Step 4: Update Routes & Add to Admin Dashboard
```ruby
# routes.rb - add Broker portal routes
# admin dashboard - add Broker Management link (if admin exists)
# lender dashboard - add Brokers button (if lender dashboard exists)
```

### Step 5: Test
```bash
bundle exec rails console
# Test: Broker.create!, BrokerLender.create!, Application.by_broker
# Test: /broker, /broker/applications routes
# Test: Lender can see broker performance
```

---

## WARNINGS - What NOT to Do

🚨 **DO NOT:**
- Copy migrations blindly — they may need timestamp adjustments
- Use wrong project's routes.rb — merge carefully
- Assume Devise is configured same way — verify config/initializers/devise.rb
- Copy admin views if admin dashboard structure is different
- Assume Application model has same fields (check schema.rb first)

✅ **DO:**
- Check `/Users/zen/projects/futureproof/futureproof/db/schema.rb` for field names
- Read `/Users/zen/projects/futureproof/futureproof/.claude-on-rails/context.md` for rules
- Test each feature after migration (don't bulk migrate + test)
- Run `bundle exec rails test` after each change
- Verify git status is clean before major work

---

## Exact Commit History to Reference

**Wrong Project Commits (for reference only):**
1. `3901c90` — Task 1: Broker model + BrokerLender + Application tagging
2. `76b780f` — Task 2: Seed data + Broker fields
3. `0fe9019` — Task 3: Broker portal + access control
4. `693dbf0` — Task 4: Lender broker reporting service
5. `eddf899` — Merge admin_dashboard.css into admin.css
6. `39b8bc4` — Revert layout change
7. `b247e81` — Consistent admin layout + jurisdiction switcher
... and 19 more (see wrong project git log)

---

## Session Script for Next Session

**BEFORE DOING ANYTHING:**
1. ✅ Read this file (you're reading it now)
2. ✅ Open `/Users/zen/projects/internetschminternet/future-proof-rails.WRONG_PROJECT/` to reference
3. ✅ Confirm correct project path: `/Users/zen/projects/futureproof/futureproof/`
4. ✅ Check schema.rb for field names + relationships

**THEN:**
1. Migrate Broker models
2. Create migrations (adjust timestamps)
3. Copy controllers
4. Copy views (adjust paths if needed)
5. Update routes
6. Run migrations
7. Test each step
8. Commit with clear messages
9. **Document what was done in MEMORY.md**

---

## DO NOT LET THIS HAPPEN AGAIN

This document exists to prevent amnesia. 

**Rules:**
- ✅ ALWAYS save important work in workspace (not just project git)
- ✅ ALWAYS create migration guides BEFORE session ends
- ✅ ALWAYS tag sessions with project name (Session 16: FutureProof wrong project — IGNORE)
- ✅ ALWAYS verify project path BEFORE starting: `pwd` → confirm `/futureproof/futureproof/`
- ✅ ALWAYS commit to CORRECT project repo

**This session:** Created `/Users/zen/.openclaw/workspace/NEXT_SESSION_MIGRATION.md` (this file) to survive session reset.

---

## Success Criteria for Next Session

✅ **Done when:**
- Broker model working on correct project
- Broker can sign in
- Broker can see their applications
- Lender can manage brokers
- All tests passing
- All work committed to `/Users/zen/projects/futureproof/futureproof/` git
- MEMORY.md updated with completion note
- Wrong project files backed up (not deleted, just in case)

