namespace :demo do
  desc "Send a demo application submitted email to see what it looks like"
  task send_email: :environment do
    # Find or create a test user
    user = User.find_by(email: 'demo@example.com') || User.create!(
      first_name: 'Demo',
      last_name: 'User',
      email: 'demo@example.com',
      password: 'password123',
      password_confirmation: 'password123',
      country_of_residence: 'Australia',
      confirmed_at: Time.current
    )
    
    # Find or create a test application
    application = user.applications.first || user.applications.create!(
      address: '123 Demo Street, Sydney NSW 2000',
      home_value: 1500000,
      ownership_status: 'individual',
      property_state: 'primary_residence',
      has_existing_mortgage: false,
      status: 'submitted',
      borrower_age: 65,
      loan_term: 15,
      income_payout_term: 15,
      growth_rate: 3.5
    )
    
    # Create a mortgage if it doesn't exist
    unless application.mortgage
      mortgage = Mortgage.find_by(name: 'Interest Only') || Mortgage.create!(
        name: 'Interest Only',
        lvr: 50,
        max_age: 85,
        description: 'Interest only payments with equity preservation'
      )
      application.update!(mortgage: mortgage)
    end
    
    # Send the email
    puts "Sending demo application submitted email..."
    UserMailer.application_submitted(application).deliver_now
    puts "Email sent! Check your browser - Letter Opener should have opened a new tab."
    puts "If it doesn't open automatically, check your Rails server logs for the Letter Opener URL."
  end
end