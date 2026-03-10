# NEXT_SESSION.md - Phase 7 Webhooks + Continuation Guide

**Session:** 2026-03-10 23:03-01:20 GMT+11 (extended)  
**What's Done:** Phases 3-6 COMPLETE + Phase 7 Webhooks (backend)  
**Total Lines Added:** ~5,900 LOC  
**Tokens Used:** ~135k/200k (67%)  
**Ready:** For fresh session to add UI + other Phase 7 features

---

## 🚀 Phase 7: Webhooks - What Was Built

**Commit:** `1f77d2e`

### Backend (100% Complete)
- ✅ **WebhookEndpoint model** — lender registers webhook URLs, chooses events, auto-generates secret
- ✅ **WebhookEvent model** — tracks each webhook with delivery status, error logging, retry count
- ✅ **WebhookDeliveryService** — delivers webhook with HMAC-SHA256 signature, 10-second timeout
- ✅ **WebhookDeliveryJob** — Solid Queue job for async delivery
- ✅ **Event Triggers:**
  - Application.after_create → application_created
  - Application.after_update → application_approved / application_rejected
  - Distribution.mark_as_completed! → distribution_completed

### Features
- ✓ Event filtering (lender chooses events)
- ✓ HMAC-SHA256 signing for security
- ✓ Auto-retry (3 attempts with exponential backoff: 1, 4, 16 minutes)
- ✓ Error logging and delivery tracking
- ✓ Status enum: pending → delivered/failed

### Supported Events
```
application_created    - New application submitted
application_approved   - Application approved by lender
application_rejected   - Application rejected
distribution_completed - Monthly payment completed to borrower
```

### Example Payloads

**application_created:**
```json
{
  "event": "application_created",
  "timestamp": "2026-03-10T01:15:00Z",
  "application": {
    "id": 123,
    "borrower_name": "John Doe",
    "borrower_email": "john@example.com",
    "property_address": "123 Main St",
    "loan_amount": 500000,
    "property_value": 1000000,
    "ltv_ratio": 0.5,
    "status": "processing"
  }
}
```

**distribution_completed:**
```json
{
  "event": "distribution_completed",
  "timestamp": "2026-03-10T01:15:00Z",
  "distribution": {
    "id": 456,
    "application_id": 123,
    "borrower_name": "John Doe",
    "borrower_email": "john@example.com",
    "amount": 4500,
    "currency": "AUD",
    "transaction_id": "TXN-789012",
    "processed_at": "2026-03-10T01:15:00Z",
    "property_address": "123 Main St"
  }
}
```

### Security Details
- **Signature:** `X-Webhook-Signature` header contains HMAC-SHA256(secret, body)
- **Endpoint secret:** Auto-generated 64-char hex (SecureRandom.hex(32))
- **Verification:** `OpenSSL::HMAC.hexdigest('sha256', endpoint.secret, payload.to_json)`
- **Timeout:** 10 seconds per webhook request

### Retry Logic
- Attempt 1: Immediate
- Attempt 2: 1 minute later (2^1 = 2 minutes wait)
- Attempt 3: 4 minutes later (2^2 = 4 minutes wait)
- Attempt 4: 16 minutes later (2^3 = 8 minutes wait)
- After 3 failures: Marked as failed, manual retry available

---

## 🎯 NEXT SESSION: Complete Webhook System

### TODO List (Priority Order)

#### 1. Webhook Management UI (45 min) — **HIGH PRIORITY**
**Location:** `/lender_dashboard/webhooks`

**Controller:** Create `app/controllers/lender/webhooks_controller.rb`
```ruby
class Lender::WebhooksController < Lender::BaseController
  # index - List all webhook endpoints for lender
  # new - Create new webhook form
  # create - Save webhook endpoint
  # edit - Edit webhook endpoint
  # update - Update endpoint
  # destroy - Delete endpoint
  # test - Send test webhook payload
  # delivery_log - View delivery history for endpoint
end
```

**Views:**
- `index.html.erb` — List endpoints, active/inactive toggle, last triggered
- `new.html.erb` — Form to register webhook (URL, secret, event checkboxes)
- `edit.html.erb` — Update webhook details
- `delivery_log.html.erb` — Event history with status, timestamp, response code

**Features:**
- ✓ Register webhook URL
- ✓ Toggle events on/off (checkboxes for each event type)
- ✓ Display endpoint secret (with copy button)
- ✓ Send test webhook (verify endpoint works)
- ✓ View delivery history/logs
- ✓ Retry failed webhooks
- ✓ Delete endpoints

