#!/usr/bin/env ruby
# Script to allocate existing contracts to available wholesale_funder pools
# Run with: rails runner lib/scripts/allocate_existing_contracts.rb

puts "🔄 Allocating Existing Contracts to WholesaleFunder Pools"
puts "=" * 60

# Check if we have any unallocated contracts
unallocated_contracts = Contract.where(wholesale_funder_pool_id: nil)
total_contracts = unallocated_contracts.count

if total_contracts.zero?
  puts "✅ No unallocated contracts found. All contracts already have wholesale_funder pool allocations."
  exit
end

puts "📊 Found #{total_contracts} unallocated contract#{'s' if total_contracts != 1}"

# Calculate total capital needed
total_needed = unallocated_contracts.joins(:application).sum('applications.home_value').to_i
formatted_total = ActionController::Base.helpers.number_to_currency(total_needed, precision: 0)
puts "💰 Total capital needed: #{formatted_total}"

# Check available wholesale_funder pools
available_pools = WholesaleFunderPool.all.order(:created_at)
if available_pools.empty?
  puts "❌ ERROR: No wholesale_funder pools available for allocation!"
  puts "   Please create at least one wholesale_funder pool before running this script."
  exit 1
end

puts "\n📋 Available WholesaleFunder Pools:"
available_pools.each do |pool|
  puts "  • #{pool.display_name}"
  puts "    Total: #{pool.formatted_amount} | Available: #{pool.formatted_available}"
end

# Check if we have sufficient total capacity
total_available = available_pools.sum { |p| p.available_amount }
if total_available < total_needed
  puts "\n❌ ERROR: Insufficient total capacity!"
  puts "   Available: #{ActionController::Base.helpers.number_to_currency(total_available, precision: 0)}"
  puts "   Needed: #{formatted_total}"
  puts "   Shortfall: #{ActionController::Base.helpers.number_to_currency(total_needed - total_available, precision: 0)}"
  exit 1
end

puts "\n✅ Sufficient capacity available. Proceeding with allocation..."

# Process each unallocated contract
allocated_count = 0
total_allocated = 0
allocation_errors = []

unallocated_contracts.includes(application: :user).find_each do |contract|
  begin
    application = contract.application
    home_value = application.home_value
    customer_name = application.user.display_name
    
    puts "\n🏠 Processing Contract ##{contract.id}"
    puts "   Customer: #{customer_name}"
    puts "   Property: #{application.address.truncate(50)}"
    puts "   Amount: #{ActionController::Base.helpers.number_to_currency(home_value, precision: 0)}"
    
    # Find available wholesale_funder pool with sufficient capacity
    available_pool = nil
    
    # First try to find mortgage-specific pool if application has a mortgage
    if application.mortgage.present?
      puts "   🔍 Looking for mortgage-specific pools..."
      available_pool = application.mortgage.wholesale_funder_pools
                                 .joins(:mortgage_wholesale_funder_pools)
                                 .where(mortgage_wholesale_funder_pools: { active: true })
                                 .where("wholesale_funder_pools.amount - wholesale_funder_pools.allocated >= ?", home_value)
                                 .order(:created_at)
                                 .first
      
      if available_pool
        puts "   ✅ Found mortgage-specific pool: #{available_pool.display_name}"
      end
    end
    
    # If no mortgage-specific pool found, use any available pool
    if available_pool.nil?
      puts "   🔍 Looking for any available pool..."
      available_pool = WholesaleFunderPool.where("amount - allocated >= ?", home_value)
                                 .order(:created_at)
                                 .first
      
      if available_pool
        puts "   ✅ Found available pool: #{available_pool.display_name}"
      end
    end
    
    if available_pool.nil?
      error_msg = "No pool with sufficient capacity (#{ActionController::Base.helpers.number_to_currency(home_value, precision: 0)}) available"
      puts "   ❌ #{error_msg}"
      allocation_errors << { contract_id: contract.id, customer: customer_name, error: error_msg }
      next
    end
    
    # Perform the allocation
    Contract.transaction do
      # Update contract with wholesale_funder pool and allocated amount
      contract.update!(
        wholesale_funder_pool: available_pool,
        allocated_amount: home_value
      )
      
      # Update wholesale_funder pool allocated amount
      available_pool.update!(
        allocated: available_pool.allocated + home_value
      )
      
      puts "   ✅ Allocated to #{available_pool.display_name}"
      puts "   💰 Amount: #{ActionController::Base.helpers.number_to_currency(home_value, precision: 0)}"
      
      allocated_count += 1
      total_allocated += home_value
    end
    
  rescue => e
    error_msg = "Failed to allocate: #{e.message}"
    puts "   ❌ #{error_msg}"
    allocation_errors << { contract_id: contract.id, customer: customer_name, error: error_msg }
    
    # Log the full error for debugging
    Rails.logger.error "Contract allocation error for contract #{contract.id}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end
end

# Summary
puts "\n" + "=" * 60
puts "📊 ALLOCATION SUMMARY"
puts "=" * 60

puts "✅ Successfully allocated: #{allocated_count} / #{total_contracts} contracts"
puts "💰 Total allocated: #{ActionController::Base.helpers.number_to_currency(total_allocated, precision: 0)}"

if allocation_errors.any?
  puts "\n❌ Allocation errors (#{allocation_errors.count}):"
  allocation_errors.each do |error|
    puts "   • Contract #{error[:contract_id]} (#{error[:customer]}): #{error[:error]}"
  end
end

# Show updated wholesale_funder pool status
puts "\n📋 Updated WholesaleFunder Pool Status:"
WholesaleFunderPool.all.each do |pool|
  pool.reload
  puts "  • #{pool.display_name}"
  puts "    Total: #{pool.formatted_amount} | Allocated: #{pool.formatted_allocated} | Available: #{pool.formatted_available}"
  puts "    Utilization: #{pool.allocation_percentage}% | Contracts: #{pool.contracts.count}"
end

if allocated_count == total_contracts
  puts "\n🎉 All contracts successfully allocated to wholesale_funder pools!"
else
  puts "\n⚠️  #{total_contracts - allocated_count} contracts could not be allocated."
  puts "   Please review the errors above and ensure sufficient wholesale_funder pool capacity."
end

puts "=" * 60