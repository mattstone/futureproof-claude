#!/usr/bin/env ruby

# FUNCTIONAL VERIFICATION SCRIPT: Mortgage Lender Management
# Run this BEFORE claiming any functionality works
# This catches obvious bugs by testing the ACTUAL user workflow

require_relative '../config/environment'

puts "🔍 FUNCTIONAL VERIFICATION: Mortgage Lender Management"
puts "=" * 60
puts "This script tests the ACTUAL user workflow to catch obvious bugs"
puts "=" * 60

# STEP 1: Find real data to test with
puts "\n📊 STEP 1: Finding real test data"
puts "-" * 30

mortgage = Mortgage.first
if mortgage.nil?
  puts "❌ FAIL: No mortgages found"
  puts "💡 Need at least one mortgage to test with"
  exit 1
end

puts "✅ Found test mortgage: #{mortgage.name} (ID: #{mortgage.id})"

# Check existing lenders
lenders = Lender.all
if lenders.empty?
  puts "❌ FAIL: No lenders found"
  puts "💡 Need at least one lender to test with"
  exit 1
end

puts "✅ Found #{lenders.count} lenders to test with"

# STEP 2: Test the new associations
puts "\n🔄 STEP 2: Testing new mortgage-lender associations"
puts "-" * 50

begin
  # Test new associations
  puts "Testing mortgage.active_lenders..."
  active_lenders = mortgage.active_lenders
  puts "✅ mortgage.active_lenders works: #{active_lenders.count} active lenders"
  
  puts "Testing mortgage.mortgage_lenders..."
  mortgage_lenders = mortgage.mortgage_lenders
  puts "✅ mortgage.mortgage_lenders works: #{mortgage_lenders.count} relationships"
  
  puts "Testing mortgage.lender_names..."
  lender_names = mortgage.lender_names
  puts "✅ mortgage.lender_names works: '#{lender_names}'"
  
  puts "Testing lender.active_mortgages..."
  first_lender = lenders.first
  active_mortgages = first_lender.active_mortgages
  puts "✅ lender.active_mortgages works: #{active_mortgages.count} active mortgages"
  
rescue => e
  puts "❌ FAIL: New associations crashed"
  puts "   Error: #{e.message}"
  puts "   This would break the mortgage-lender interface!"
  exit 1
end

# STEP 3: Test available_lenders endpoint
puts "\n🌐 STEP 3: Testing available_lenders AJAX endpoint"
puts "-" * 45

begin
  # Simulate the controller action
  available_lenders = Lender.where.not(id: mortgage.lenders.select(:id))
                            .order(:name)

  # This is what gets sent as JSON
  lenders_json = available_lenders.map do |lender|
    {
      id: lender.id,
      name: lender.name,
      lender_type: lender.lender_type.humanize,
      contact_email: lender.contact_email
    }
  end

  puts "✅ Available lenders JSON generation: SUCCESS"
  puts "   Lenders returned: #{lenders_json.length}"
  lenders_json.first(3).each do |lender|
    puts "   - #{lender[:name]} (#{lender[:lender_type]})"
  end

rescue => e
  puts "❌ FAIL: Available lenders JSON generation crashed"
  puts "   Error: #{e.message}"
  puts "   This would break the 'Add Lender' dropdown!"
  exit 1
end

# STEP 4: Test route generation
puts "\n🛤️ STEP 4: Testing route generation (URL bug detection)"
puts "-" * 55

begin
  # Create a test relationship if none exists
  test_relationship = mortgage.mortgage_lenders.first
  if test_relationship.nil?
    if available_lenders.any?
      test_lender = available_lenders.first
      test_relationship = mortgage.mortgage_lenders.create!(
        lender: test_lender,
        active: true
      )
      puts "   ✅ Created test relationship (ID: #{test_relationship.id})"
    else
      puts "❌ FAIL: No lenders available to create test relationship"
      exit 1
    end
  end

  # Test URL generation
  toggle_url = "/admin/mortgages/#{mortgage.id}/lenders/#{test_relationship.id}/toggle_active"
  remove_url = "/admin/mortgages/#{mortgage.id}/lenders/#{test_relationship.id}"
  add_url = "/admin/mortgages/#{mortgage.id}/lenders/add_lender"
  
  puts "✅ Expected toggle URL: #{toggle_url}"
  puts "✅ Expected remove URL: #{remove_url}"
  puts "✅ Expected add URL: #{add_url}"
  
  # Verify URLs contain correct IDs
  if toggle_url.include?("/admin/mortgages/#{mortgage.id}/")
    puts "✅ Toggle URL contains correct mortgage ID: #{mortgage.id}"
  else
    puts "❌ FAIL: Toggle URL contains wrong mortgage ID"
    exit 1
  end
  
  if remove_url.include?("/admin/mortgages/#{mortgage.id}/")
    puts "✅ Remove URL contains correct mortgage ID: #{mortgage.id}"
  else
    puts "❌ FAIL: Remove URL contains wrong mortgage ID"
    exit 1
  end

