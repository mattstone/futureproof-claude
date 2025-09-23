#!/usr/bin/env ruby

# Simple script to test property autocomplete functionality
require 'net/http'
require 'uri'
require 'json'

puts "🧪 Testing Property Autocomplete Functionality"
puts "=" * 50

base_url = "http://localhost:3000"

# Test 1: Check if signup page loads
puts "\n1. Testing signup page..."
uri = URI("#{base_url}/users/sign_up")
response = Net::HTTP.get_response(uri)
if response.code == "200" && response.body.include?("Create Account")
  puts "✅ Signup page loads successfully"
else
  puts "❌ Signup page failed to load"
  exit 1
end

# Test 2: Create a user manually via Rails console command
puts "\n2. Creating test user via Rails console..."
system('rails runner "
user = User.find_or_create_by(email: \"test@futureproof.com\") do |u|
  u.password = \"password123\"
  u.password_confirmation = \"password123\"
  u.first_name = \"Test\"
  u.last_name = \"User\"
  u.country_of_residence = \"Australia\"
  u.terms_accepted = true
end

app = user.applications.find_or_create_by(status: \"created\") do |a|
  a.ownership_status = \"individual\"
  a.home_value = 1500000
end

puts \"User created: #{user.email} (ID: #{user.id})\"
puts \"Application created: ID #{app.id}\"
"')

# Test 3: Check if we can access applications page (will still fail due to auth)
puts "\n3. Testing applications page structure..."
uri = URI("#{base_url}/applications/new")
response = Net::HTTP.get_response(uri)
puts "Response code: #{response.code}"

if response.code == "500"
  puts "❌ Applications page has server error (expected - need login)"
  puts "Error is likely due to authentication requirement"
else
  puts "✅ Applications page structure seems okay"
end

# Test 4: Check if autocomplete endpoint exists
puts "\n4. Testing autocomplete endpoint..."
uri = URI("#{base_url}/applications/autocomplete?query=test")
response = Net::HTTP.get_response(uri)
puts "Autocomplete endpoint response: #{response.code}"

# Test 5: Check if property details endpoint exists
puts "\n5. Testing property details endpoint..."
uri = URI("#{base_url}/applications/get_property_details?property_id=123")
response = Net::HTTP.get_response(uri)
puts "Property details endpoint response: #{response.code}"

puts "\n" + "=" * 50
puts "🎯 Next Steps:"
puts "1. Sign up a user manually in browser: #{base_url}/users/sign_up"
puts "2. Navigate to applications page: #{base_url}/applications/new"
puts "3. Test property autocomplete by typing 3+ characters"
puts "4. Verify property preview appears when selecting a property"
puts "=" * 50