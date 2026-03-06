# db/seeds/regional_ecosystem_au.rb
# Australian ecosystem: lender, investment partner, brokers, consumers
# Run with: rails db:seed (loads all seed files)

return unless Rails.env.development? || Rails.env.staging?

puts "🇦🇺 Seeding AU ecosystem..."

# --- Lender: FutureProof Financial AU ---
# (The futureproof lender likely already exists from other seeds)
fp_lender = Lender.find_or_create_by!(lender_type: :futureproof) do |l|
  l.name = "FutureProof Financial Pty Ltd"
  l.address = "Level 12, 100 Barangaroo Ave, Sydney NSW 2000"
  l.postcode = "2000"
  l.country = "Australia"
  l.contact_email = "info@futureprooffinancial.co"
  l.contact_telephone = "0432212713"
  l.contact_telephone_country_code = "+61"
end
puts "  ✅ Lender: #{fp_lender.name}"

# --- Wholesale Funder ---
au_funder = WholesaleFunder.find_or_create_by!(name: "FutureProof Capital Trust") do |f|
  f.country = "Australia"
end
puts "  ✅ Wholesale Funder: #{au_funder.name}"

# --- Investment Partner ---
au_ip = InvestmentPartner.find_or_create_by!(licence_number: "AFSL-IP-2024-001") do |ip|
  ip.name = "FutureProof Capital AU"
  ip.region = "au"
  ip.aum = 75_000_000.00
  ip.portfolio_strategy = "balanced_etf"
  ip.fee_rate = 1.25
  ip.status = "active"
  ip.wholesale_funder = au_funder
end
puts "  ✅ Investment Partner: #{au_ip.name}"

# --- Funder Pool ---
au_pool = FunderPool.find_by(name: "AU Residential Pool 2026")
unless au_pool
  au_pool = FunderPool.new(
    name: "AU Residential Pool 2026",
    wholesale_funder: au_funder,
    amount: 50_000_000.00,
    allocated: 12_500_000.00,
    benchmark_rate: 5.75,
    margin_rate: 1.50
  )
  au_pool.save!(validate: false)
end
# Link pool to lender
lfp = LenderFunderPool.find_or_initialize_by(lender: fp_lender, funder_pool: au_pool)
lfp.active = true
lfp.save!(validate: false) if lfp.new_record?
puts "  ✅ Funder Pool: #{au_pool.name} ($#{au_pool.amount.to_i.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse})"

# --- Brokers (ReferralPartners) ---
brokers = [
  {
    name: "Helen Chen",
    company: "Pacific Mortgage Brokers",
    licence_number: "ACR-NSW-2024-1847",
    region: "au",
    commission_rate: 2.50,
    contact_email: "helen.chen@pacificbrokers.com.au",
    phone: "+61 402 381 947"
  },
  {
    name: "James Wright",
    company: "National Mortgage Group",
    licence_number: "ACR-VIC-2024-3291",
    region: "au",
    commission_rate: 3.00,
    contact_email: "james.wright@nmg.com.au",
    phone: "+61 438 192 754"
  }
]

brokers.each do |attrs|
  rp = ReferralPartner.find_or_create_by!(licence_number: attrs[:licence_number]) do |p|
    p.name = attrs[:name]
    p.company = attrs[:company]
    p.region = attrs[:region]
    p.commission_rate = attrs[:commission_rate]
    p.contact_email = attrs[:contact_email]
    p.phone = attrs[:phone]
    p.status = "active"
    p.lender = fp_lender
  end
  puts "  ✅ Broker: #{rp.name} (#{rp.company})"
end

helen = ReferralPartner.find_by!(licence_number: "ACR-NSW-2024-1847")
james = ReferralPartner.find_by!(licence_number: "ACR-VIC-2024-3291")

# --- Consumers ---
consumers = [
  {
    first_name: "Margaret", last_name: "Thompson",
    email: "margaret.thompson@bigpond.com.au",
    country: "Australia", mobile_code: "+61", mobile: "412345678",
    age: 72, home_value: 1_850_000, address: "14 Harbour View Rd, Mosman NSW 2088",
    status: :submitted, broker: helen
  },
  {
    first_name: "Robert", last_name: "Mitchell",
    email: "rob.mitchell@optusnet.com.au",
    country: "Australia", mobile_code: "+61", mobile: "423876543",
    age: 68, home_value: 950_000, address: "7 Toorak Rd, South Yarra VIC 3141",
    status: :accepted, broker: james
  },
  {
    first_name: "Patricia", last_name: "O'Brien",
    email: "pat.obrien@gmail.com",
    country: "Australia", mobile_code: "+61", mobile: "434567891",
    age: 75, home_value: 1_200_000, address: "22 Marine Pde, Cottesloe WA 6011",
    status: :processing, broker: helen
  },
  {
    first_name: "David", last_name: "Nguyen",
    email: "david.nguyen@icloud.com",
    country: "Australia", mobile_code: "+61", mobile: "445234567",
    age: 65, home_value: 780_000, address: "5/31 Coronation Dr, Toowong QLD 4066",
    status: :user_details, broker: nil
  },
  {
    first_name: "Susan", last_name: "Campbell",
    email: "susan.campbell@outlook.com.au",
    country: "Australia", mobile_code: "+61", mobile: "456789012",
    age: 70, home_value: 1_450_000, address: "8 The Esplanade, Brighton SA 5048",
    status: :created, broker: james
  }
]

consumers.each do |attrs|
  user = User.find_or_create_by!(email: attrs[:email], lender: fp_lender) do |u|
    u.first_name = attrs[:first_name]
    u.last_name = attrs[:last_name]
    u.country_of_residence = attrs[:country]
    u.mobile_country_code = attrs[:mobile_code]
    u.mobile_number = attrs[:mobile]
    u.password = "SecurePass2026!"
    u.terms_accepted = true
    u.confirmed_at = Time.current
    u.admin = false
  end

  # Create or find application
  app = user.applications.first || user.applications.create!(
    status: attrs[:status],
    home_value: attrs[:home_value],
    address: attrs[:address],
    borrower_age: attrs[:age],
    ownership_status: :individual,
    property_state: :primary_residence,
    has_existing_mortgage: false,
    existing_mortgage_amount: 0,
    growth_rate: 2.0
  )

  # Link broker if provided
  if attrs[:broker] && app.referral_partner_id.nil?
    app.update!(referral_partner: attrs[:broker])
  end

  # Create mortgage contract for accepted applications
  if attrs[:status] == :accepted && user.primary_mortgage_contracts.empty?
    begin
      max_version = MortgageContract.maximum(:version) || 0
      MortgageContract.create!(
        primary_user: user,
        created_by: user,
        title: "EPM Agreement — #{user.full_name}",
        content: "Equity Preservation Mortgage agreement for #{user.full_name}. Property: #{attrs[:address]}. Home value: $#{attrs[:home_value].to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}.",
        version: max_version + 1,
        is_active: true,
        is_draft: false,
        last_updated: Time.current
      )
    rescue => e
      puts "  ⚠️  Skipped mortgage contract for #{user.full_name}: #{e.message}"
    end
  end

  puts "  ✅ Consumer: #{user.full_name} (#{attrs[:address].split(',').last.strip}) — #{attrs[:status]}"
end

puts "🇦🇺 AU ecosystem seeded!"
