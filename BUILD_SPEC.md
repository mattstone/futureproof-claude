# BUILD_SPEC.md — FutureProof: Build Missing Features

**Project:** `/Users/zen/projects/futureproof/futureproof`
**Ruby:** `export PATH="/opt/homebrew/opt/ruby@3.4/bin:/opt/homebrew/lib/ruby/gems/3.4.0/bin:$PATH"`
**Run tests:** `bundle exec rails test` (must stay at 0 failures, 0 errors throughout)
**Current:** 490 tests, 2585 assertions, all passing

---

## What Exists & Works

The platform has a working core loop: Quote → Application → Approval → Distribution.

**Working controllers:** ApplicationsController, DashboardController, PagesController, Admin::* (full admin panel with lenders, mortgages, contracts, email workflows, users, agent dashboard), Lender::ApplicationsController (approve/reject), API::* (quotes, chat, calculations), SupportController, GamesController

**Working models:** User (Devise + admin boolean), Application (full status enum), Lender, MortgageContract, Distribution, AuditLog, Contract, Mortgage, WholesaleFunder, FunderPool, and many more

**Working services:** CalculationEngine, PaymentProcessingService, CustomerSupportService, MockPaymentProcessor

---

## What Needs Building

**⚠️ CRITICAL: See `AUDIT_REPORT.md` - platform is using traditional mortgage logic instead of EPM. This must be fixed before building new features.**

Build each feature below as a self-contained unit. After each one: run `bundle exec rails test`, confirm 0 failures, commit.

### 0. **EPM Logic Fix (Priority: CRITICAL)**

**MUST DO FIRST** - The platform currently implements traditional mortgage logic where borrowers pay monthly amounts to lenders. EPM should work in reverse: lenders invest capital and receive distributions from property performance.

**Files to fix:**
- `app/services/payment_processing_service.rb` - Remove amortization formula, auto-generation
- `app/models/distribution.rb` - Remove monthly payment scopes, add approval workflow  
- Application schema - Rename loan fields to equity fields
- Remove `payment_period_month/year` dependencies

**See AUDIT_REPORT.md for complete analysis and fix recommendations.**

### 1. Borrower Portal (Priority: HIGH)

Logged-in borrowers need a dashboard to view their application, property, loan details, and documents.

**Routes already exist in routes.rb — DO NOT add them again.** They are inside the `scope "/:region"` block at the top of the `namespace :dashboard` section. Check with:
```
bundle exec rails routes | grep borrower_portal
```
If no routes exist, add under the regional scope:
```ruby
get 'borrower_portal/:application_id', to: 'borrower_portal#dashboard', as: 'borrower_portal'
get 'borrower_portal/:application_id/annuity_schedule', to: 'borrower_portal#annuity_schedule'
get 'borrower_portal/:application_id/loan_details', to: 'borrower_portal#loan_details'
get 'borrower_portal/:application_id/property_details', to: 'borrower_portal#property_details'
get 'borrower_portal/:application_id/documents', to: 'borrower_portal#documents'
```

**Create:** `app/controllers/borrower_portal_controller.rb`
```ruby
class BorrowerPortalController < ApplicationController
  before_action :authenticate_user!
  before_action :load_application

  def dashboard; end
  def annuity_schedule; end
  def loan_details; end
  def property_details; end
  def documents; end

  private

  def load_application
    @application = current_user.applications.find(params[:application_id])
    @region = params[:region]
  end
end
```

**Create views** in `app/views/borrower_portal/` — use these **actual Application columns**:
- `address` (string) — property address
- `home_value` (integer) — property value in dollars
- `status` (enum: created, user_details, property_details, income_and_loan_options, submitted, processing, rejected, accepted)
- `region` (string, default "us")
- `property_type` (string)
- `borrower_age` (integer)
- `loan_term` (integer)
- `ownership_status` (enum: individual, joint, trust, company)
- `property_state` (enum: primary_residence, investment, holiday_home)
- `equity_investment_amount` (decimal) — EPM equity investment amount
- `equity_percentage` (decimal) — EPM equity participation percentage
- `participation_term_years` (integer) — EPM participation term
- `existing_mortgage_amount` (decimal)
- `has_existing_mortgage` (boolean)
- `credit_score` (string)
- `property_valuation_low/middle/high` (integers)
- `corelogic_data` (text/JSON)
- `property_images` (text)

**DO NOT use:** `property_address`, `property_valuation_in_cents`, `property_vendor`, `outstanding_mortgage_balance_in_cents`, `application_status` — these don't exist.

**Test:** Integration test — authenticated user can view all 5 pages for their own application, gets 302 for other users' applications.

### 2. Loan Activation (Priority: MEDIUM)

When an application is approved (`status: accepted`), the borrower confirms activation.

**Routes:** Add if not present:
```ruby
get 'loan_activation/:application_id', to: 'loan_activation#show', as: 'loan_activation'
post 'loan_activation/:application_id', to: 'loan_activation#activate', as: 'loan_activation_confirm'
```

**Create:** `app/controllers/loan_activation_controller.rb`
- `show` — display approved terms (approved_loan_amount, approved_interest_rate, approved_term_years)
- `activate` — user confirms, could trigger first distribution or status update

**Create view:** `app/views/loan_activation/show.html.erb`

**Test:** Integration test for the activation flow.

