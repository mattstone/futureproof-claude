# Integration Tests

## Overview

Integration tests verify the complete customer journey through the EPM platform, from account creation through to a fully activated application.

## Test Scenarios

### 1. Customer Application Journey (`customer_application_journey_test.rb`)

**Purpose:** Validate the complete customer application flow

**What it tests:**
- Borrower account creation
- Application submission with property/income details
- Lender approval workflow
- Document generation and delivery
- Document upload and verification
- Loan activation
- Payment processing
- Borrower portal access

**Scenario:**
- Customer: John Doe (65-year-old, primary residence)
- Property: $750,000 Sydney home
- Loan: $300,000 (40% LTV)
- Mortgage: EPM Standard (1.5% guaranteed income)
- Outcome: Full loan activation with payments commencing

**Status:** Ready to run (see instructions below)

---

## Running Integration Tests

### Prerequisites

```bash
# Ensure database is set up
bin/rails db:prepare

# Clear test database
bin/rails db:test:purge
```

### Run all integration tests

```bash
bin/rails test test/integration/
```

### Run specific test

```bash
bin/rails test test/integration/customer_application_journey_test.rb
```

### Run with verbose output

```bash
bin/rails test test/integration/ -v
```

---

## Expected Output Example

```
Running 1 tests in a single process (parallelization threshold is 50)
Run options: --seed 12345

# Running:

======================================================================
CUSTOMER APPLICATION JOURNEY - FULL INTEGRATION TEST
======================================================================

✓ Step 1: Borrower account created (john.doe@example.com)
✓ Step 2: Application created (ID: 1, Status: created)
✓ Step 3: Property details filled (Address: 123 Main Street, Sydney NSW 2000)
✓ Step 4: Income & loan details filled (Loan Amount: $300000)
✓ Step 5: Application submitted (Status: submitted)
✓ Step 6: Application approved by lender
✓ Step 7: Documents generated (4 documents)
✓ Step 8: Borrower can view documents in portal
✓ Step 9: Borrower downloads documents
✓ Step 10: Required documents uploaded by borrower
✓ Step 11: Documents verified by admin
✓ Step 12: Application activated
✓ Step 13: Final verification - Application fully uploaded and complete

======================================================================
✅ FULL CUSTOMER JOURNEY COMPLETE
======================================================================
   Application ID: 1
   Borrower: john.doe@example.com
   Final Status: activated
   Total Documents: 7
   Verified Documents: 7
   Active Distributions: 1
======================================================================

Finished in 2.345678s, 0.4268 runs/s, 6.8000 assertions/s.
1 runs, 13 assertions, 0 failures, 0 errors, 0 skips
```

---

## Manual Test Scenario

For a complete step-by-step manual walkthrough, see: `TEST_SCENARIO.md`

This provides detailed instructions for manually testing the same flow through the web UI.

---

## Troubleshooting

### Model Loading Errors

If you encounter errors like "wrong number of arguments" when running tests:

1. Clear cache:
```bash
bin/rails cache:clear
```

2. Reload database:
```bash
bin/rails db:test:prepare
```

3. Run tests again:
```bash
bin/rails test test/integration/customer_application_journey_test.rb -v
```

### Database State Issues

If tests fail with foreign key errors:

```bash
# Reset database completely
bin/rails db:drop RAILS_ENV=test
bin/rails db:create RAILS_ENV=test
bin/rails db:migrate RAILS_ENV=test
bin/rails test test/integration/
```

### Flaky Tests

Some tests may be timing-dependent. Increase timeout if needed:

```bash
TIMEOUT=30 bin/rails test test/integration/
```

---

## Test Coverage

| Component | Coverage | Notes |
|-----------|----------|-------|
| Account Creation | ✅ Full | Email verification tested |
| Application Flow | ✅ Full | All 5 status transitions |
| Lender Approval | ✅ Full | Loan amount, rate, term |
| Document Generation | ✅ Full | 3 system documents + borrower |
| Document Upload | ✅ Full | Upload + verification flow |
| Loan Activation | ✅ Full | Status change + payment creation |
| Borrower Portal | ⚠️ Partial | Access verified, detailed interactions need manual testing |
| Payments | ✅ Full | First distribution created |
| Email Notifications | ⚠️ Partial | Queued for delivery, not verified |

---

## Adding New Test Scenarios

To add new integration test scenarios:

1. Create file: `test/integration/[feature]_journey_test.rb`
2. Inherit from `ActionDispatch::IntegrationTest`
3. Define private helper methods for each step
4. Call helpers in test method with assertions

Example:

```ruby
class AlternativeScenarioTest < ActionDispatch::IntegrationTest
  test "alternative borrower scenario" do
    # Step 1
    borrower = create_borrower
    assert borrower.persisted?
    
    # Step 2
    application = start_application(borrower)
    # ... etc
  end
  
  private
  
  def create_borrower
    # Create and return test borrower
  end
  
  def start_application(borrower)
    # Create and return test application
  end
end
```

---

## CI/CD Integration

These tests are designed to run in CI pipelines:

```yaml
# Example GitHub Actions
- name: Run Integration Tests
  run: bin/rails test test/integration/
```

---

## Next Steps

1. ✅ Review `TEST_SCENARIO.md` for full manual flow
2. ✅ Run integration tests: `bin/rails test test/integration/`
3. ✅ Perform manual testing if integration tests pass
4. ✅ Add additional scenarios as needed
