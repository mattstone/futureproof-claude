# Simple Test Applications Seed File
# Creates 40 diverse applications in various stages of completion

puts "Creating test applications..."

# Ensure we have the futureproof lender and admin user
futureproof_lender = Lender.find_by(lender_type: :futureproof) || Lender.create!(
  name: 'Futureproof Financial Pty Ltd',
  lender_type: :futureproof,
  address: 'Wework Barangaroo, Sydney',
  postcode: '2000',
  country: 'Australia',
  contact_email: 'info@futureprooffinancial.co',
  contact_telephone: '0432212713',
  contact_telephone_country_code: '+61'
)

admin_user = User.find_by(admin: true)
unless admin_user
  admin_user = User.create!(
    first_name: 'Admin',
    last_name: 'User',
    email: 'admin@futureprooffinancial.co',
    password: 'AdminPassword123',
    password_confirmation: 'AdminPassword123',
    admin: true,
    country_of_residence: 'Australia',
    mobile_country_code: '+61',
    mobile_number: '400000000',
    confirmed_at: Time.current,
    terms_accepted: true,
    lender: futureproof_lender
  )
end

# Create mortgages if they don't exist
if Mortgage.count == 0
  Mortgage.create!([
    { name: 'Standard Interest Only', mortgage_type: 'interest_only', lvr: 60.0, current_user: admin_user },
    { name: 'Premium Interest Only', mortgage_type: 'interest_only', lvr: 70.0, current_user: admin_user },
    { name: 'Standard Principal & Interest', mortgage_type: 'principal_and_interest', lvr: 65.0, current_user: admin_user },
    { name: 'Premium Principal & Interest', mortgage_type: 'principal_and_interest', lvr: 75.0, current_user: admin_user }
  ])
end

mortgages = Mortgage.all
puts "Using #{mortgages.count} mortgages for applications"

