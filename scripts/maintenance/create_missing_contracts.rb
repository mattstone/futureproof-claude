# Create contracts for accepted applications that don't have them
missing_apps = Application.where(status: :accepted).left_joins(:contract).where(contracts: { id: nil })
puts "Creating contracts for #{missing_apps.count} accepted applications without contracts:"

missing_apps.each do |app|
  contract = Contract.create!(
    application: app,
    start_date: Date.current,
    end_date: Date.current + 5.years,
    status: :awaiting_funding
  )
  puts "  ✅ Created Contract ID: #{contract.id} for Application ID: #{app.id} (#{app.user.display_name})"
end

puts
puts 'Updated status:'
Application.where(status: :accepted).includes(:user, :contract).each do |app|
  puts "  ID: #{app.id}, User: #{app.user.display_name}, Contract: #{app.contract ? 'YES (ID: ' + app.contract.id.to_s + ')' : 'NO'}"
end

puts
puts "Total contracts now: #{Contract.count}"