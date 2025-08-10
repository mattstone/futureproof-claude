namespace :applications do
  desc "Assign random mortgages to applications that don't have mortgages"
  task assign_mortgages: :environment do
    puts "Starting mortgage assignment..."
    
    # Get all mortgages
    mortgages = Mortgage.all.to_a
    puts "Available mortgages: #{mortgages.count}"
    mortgages.each { |m| puts "  - #{m.name} (#{m.mortgage_type_display})" }
    
    # Get applications without mortgages
    applications_without_mortgages = Application.where(mortgage: nil)
    puts "\nApplications without mortgages: #{applications_without_mortgages.count}"
    
    if mortgages.empty?
      puts "No mortgages available to assign!"
      exit
    end
    
    if applications_without_mortgages.empty?
      puts "All applications already have mortgages assigned!"
      exit
    end
    
    # Assign random mortgages to applications
    updated_count = 0
    applications_without_mortgages.find_each do |application|
      # Select a random mortgage
      random_mortgage = mortgages.sample
      
      # Set default loan parameters if they don't exist
      loan_term = application.loan_term || [20, 25, 30].sample
      income_payout_term = application.income_payout_term || loan_term
      growth_rate = application.growth_rate || [2.5, 3.0, 3.5, 4.0].sample
      
      # Update the application
      application.update!(
        mortgage: random_mortgage,
        loan_term: loan_term,
        income_payout_term: income_payout_term,
        growth_rate: growth_rate
      )
      
      updated_count += 1
      puts "Application ##{application.id}: assigned #{random_mortgage.name} mortgage, loan_term: #{loan_term}, income_payout_term: #{income_payout_term}, growth_rate: #{growth_rate}%"
    end
    
    puts "\n✅ Successfully assigned mortgages to #{updated_count} applications!"
    
    # Verify the results
    remaining_without_mortgages = Application.where(mortgage: nil).count
    total_with_mortgages = Application.where.not(mortgage: nil).count
    
    puts "\nFinal status:"
    puts "  Applications with mortgages: #{total_with_mortgages}"
    puts "  Applications without mortgages: #{remaining_without_mortgages}"
  end
end