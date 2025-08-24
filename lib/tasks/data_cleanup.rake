namespace :data do
  desc "Clean up customer data and reset system to initial state"
  task cleanup: :environment do
    puts "Starting data cleanup..."
    
    ActiveRecord::Base.transaction do
      puts "Removing customer related data..."
      
      # Remove all contracts first (due to dependencies)
      Contract.destroy_all
      puts "✓ Removed all contracts"
      
      # Remove all applications 
      Application.destroy_all
      puts "✓ Removed all applications"
      
      # Remove all non-admin users
      non_admin_users = User.where(admin: false)
      puts "Found #{non_admin_users.count} non-admin users to remove"
      non_admin_users.destroy_all
      puts "✓ Removed all non-admin users"
      
      # Remove change histories (version tables)
      puts "Removing change histories..."
      ApplicationVersion.destroy_all
      ContractVersion.destroy_all  
      UserVersion.destroy_all
      puts "✓ Removed all change histories"
      
      puts "✓ Customer data cleanup completed"
    end
    
    puts "Data cleanup task completed successfully!"
  end
  
  desc "Reset mortgages to only Interest Only and Principal & Interest at 80% LVR"
  task reset_mortgages: :environment do
    puts "Resetting mortgages..."
    
    ActiveRecord::Base.transaction do
      # Remove all existing mortgages and their relationships
      MortgageLender.destroy_all
      MortgageContract.destroy_all
      MortgageVersion.destroy_all
      Mortgage.destroy_all
      puts "✓ Removed all existing mortgages"
      
      # Create Interest Only mortgage
      interest_only = Mortgage.create!(
        name: "Interest Only - LVR 80%",
        mortgage_type: :interest_only,
        lvr: 80.0,
        status: :active
      )
      puts "✓ Created Interest Only mortgage (ID: #{interest_only.id})"
      
      # Create Principal and Interest mortgage  
      principal_interest = Mortgage.create!(
        name: "Principal and Interest - LVR 80%",
        mortgage_type: :principal_and_interest,
        lvr: 80.0,
        status: :active
      )
      puts "✓ Created Principal and Interest mortgage (ID: #{principal_interest.id})"
      
      # Find existing mortgage contracts
      mortgage_contracts = MortgageContract.all
      if mortgage_contracts.any?
        puts "Assigning mortgage contracts to new mortgages..."
        mortgage_contracts.each do |contract|
          # Assign to both mortgages
          contract.update!(mortgage: interest_only)
          # Note: This will assign to interest_only first, 
          # we'll need to create relationships for both
        end
        puts "✓ Assigned mortgage contracts"
      end
      
      puts "✓ Mortgage reset completed"
    end
  end
  
  desc "Remove all funding entities (wholesale_funders, funder_pools, lenders)"
  task remove_funding_entities: :environment do
    puts "Removing all funding entities..."
    
    ActiveRecord::Base.transaction do
      # Remove version records and lender clauses first to avoid foreign key constraints
      puts "Removing version records and lender clauses..."
      LenderVersion.destroy_all
      WholesaleFunderVersion.destroy_all
      FunderPoolVersion.destroy_all
      LenderFunderPoolVersion.destroy_all
      LenderWholesaleFunderVersion.destroy_all
      MortgageLenderVersion.destroy_all
      MortgageContractVersion.destroy_all
      
      # Remove lender clauses that reference users
      LenderClause.destroy_all if defined?(LenderClause)
      LenderClauseVersion.destroy_all if defined?(LenderClauseVersion)
      
      puts "✓ Removed all version records and lender clauses"
      
      # Remove all users (including admins) to avoid dependency issues
      User.destroy_all
      puts "✓ Removed all users (will be recreated during setup)"
      
      # Remove join table records
      LenderFunderPool.destroy_all
      LenderWholesaleFunder.destroy_all
      MortgageLender.destroy_all
      puts "✓ Removed all relationship records"
      
      # Remove funding entities
      FunderPool.destroy_all
      puts "✓ Removed all funder pools"
      
      WholesaleFunder.destroy_all
      puts "✓ Removed all wholesale funders"
      
      Lender.destroy_all
      puts "✓ Removed all lenders"
      
      puts "✓ Funding entities removal completed"
    end
  end
  
  desc "Create initial funding setup"
  task create_initial_funding: :environment do
    puts "Creating initial funding setup..."
    
    ActiveRecord::Base.transaction do
      # Create Test Wholesale Lender
      wholesale_funder = WholesaleFunder.create!(
        name: "Test Wholesale Lender",
        country: "Australia", 
        currency: "AUD"
      )
      puts "✓ Created Test Wholesale Lender (ID: #{wholesale_funder.id})"
      
      # Create Initial Tranche funder pool
      funder_pool = FunderPool.create!(
        wholesale_funder: wholesale_funder,
        name: "Initial Tranche",
        amount: 100_000_000, # 100M
        allocated: 0,
        benchmark_rate: 4.0,
        margin_rate: 0.0
      )
      puts "✓ Created Initial Tranche pool with $100M (ID: #{funder_pool.id})"
      
      # Create 3 lenders
      futureproof_lender = Lender.create!(
        name: "Futureproof",
        lender_type: :futureproof,
        contact_email: "admin@futureproof.com",
        country: "Australia"
      )
      puts "✓ Created Futureproof lender (ID: #{futureproof_lender.id})"
      
      bank_lender = Lender.create!(
        name: "Bank Lender",
        lender_type: :lender,
        contact_email: "admin@banklender.com",
        country: "Australia"
      )
      puts "✓ Created Bank Lender (ID: #{bank_lender.id})"
      
      non_bank_lender = Lender.create!(
        name: "Non Bank Lender", 
        lender_type: :lender,
        contact_email: "admin@nonbanklender.com",
        country: "Australia"
      )
      puts "✓ Created Non Bank Lender (ID: #{non_bank_lender.id})"
      
      # Create default admin user for Futureproof lender
      admin_user = User.create!(
        email: "admin@futureproof.com",
        password: "password",
        password_confirmation: "password",
        first_name: "Admin",
        last_name: "User",
        admin: true,
        country_of_residence: "Australia",
        mobile_country_code: "+61",
        mobile_number: "400000000",
        terms_accepted: true,
        terms_version: 1,
        confirmed_at: Time.current,
        lender: futureproof_lender
      )
      puts "✓ Created admin user (#{admin_user.email})"
      
      # Connect all lenders to wholesale funder
      lenders = [futureproof_lender, bank_lender, non_bank_lender]
      lenders.each do |lender|
        LenderWholesaleFunder.create!(
          lender: lender,
          wholesale_funder: wholesale_funder,
          active: true
        )
        
        # Connect to the funder pool
        LenderFunderPool.create!(
          lender: lender,
          funder_pool: funder_pool,
          active: true
        )
        
        puts "✓ Connected #{lender.name} to wholesale funder and Initial Tranche pool"
      end
      
      # Assign each lender to both mortgages
      mortgages = Mortgage.all
      if mortgages.count == 2
        lenders.each do |lender|
          mortgages.each do |mortgage|
            MortgageLender.create!(
              mortgage: mortgage,
              lender: lender,
              active: true
            )
          end
          puts "✓ Assigned #{lender.name} to both mortgages"
        end
      else
        puts "⚠️  Expected 2 mortgages but found #{mortgages.count}. Please run reset_mortgages task first."
      end
      
      puts "✓ Initial funding setup completed"
    end
  end
  
  desc "Complete system reset (runs all cleanup and setup tasks)"
  task complete_reset: :environment do
    puts "Starting complete system reset..."
    puts "=" * 50
    
    Rake::Task["data:cleanup"].invoke
    puts
    Rake::Task["data:reset_mortgages"].invoke
    puts  
    Rake::Task["data:remove_funding_entities"].invoke
    puts
    Rake::Task["data:create_initial_funding"].invoke
    puts
    
    puts "=" * 50
    puts "✅ Complete system reset finished successfully!"
    
    # Display summary
    puts
    puts "SUMMARY:"
    puts "- Mortgages: #{Mortgage.count}"
    Mortgage.all.each do |m|
      puts "  * #{m.name} (#{m.mortgage_type.humanize}, LVR: #{m.lvr}%)"
    end
    puts "- Wholesale Funders: #{WholesaleFunder.count}"
    puts "- Funder Pools: #{FunderPool.count} (Total: #{FunderPool.sum(:amount).to_i})"
    puts "- Lenders: #{Lender.count}"
    Lender.all.each do |l|
      puts "  * #{l.name} (#{l.lender_type.humanize})"
    end
    puts "- Users (admin only): #{User.count}"
    puts "- Applications: #{Application.count}"
    puts "- Contracts: #{Contract.count}"
  end
end