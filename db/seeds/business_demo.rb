puts "=== Seeding Business Demo Data ==="

# --- Wholesale Funders ---
funders_data = [
  { name: "Macquarie Capital", country: "AUS", currency: "AUD" },
  { name: "Blackrock Investments", country: "US", currency: "USD" },
  { name: "IFM Investors", country: "AUS", currency: "AUD" }
]

funders = funders_data.map do |attrs|
  WholesaleFunder.find_or_create_by!(name: attrs[:name]) do |f|
    f.country = attrs[:country]
    f.currency = attrs[:currency]
    f.demo = true
  end
end
puts "  Created #{funders.size} wholesale funders"

# --- Funder Pools ---
pools_data = [
  { funder: funders[0], name: "Macquarie Growth Fund I",    amount: 25_000_000, benchmark_rate: 4.75, margin_rate: 1.50 },
  { funder: funders[0], name: "Macquarie Income Fund II",   amount: 15_000_000, benchmark_rate: 5.25, margin_rate: 2.00 },
  { funder: funders[1], name: "Blackrock Global Alpha",     amount: 50_000_000, benchmark_rate: 5.50, margin_rate: 1.75 },
  { funder: funders[1], name: "Blackrock Fixed Income",     amount: 10_000_000, benchmark_rate: 4.25, margin_rate: 2.50 },
  { funder: funders[2], name: "IFM Australian Mortgage Trust", amount: 20_000_000, benchmark_rate: 5.00, margin_rate: 1.25 }
]

pools = pools_data.map do |attrs|
  FunderPool.find_or_create_by!(name: attrs[:name]) do |p|
    p.wholesale_funder = attrs[:funder]
    p.amount = attrs[:amount]
    p.allocated = 0
    p.benchmark_rate = attrs[:benchmark_rate]
    p.margin_rate = attrs[:margin_rate]
    p.demo = true
  end
end
puts "  Created #{pools.size} funder pools"

# --- Additional Lenders ---
[["Meridian Finance", "info@meridianfinance.com.au"], ["Pacific Home Loans", "info@pacifichomeloans.com.au"]].each do |name, email|
  Lender.find_or_create_by!(name: name) do |l|
    l.lender_type = :lender
    l.contact_email = email
  end
end
all_lenders = Lender.all.to_a
puts "  Lenders: #{all_lenders.map(&:name).join(', ')}"

# --- Contracts ---
app_ids = Application.where(status: %w[submitted processing accepted]).order(:id).pluck(:id)
if app_ids.size < 25
  puts "  ⏭️  Skipping demo contracts — needs 25+ applications, found #{app_ids.size} (fresh database)"
else

  # Contract definitions: [app_index, pool_index, status, months_ago, return_rate]
  contract_defs = [
    # Profitable contracts (good S&P returns)
    [0,  0, :ok, 22, 28.5],
    [1,  0, :ok, 20, 22.0],
    [2,  2, :ok, 18, 31.5],
    [3,  2, :ok, 16, 19.0],
    [4,  4, :ok, 15, 25.0],
    [5,  1, :ok, 14, 18.5],
    [6,  0, :ok, 12, 35.0],
    [7,  2, :ok, 11, 20.0],
    [8,  4, :ok, 10, 15.5],
    [9,  1, :ok, 8,  24.0],
    [10, 3, :ok, 6,  17.0],
    [11, 2, :ok, 5,  12.5],
    [12, 0, :ok, 4,  22.0],
    [13, 4, :ok, 3,  16.0],
    [14, 1, :ok, 2,  10.0],
    # In holiday
    [15, 2, :in_holiday, 19, 8.5],
    [16, 0, :in_holiday, 13, 5.0],
    [17, 3, :in_holiday, 9,  -2.5],
    # Investment at risk (losses)
    [18, 1, :investment_at_risk, 17, -12.0],
    [19, 3, :investment_at_risk, 7,  -15.0],
    # Complete
    [20, 0, :complete, 24, 14.0],
    [21, 2, :complete, 23, -5.0],
    [22, 4, :complete, 21, 9.5],
    # Awaiting funding
    [23, 1, :awaiting_funding, 0, 0.0],
    [24, 3, :awaiting_funding, 0, 0.0],
  ]

  created_count = 0
  contract_defs.each do |app_idx, pool_idx, status, months_ago, return_rate|
    app_id = app_ids[app_idx]
    next if Contract.exists?(application_id: app_id)
    
    pool = pools[pool_idx]
    app = Application.find(app_id)
    home_val = app.home_value.to_f
    home_val = rand(400_000..1_500_000) if home_val <= 0
    
    lvr = rand(0.55..0.80).round(2)
    allocated = (home_val * lvr).round(-3) # round to nearest 1000
    allocated = [[allocated, 200_000].max, 2_000_000].min
    
    start_date = months_ago.months.ago.to_date
    end_date = start_date + 25.years
    months_active = [(Date.today - start_date).to_i / 30, 0].max
    
    monthly_payment = (allocated * rand(0.003..0.005)).round(2) # ~$1500-$8000
    monthly_payment = [[monthly_payment, 1500].max, 8000].min.round(2)
    total_payments = (monthly_payment * months_active).round(2)
    
    # Balances: offset + investment ≈ allocated - some principal paid
    remaining = allocated - (total_payments * 0.3) # 30% of payments reduce principal
    remaining = [remaining, allocated * 0.5].max
    offset_pct = rand(0.40..0.60)
    offset_balance = (remaining * offset_pct).round(2)
    investment_balance = (remaining * (1 - offset_pct)).round(2)
    
    cost_rate = (pool.benchmark_rate + pool.margin_rate).round(4)
    
    # For awaiting_funding, zero out balances
    if status == :awaiting_funding
      offset_balance = 0
      investment_balance = 0
      monthly_payment = (allocated * 0.004).round(2)
      total_payments = 0
    end
    
    contract = Contract.create!(
      demo: true,
      application_id: app_id,
      funder_pool: pool,
      lender: all_lenders.sample,
      status: status,
      start_date: start_date,
      end_date: end_date,
      allocated_amount: allocated,
      offset_balance: offset_balance,
      investment_balance: investment_balance,
      monthly_payment: monthly_payment,
      total_payments_made: total_payments,
      investment_return_rate: return_rate,
      cost_of_capital_rate: cost_rate
    )
    
    # Update pool allocation
    pool.update!(allocated: pool.contracts.sum(:allocated_amount))
    created_count += 1
  end

  puts "  Created #{created_count} contracts"
  puts "  Pool allocations updated"
  puts "=== Business Demo Seed Complete ==="
end
