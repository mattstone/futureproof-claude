namespace :db do
  desc "Reset database to clean initial state (DEVELOPMENT ONLY)"
  task reset_to_initial_state: :environment do
    # Safety check - only allow in development
    unless Rails.env.development?
      puts "❌ ERROR: This task can only be run in development mode for safety!"
      puts "Current environment: #{Rails.env}"
      exit 1
    end
    
    puts "🔄 Starting database reset to initial state..."
    puts "⚠️  This will remove ALL data and reset to clean state"
    puts
    
    # Confirm with user
    print "Are you sure you want to continue? (yes/no): "
    confirmation = $stdin.gets.chomp.downcase
    unless confirmation == 'yes'
      puts "Operation cancelled."
      exit 0
    end
    
    puts "=" * 60
    puts "PHASE 1: Database Analysis and Cleanup"
    puts "=" * 60
    
    ActiveRecord::Base.transaction do
      # Get all tables except schema and internal Rails tables
      tables_to_skip = %w[
        schema_migrations
        ar_internal_metadata
        active_storage_blobs
        active_storage_attachments
        active_storage_variant_records
      ]
      
      all_tables = ActiveRecord::Base.connection.tables - tables_to_skip
      puts "📊 Found #{all_tables.length} tables to process"
      
      # Disable foreign key constraints temporarily
      if ActiveRecord::Base.connection.adapter_name.downcase.include?('postgresql')
        puts "🔓 Temporarily disabling foreign key constraints..."
        ActiveRecord::Base.connection.execute("SET session_replication_role = 'replica';")
      elsif ActiveRecord::Base.connection.adapter_name.downcase.include?('mysql')
        ActiveRecord::Base.connection.execute("SET FOREIGN_KEY_CHECKS = 0;")
      end
      
      # Clear all tables in reverse dependency order (best effort)
      dependency_order = [
        # Version/audit tables first (they reference everything)
        'user_versions', 'application_versions', 'contract_versions', 
        'mortgage_versions', 'lender_versions', 'wholesale_funder_versions',
        'funder_pool_versions', 'lender_funder_pool_versions', 
        'lender_wholesale_funder_versions', 'mortgage_lender_versions',
        'mortgage_contract_versions', 'email_template_versions',
        'lender_clause_versions',
        
        # Junction/join tables
        'mortgage_contract_users', 'application_messages', 'contract_messages',
        'application_checklists', 'lender_clauses', 'contract_clause_usages',
        'clause_positions', 'lender_funder_pools', 'lender_wholesale_funders',
        'mortgage_lenders', 'mortgage_contracts',
        
        # Main entity dependent tables
        'contracts', 'applications', 
        
        # Independent entities with dependencies
        'users', 'funder_pools', 'mortgages', 'lenders', 'wholesale_funders',
        
        # Static/reference tables
        'email_templates', 'terms_of_uses', 'terms_and_conditions', 
        'privacy_policies', 'ai_agents'
      ]
      
      # First, try to clear tables in dependency order
      cleared_tables = []
      dependency_order.each do |table_name|
        if all_tables.include?(table_name)
          begin
            count = ActiveRecord::Base.connection.execute("SELECT COUNT(*) FROM #{table_name}").first
            row_count = count.is_a?(Hash) ? count.values.first : count.first
            
            if row_count > 0
              ActiveRecord::Base.connection.execute("TRUNCATE TABLE #{table_name} CASCADE")
              puts "✅ Cleared #{table_name} (#{row_count} rows)"
            else
              puts "⚪ #{table_name} already empty"
            end
            cleared_tables << table_name
          rescue => e
            puts "⚠️  Could not clear #{table_name}: #{e.message}"
          end
        end
      end
      
      # Clear any remaining tables that weren't in our dependency order
      remaining_tables = all_tables - cleared_tables
      remaining_tables.each do |table_name|
        begin
          count = ActiveRecord::Base.connection.execute("SELECT COUNT(*) FROM #{table_name}").first
          row_count = count.is_a?(Hash) ? count.values.first : count.first
          
          if row_count > 0
            ActiveRecord::Base.connection.execute("TRUNCATE TABLE #{table_name} CASCADE")
            puts "✅ Cleared #{table_name} (#{row_count} rows) [remaining]"
          else
            puts "⚪ #{table_name} already empty [remaining]"
          end
        rescue => e
          puts "⚠️  Could not clear #{table_name}: #{e.message}"
        end
      end
      
      # Re-enable foreign key constraints
      if ActiveRecord::Base.connection.adapter_name.downcase.include?('postgresql')
        puts "🔒 Re-enabling foreign key constraints..."
        ActiveRecord::Base.connection.execute("SET session_replication_role = 'origin';")
      elsif ActiveRecord::Base.connection.adapter_name.downcase.include?('mysql')
        ActiveRecord::Base.connection.execute("SET FOREIGN_KEY_CHECKS = 1;")
      end
      
      # Reset sequences (PostgreSQL)
      if ActiveRecord::Base.connection.adapter_name.downcase.include?('postgresql')
        puts "🔄 Resetting ID sequences..."
        all_tables.each do |table|
          begin
            # Check if table has an id column
            if ActiveRecord::Base.connection.column_exists?(table, :id)
              ActiveRecord::Base.connection.execute("SELECT setval(pg_get_serial_sequence('#{table}', 'id'), 1, false);")
            end
          rescue => e
            # Ignore sequence reset errors
          end
        end
      end
    end
    
    puts
    puts "=" * 60
    puts "PHASE 2: Creating Initial Data"
    puts "=" * 60
    
    ActiveRecord::Base.transaction do
      puts "🏗️  Creating initial mortgages..."
      
      # Create Interest Only mortgage
      interest_only = Mortgage.create!(
        name: "Interest Only - LVR 80%",
        mortgage_type: :interest_only,
        lvr: 80.0,
        status: :active
      )
      puts "✅ Created Interest Only mortgage (ID: #{interest_only.id})"
      
      # Create Principal and Interest mortgage  
      principal_interest = Mortgage.create!(
        name: "Principal and Interest - LVR 80%",
        mortgage_type: :principal_and_interest,
        lvr: 80.0,
        status: :active
      )
      puts "✅ Created Principal and Interest mortgage (ID: #{principal_interest.id})"
      
      puts "🏗️  Creating wholesale funding structure..."
      
      # Create Test Wholesale Lender
      wholesale_funder = WholesaleFunder.create!(
        name: "Test Wholesale Lender",
        country: "Australia", 
        currency: "AUD"
      )
      puts "✅ Created Test Wholesale Lender (ID: #{wholesale_funder.id})"
      
      # Create Initial Tranche funder pool
      funder_pool = FunderPool.create!(
        wholesale_funder: wholesale_funder,
        name: "Initial Tranche",
        amount: 100_000_000, # 100M
        allocated: 0,
        benchmark_rate: 4.0,
        margin_rate: 0.0
      )
      puts "✅ Created Initial Tranche pool with $100M (ID: #{funder_pool.id})"
      
      puts "🏗️  Creating lenders..."
      
      # Create 3 lenders
      futureproof_lender = Lender.create!(
        name: "Futureproof",
        lender_type: :futureproof,
        contact_email: "admin@futureproof.com",
        country: "Australia"
      )
      puts "✅ Created Futureproof lender (ID: #{futureproof_lender.id})"
      
      bank_lender = Lender.create!(
        name: "Bank Lender",
        lender_type: :lender,
        contact_email: "admin@banklender.com",
        country: "Australia"
      )
      puts "✅ Created Bank Lender (ID: #{bank_lender.id})"
      
      non_bank_lender = Lender.create!(
        name: "Non Bank Lender", 
        lender_type: :lender,
        contact_email: "admin@nonbanklender.com",
        country: "Australia"
      )
      puts "✅ Created Non Bank Lender (ID: #{non_bank_lender.id})"
      
      puts "🏗️  Creating admin user..."
      
      # Create default admin user for Futureproof lender
      admin_user = User.create!(
        email: "admin@futureprooffinancial.co",
        password: "pathword",
        password_confirmation: "pathword",
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
      puts "✅ Created admin user (#{admin_user.email})"
      
      puts "🏗️  Establishing relationships..."
      
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
        
        puts "✅ Connected #{lender.name} to wholesale funder and pool"
      end
      
      # Assign each lender to both mortgages
      mortgages = [interest_only, principal_interest]
      lenders.each do |lender|
        mortgages.each do |mortgage|
          MortgageLender.create!(
            mortgage: mortgage,
            lender: lender,
            active: true
          )
        end
        puts "✅ Assigned #{lender.name} to both mortgages"
      end
      
      puts "🏗️  Ensuring email templates..."
      
      # Ensure default email templates exist
      %w[verification application_submitted security_notification].each do |template_type|
        template = EmailTemplate.for_type(template_type)
        puts "✅ Ensured #{template_type} email template exists (ID: #{template.id})"
      end
    end
    
    puts
    puts "=" * 60
    puts "🎉 DATABASE RESET COMPLETED SUCCESSFULLY!"
    puts "=" * 60
    
    # Display summary
    puts
    puts "📊 FINAL STATE SUMMARY:"
    puts "- Mortgages: #{Mortgage.count}"
    Mortgage.all.each do |m|
      puts "  • #{m.name} (#{m.mortgage_type.humanize}, LVR: #{m.lvr}%)"
    end
    
    puts "- Wholesale Funders: #{WholesaleFunder.count}"
    WholesaleFunder.all.each do |wf|
      puts "  • #{wf.name} (#{wf.currency})"
    end
    
    puts "- Funder Pools: #{FunderPool.count} (Total: $#{FunderPool.sum(:amount).to_i.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse})"
    FunderPool.all.each do |fp|
      puts "  • #{fp.name}: #{fp.formatted_amount}"
    end
    
    puts "- Lenders: #{Lender.count}"
    Lender.all.each do |l|
      puts "  • #{l.name} (#{l.lender_type.humanize})"
    end
    
    puts "- Users: #{User.count} (Admin: #{User.where(admin: true).count})"
    User.all.each do |u|
      puts "  • #{u.email} (#{u.admin? ? 'Admin' : 'User'})"
    end
    
    puts "- Email Templates: #{EmailTemplate.count}"
    EmailTemplate.all.each do |et|
      puts "  • #{et.name} (#{et.template_type})"
    end
    
    puts "- Applications: #{Application.count}"
    puts "- Contracts: #{Contract.count}"
    puts
    
    puts "✅ Database is now in clean initial state for testing!"
    puts "🔑 Admin Login: admin@futureprooffinancial.co / pathword"
  end
  
  desc "Quick database reset (alias for reset_to_initial_state)"
  task reset: :environment do
    Rake::Task["db:reset_to_initial_state"].invoke
  end
end