# Create test users with simple data
40.times do |i|
  first_names = ['Sarah', 'Michael', 'Emma', 'David', 'Lisa', 'James', 'Sophie', 'Robert', 'Kate', 'Andrew', 'Nicole', 'Mark', 'Rachel', 'Chris', 'Jessica', 'Paul', 'Amanda', 'Simon', 'Helen', 'Tom', 'Laura', 'Daniel', 'Michelle', 'Anthony', 'Karen', 'Steven', 'Maria', 'Matthew', 'Jennifer', 'Kevin', 'Samantha', 'Jason', 'Angela', 'Ryan', 'Rebecca', 'Benjamin', 'Amy', 'Jonathan', 'Stephanie', 'Brian']
  last_names = ['Johnson', 'Chen', 'Williams', 'Brown', 'Davis', 'Miller', 'Wilson', 'Moore', 'Taylor', 'Anderson', 'Thomas', 'Jackson', 'White', 'Harris', 'Martin', 'Thompson', 'Garcia', 'Martinez', 'Robinson', 'Clark', 'Rodriguez', 'Lewis', 'Lee', 'Walker', 'Hall', 'Allen', 'Young', 'Hernandez', 'King', 'Wright', 'Lopez', 'Hill', 'Scott', 'Green', 'Adams', 'Baker', 'Gonzalez', 'Nelson', 'Carter', 'Mitchell']
  
  first_name = first_names[i]
  last_name = last_names[i]
  
  user = User.find_or_create_by(email: "#{first_name.downcase}.#{last_name.downcase}@example.com") do |u|
    u.first_name = first_name
    u.last_name = last_name
    u.password = 'TestPassword123'
    u.password_confirmation = 'TestPassword123'
    u.admin = false
    u.country_of_residence = 'Australia'
    u.mobile_country_code = '+61'
    u.mobile_number = "4#{rand(10000000..99999999)}"
    u.confirmed_at = Time.current
    u.terms_accepted = true
  end

  # Property addresses across Australia
  addresses = [
    "123 Collins Street, Melbourne VIC 3000", "456 George Street, Sydney NSW 2000", "789 Queen Street, Brisbane QLD 4000",
    "321 King William Street, Adelaide SA 5000", "654 St Georges Terrace, Perth WA 6000", "987 Elizabeth Street, Hobart TAS 7000",
    "147 Smith Street, Darwin NT 0800", "258 Northbourne Avenue, Canberra ACT 2600", "369 Chapel Street, South Yarra VIC 3141",
    "741 Oxford Street, Bondi Junction NSW 2022", "852 Queen Street Mall, Brisbane QLD 4000", "963 Rundle Mall, Adelaide SA 5000",
    "159 Hay Street, Perth WA 6000", "357 Battery Point, Hobart TAS 7004", "456 Mitchell Street, Darwin NT 0800",
    "789 Civic Square, Canberra ACT 2601", "123 Brunswick Street, Fitzroy VIC 3065", "456 Crown Street, Surry Hills NSW 2010",
    "789 Fortitude Valley, Brisbane QLD 4006", "321 North Adelaide SA 5006", "654 Subiaco WA 6008", "987 Sandy Bay TAS 7005",
    "147 Parap NT 0820", "258 Barton ACT 2600", "369 Richmond VIC 3121", "741 Newtown NSW 2042", "852 New Farm QLD 4005",
    "963 Unley SA 5061", "159 Cottesloe WA 6011", "357 South Hobart TAS 7004", "456 Nightcliff NT 0810", "789 Kingston ACT 2604",
    "123 Carlton VIC 3053", "456 Paddington NSW 2021", "789 Teneriffe QLD 4005", "321 Parkside SA 5063", "654 Claremont WA 6010",
    "987 West Hobart TAS 7000", "147 Stuart Park NT 0820", "258 Griffith ACT 2603"
  ]

  # Property values
  property_values = [425000, 480000, 520000, 650000, 750000, 820000, 950000, 1100000, 1250000, 1400000, 1550000, 1700000, 1850000, 2000000, 2200000, 2400000, 2600000, 2800000, 3000000, 3200000, 3500000]
  
  # Status distribution: 3 created, 4 user_details, 6 property_details, 5 income_loan, 8 submitted, 5 processing, 4 accepted, 3 rejected, 2 user_details
  statuses = [:created, :created, :created, :user_details, :user_details, :user_details, :user_details, :property_details, :property_details, :property_details, :property_details, :property_details, :property_details, :income_and_loan_options, :income_and_loan_options, :income_and_loan_options, :income_and_loan_options, :income_and_loan_options, :submitted, :submitted, :submitted, :submitted, :submitted, :submitted, :submitted, :submitted, :processing, :processing, :processing, :processing, :processing, :accepted, :accepted, :accepted, :accepted, :rejected, :rejected, :rejected, :user_details, :user_details]
  
  address = addresses[i]
  home_value = property_values.sample
  status = statuses[i]
  ownership_status = [:individual, :joint, :lender, :super].sample
  property_state = [:primary_residence, :investment, :holiday].sample
  
  # Determine if property has existing mortgage (about 60% do)
  has_existing_mortgage = rand < 0.6
  existing_mortgage_amount = has_existing_mortgage ? rand(100000...(home_value * 0.8).to_i) : 0
  
  # Set borrower age for individual ownership
  borrower_age = ownership_status == :individual ? rand(35..65) : nil
  
  # Set required fields based on ownership status
  borrower_names = nil
  lender_name = nil
  super_fund_name = nil
  
  case ownership_status
  when :joint
    # Create borrower names for joint applications
    borrower_names = [
      { name: "#{first_name} #{last_name}", age: rand(35..65) },
      { name: "#{['Alex', 'Jordan', 'Taylor', 'Casey', 'Morgan'].sample} #{last_name}", age: rand(35..65) }
    ].to_json
  when :lender
    lender_name = "#{last_name} Holdings Pty Ltd"
  when :super
    super_fund_name = "#{last_name} Family Super Fund"
  end
  
  # Set mortgage and loan details for advanced applications
  mortgage = status.in?(['income_and_loan_options', 'submitted', 'processing', 'accepted', 'rejected']) ? mortgages.sample : nil
  loan_term = mortgage ? rand(10..30) : nil
  income_payout_term = loan_term ? rand(10..loan_term) : nil
  
  # Growth rate is required
  growth_rate = [2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0].sample
  
  # Rejected reason for rejected applications
  rejected_reason = if status == :rejected
    ['Property value outside acceptable range', 'Insufficient income documentation', 'Credit check failed'].sample
  else
    nil
  end
  
  begin
    application = Application.create!(
      user: user,
      address: address,
      home_value: home_value,
      ownership_status: ownership_status,
      property_state: property_state,
      status: status,
      has_existing_mortgage: has_existing_mortgage,
      existing_mortgage_amount: existing_mortgage_amount,
      borrower_age: borrower_age,
      borrower_names: borrower_names,
      company_name: lender_name,
      super_fund_name: super_fund_name,
      loan_term: loan_term,
      income_payout_term: income_payout_term,
      mortgage: mortgage,
      growth_rate: growth_rate,
      rejected_reason: rejected_reason,
      current_user: admin_user,
      created_at: rand(60.days.ago..Time.current),
      updated_at: rand(30.days.ago..Time.current)
    )
    
    print "." if i % 5 == 0
    
  rescue => e
    puts "\nError creating application #{i + 1}: #{e.message}"
    puts "Status: #{status}, Ownership: #{ownership_status}, Borrower Age: #{borrower_age}"
  end
end

puts "\n✅ Successfully created #{Application.count} test applications:"
puts "   - #{Application.status_created.count} applications in 'Created' status"
puts "   - #{Application.status_user_details.count} applications in 'User Details' status"  
puts "   - #{Application.status_property_details.count} applications in 'Property Details' status"
puts "   - #{Application.status_income_and_loan_options.count} applications in 'Income and Loan Options' status"
puts "   - #{Application.status_submitted.count} applications in 'Submitted' status"
puts "   - #{Application.status_processing.count} applications in 'Processing' status"
puts "   - #{Application.status_accepted.count} applications in 'Accepted' status"
puts "   - #{Application.status_rejected.count} applications in 'Rejected' status"

puts "\nProperty value distribution:"
puts "   - Under $1M: #{Application.where('home_value < 1000000').count} applications"
puts "   - $1M - $2M: #{Application.where(home_value: 1000000..2000000).count} applications"
puts "   - Over $2M: #{Application.where('home_value > 2000000').count} applications"

puts "\nOwnership status distribution:"
Application.group(:ownership_status).count.each do |status, count|
  puts "   - #{status.humanize}: #{count} applications"
end

puts "\n🎉 Test application creation completed successfully!"