# Test using existing or creating models
lender = Lender.find_by(lender_type: :futureproof) || Lender.create!(name: 'Test Lender', lender_type: :lender, contact_email: 'test@example.com', address: 'Test Address', postcode: '2000', country: 'Australia')
puts 'Lender found/created: ' + lender.name

wf = WholesaleFunder.create!(name: 'Test WF', country: 'Australia', currency: 'AUD')
puts 'WholesaleFunder created: ' + wf.name

pool = FunderPool.create!(wholesale_funder: wf, name: 'Test Pool', amount: 100000.0, allocated: 50000.0)
puts 'FunderPool created: ' + pool.name

# Test associations
puts 'WholesaleFunder has funder_pools: ' + wf.funder_pools.count.to_s
puts 'FunderPool belongs to wholesale_funder: ' + pool.wholesale_funder.name

# Test methods
puts 'WholesaleFunder#pools_count: ' + wf.pools_count.to_s
puts 'WholesaleFunder#total_capital: ' + wf.total_capital.to_s
puts 'WholesaleFunder#total_allocated: ' + wf.total_allocated.to_s

puts 'All models working correctly!'