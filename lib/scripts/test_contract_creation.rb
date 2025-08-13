# Test automatic contract creation
test_app = Application.where(status: :submitted).first
if test_app
  puts "Testing automatic contract creation with Application ID: #{test_app.id} (#{test_app.user.display_name})"
  puts "Current status: #{test_app.status}"
  puts "Has contract before: #{test_app.contract.present?}"
  
  # Change status to accepted
  test_app.update!(status: :accepted)
  test_app.reload
  
  puts "New status: #{test_app.status}"
  puts "Has contract after: #{test_app.contract.present?}"
  if test_app.contract
    puts "Contract ID: #{test_app.contract.id}"
    puts "Contract Status: #{test_app.contract.status}"
  end
  
  puts "\n✅ Automatic contract creation test completed!"
else
  puts 'No submitted applications found to test with'
  
  # Create a test application to verify the functionality
  puts 'Creating a test application to verify automatic contract creation...'
  test_user = User.first
  test_app = Application.create!(
    user: test_user,
    address: "123 Test Street, Test City",
    home_value: 500000,
    ownership_status: :individual,
    property_state: :primary_residence,
    borrower_age: 65,
    status: :submitted
  )
  
  puts "Created test application ID: #{test_app.id}"
  puts "Current status: #{test_app.status}"
  puts "Has contract before: #{test_app.contract.present?}"
  
  # Change status to accepted
  test_app.update!(status: :accepted)
  test_app.reload
  
  puts "New status: #{test_app.status}"
  puts "Has contract after: #{test_app.contract.present?}"
  if test_app.contract
    puts "Contract ID: #{test_app.contract.id}"
    puts "Contract Status: #{test_app.contract.status}"
  end
  
  puts "\n✅ Test completed with newly created application!"
end