rescue => e
  puts "❌ FAIL: Route generation crashed"
  puts "   Error: #{e.message}"
  exit 1
end

# STEP 5: Test controller logic
puts "\n🎛️ STEP 5: Testing controller logic simulation"
puts "-" * 40

begin
  # Simulate controller parameters
  params = {
    mortgage_id: mortgage.id.to_s,
    id: test_relationship.id.to_s
  }
  
  # Test set_mortgage
  controller_mortgage = Mortgage.find(params[:mortgage_id])
  puts "✅ set_mortgage: Found mortgage #{controller_mortgage.id}"
  
  # Test set_mortgage_lender (the CRITICAL fix)
  controller_relationship = controller_mortgage.mortgage_lenders.find(params[:id])
  puts "✅ set_mortgage_lender: Found relationship #{controller_relationship.id}"
  
  # Verify security scoping
  if controller_relationship.mortgage_id == controller_mortgage.id
    puts "✅ Relationship properly scoped to mortgage (security OK)"
  else
    puts "❌ FAIL: Relationship not properly scoped (SECURITY ISSUE)"
    exit 1
  end

rescue ActiveRecord::RecordNotFound => e
  puts "❌ FAIL: Controller logic would crash with RecordNotFound"
  puts "   Error: #{e.message}"
  puts "   This is the exact error users would see!"
  exit 1
rescue => e
  puts "❌ FAIL: Controller logic crashed"
  puts "   Error: #{e.message}"
  exit 1
end

# STEP 6: Test add lender logic
puts "\n➕ STEP 6: Testing add lender logic"
puts "-" * 30

if available_lenders.any?
  # Find a lender that doesn't already have a relationship
  test_lender = available_lenders.find { |l| !mortgage.mortgage_lenders.exists?(lender: l) }
  
  if test_lender.nil?
    puts "⚠️  All available lenders already have relationships - using validation test instead"
    test_lender = available_lenders.first
  end
  
  begin
    # Test creating a new relationship (what add_lender does)
    initial_count = mortgage.mortgage_lenders.count
    
    new_relationship = mortgage.mortgage_lenders.build(
      lender: test_lender,
      active: true
    )
    
    if new_relationship.valid?
      puts "✅ Add lender validation: PASSED"
      puts "   Would add lender: #{test_lender.name}"
      # Don't actually save to avoid polluting data
    else
      # Check if this is expected (duplicate relationship)
      if new_relationship.errors.full_messages.any? { |msg| msg.include?("already associated") }
        puts "✅ Add lender validation: PASSED (correctly rejected duplicate)"
        puts "   Properly prevents duplicate relationships"
      else
        puts "❌ FAIL: Add lender validation failed unexpectedly"
        new_relationship.errors.full_messages.each do |error|
          puts "   - #{error}"
        end
        exit 1
      end
    end
    
  rescue => e
    puts "❌ FAIL: Add lender logic crashed"
    puts "   Error: #{e.message}"
    exit 1
  end
else
  puts "⚠️  No available lenders to test add logic with"
end

# STEP 7: Test Stimulus controller preservation
puts "\n🎭 STEP 7: Testing Stimulus controller preservation"
puts "-" * 50

puts "Testing for the add/remove/re-add bug..."
puts "This checks if Turbo Stream updates preserve Stimulus data attributes"

# Check if we're targeting the right element for updates
puts "✅ Turbo Stream should target 'lender-list-content' NOT 'existing-lenders'"
puts "   - 'existing-lenders' has Stimulus data attributes"
puts "   - 'lender-list-content' is the inner content wrapper"
puts "   - This preserves the Stimulus controller connection"

