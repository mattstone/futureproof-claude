#!/usr/bin/env ruby

# Concise verification script for Lender Clauses Version Control System
# This script quickly verifies all key functionality is working

require_relative '../config/environment'

class LenderClausesVerification
  def self.run
    puts "🔬 Lender Clauses Version Control System - Quick Verification"
    puts "=" * 70
    
    begin
      setup_test_data
      
      puts "\n✅ 1. Database Structure"
      verify_database_structure
      
      puts "✅ 2. Model Relationships" 
      verify_model_relationships
      
      puts "✅ 3. Version Control"
      verify_version_control
      
      puts "✅ 4. Contract Integration"
      verify_contract_integration
      
      puts "✅ 5. Historical Snapshots"
      verify_historical_snapshots
      
      puts "✅ 6. Content Rendering"
      verify_content_rendering
      
      puts "\n" + "=" * 70
      puts "🎉 ALL VERIFICATIONS PASSED!"
      puts "✅ Lender Clauses Version Control System is fully functional"
      puts "✅ Ready for production use"
      
      return true
      
    rescue => e
      puts "\n💥 VERIFICATION FAILED: #{e.message}"
      puts e.backtrace.first(3).join("\n")
      return false
    ensure
      cleanup_test_data
    end
  end

  private

  def self.setup_test_data
    puts "\n📋 Setting up test data..."
    
    @test_lender = Lender.find_or_create_by(name: "Verification Bank") do |lender|
      lender.contact_email = "verify@bank.com"
      lender.lender_type = :lender
      lender.country = "Australia"
    end
    
    @test_user = User.find_by(email: "verify@futureproof.com")
    if @test_user.nil?
      @test_user = User.new(
        email: "verify@futureproof.com",
        first_name: "Verify",
        last_name: "User",
        mobile_number: "400000000",
        mobile_country_code: "+61",
        country_of_residence: "Australia",
        password: "password123",
        confirmed_at: Time.current,
        terms_accepted: true,
        lender: @test_lender
      )
      
      unless @test_user.save
        puts "User validation errors: #{@test_user.errors.full_messages.join(', ')}"
        raise "Could not create test user"
      end
    end
    
    @test_mortgage = Mortgage.create!(
      name: "Verification Mortgage",
      lvr: 80.0,
      mortgage_type: :principal_and_interest
    )
    
    @test_contract = MortgageContract.create!(
      title: "Verification Contract",
      content: "## 1. Parties\n\n{{primary_user_full_name}} and {{lender_name}}\n\n## 2. Terms\n\nStandard terms.",
      mortgage: @test_mortgage,
      primary_user: @test_user,
      last_updated: Time.current,
      is_draft: false,
      is_active: true
    )
  end

  def self.verify_database_structure
    # Check all tables exist
    tables = %w[clause_positions lender_clauses lender_clause_versions contract_clause_usages]
    tables.each { |table| ActiveRecord::Base.connection.execute("SELECT 1 FROM #{table} LIMIT 1") }
    
    # Check default positions created
    expected_count = 6
    actual_count = ClausePosition.count
    raise "Expected #{expected_count} clause positions, got #{actual_count}" unless actual_count >= expected_count
  end

  def self.verify_model_relationships
    # Create clause
    clause = @test_lender.lender_clauses.build(
      title: "Test Clause",
      content: "## Test\n\nThis is a test clause.",
      description: "Test clause",
      last_updated: Time.current
    )
    clause.current_user = @test_user
    clause.save!
    
    # Verify relationships
    raise "Lender relationship broken" unless clause.lender == @test_lender
    raise "Lender clauses association broken" unless @test_lender.lender_clauses.include?(clause)
    raise "Created by relationship broken" unless clause.created_by == @test_user
  end

  def self.verify_version_control
    # Create clause
    clause = @test_lender.lender_clauses.create!(
      title: "Version Test Clause",
      content: "## Original\n\nOriginal content.",
      description: "Test",
      last_updated: Time.current,
      current_user: @test_user
    )
    
    # Check initial state
    raise "Should be draft" unless clause.draft?
    raise "Should not be active" if clause.is_active?
    raise "Version history not created" unless clause.lender_clause_versions.any?
    
    # Test publishing
    clause.publish!
    raise "Should be published" unless clause.published?
    
    # Test activation
    clause.activate!
    raise "Should be active" unless clause.is_active?
    
    # Test version increment
    original_version = clause.version
    new_clause = @test_lender.lender_clauses.create!(
      title: "Version Test 2",
      content: "New content",
      description: "Test",
      last_updated: Time.current,
      current_user: @test_user
    )
    raise "Version should increment" unless new_clause.version == original_version + 1
  end

  def self.verify_contract_integration
    # Create active clause
    clause = @test_lender.lender_clauses.create!(
      title: "Integration Test",
      content: "## Integration\n\nThis clause integrates with contracts.",
      description: "Test",
      last_updated: Time.current,
      is_active: true,
      is_draft: false,
      current_user: @test_user
    )
    
    # Add to contract
    position = ClausePosition.find_by(section_identifier: 'after_section_2')
    @test_contract.add_lender_clause(clause, position, @test_user)
    
    # Verify integration
    raise "Contract should have active clauses" unless @test_contract.has_active_clauses?
    
    usage = @test_contract.contract_clause_usages.first
    raise "Usage not created" unless usage
    raise "Clause not linked" unless usage.lender_clause == clause
    raise "Position not linked" unless usage.clause_position == position
    raise "User not tracked" unless usage.added_by == @test_user
  end

  def self.verify_historical_snapshots
    # Create clause and add to contract
    clause = @test_lender.lender_clauses.create!(
      title: "Snapshot Test",
      content: "## Original Snapshot\n\nOriginal content for snapshot test.",
      description: "Test",
      last_updated: Time.current,
      is_active: true,
      is_draft: false,
      current_user: @test_user
    )
    
    position = ClausePosition.find_by(section_identifier: 'after_section_1') || 
               ClausePosition.find_by(section_identifier: 'after_section_2')
    @test_contract.add_lender_clause(clause, position, @test_user)
    
    usage = @test_contract.contract_clause_usages.where(lender_clause: clause).first
    
    # Check snapshot
    raise "Content snapshot not captured" if usage.clause_content_snapshot.blank?
    raise "Snapshot content incorrect" unless usage.clause_content_snapshot.include?("Original Snapshot")
    
    # Check version tracking
    raise "Contract version not captured" unless usage.contract_version_at_usage == @test_contract.version
    raise "Clause version not captured" unless usage.clause_version_at_usage == clause.version
    
    # Modify clause after usage
    clause.update!(
      content: "## Modified Snapshot\n\nModified content.",
      current_user: @test_user
    )
    
    # Verify snapshot preservation
    usage.reload
    raise "Historical snapshot should be preserved" unless usage.clause_content_snapshot.include?("Original Snapshot")
    raise "Modified content should be different" if clause.content.include?("Original Snapshot")
  end

  def self.verify_content_rendering
    # Create clause with markup
    clause = @test_lender.lender_clauses.create!(
      title: "Rendering Test",
      content: "## Rendering Test\n\n**Bold text** and regular text.\n\n- Item 1\n- Item 2\n\nLender: {{lender_name}}",
      description: "Test",
      last_updated: Time.current,
      current_user: @test_user
    )
    
    # Test basic rendering
    rendered = clause.rendered_content
    raise "HTML not generated" if rendered.blank?
    raise "Bold not rendered" unless rendered.include?("<strong>Bold text</strong>")
    raise "List not rendered" unless rendered.include?("<li>Item 1</li>")
    
    # Test placeholder substitution
    substitutions = { 'lender_name' => 'Test Bank Name' }
    rendered_with_subs = clause.rendered_content(substitutions)
    raise "Placeholder not substituted" unless rendered_with_subs.include?("Test Bank Name")
    
    # Test contract integration rendering
    position = ClausePosition.first
    @test_contract.add_lender_clause(clause, position, @test_user)
    
    contract_rendered = @test_contract.rendered_content
    raise "Contract rendering failed" if contract_rendered.blank?
    raise "Lender clause not integrated" unless contract_rendered.include?("Rendering Test")
  end

  def self.cleanup_test_data
    puts "\n🧹 Cleaning up..."
    
    ContractClauseUsage.where(mortgage_contract: @test_contract).destroy_all if @test_contract
    LenderClause.where(lender: @test_lender).destroy_all if @test_lender
    @test_contract&.destroy
    @test_mortgage&.destroy
    
    puts "  ✅ Cleanup completed"
  end
end

# Run verification if executed directly
if __FILE__ == $0
  success = LenderClausesVerification.run
  exit(success ? 0 : 1)
end