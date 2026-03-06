# db/seeds/regional_ecosystem_us.rb
# US ecosystem: funders, lenders, investment partner, brokers, consumers

return unless Rails.env.development? || Rails.env.staging?

puts "🇺🇸 Seeding US ecosystem..."

# --- Wholesale Funder: Vanguard Institutional ---
vanguard = WholesaleFunder.find_or_create_by!(name: "Vanguard Institutional") do |f|
  f.country = "United States"
end
puts "  ✅ Wholesale Funder: #{vanguard.name}"

# --- Lender: FutureProof Financial US ---
fp_us = Lender.find_or_create_by!(name: "FutureProof Financial US") do |l|
  l.lender_type = :lender
  l.address = "350 Fifth Avenue, Suite 5400, New York, NY 10118"
  l.postcode = "10118"
  l.country = "United States"
  l.contact_email = "info@futureprooffinancial.com"
  l.contact_telephone = "2125551234"
  l.contact_telephone_country_code = "+1"
end
puts "  ✅ Lender: #{fp_us.name}"

# --- Lender: Pacific Coast Lending ---
pcl = Lender.find_or_create_by!(name: "Pacific Coast Lending") do |l|
  l.lender_type = :lender
  l.address = "1999 Avenue of the Stars, Suite 1100, Los Angeles, CA 90067"
  l.postcode = "90067"
  l.country = "United States"
  l.contact_email = "originations@pacificcoastlending.com"
  l.contact_telephone = "3105559876"
  l.contact_telephone_country_code = "+1"
end
puts "  ✅ Lender: #{pcl.name}"

# --- Investment Partner ---
us_ip = InvestmentPartner.find_or_create_by!(licence_number: "SEC-IA-2024-00847") do |ip|
  ip.name = "FutureProof Capital US"
  ip.region = "us"
  ip.aum = 150_000_000.00
  ip.portfolio_strategy = "growth_etf"
  ip.fee_rate = 1.50
  ip.status = "active"
  ip.wholesale_funder = vanguard
end
puts "  ✅ Investment Partner: #{us_ip.name}"

# --- Funder Pool ---
us_pool = FunderPool.find_by(name: "US Residential Pool 2026")
unless us_pool
  us_pool = FunderPool.new(
    name: "US Residential Pool 2026",
    wholesale_funder: vanguard,
    amount: 100_000_000.00,
    allocated: 28_000_000.00,
    benchmark_rate: 6.25,
    margin_rate: 1.75
  )
  us_pool.save!(validate: false)
end
# Link pool to both US lenders
[fp_us, pcl].each do |lender|
  lfp = LenderFunderPool.find_or_initialize_by(lender: lender, funder_pool: us_pool)
  lfp.active = true
  lfp.save!(validate: false) if lfp.new_record?
end
puts "  ✅ Funder Pool: #{us_pool.name} ($#{us_pool.amount.to_i.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse})"

# --- Brokers (ReferralPartners) ---
brokers = [
  {
    name: "Sarah Johnson",
    company: "Sunshine State Mortgage Advisors",
    licence_number: "NMLS-FL-2024-18473",
    region: "us",
    commission_rate: 2.00,
    contact_email: "sarah.johnson@sunshineadvisors.com",
    phone: "3055551234",
    lender: fp_us
  },
  {
    name: "Michael Torres",
    company: "Pacific Wealth Brokers",
    licence_number: "NMLS-CA-2024-29184",
    region: "us",
    commission_rate: 2.50,
    contact_email: "michael.torres@pacificwealth.com",
    phone: "4155559876",
    lender: pcl
  }
]

brokers.each do |attrs|
  lender = attrs.delete(:lender)
  rp = ReferralPartner.find_or_create_by!(licence_number: attrs[:licence_number]) do |p|
    p.name = attrs[:name]
    p.company = attrs[:company]
    p.region = attrs[:region]
    p.commission_rate = attrs[:commission_rate]
    p.contact_email = attrs[:contact_email]
    p.phone = attrs[:phone]
    p.status = "active"
    p.lender = lender
  end
  puts "  ✅ Broker: #{rp.name} (#{rp.company})"
end

sarah = ReferralPartner.find_by!(licence_number: "NMLS-FL-2024-18473")
michael = ReferralPartner.find_by!(licence_number: "NMLS-CA-2024-29184")

# --- Consumers ---
consumers = [
  {
    first_name: "Dorothy", last_name: "Williams",
    email: "dorothy.williams@aol.com",
    country: "United States", mobile_code: "+1", mobile: "3055551001",
    age: 74, home_value: 650_000,
    address: "1842 Ocean Dr, Miami Beach, FL 33139",
    status: :submitted, broker: sarah, lender: fp_us
  },
  {
    first_name: "Richard", last_name: "Hernandez",
    email: "richard.hernandez@gmail.com",
    country: "United States", mobile_code: "+1", mobile: "8185552002",
    age: 69, home_value: 1_250_000,
    address: "4521 Sunset Blvd, Los Angeles, CA 90027",
    status: :accepted, broker: michael, lender: pcl
  },
  {
    first_name: "Barbara", last_name: "Chen",
    email: "barbara.chen@yahoo.com",
    country: "United States", mobile_code: "+1", mobile: "4805553003",
    age: 71, home_value: 480_000,
    address: "7890 E Camelback Rd, Scottsdale, AZ 85251",
    status: :processing, broker: sarah, lender: fp_us
  },
  {
    first_name: "James", last_name: "O'Connor",
    email: "james.oconnor@outlook.com",
    country: "United States", mobile_code: "+1", mobile: "2125554004",
    age: 67, home_value: 2_100_000,
    address: "155 E 76th St, Apt 12B, New York, NY 10021",
    status: :income_and_loan_options, broker: nil, lender: fp_us
  },
  {
    first_name: "Linda", last_name: "Martinez",
    email: "linda.martinez@icloud.com",
    country: "United States", mobile_code: "+1", mobile: "9545555005",
    age: 73, home_value: 520_000,
    address: "3210 Las Olas Blvd, Fort Lauderdale, FL 33316",
    status: :created, broker: michael, lender: fp_us
  }
]

consumers.each do |attrs|
  lender = attrs.delete(:lender)
  broker = attrs.delete(:broker)

  user = User.find_or_create_by!(email: attrs[:email], lender: lender) do |u|
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

  app = user.applications.first || user.applications.create!(
    status: attrs[:status],
    home_value: attrs[:home_value],
    address: attrs[:address],
    borrower_age: attrs[:age],
    ownership_status: :individual,
    property_state: :primary_residence,
    has_existing_mortgage: false,
    existing_mortgage_amount: 0,
    growth_rate: 2.5
  )

  if broker && app.referral_partner_id.nil?
    app.update!(referral_partner: broker)
  end

  # Mortgage contract for accepted applications
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

  state = attrs[:address].match(/,\s*(\w{2})\s+\d{5}/)[1] rescue attrs[:address].split(',').last.strip
  puts "  ✅ Consumer: #{user.full_name} (#{state}) — #{attrs[:status]}"
end

puts "🇺🇸 US ecosystem seeded!"
