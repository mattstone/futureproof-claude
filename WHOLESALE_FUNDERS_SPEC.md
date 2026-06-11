# Wholesale Funders Management - Complete Specification

**Priority:** HIGH  
**Scope:** Admin dashboard for managing wholesale funders with jurisdiction switching, sample contracts, and real-time fund tracking  
**Jurisdictions:** AU, US, NZ, UK

---

## Schema Changes

### 1. Add columns to `wholesale_funders` table:
```ruby
t.decimal :total_allocated_amount, precision: 15, scale: 2, null: false, default: 0
# committed_amount and runway_months will be calculated methods, not stored
```

### 2. Create `wholesale_funder_contracts` table:
```ruby
create_table :wholesale_funder_contracts do |t|
  t.references :wholesale_funder, null: false, foreign_key: true
  t.string :jurisdiction, null: false  # AU, US, NZ, UK
  t.text :html_content, null: false    # Sample contract HTML
  t.string :party_type, null: false    # e.g., "Lender Agreement", "Broker Agreement", "Terms of Service"
  t.string :version, default: "1.0"
  t.timestamps
end

add_index :wholesale_funder_contracts, [:wholesale_funder_id, :jurisdiction, :party_type], unique: true, name: 'index_wf_contracts_unique'
```

---

## Models

### WholesaleFunder (existing, add methods)
```ruby
def committed_amount
  # Sum of equity_investment_amount from all active Applications 
  # where lender is in active_lenders
  active_lenders.joins(:applications)
               .where(applications: { status: :accepted })
               .sum('applications.equity_investment_amount')
end

def available_amount
  total_allocated_amount - committed_amount
end

def utilization_percentage
  return 0 if total_allocated_amount == 0
  ((committed_amount.to_f / total_allocated_amount) * 100).round(2)
end

def average_monthly_deployment(months = 12)
  start_date = months.months.ago
  distributions = Distribution.joins(application: [lender: :wholesale_funder])
                              .where(wholesale_funders: { id: id })
                              .where('distributions.created_at >= ?', start_date)
                              .sum(:amount)
  months_count = [months, 1].max
  (distributions / months_count).round(2)
end

def runway_months
  monthly_avg = average_monthly_deployment(12)
  return 999 if monthly_avg == 0 || monthly_avg < 0.01
  (available_amount / monthly_avg).round(1)
end

has_many :wholesale_funder_contracts, dependent: :destroy
```

### WholesaleFunderContract (new model)
```ruby
class WholesaleFunderContract < ApplicationRecord
  belongs_to :wholesale_funder
  
  validates :jurisdiction, presence: true, inclusion: { in: %w[AU US NZ UK] }
  validates :html_content, presence: true
  validates :party_type, presence: true
  validates :wholesale_funder_id, uniqueness: { scope: [:jurisdiction, :party_type] }
  
  scope :by_jurisdiction, ->(jurisdiction) { where(jurisdiction: jurisdiction) }
  scope :by_party_type, ->(party_type) { where(party_type: party_type) }
end
```

---

## Admin Dashboard

### Routes (add to config/routes.rb under namespace :admin)
```ruby
resources :wholesale_funders do
  collection do
    get :by_jurisdiction
  end
  resources :contracts, controller: 'wholesale_funder_contracts', only: [:index, :new, :create, :edit, :update, :destroy]
end
```

### Views Structure
```
app/views/admin/wholesale_funders/
  - index.html.erb          # Main dashboard with jurisdiction switcher
  - show.html.erb           # Detail view (edit inline)
  - _summary_card.html.erb  # Global view card
  - _jurisdiction_table.html.erb # Jurisdiction view table

app/views/admin/wholesale_funder_contracts/
  - index.html.erb          # List contracts for a funder
  - new.html.erb            # Create sample contract
  - edit.html.erb           # Edit contract
```

---

## Admin Dashboard Features

### 1. Global View (Top of page)
- Summary cards showing:
  - Total Allocated (all jurisdictions)
  - Total Committed (all jurisdictions)
  - Total Available (all jurisdictions)
  - Overall Utilization %
  - Jurisdictions with highest utilization (warning if >80%)

### 2. Jurisdiction Switcher
- Dropdown: [All] [AU] [US] [NZ] [UK]
- Switches view below

### 3. Jurisdiction View - Table with columns:
| Column | Content |
|--------|---------|
| Name | Wholesale funder name |
| Country | Country (from jurisdiction) |
| Currency | AUD/USD/GBP/etc |
| Total Allocated | $XXX.XX |
| Committed | $XXX.XX (live calc from active applications) |
| Available | $XXX.XX |
| Utilization | 45% (committed/total) |
| Runway | 24 months (available / monthly_avg) |
| Contracts | [View/Edit] button |
| Actions | [Edit] [Delete] |

### 4. Create/Edit Funder Form
- Name (text, required)
- Country (dropdown: Australia, United States, New Zealand, United Kingdom)
- Currency (dropdown: AUD, USD, GBP, NZD)
- Total Allocated Amount (currency input, required)
- [Save] [Cancel]

### 5. Contracts Management
- Show all sample contracts for selected funder
- Create new contract: jurisdiction + party_type + HTML editor
- Edit/Delete existing contracts
- Sample party types: "Lender Agreement", "Broker Agreement", "Terms of Service"

---

## Implementation Notes

1. **Committed amount calculation:**
   - Query: `active_lenders.joins(:applications).where(status: :accepted).sum(:equity_investment_amount)`
   - Re-calculated on each view (not cached)

2. **Runway calculation:**
   - Distribution data from last 12 months
   - Average = total_distributed_12mo / 12
   - Runway = available_amount / average_monthly
   - If avg is 0, show "unlimited"

3. **Jurisdiction filtering:**
   - Wholesale funders have `country` field
   - "All" view shows all 4 jurisdictions
   - Individual jurisdiction shows only that country's funders

4. **Contracts:**
   - Store as HTML in database
   - Admin can use a simple HTML editor or textarea
   - Each funder can have multiple contracts (one per jurisdiction per party type)

---

## Testing

- Create wholesale funder with $10M allocation
- Deploy $5M via lenders to applications
- Verify committed = $5M, available = $5M, utilization = 50%
- Add distributions over 12 months, verify runway calc
- Test jurisdiction switching

---

## Success Criteria

✅ Global view shows all 4 jurisdictions summary  
✅ Jurisdiction switcher works, filters to that country  
✅ Create/Edit/Delete wholesale funders  
✅ Committed amount auto-calculated from active applications  
✅ Runway calculated from last 12 months distributions  
✅ Sample contracts manageable per jurisdiction  
✅ All tests passing  
✅ Zero hard-coded values (all dynamic)
