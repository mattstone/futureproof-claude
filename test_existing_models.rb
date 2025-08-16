# Test using existing data or create unique records
lender = Lender.find_by(lender_type: :futureproof) || Lender.create!(name: 'Test Lender', lender_type: :lender, contact_email: 'test2@example.com', address: 'Test Address', postcode: '2000', country: 'Australia')
puts 'Lender found/created: ' + lender.name

# Create unique WholesaleFunder
wf = WholesaleFunder.find_by(name: 'Test WF') || WholesaleFunder.create!(name: "Test WF #{Time.current.to_i}", country: 'Australia', currency: 'AUD')
puts 'WholesaleFunder found/created: ' + wf.name

# Create unique FunderPool
pool = FunderPool.find_by(name: 'Test Pool', wholesale_funder: wf) || FunderPool.create!(wholesale_funder: wf, name: "Test Pool #{Time.current.to_i}", amount: 100000.0, allocated: 50000.0)
puts 'FunderPool found/created: ' + pool.name

# Test associations
puts 'WholesaleFunder has funder_pools: ' + wf.funder_pools.count.to_s
puts 'FunderPool belongs to wholesale_funder: ' + pool.wholesale_funder.name

# Test methods
puts 'WholesaleFunder#pools_count: ' + wf.pools_count.to_s
puts 'WholesaleFunder#total_capital: ' + wf.total_capital.to_s
puts 'WholesaleFunder#total_allocated: ' + wf.total_allocated.to_s

puts 'All models working correctly!'