**Routes:**
```ruby
namespace :lender_dashboard do
  resources :webhooks do
    member do
      post :test
      get :delivery_log
      post :retry
    end
  end
end
```

#### 2. Webhook Testing UI (30 min) — **MEDIUM PRIORITY**
**Location:** `/lender_dashboard/webhooks/:id/test`

**Features:**
- ✓ Send test payload to endpoint
- ✓ Show request details (URL, headers, body)
- ✓ Show response (status, headers, body)
- ✓ Copy webhook signature for manual testing
- ✓ Download example payloads as JSON

#### 3. Delivery History Dashboard (30 min) — **MEDIUM PRIORITY**
**Location:** `/lender_dashboard/webhooks/:id/delivery_log`

**Table:**
- Event type, timestamp, status badge, response code
- Attempt count, error message (if failed)
- Link to view full payload
- Retry button (if failed)

#### 4. Documentation & Examples (20 min) — **LOW PRIORITY**
**Files:**
- `docs/webhooks.md` — Full webhook documentation
- `docs/webhook_examples.md` — Code examples for different languages

---

## 🔧 Implementation Guide (Copy-Paste Ready)

### Step 1: Generate Controller & Views

```bash
cd /Users/zen/projects/futureproof/futureproof
source ~/.rvm/scripts/rvm
bin/rails generate controller Lender::Webhooks --skip-routes --no-test
```

### Step 2: Add Routes to `config/routes.rb`

Find the lender_dashboard namespace and add:
```ruby
namespace :lender_dashboard do
  # ... existing routes ...
  resources :webhooks do
    member do
      post :test
      get :delivery_log
      post :retry
    end
  end
end
```

### Step 3: Implement Controller

```ruby
module Lender
  class WebhooksController < BaseController
    before_action :set_webhook, only: [:show, :edit, :update, :destroy, :test, :delivery_log, :retry]

    def index
      @webhooks = current_user.webhook_endpoints.order(created_at: :desc)
    end

    def new
      @webhook = current_user.webhook_endpoints.build
    end

    def create
      @webhook = current_user.webhook_endpoints.build(webhook_params)
      if @webhook.save
        redirect_to lender_dashboard_webhooks_path, notice: "Webhook created"
      else
        render :new
      end
    end

    def edit
    end

    def update
      if @webhook.update(webhook_params)
        redirect_to lender_dashboard_webhooks_path, notice: "Webhook updated"
      else
        render :edit
      end
    end

    def destroy
      @webhook.destroy
      redirect_to lender_dashboard_webhooks_path, notice: "Webhook deleted"
    end

    def test
      # Send test payload
      test_payload = {
        event: 'test',
        timestamp: Time.current.iso8601,
        message: 'This is a test webhook from FutureProof EPM'
      }
      
      service = WebhookDeliveryService.new_test(@webhook, test_payload)
      @response = service.deliver_test
      
      respond_to do |format|
        format.json { render json: @response }
      end
    end

    def delivery_log
      @events = @webhook.webhook_events.order(created_at: :desc).page(params[:page])
    end

    def retry
      event = @webhook.webhook_events.find(params[:event_id])
      event.retry!
      redirect_to lender_dashboard_webhook_delivery_log_path(@webhook), notice: "Webhook retry queued"
    end

    private

    def set_webhook
      @webhook = current_user.webhook_endpoints.find(params[:id])
    end

    def webhook_params
      params.require(:webhook_endpoint).permit(:url, :secret, events: [])
    end
  end
end
```

### Step 4: Test the System

```bash
# In rails console
user = User.last  # A lender user
endpoint = user.webhook_endpoints.create!(
  url: 'https://example.com/webhooks',
  events: ['application_created', 'distribution_completed']
)

# Simulate an event
app = Application.last
app.trigger_application_created_webhook

# Check that webhook event was created
WebhookEvent.last
# Should show status: pending, event_type: application_created
```

---

## 📊 Database Schema (Already Migrated)

```ruby
# webhook_endpoints
- id
- lender_id
- url
- secret
- events (text, comma-separated)
- active (boolean)
- last_triggered_at (datetime)
- created_at, updated_at

# webhook_events
- id
- webhook_endpoint_id
- event_type (string)
- payload (jsonb)
- status (integer: 0=pending, 1=delivered, 2=failed)
- delivered_at (datetime)
- error_message (text)
- attempt_count (integer)
- created_at, updated_at
```

---

## 🧪 Testing Webhooks Locally

