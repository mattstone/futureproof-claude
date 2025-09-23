#!/usr/bin/env ruby

# Test CoreLogic integration end-to-end
require 'net/http'
require 'json'
require 'uri'

puts "🧪 Testing Complete CoreLogic Integration"
puts "=" * 50

base_url = "http://localhost:3000"

# Step 1: Create test user
puts "\n1. Creating test user for CoreLogic testing..."
system('rails runner "
user = User.find_or_create_by(email: \"corelogic_test@example.com\") do |u|
  u.password = \"password123\"
  u.password_confirmation = \"password123\"
  u.first_name = \"CoreLogic\"
  u.last_name = \"Test\"
  u.country_of_residence = \"Australia\"
  u.terms_accepted = true
end

app = user.applications.find_or_create_by(status: \"created\") do |a|
  a.ownership_status = \"individual\"
  a.home_value = 1500000
end

puts \"✅ User created: #{user.email} (ID: #{user.id})\"
puts \"✅ Application created: ID #{app.id}\"
"')

# Step 2: Test property autocomplete API
puts "\n2. Testing property autocomplete API..."
uri = URI("#{base_url}/applications/autocomplete?query=123%20Collins")
response = Net::HTTP.get_response(uri)

if response.code == "200"
  suggestions = JSON.parse(response.body)
  puts "✅ Autocomplete API working - #{suggestions.length} suggestions"

  if suggestions.length > 0
    property_id = suggestions.first['id']
    puts "🏠 Testing with property ID: #{property_id}"

    # Step 3: Test property details API
    puts "\n3. Testing property details API..."
    uri = URI("#{base_url}/applications/get_property_details?property_id=#{property_id}")
    response = Net::HTTP.get_response(uri)

    if response.code == "200"
      details = JSON.parse(response.body)
      puts "✅ Property details API working"

      # Check key data points
      if details['valuation'] && details['valuation']['estimate']
        puts "💰 Property valuation: $#{details['valuation']['estimate']}"
        puts "📊 Valuation range: $#{details['valuation']['low_estimate']} - $#{details['valuation']['high_estimate']}"
      end

      if details['attributes']
        attrs = details['attributes']
        puts "🏠 Property details:"
        puts "   - Type: #{attrs['property_type']}"
        puts "   - Bedrooms: #{attrs['beds']}"
        puts "   - Bathrooms: #{attrs['baths']}"
        puts "   - Car spaces: #{attrs['car_spaces']}"
      end

      if details['images'] && details['images'].is_a?(Array)
        puts "📸 Images: #{details['images'].length} property images available"
        puts "   - First image: #{details['images'].first['base_photo_url']}" if details['images'].first
      end

      puts "\n✅ All API endpoints working correctly!"

    else
      puts "❌ Property details API failed: #{response.code}"
    end
  end
else
  puts "❌ Autocomplete API failed: #{response.code}"
end

puts "\n" + "=" * 50
puts "🎯 Manual Browser Test Instructions:"
puts "1. Login: #{base_url}/users/sign_in"
puts "   Email: corelogic_test@example.com"
puts "   Password: password123"
puts "2. Go to: #{base_url}/applications/new"
puts "3. Type '123 Collins' in address field"
puts "4. Select a property suggestion"
puts "5. Verify property preview appears with:"
puts "   - Property images gallery"
puts "   - Property valuation and details"
puts "   - Auto-updated home value slider"
puts "=" * 50