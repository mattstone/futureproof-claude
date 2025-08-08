# Comprehensive Test Applications Seed File
# Creates 40 diverse applications in various stages of completion

puts "Creating test applications..."

# First, ensure we have mortgages and a regular user to create applications
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
    terms_accepted: true
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

# Create test users for applications
test_users_data = [
  { first_name: 'Sarah', last_name: 'Johnson', email: 'sarah.johnson@example.com', age: 45 },
  { first_name: 'Michael', last_name: 'Chen', email: 'michael.chen@example.com', age: 52 },
  { first_name: 'Emma', last_name: 'Williams', email: 'emma.williams@example.com', age: 38 },
  { first_name: 'David', last_name: 'Brown', email: 'david.brown@example.com', age: 61 },
  { first_name: 'Lisa', last_name: 'Davis', email: 'lisa.davis@example.com', age: 49 },
  { first_name: 'James', last_name: 'Miller', email: 'james.miller@example.com', age: 43 },
  { first_name: 'Sophie', last_name: 'Wilson', email: 'sophie.wilson@example.com', age: 56 },
  { first_name: 'Robert', last_name: 'Moore', email: 'robert.moore@example.com', age: 47 },
  { first_name: 'Kate', last_name: 'Taylor', email: 'kate.taylor@example.com', age: 41 },
  { first_name: 'Andrew', last_name: 'Anderson', email: 'andrew.anderson@example.com', age: 59 },
  { first_name: 'Nicole', last_name: 'Thomas', email: 'nicole.thomas@example.com', age: 44 },
  { first_name: 'Mark', last_name: 'Jackson', email: 'mark.jackson@example.com', age: 48 },
  { first_name: 'Rachel', last_name: 'White', email: 'rachel.white@example.com', age: 53 },
  { first_name: 'Chris', last_name: 'Harris', email: 'chris.harris@example.com', age: 37 },
  { first_name: 'Jessica', last_name: 'Martin', email: 'jessica.martin@example.com', age: 46 },
  { first_name: 'Paul', last_name: 'Thompson', email: 'paul.thompson@example.com', age: 55 },
  { first_name: 'Amanda', last_name: 'Garcia', email: 'amanda.garcia@example.com', age: 42 },
  { first_name: 'Simon', last_name: 'Martinez', email: 'simon.martinez@example.com', age: 50 },
  { first_name: 'Helen', last_name: 'Robinson', email: 'helen.robinson@example.com', age: 39 },
  { first_name: 'Tom', last_name: 'Clark', email: 'tom.clark@example.com', age: 57 },
  { first_name: 'Laura', last_name: 'Rodriguez', email: 'laura.rodriguez@example.com', age: 45 },
  { first_name: 'Daniel', last_name: 'Lewis', email: 'daniel.lewis@example.com', age: 51 },
  { first_name: 'Michelle', last_name: 'Lee', email: 'michelle.lee@example.com', age: 40 },
  { first_name: 'Anthony', last_name: 'Walker', email: 'anthony.walker@example.com', age: 58 },
  { first_name: 'Karen', last_name: 'Hall', email: 'karen.hall@example.com', age: 43 },
  { first_name: 'Steven', last_name: 'Allen', email: 'steven.allen@example.com', age: 49 },
  { first_name: 'Maria', last_name: 'Young', email: 'maria.young@example.com', age: 36 },
  { first_name: 'Matthew', last_name: 'Hernandez', email: 'matthew.hernandez@example.com', age: 54 },
  { first_name: 'Jennifer', last_name: 'King', email: 'jennifer.king@example.com', age: 41 },
  { first_name: 'Kevin', last_name: 'Wright', email: 'kevin.wright@example.com', age: 47 },
  { first_name: 'Samantha', last_name: 'Lopez', email: 'samantha.lopez@example.com', age: 38 },
  { first_name: 'Jason', last_name: 'Hill', email: 'jason.hill@example.com', age: 52 },
  { first_name: 'Angela', last_name: 'Scott', email: 'angela.scott@example.com', age: 46 },
  { first_name: 'Ryan', last_name: 'Green', email: 'ryan.green@example.com', age: 35 },
  { first_name: 'Rebecca', last_name: 'Adams', email: 'rebecca.adams@example.com', age: 50 },
  { first_name: 'Benjamin', last_name: 'Baker', email: 'benjamin.baker@example.com', age: 44 },
  { first_name: 'Amy', last_name: 'Gonzalez', email: 'amy.gonzalez@example.com', age: 48 },
  { first_name: 'Jonathan', last_name: 'Nelson', email: 'jonathan.nelson@example.com', age: 56 },
  { first_name: 'Stephanie', last_name: 'Carter', email: 'stephanie.carter@example.com', age: 42 },
  { first_name: 'Brian', last_name: 'Mitchell', email: 'brian.mitchell@example.com', age: 53 }
]