### 3. Lender Dashboard (Priority: HIGH)

Lenders need a portfolio overview. Note: `Lender::ApplicationsController` already exists for approve/reject — this is the overview dashboard.

**Routes:** Add under regional scope:
```ruby
namespace :lender_dashboard do
  get '/', to: 'lender_dashboard#index', as: 'index'
  get 'applications', to: 'lender_dashboard#applications'
  get 'applications/:id', to: 'lender_dashboard#application_detail'
  get 'payments', to: 'lender_dashboard#payments'
  get 'reports', to: 'lender_dashboard#reports'
  get 'account', to: 'lender_dashboard#account'
  patch 'account', to: 'lender_dashboard#update_account'
end
```

**Create:** `app/controllers/lender_dashboard_controller.rb`
- Load `@lender = current_user.lender` (User belongs_to :lender)
- Portfolio from: `Application.where(lender: @lender)`
- Payments from: `Distribution.joins(:application).where(applications: { lender: @lender })`
- Use **actual Lender columns**: `name`, `lender_type` (enum: futureproof/lender), `contact_email`, `country`, `address`, `postcode`
- **NO** `region`, `interest_rate`, `term_years`, `account_status` on Lender

**Create views** in `app/views/lender_dashboard/`

**Test:** Integration test — lender user sees their portfolio.

### 4. Admin Dashboard v2 (Priority: LOW)

The existing `Admin::DashboardController` already provides a full admin panel. This would be a modernized dashboard with metrics. Build ONLY if time permits.

**Note:** There is NO `KycVerification` model. Do not reference it. KYC is a future feature.

**Metrics available from existing models:**
- `User.count`, `Application.group(:status).count`
- `Application.where(status: :accepted).sum(:approved_loan_amount)`
- `Distribution.where(status: :completed).sum(:amount)`
- `MortgageContract.where(is_active: true).count`
- `AuditLog.recent.limit(20)`

### 5. Key Facts Sheet (Priority: LOW)

Legal document auto-populated from application data.

**Create:** `app/controllers/legal_documents_controller.rb` (or add action to existing controller)

**Use actual columns:**
- `@application.equity_investment_amount` (not mortgage_contract.loan_amount)
- `@application.equity_percentage` (not mortgage_contract.interest_rate)
- `@application.participation_term_years` (not mortgage_contract.term_years)
- `@application.home_value` (not property_valuation_in_cents)
- `@application.address` (not property_address)
- `@application.lender` (not mortgage_contract.lender)

### 6. Distribution Dedup Bug (Priority: MEDIUM)

**The bug:** `PaymentProcessingService#process_payment` sets `distribution_date = Date.new(year, month, 1) + 1.month`. The dedup scope `for_month(year, month)` extracts month from `distribution_date`. So March processing creates a distribution dated April 1 — then April processing finds it as "already exists for month 4" and skips.

**Fix options:**
- **Option A (recommended):** Add `payment_period_month` and `payment_period_year` integer columns. Dedup against those instead of distribution_date.
- **Option B:** Set `distribution_date` to first of input month (not +1).

**Files:** `app/models/distribution.rb` (scope), `app/services/payment_processing_service.rb` (date logic), migration if Option A.

After fixing, update `test/integration/end_to_end_workflow_test.rb` — change months back to consecutive (3,4,5,6) and verify 4 distributions created.

---

## Schema Reference

Before writing ANY code, verify columns exist:
```bash
bundle exec rails runner "puts ActiveRecord::Base.connection.columns('TABLE_NAME').map(&:name).sort.join(', ')"
```

### Application
`address, approved_interest_rate, approved_loan_amount, approved_term_years, bank_account_number, borrower_age, borrower_names, company_name, corelogic_data, created_at, credit_score, existing_mortgage_amount, existing_mortgage_lender, government_id, growth_rate, has_existing_mortgage, home_value, id, income_payout_term, lender_id, loan_term, mortgage_id, ownership_status, property_id, property_images, property_state, property_type, property_valuation_high, property_valuation_low, property_valuation_middle, referral_partner_id, region, rejected_reason, status, super_fund_name, updated_at, user_id`

### User
`address, admin, agreed_terms_version, confirmation_sent_at, confirmation_token, confirmed_at, country_of_residence, created_at, current_sign_in_at, current_sign_in_ip, email, encrypted_password, failed_attempts, first_name, id, is_test, known_browser_signatures, last_browser_info, last_browser_signature, last_name, last_sign_in_at, last_sign_in_ip, lender_id, locked_at, phone_number, remember_created_at, reset_password_sent_at, reset_password_token, role_title, sign_in_count, terms_accepted, terms_version, unlock_token, updated_at`

### Lender
`address, contact_email, contact_telephone, contact_telephone_country_code, country, created_at, custom_clause_content, id, lender_type, name, postcode, updated_at`

### MortgageContract
`content, created_at, created_by_id, id, is_active, is_draft, last_updated, mortgage_id, primary_user_id, title, updated_at, version`

### Distribution
`amount, application_id, created_at, distribution_date, failed_at, id, lender_margin, mortgage_id, notes, payment_method, processed_at, status, transaction_id, updated_at`

### AuditLog
`action, application_id, changes, created_at, id, ip_address, kyc_verification_id, notes, reason, region, resource_id, resource_type, updated_at, user_id`