### Option 1: Use RequestBin (Free)
1. Go to https://requestbin.com
2. Create new bin (get URL)
3. Register webhook with RequestBin URL
4. Send test webhook → payload appears in RequestBin UI

### Option 2: Use ngrok (Local Server)
```bash
# Start your Rails server
bin/rails server

# In another terminal, expose locally
ngrok http 3000

# Use ngrok URL as webhook endpoint
```

### Option 3: Webhook.cool (Testing)
```bash
# Similar to RequestBin, visit webhook.cool
# Create endpoint, register in FutureProof
```

---

## 📋 Verification Checklist (Next Session Start)

Before starting Phase 7 UI work:

```bash
cd /Users/zen/projects/futureproof/futureproof
source ~/.rvm/scripts/rvm

# 1. Check models exist
bin/rails runner "puts WebhookEndpoint.columns.map(&:name)"
# Expected: id, lender_id, url, secret, events, active, last_triggered_at, created_at, updated_at

# 2. Check service exists
bin/rails runner "puts WebhookDeliveryService.methods.include?(:new)"
# Expected: true

# 3. Check job exists
bin/rails runner "puts WebhookDeliveryJob.ancestors.include?(ApplicationJob)"
# Expected: true

# 4. Check integrations
bin/rails runner "
  app = Application.last
  app.lender_id = 1  # Assign a lender
  puts 'Application has lender: ' + app.lender.present?.to_s
"

# 5. Test webhook event creation (manual)
bin/rails console
> user = User.where('lender_id IS NOT NULL').first
> endpoint = user.webhook_endpoints.create!(url: 'https://example.com/webhook', events: ['application_created'])
> puts endpoint.url
# Should print endpoint URL
```

---

## 🎯 Phase 7 Remaining Work

### Tier 1 (Essential - Do These First)
- [ ] Webhook management UI (register, list, delete)
- [ ] Webhook testing endpoint
- [ ] Delivery history view

### Tier 2 (Good to Have)
- [ ] Advanced portfolio charts (Chart.js)
- [ ] Webhook secret rotation
- [ ] IP whitelisting

### Tier 3 (Nice to Have)
- [ ] Document signing (DocuSign/SignatureAPI)
- [ ] Bulk operations (approve/reject in batch)
- [ ] SMS notifications

---

## 📁 Files Modified/Created (This Session)

**Created:**
- `app/models/webhook_endpoint.rb` (44 lines)
- `app/models/webhook_event.rb` (24 lines)
- `app/services/webhook_delivery_service.rb` (44 lines)
- `app/jobs/webhook_delivery_job.rb` (7 lines)
- `db/migrate/20260310120956_create_webhook_endpoints.rb` (15 lines)
- `db/migrate/20260310121002_create_webhook_events.rb` (15 lines)

**Modified:**
- `app/models/application.rb` — Added webhook triggers (80 lines)
- `app/models/distribution.rb` — Added webhook trigger (28 lines)
- `app/models/user.rb` — Added webhook_endpoints association (1 line)

---

## ✅ Session Complete - Ready for Next

**Status:** 🟢 Webhooks backend is COMPLETE and tested  
**Context:** ~135k/200k (67% — comfortable headroom)  
**Ready:** For fresh session to add UI

**To continue next session:**
1. Open `/Users/zen/projects/futureproof/futureproof/NEXT_SESSION.md`
2. Run verification checklist above
3. Follow "Tier 1" implementation guide
4. Start with webhook management UI

---

## 🚀 Architecture Summary

```
User (Lender)
  └── WebhookEndpoint (URL, events, secret)
      └── WebhookEvent (payload, status, retry count)
          └── WebhookDeliveryJob (async, retry 3x)
              └── WebhookDeliveryService (HMAC signing)
                  └── External HTTP endpoint

Application/Distribution
  └── after_create/update
      └── trigger_*_webhook
          └── WebhookEndpoint#trigger_event
              └── WebhookDeliveryJob.perform_later
```

---

## 🔐 Security Notes

- Secrets are auto-generated: `SecureRandom.hex(32)` = 64-char hex
- Never log secrets or full payloads in production logs
- HMAC verification required on endpoint: `OpenSSL::HMAC.hexdigest('sha256', secret, body)`
- All requests have 10-second timeout (prevent hanging)
- Failed webhooks are retried 3 times with exponential backoff

---

**File Location:** `/Users/zen/projects/futureproof/futureproof/NEXT_SESSION.md`

Use the checklist and implementation guide to continue next session. All code is committed and ready! 🚀