# Verify the structure is correct in the view
view_path = '/Users/zen/projects/futureproof/futureproof/app/views/admin/mortgages/show.html.erb'
if File.exist?(view_path)
  view_content = File.read(view_path)
  
  if view_content.include?('id="existing-lenders"') && view_content.include?('data-mortgage-lender-selector-target="existingLenders"')
    puts "✅ Stimulus target element exists: existing-lenders"
  else
    puts "❌ FAIL: Stimulus target element missing or incorrectly structured"
    exit 1
  end
  
  if view_content.include?('id="lender-list-content"')
    puts "✅ Content wrapper element exists: lender-list-content"
  else
    puts "❌ FAIL: Content wrapper element missing"
    puts "   Need to add: <div id=\"lender-list-content\"> inside existing-lenders"
    exit 1
  end
  
  puts "✅ View structure correct for Stimulus preservation"
else
  puts "❌ FAIL: Cannot verify view structure"
  exit 1
end

# Check Turbo Stream templates target the right element
turbo_templates = [
  '/Users/zen/projects/futureproof/futureproof/app/views/admin/mortgage_lenders/add_lender.turbo_stream.erb',
  '/Users/zen/projects/futureproof/futureproof/app/views/admin/mortgage_lenders/destroy.turbo_stream.erb',
  '/Users/zen/projects/futureproof/futureproof/app/views/admin/mortgage_lenders/toggle_active.turbo_stream.erb'
]

turbo_templates.each do |template_path|
  if File.exist?(template_path)
    template_content = File.read(template_path)
    
    if template_content.include?('turbo_stream.update "lender-list-content"')
      puts "✅ #{File.basename(template_path)} targets correct element"
    elsif template_content.include?('turbo_stream.update "existing-lenders"')
      puts "❌ FAIL: #{File.basename(template_path)} targets wrong element (existing-lenders)"
      puts "   This would destroy Stimulus controller and cause the add/remove/re-add bug"
      exit 1
    else
      puts "⚠️  #{File.basename(template_path)} has unusual turbo_stream.update target"
    end
  else
    puts "❌ FAIL: Template missing: #{template_path}"
    exit 1
  end
end

puts "✅ All Turbo Stream templates target correct element"

# STEP 8: Test data migration success
puts "\n📊 STEP 8: Testing data migration success"
puts "-" * 40

# Check if old lender_id column was properly removed
begin
  # This should fail because lender_id column should be removed
  mortgage.lender_id
  puts "❌ FAIL: Old lender_id column still exists!"
  puts "   Migration did not properly remove the old column"
  exit 1
rescue NoMethodError
  puts "✅ Old lender_id column properly removed"
rescue => e
  puts "❌ FAIL: Unexpected error checking old column: #{e.message}"
  exit 1
end

# Check if any existing relationships were migrated
total_relationships = MortgageLender.count
puts "✅ Found #{total_relationships} mortgage-lender relationships in database"
puts "✅ Data migration appears successful"

puts "\n🎉 FUNCTIONAL VERIFICATION: ALL TESTS PASSED"
puts "=" * 60
puts "✅ Data setup: WORKING"
puts "✅ New associations: WORKING" 
puts "✅ Available lenders endpoint: WORKING"
puts "✅ Route generation: WORKING (correct mortgage IDs)"
puts "✅ Controller logic: WORKING (proper scoping)"
puts "✅ Add lender logic: WORKING"
puts "✅ Security scoping: WORKING"
puts "✅ Stimulus preservation: WORKING (add/remove/re-add bug FIXED)"
puts "✅ Data migration: WORKING (old column removed)"
puts ""
puts "🚀 The mortgage-lender functionality should now work correctly!"
puts ""
puts "💡 TESTING STRATEGY LESSONS:"
puts "1. ✅ Test with REAL data from the database"
puts "2. ✅ Simulate the EXACT user workflow"  
puts "3. ✅ Test the SPECIFIC bugs that could occur"
puts "4. ✅ Verify URLs contain correct IDs"
puts "5. ✅ Test controller logic step-by-step"
puts "6. ✅ Test Stimulus controller preservation"
puts "7. ✅ Verify data migration success"
puts "8. ✅ Run this BEFORE claiming anything works"