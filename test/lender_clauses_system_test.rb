#!/usr/bin/env ruby

# Comprehensive test suite for the Lender Clauses Version Control System
# This script verifies all aspects of the version control system functionality

require_relative '../config/environment'

class LenderClausesSystemTest
  def self.run
    puts "🔬 Lender Clauses Version Control System - Comprehensive Test Suite"
    puts "=" * 80
    
    begin
      # Test setup
      test_setup
      
      # Run all test modules
      test_database_structure
      test_model_relationships
      test_version_control_functionality
      test_clause_position_system
      test_contract_clause_integration
      test_historical_reconstruction
      test_content_rendering
      test_user_attribution
      test_validation_and_constraints
      test_edge_cases
      
      puts "\n" + "=" * 80
      puts "🎉 ALL TESTS PASSED! Lender Clauses Version Control System is fully functional!"
      puts "✅ Version control system ready for production use"
      
      return true
      
    rescue => e
      puts "\n💥 TEST FAILED: #{e.message}"
      puts e.backtrace.first(5).join("\n")
      return false
    ensure
      # Cleanup test data
      cleanup_test_data
    end
  end

  private

  def self.test_setup
    puts "\n📋 Setting up test environment..."
    
    # Ensure we have test lenders
    @test_lender1 = Lender.find_or_create_by(name: "Test Bank Alpha") do |lender|
      lender.contact_email = "alpha@testbank.com"
      lender.lender_type = :lender
      lender.country = "Australia"
    end
    
    @test_lender2 = Lender.find_or_create_by(name: "Test Credit Union Beta") do |lender|
      lender.contact_email = "beta@testcredit.com"
      lender.lender_type = :lender
      lender.country = "Australia"
    end
    
    # Create test user
    @test_user = User.find_or_create_by(email: "testuser@futureproof.com") do |user|
      user.first_name = "Test"
      user.last_name = "User"
      user.mobile_number = "1234567890"
      user.address = "123 Test Street, Melbourne VIC 3000"
      user.country_of_residence = "Australia"
    end
    
    # Create test mortgage
    @test_mortgage = Mortgage.find_or_create_by(name: "Test Mortgage for Clauses") do |mortgage|
      mortgage.lvr = 80.0
      mortgage.mortgage_type = :principal_and_interest
    end
    
    # Create test contract
    @test_contract = MortgageContract.find_or_create_by(title: "Test Contract for Clauses") do |contract|
      contract.content = create_test_contract_content
      contract.mortgage = @test_mortgage
      contract.primary_user = @test_user
      contract.last_updated = Time.current
      contract.version = 1
      contract.is_draft = false
      contract.is_active = true
    end
    
    puts "  ✅ Test environment ready"
  end

  def self.test_database_structure
    puts "\n🗄️  Testing database structure..."
    
    # Test clause_positions table
    positions = ClausePosition.count
    raise "ClausePositions not created" if positions != 6
    
    # Verify default positions exist
    expected_positions = [
      'after_section_2', 'after_section_3', 'after_section_4', 
      'after_section_5', 'after_section_6', 'before_signatures'
    ]
    
    existing_positions = ClausePosition.pluck(:section_identifier)
    missing_positions = expected_positions - existing_positions
    raise "Missing positions: #{missing_positions.join(', ')}" if missing_positions.any?
    
    # Test tables exist and have correct structure
    tables = %w[lender_clauses lender_clause_versions contract_clause_usages clause_positions]
    tables.each do |table|
      result = ActiveRecord::Base.connection.execute("SELECT COUNT(*) FROM #{table}")
      puts "    ✓ Table #{table} exists and accessible"
    end
    
    puts "  ✅ Database structure verified"
  end

  def self.test_model_relationships
    puts "\n🔗 Testing model relationships..."
    
    # Test Lender -> LenderClause relationship
    clause = @test_lender1.lender_clauses.build(
      title: "Test Privacy Clause",
      content: "## Privacy Protection\n\nThis clause ensures customer data privacy.",
      description: "Standard privacy protection clause",
      last_updated: Time.current
    )
    clause.current_user = @test_user
    clause.save!
    
    # Test associations
    raise "Lender clause not associated with lender" unless clause.lender == @test_lender1
    raise "Lender clauses association broken" unless @test_lender1.lender_clauses.include?(clause)
    
    # Test clause positions relationship
    position = ClausePosition.find_by(section_identifier: 'after_section_3')
    raise "Clause position not found" unless position
    
    puts "  ✅ Model relationships working correctly"
  end

  def self.test_version_control_functionality
    puts "\n📝 Testing version control functionality..."
    
    # Create initial clause
    clause = @test_lender1.lender_clauses.create!(
      title: "Data Protection Clause",
      content: "## Data Protection\n\nWe protect your data according to privacy laws.",
      description: "Basic data protection clause",
      last_updated: Time.current,
      current_user: @test_user
    )
    
    # Test version creation  
    expected_version = @test_lender1.lender_clauses.maximum(:version) || 1
    raise "Version not set correctly" unless clause.version == expected_version
    raise "Should be draft by default" unless clause.draft?
    raise "Should not be active by default" if clause.is_active?
    
    # Test version history creation
    versions = clause.lender_clause_versions
    raise "Version history not created" unless versions.count == 1
    raise "Creation not logged" unless versions.first.action == 'created'
    
    # Test publishing
    clause.publish!
    raise "Should be published" unless clause.published?
    
    # Test activation
    clause.activate!
    raise "Should be active" unless clause.is_active?
    raise "Should still be published" unless clause.published?
    
    # Test version increment when creating new version
    new_clause = @test_lender1.lender_clauses.create!(
      title: "Enhanced Data Protection Clause",
      content: "## Enhanced Data Protection\n\nWe provide enhanced data protection.",
      description: "Enhanced data protection clause",
      last_updated: Time.current,
      current_user: @test_user
    )
    
    raise "Version should increment" unless new_clause.version == clause.version + 1
    
    puts "  ✅ Version control functionality working correctly"
  end

  def self.test_clause_position_system
    puts "\n📍 Testing clause position system..."
    
    # Test position ordering
    positions = ClausePosition.ordered
    raise "Positions not ordered correctly" unless positions.first.display_order <= positions.last.display_order
    
    # Test position validation
    position = ClausePosition.new(
      name: "Test Position",
      section_identifier: "duplicate_test",
      description: "Test position",
      display_order: 10
    )
    
    raise "Position should be valid" unless position.valid?
    position.save!
    
    # Test uniqueness constraint
    duplicate_position = ClausePosition.new(
      name: "Another Test Position", 
      section_identifier: "duplicate_test",
      description: "Duplicate test position",
      display_order: 11
    )
    
    raise "Duplicate section_identifier should not be allowed" if duplicate_position.valid?
    
    puts "  ✅ Clause position system working correctly"
  end

  def self.test_contract_clause_integration
    puts "\n🔗 Testing contract-clause integration..."
    
    # Create lender clause
    clause = @test_lender1.lender_clauses.create!(
      title: "Security Clause",
      content: "## Security Requirements\n\nThis property must maintain adequate security measures.",
      description: "Security requirements clause",
      last_updated: Time.current,
      is_active: true,
      is_draft: false,
      current_user: @test_user
    )
    
    # Get clause position
    position = ClausePosition.find_by(section_identifier: 'after_section_5')
    
    # Test adding clause to contract
    @test_contract.add_lender_clause(clause, position, @test_user)
    
    # Verify integration
    usage = @test_contract.contract_clause_usages.first
    raise "Contract clause usage not created" unless usage
    raise "Clause not linked correctly" unless usage.lender_clause == clause
    raise "Position not linked correctly" unless usage.clause_position == position
    raise "User not attributed correctly" unless usage.added_by == @test_user
    
    # Test snapshot creation
    raise "Content snapshot not captured" if usage.clause_content_snapshot.blank?
    raise "Snapshot content mismatch" unless usage.clause_content_snapshot == clause.content
    
    # Test version tracking
    raise "Contract version not captured" unless usage.contract_version_at_usage == @test_contract.version
    raise "Clause version not captured" unless usage.clause_version_at_usage == clause.version
    
    # Test active clause queries
    raise "Active clauses not found" unless @test_contract.has_active_clauses?
    raise "Active clause count incorrect" unless @test_contract.active_clauses_count == 1
    
    puts "  ✅ Contract-clause integration working correctly"
  end

  def self.test_historical_reconstruction
    puts "\n⏰ Testing historical reconstruction..."
    
    # Create clause and add to contract
    clause = @test_lender2.lender_clauses.create!(
      title: "Historical Clause",
      content: "## Original Content\n\nThis is the original clause content.",
      description: "Test clause for historical reconstruction",
      last_updated: Time.current,
      is_active: true,
      is_draft: false,
      current_user: @test_user
    )
    
    position = ClausePosition.find_by(section_identifier: 'after_section_3')
    @test_contract.add_lender_clause(clause, position, @test_user)
    
    # Record timestamp for later reconstruction
    usage_time = Time.current
    sleep(0.1) # Ensure different timestamps
    
    # Simulate changes over time
    clause.update!(
      content: "## Updated Content\n\nThis is updated clause content.",
      last_updated: Time.current,
      current_user: @test_user
    )
    
    # Test historical reconstruction
    historical_state = @test_contract.contract_at_time(usage_time)
    raise "Historical clauses not found" unless historical_state[:active_clauses].any?
    
    historical_usage = historical_state[:active_clauses].first
    raise "Historical content not preserved" unless historical_usage.clause_content_snapshot.include?("Original Content")
    
    # Verify snapshot is different from current content
    current_content = clause.reload.content
    raise "Current content should be different" if current_content.include?("Original Content")
    raise "Historical snapshot preserved incorrectly" unless historical_usage.clause_content_snapshot.include?("Original Content")
    
    puts "  ✅ Historical reconstruction working correctly"
  end

  def self.test_content_rendering
    puts "\n🎨 Testing content rendering..."
    
    # Create clause with markup content
    clause = @test_lender1.lender_clauses.create!(
      title: "Rendering Test Clause",
      content: "## Test Section\n\n**Bold text** and regular text.\n\n- List item 1\n- List item 2\n\n**Field:** Value",
      description: "Test clause for rendering",
      last_updated: Time.current,
      is_active: true,
      is_draft: false,
      current_user: @test_user
    )
    
    # Test basic rendering
    rendered = clause.rendered_content
    raise "HTML not generated" if rendered.blank?
    raise "Bold text not rendered" unless rendered.include?("<strong>Bold text</strong>")
    raise "List not rendered" unless rendered.include?("<li>List item 1</li>")
    
    # Test placeholder substitution
    substitutions = { 'lender_name' => 'Test Lender Name' }
    clause_with_placeholder = @test_lender1.lender_clauses.create!(
      title: "Placeholder Test Clause",
      content: "## Lender Information\n\nLender: {{lender_name}}",
      description: "Test clause with placeholders",
      last_updated: Time.current,
      current_user: @test_user
    )
    
    rendered_with_subs = clause_with_placeholder.rendered_content(substitutions)
    raise "Placeholder not substituted" unless rendered_with_subs.include?("Test Lender Name")
    
    # Test preview rendering
    preview = clause.rendered_preview_content
    raise "Preview not generated" if preview.blank?
    
    puts "  ✅ Content rendering working correctly"
  end

  def self.test_user_attribution
    puts "\n👤 Testing user attribution..."
    
    # Create clause with user attribution
    clause = @test_lender1.lender_clauses.build(
      title: "Attribution Test Clause",
      content: "## Attribution Test\n\nThis clause tests user attribution.",
      description: "Test clause for attribution",
      last_updated: Time.current
    )
    clause.current_user = @test_user
    clause.save!
    
    # Test creation attribution
    version = clause.lender_clause_versions.first
    raise "User not attributed in version" unless version.user == @test_user
    raise "Creation action not logged" unless version.action == 'created'
    
    # Test update attribution
    clause.update!(
      content: "## Updated Attribution Test\n\nThis clause has been updated.",
      current_user: @test_user
    )
    
    update_version = clause.lender_clause_versions.where(action: 'updated').first
    raise "Update not logged" unless update_version
    raise "User not attributed in update" unless update_version.user == @test_user
    
    # Test contract clause usage attribution
    position = ClausePosition.find_by(section_identifier: 'after_section_4')
    @test_contract.add_lender_clause(clause, position, @test_user)
    
    usage = @test_contract.contract_clause_usages.where(lender_clause: clause).first
    raise "Usage user not attributed" unless usage.added_by == @test_user
    
    puts "  ✅ User attribution working correctly"
  end

  def self.test_validation_and_constraints
    puts "\n✅ Testing validation and constraints..."
    
    # Test required field validations
    invalid_clause = LenderClause.new
    raise "Should be invalid without required fields" if invalid_clause.valid?
    
    expected_errors = %w[lender title content last_updated version]
    actual_errors = invalid_clause.errors.keys.map(&:to_s)
    missing_validations = expected_errors - actual_errors
    raise "Missing validations: #{missing_validations.join(', ')}" if missing_validations.any?
    
    # Test unique version constraint per lender
    clause1 = @test_lender1.lender_clauses.create!(
      title: "Constraint Test 1",
      content: "Test content 1",
      description: "Test",
      last_updated: Time.current,
      version: 100
    )
    
    clause2 = @test_lender1.lender_clauses.build(
      title: "Constraint Test 2", 
      content: "Test content 2",
      description: "Test",
      last_updated: Time.current,
      version: 100  # Same version, same lender - should fail
    )
    
    raise "Version uniqueness constraint not working" if clause2.valid?
    
    # Test clause position uniqueness in active contract clauses
    clause_a = @test_lender1.lender_clauses.create!(
      title: "Position Test A",
      content: "Test content A",
      description: "Test",
      last_updated: Time.current,
      is_active: true,
      is_draft: false
    )
    
    clause_b = @test_lender1.lender_clauses.create!(
      title: "Position Test B", 
      content: "Test content B",
      description: "Test",
      last_updated: Time.current,
      is_active: true,
      is_draft: false
    )
    
    position = ClausePosition.find_by(section_identifier: 'after_section_2')
    
    # Add first clause - should work
    @test_contract.add_lender_clause(clause_a, position, @test_user)
    
    # Add second clause to same position - should replace first
    @test_contract.add_lender_clause(clause_b, position, @test_user)
    
    active_usages = @test_contract.active_contract_clause_usages.where(clause_position: position)
    raise "Should only have one active clause per position" unless active_usages.count == 1
    raise "Should have the latest clause active" unless active_usages.first.lender_clause == clause_b
    
    puts "  ✅ Validation and constraints working correctly"
  end

  def self.test_edge_cases
    puts "\n🎯 Testing edge cases..."
    
    # Test empty content handling
    clause = @test_lender1.lender_clauses.create!(
      title: "Empty Content Test",
      content: "",
      description: "Test empty content",
      last_updated: Time.current
    )
    
    # Should not crash on empty content
    rendered = clause.rendered_content
    raise "Empty content should return empty string" unless rendered == ""
    
    # Test removing and reactivating clauses
    clause = @test_lender1.lender_clauses.create!(
      title: "Remove/Reactivate Test",
      content: "## Test Content\n\nThis clause will be removed and reactivated.",
      description: "Test",
      last_updated: Time.current,
      is_active: true,
      is_draft: false
    )
    
    position = ClausePosition.find_by(section_identifier: 'before_signatures')
    @test_contract.add_lender_clause(clause, position, @test_user)
    
    usage = @test_contract.contract_clause_usages.where(
      lender_clause: clause, 
      clause_position: position
    ).first
    
    # Test removal
    usage.remove!(@test_user)
    raise "Should be marked as removed" unless usage.removed?
    raise "Should not be active" if usage.active?
    raise "Removed by should be set" unless usage.removed_by == @test_user
    
    # Test reactivation
    usage.reactivate!(@test_user)
    raise "Should be active again" unless usage.active?
    raise "Should not be removed" if usage.removed?
    raise "Removed by should be cleared" if usage.removed_by.present?
    
    # Test multiple lenders with same clause titles (should be allowed)
    title = "Common Clause Title"
    
    clause1 = @test_lender1.lender_clauses.create!(
      title: title,
      content: "Lender 1 content",
      description: "Test", 
      last_updated: Time.current
    )
    
    clause2 = @test_lender2.lender_clauses.create!(
      title: title,
      content: "Lender 2 content",
      description: "Test",
      last_updated: Time.current
    )
    
    raise "Different lenders should be able to use same clause title" unless clause1.valid? && clause2.valid?
    
    puts "  ✅ Edge cases handled correctly"
  end

  def self.create_test_contract_content
    <<~CONTENT
      ## 1. Agreement Parties
      
      This Test Contract is between {{primary_user_full_name}} and {{lender_name}}.
      
      ## 2. Loan Details
      
      **Property:** Test Property
      **Loan Amount:** $500,000
      
      ## 3. Terms and Conditions
      
      Standard terms apply.
      
      ## 4. Repayment
      
      Monthly payments required.
      
      ## 5. Security
      
      Property serves as security.
      
      ## 6. Default
      
      Default provisions apply.
      
      ## 7. Signatures
      
      Both parties must sign.
    CONTENT
  end

  def self.cleanup_test_data
    puts "\n🧹 Cleaning up test data..."
    
    # Clean up in reverse dependency order
    ContractClauseUsage.where(
      mortgage_contract: @test_contract
    ).destroy_all if @test_contract
    
    LenderClause.where(
      lender: [@test_lender1, @test_lender2]
    ).destroy_all if @test_lender1 && @test_lender2
    
    @test_contract&.destroy
    @test_mortgage&.destroy
    
    # Clean up test positions (keep default ones)
    ClausePosition.where(section_identifier: 'duplicate_test').destroy_all
    
    puts "  ✅ Test cleanup completed"
  end
end

# Run the test if this file is executed directly
if __FILE__ == $0
  success = LenderClausesSystemTest.run
  exit(success ? 0 : 1)
end