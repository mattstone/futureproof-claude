# Balanced demo data across all four regions (AU / US / NZ / UK) so the console
# region picker shows a clearly different world per region: a populated
# acquisition pipeline, a live portfolio with varied investment health,
# region-resident customers, and a couple of local brokers.
#
# Fully idempotent and ADDITIVE — keyed on deterministic demo emails / names, so
# re-running creates nothing new. Safe to run via `bin/rails db:seed` or
# directly: `bin/rails runner "load 'db/seeds/regional_demo.rb'"`.
#
# Existing region data (the AU-heavy seed set) is left untouched; this only
# fills the gaps so every region has something to look at.

module RegionalDemoSeed
  module_function

  REGIONS = [
    {
      code: "AU", country: "Australia", cc: "+61", value: 650_000..2_500_000,
      mobile: -> { "4#{rand(10_000_000..99_999_999)}" },
      addresses: [
        "15 Macleay Street, Potts Point NSW 2011", "88 Toorak Road, South Yarra VIC 3141",
        "210 Adelaide Street, Brisbane QLD 4000", "34 Jetty Road, Glenelg SA 5045",
        "120 St Georges Terrace, Perth WA 6000", "9 Salamanca Place, Hobart TAS 7004",
        "55 Mitchell Street, Darwin NT 0800", "17 Kingston Foreshore, Kingston ACT 2604",
        "402 Chapel Street, Prahran VIC 3181", "76 Campbell Parade, Bondi Beach NSW 2026"
      ],
      brokers: [ "Harbour City Mortgages", "Southern Cross Finance" ]
    },
    {
      code: "US", country: "United States", cc: "+1", value: 400_000..2_000_000,
      mobile: -> { rand(2_000_000_000..9_999_999_999).to_s },
      addresses: [
        "350 Fifth Avenue, New York NY 10118", "1 Ferry Building, San Francisco CA 94111",
        "233 S Wacker Drive, Chicago IL 60606", "400 Broad Street, Seattle WA 98109",
        "100 Biscayne Blvd, Miami FL 33132", "1201 Elm Street, Dallas TX 75270",
        "1 Lincoln Street, Boston MA 02111", "555 California Street, San Francisco CA 94104",
        "2000 Avenue of the Stars, Los Angeles CA 90067", "1100 Peachtree Street, Atlanta GA 30309"
      ],
      brokers: [ "Liberty Home Lending", "Pacific Coast Mortgage Co" ]
    },
    {
      code: "NZ", country: "New Zealand", cc: "+64", value: 700_000..2_000_000,
      mobile: -> { "2#{rand(1_000_000..9_999_999)}" },
      addresses: [
        "1 Queen Street, Auckland 1010", "100 Lambton Quay, Wellington 6011",
        "120 Hereford Street, Christchurch 8011", "33 Cuba Street, Wellington 6011",
        "12 Ponsonby Road, Auckland 1011", "200 Victoria Street, Hamilton 3204",
        "5 Marine Parade, Napier 4110", "80 Tay Street, Invercargill 9810",
        "60 Dixon Street, Wellington 6011", "240 Riccarton Road, Christchurch 8041"
      ],
      brokers: [ "Kiwi Home Loans", "Aotearoa Mortgage Advisers" ]
    },
    {
      code: "UK", country: "United Kingdom", cc: "+44", value: 350_000..1_500_000,
      mobile: -> { "7#{rand(100_000_000..999_999_999)}" },
      addresses: [
        "221B Baker Street, London NW1 6XE", "1 Deansgate, Manchester M3 1SX",
        "30 St Mary Axe, London EC3A 8BF", "1 Princes Street, Edinburgh EH2 2EQ",
        "5 King Street, Leeds LS1 2HH", "12 Park Lane, London W1K 1PN",
        "100 Victoria Street, Bristol BS1 6HZ", "2 Colmore Row, Birmingham B3 2BJ",
        "8 Royal Crescent, Bath BA1 2LR", "14 George Street, Glasgow G2 1DY"
      ],
      brokers: [ "Albion Mortgage Group", "Thames Valley Home Finance" ]
    }
  ].freeze

  COUNTRY_ALIASES = {
    "AU" => %w[AU AUS Australia AUSTRALIA], "US" => [ "US", "USA", "United States", "UNITED STATES" ],
    "NZ" => [ "NZ", "New Zealand" ], "UK" => [ "UK", "GB", "United Kingdom" ]
  }.freeze

  # 10 applications per region: 5 in the pipeline, 5 accepted (each gets a contract).
  APP_STATUSES = %i[
    created user_details property_details submitted processing
    accepted accepted accepted accepted accepted
  ].freeze

  # The five accepted apps get one contract each, spanning the health spectrum.
  CONTRACT_SPECS = [
    { status: :ok,                 months_ago: 18, return_rate: 24.0 },
    { status: :in_holiday,         months_ago: 12, return_rate: 6.5 },
    { status: :investment_at_risk, months_ago: 9,  return_rate: -11.0 },
    { status: :complete,           months_ago: 22, return_rate: 12.0 },
    { status: :awaiting_funding,   months_ago: 0,  return_rate: 0.0 }
  ].freeze

  FIRST_NAMES = %w[James Olivia William Sophia Liam Emma Noah Ava Lucas Mia Ethan Charlotte].freeze
  LAST_NAMES  = %w[Carter Bennett Hughes Foster Reed Coleman Murphy Bailey Hayes Porter].freeze

  def run
    futureproof = Lender.find_by(lender_type: :futureproof) || Lender.first
    mortgage = Mortgage.first

    summary = {}
    REGIONS.each do |region|
      lender = lender_for(region[:code], futureproof)
      pool   = pool_for(region[:code])
      ensure_brokers(region)

      contracts_made = 0
      10.times do |i|
        user = ensure_user(region, i, futureproof)
        app  = ensure_application(region, user, i, mortgage)
        next unless app

        # The accepted apps (indexes 5..9) each carry one contract.
        if APP_STATUSES[i] == :accepted && pool
          spec = CONTRACT_SPECS[i - 5]
          contracts_made += 1 if ensure_contract(app, spec, pool, lender)
        end
      end

      summary[region[:code]] = {
        users: User.where(country_of_residence: region[:country]).count,
        applications: Application.where(region: region[:code]).count,
        contracts: Contract.joins(:application).where(applications: { region: region[:code] }).count,
        contracts_added_now: contracts_made
      }
    end
    summary
  end

  # --- builders --------------------------------------------------------------

  def ensure_user(region, index, futureproof)
    email = "demo-#{region[:code].downcase}-#{index + 1}@futureproof.example"
    User.find_or_create_by!(email: email) do |u|
      u.first_name = FIRST_NAMES[(index + region[:code].sum) % FIRST_NAMES.size]
      u.last_name  = LAST_NAMES[index % LAST_NAMES.size]
      u.password = u.password_confirmation = "DemoPass#{region[:code]}123"
      u.admin = false
      u.country_of_residence = region[:country]
      u.mobile_country_code = region[:cc]
      u.mobile_number = region[:mobile].call
      u.confirmed_at = Time.current
      u.terms_accepted = true
      u.lender = futureproof
    end
  end

  def ensure_application(region, user, index, mortgage)
    return user.applications.find_by(region: region[:code]) if user.applications.where(region: region[:code]).exists?

    status = APP_STATUSES[index]
    advanced = %i[submitted processing accepted].include?(status)
    Application.create!(
      user: user,
      region: region[:code],
      address: region[:addresses][index],
      home_value: rand(region[:value]).round(-3),
      ownership_status: :individual,
      property_state: %i[primary_residence investment holiday].sample,
      status: status,
      borrower_age: rand(45..72),
      has_existing_mortgage: false,
      existing_mortgage_amount: 0,
      growth_rate: [ 2.5, 3.0, 3.5, 4.0, 4.5 ].sample,
      loan_term: advanced ? [ 15, 20, 25, 30 ].sample : nil,
      income_payout_term: advanced ? [ 10, 15, 20 ].sample : nil,
      mortgage: advanced ? mortgage : nil,
      created_at: rand(120.days.ago..20.days.ago)
    )
  end

  def ensure_contract(app, spec, pool, lender)
    return false if Contract.exists?(application_id: app.id)

    home_val = app.home_value.to_f
    home_val = 800_000 if home_val <= 0
    allocated = [ [ (home_val * rand(0.55..0.80)).round(-3), 200_000 ].max, 2_000_000 ].min
    start_date = spec[:months_ago].months.ago.to_date
    months_active = [ (Date.today - start_date).to_i / 30, 0 ].max
    monthly_payment = [ [ (allocated * rand(0.003..0.005)).round(2), 1_500 ].max, 8_000 ].min
    total_payments = (monthly_payment * months_active).round(2)
    remaining = [ allocated - (total_payments * 0.3), allocated * 0.5 ].max
    offset_pct = rand(0.40..0.60)

    awaiting = spec[:status] == :awaiting_funding
    Contract.create!(
      demo: true,
      application: app,
      funder_pool: pool,
      lender: lender,
      status: spec[:status],
      start_date: start_date,
      end_date: start_date + 25.years,
      allocated_amount: allocated,
      offset_balance: awaiting ? 0 : (remaining * offset_pct).round(2),
      investment_balance: awaiting ? 0 : (remaining * (1 - offset_pct)).round(2),
      monthly_payment: monthly_payment,
      total_payments_made: awaiting ? 0 : total_payments,
      investment_return_rate: spec[:return_rate],
      cost_of_capital_rate: (pool.benchmark_rate.to_f + pool.margin_rate.to_f).round(4)
    )
    pool.update!(allocated: pool.contracts.sum(:allocated_amount))
    true
  end

  def ensure_brokers(region)
    region[:brokers].each_with_index do |name, i|
      email = "broker-#{region[:code].downcase}-#{i + 1}@futureproof.example"
      Broker.find_or_create_by!(email: email) do |b|
        b.name = name
        b.password = b.password_confirmation = "DemoBroker#{region[:code]}123"
        b.jurisdiction = region[:code]
        b.status = :active
      end
    end
  end

  # --- lookups ---------------------------------------------------------------

  def lender_for(code, fallback)
    Lender.where(country: COUNTRY_ALIASES[code]).where(status: :active).first ||
      Lender.where(country: COUNTRY_ALIASES[code]).first ||
      Lender.where(status: :active).first || fallback
  end

  def pool_for(code)
    FunderPool.joins(:wholesale_funder)
              .where(wholesale_funders: { country: COUNTRY_ALIASES[code] }).first ||
      FunderPool.first
  end
end

result = RegionalDemoSeed.run
puts "🌍 Regional demo data:"
result.each do |code, counts|
  puts "   #{code}: #{counts[:applications]} apps · #{counts[:contracts]} contracts " \
       "(#{counts[:contracts_added_now]} new) · #{counts[:users]} customers"
end