# Create a hash to store ages separately since User model doesn't have age column
user_ages = {}
test_users = test_users_data.map do |user_data|
  user = User.find_or_create_by(email: user_data[:email]) do |u|
    u.first_name = user_data[:first_name]
    u.last_name = user_data[:last_name]
    u.password = 'TestPassword123'
    u.password_confirmation = 'TestPassword123'
    u.admin = false
    u.country_of_residence = 'Australia'
    u.mobile_country_code = '+61'
    u.mobile_number = "4#{rand(10000000..99999999)}"
    u.confirmed_at = Time.current
    u.terms_accepted = true
  end
  user_ages[user.id] = user_data[:age]
  user
end

puts "Created or found #{test_users.count} test users"

# Diverse property addresses across Australia
addresses = [
  "123 Collins Street, Melbourne VIC 3000",
  "456 George Street, Sydney NSW 2000",
  "789 Queen Street, Brisbane QLD 4000",
  "321 King William Street, Adelaide SA 5000",
  "654 St Georges Terrace, Perth WA 6000",
  "987 Elizabeth Street, Hobart TAS 7000",
  "147 Smith Street, Darwin NT 0800",
  "258 Northbourne Avenue, Canberra ACT 2600",
  "369 Chapel Street, South Yarra VIC 3141",
  "741 Oxford Street, Bondi Junction NSW 2022",
  "852 Queen Street Mall, Brisbane QLD 4000",
  "963 Rundle Mall, Adelaide SA 5000",
  "159 Hay Street, Perth WA 6000",
  "357 Battery Point, Hobart TAS 7004",
  "456 Mitchell Street, Darwin NT 0800",
  "789 Civic Square, Canberra ACT 2601",
  "123 Brunswick Street, Fitzroy VIC 3065",
  "456 Crown Street, Surry Hills NSW 2010",
  "789 Fortitude Valley, Brisbane QLD 4006",
  "321 North Adelaide SA 5006",
  "654 Subiaco WA 6008",
  "987 Sandy Bay TAS 7005",
  "147 Parap NT 0820",
  "258 Barton ACT 2600",
  "369 Richmond VIC 3121",
  "741 Newtown NSW 2042",
  "852 New Farm QLD 4005",
  "963 Unley SA 5061",
  "159 Cottesloe WA 6011",
  "357 South Hobart TAS 7004",
  "456 Nightcliff NT 0810",
  "789 Kingston ACT 2604",
  "123 Carlton VIC 3053",
  "456 Paddington NSW 2021",
  "789 Teneriffe QLD 4005",
  "321 Parkside SA 5063",
  "654 Claremont WA 6010",
  "987 West Hobart TAS 7000",
  "147 Stuart Park NT 0820",
  "258 Griffith ACT 2603"
]

# Property values ranging from $400k to $3.5M
property_values = [
  425000, 480000, 520000, 650000, 750000, 820000, 950000, 1100000,
  1250000, 1400000, 1550000, 1700000, 1850000, 2000000, 2200000,
  2400000, 2600000, 2800000, 3000000, 3200000, 3500000
]

# Different ownership statuses and property states
ownership_statuses = [:individual, :joint, :company, :super]
property_states = [:primary_residence, :investment, :holiday]

# Application statuses with varying distribution
application_statuses = [
  :created, :created, :created,  # 3 new applications
  :user_details, :user_details, :user_details, :user_details, # 4 in user details step
  :property_details, :property_details, :property_details, :property_details, :property_details, :property_details, # 6 in property details
  :income_and_loan_options, :income_and_loan_options, :income_and_loan_options, :income_and_loan_options, :income_and_loan_options, # 5 in loan options
  :submitted, :submitted, :submitted, :submitted, :submitted, :submitted, :submitted, :submitted, # 8 submitted
  :processing, :processing, :processing, :processing, :processing, # 5 processing
  :accepted, :accepted, :accepted, :accepted, # 4 accepted
  :rejected, :rejected, :rejected # 3 rejected
]

# Growth rates (property appreciation expectations)
growth_rates = [2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0]

# Create 40 diverse applications
40.times do |i|
  user = test_users[i]
  address = addresses[i]
  home_value = property_values.sample
  ownership_status = ownership_statuses.sample
  property_state = property_states.sample
  status = application_statuses[i]
  
  # Determine if property has existing mortgage (about 60% do)
  has_existing_mortgage = rand < 0.6
  existing_mortgage_amount = has_existing_mortgage ? rand(100000...(home_value * 0.8).to_i) : 0
  
  # Create borrower names for joint applications
  borrower_names = if ownership_status == :joint
    [
      { name: "#{user.first_name} #{user.last_name}", age: user_ages[user.id] },
      { name: "#{['Alex', 'Jordan', 'Taylor', 'Casey', 'Morgan'].sample} #{user.last_name}", age: rand(30..65) }
    ].to_json
  else
    nil
  end
  
  # Company names for company ownership
  company_name = if ownership_status == :company
    ["#{user.last_name} Holdings Pty Ltd", "#{user.first_name} Investment Co", "#{user.last_name} Property Group", "#{user.first_name} Enterprises"].sample
  else
    nil
  end
  
  # Super fund names for super ownership
  super_fund_name = if ownership_status == :super
    ["#{user.last_name} Family Super Fund", "#{user.first_name} SMSF", "#{user.last_name} Superannuation Fund"].sample
  else
    nil
  end
  
  # Loan and income terms for more advanced applications
  loan_term = status.in?(['income_and_loan_options', 'submitted', 'processing', 'accepted', 'rejected']) ? rand(10..30) : nil
  income_payout_term = loan_term ? rand(10..loan_term) : nil
  mortgage = status.in?(['income_and_loan_options', 'submitted', 'processing', 'accepted', 'rejected']) ? mortgages.sample : nil
  growth_rate = growth_rates.sample  # Always provide growth rate as it's required
  
  # Rejected reason for rejected applications
  rejected_reason = if status == :rejected
    [
      "Property value outside acceptable range",
      "Insufficient income documentation",
      "Credit check failed",
      "Property location not in approved areas",
      "Age requirements not met",
      "Incomplete application submitted"
    ].sample
  else
    nil
  end
  
  application = Application.create!(
    user: user,
    address: address,
    home_value: home_value,
    ownership_status: ownership_status,
    property_state: property_state,
    status: status,
    has_existing_mortgage: has_existing_mortgage,
    existing_mortgage_amount: existing_mortgage_amount,
    borrower_age: ownership_status == :individual ? user_ages[user.id] : nil,
    borrower_names: borrower_names,
    company_name: company_name,
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
  
  # Add some application messages for a subset of applications (about 30%)
  if rand < 0.3 && application.status.in?(['submitted', 'processing', 'accepted', 'rejected'])
    # Customer message
    customer_message_content = [
      "I have some questions about my application timeline.",
      "Could you please provide an update on the processing status?",
      "I need to update some information in my application.",
      "When can I expect to hear back about the decision?",
      "I have additional documentation to submit.",
      "Can we schedule a call to discuss my application?"
    ].sample
    
    application.application_messages.create!(
      sender_type: 'User',
      sender: user,
      subject: "Inquiry about Application ##{application.id}",
      content: customer_message_content,
      message_type: 'customer_to_admin',
      status: 'sent',
      sent_at: rand(14.days.ago..3.days.ago),
      created_at: rand(14.days.ago..3.days.ago)
    )
    
    # Admin response (for some messages)
    if rand < 0.7
      admin_response_content = [
        "Thank you for your inquiry. We're currently reviewing your application and will update you within 2-3 business days.",
        "Your application is progressing well. We may need some additional documentation, which we'll request if needed.",
        "We've received your additional documents and they're being reviewed by our assessment team.",
        "Your application has been approved! We'll be in touch shortly with the next steps.",
        "We're pleased to inform you that your application has been processed successfully."
      ].sample
      
      application.application_messages.create!(
        sender_type: 'User',
        sender: admin_user,
        subject: "Re: Inquiry about Application ##{application.id}",
        content: admin_response_content,
        message_type: 'admin_to_customer',
        status: 'sent',
        sent_at: rand(3.days.ago..1.day.ago),
        created_at: rand(3.days.ago..1.day.ago)
      )
    end
  end
  
  # Add application versions (change history) for some applications
  if rand < 0.4
    # Simulate some status changes
    if application.status != 'created'
      application.application_versions.create!(
        user: admin_user,
        action: 'status_changed',
        change_details: "Application status updated during processing",
        previous_status: 'created',
        new_status: application.status_before_type_cast,
        created_at: rand(application.created_at..application.updated_at)
      )
    end
    
    # Simulate admin viewing the application
    if application.status.in?(['submitted', 'processing', 'accepted', 'rejected'])
      application.application_versions.create!(
        user: admin_user,
        action: 'viewed',
        change_details: "Admin #{admin_user.display_name} viewed application",
        created_at: rand(application.created_at..Time.current)
      )
    end
  end
  
  print "." if i % 5 == 0
end

puts "\n✅ Successfully created 40 test applications with diverse characteristics:"
puts "   - #{Application.status_created.count} applications in 'Created' status"
puts "   - #{Application.status_user_details.count} applications in 'User Details' status"
puts "   - #{Application.status_property_details.count} applications in 'Property Details' status"
puts "   - #{Application.status_income_and_loan_options.count} applications in 'Income and Loan Options' status"
puts "   - #{Application.status_submitted.count} applications in 'Submitted' status"
puts "   - #{Application.status_processing.count} applications in 'Processing' status"
puts "   - #{Application.status_accepted.count} applications in 'Accepted' status"
puts "   - #{Application.status_rejected.count} applications in 'Rejected' status"
puts "   - #{Application.joins(:application_messages).distinct.count} applications with messages"
puts "   - #{Application.joins(:application_versions).distinct.count} applications with change history"

puts "\nProperty value distribution:"
puts "   - Under $1M: #{Application.where('home_value < 1000000').count} applications"
puts "   - $1M - $2M: #{Application.where(home_value: 1000000..2000000).count} applications"
puts "   - Over $2M: #{Application.where('home_value > 2000000').count} applications"

puts "\nOwnership status distribution:"
Application.group(:ownership_status).count.each do |status, count|
  puts "   - #{status.humanize}: #{count} applications"
end

puts "\n🎉 Test data creation completed successfully!"