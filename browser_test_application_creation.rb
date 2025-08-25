# Browser-based test for complete application creation workflow
require 'selenium-webdriver'

puts "=== Browser-based Application Creation Test ==="

# Set up Selenium WebDriver
options = Selenium::WebDriver::Chrome::Options.new
options.add_argument('--headless')  # Run in headless mode
options.add_argument('--no-sandbox')
options.add_argument('--disable-dev-shm-usage')

begin
  driver = Selenium::WebDriver.for :chrome, options: options
  driver.manage.timeouts.implicit_wait = 10
  
  puts "✓ WebDriver initialized"
  
  # Navigate to the application
  driver.navigate.to "http://localhost:3000"
  puts "✓ Navigated to application home"
  
  # Test user registration/login
  # Check if sign up link exists
  if driver.find_elements(css: 'a[href*="sign_up"]').any?
    puts "✓ Sign up link found"
  end
  
  # Test application creation flow
  # Navigate to new application page (assuming user is logged in or can access)
  driver.navigate.to "http://localhost:3000/applications/new"
  puts "✓ Navigated to new application page"
  
  # Check for form elements
  form_elements = [
    'input[name*="address"]',
    'input[name*="home_value"]', 
    'select[name*="ownership_status"]',
    'select[name*="property_state"]'
  ]
  
  form_elements.each do |selector|
    if driver.find_elements(css: selector).any?
      puts "✓ Found form field: #{selector}"
    else
      puts "✗ Missing form field: #{selector}"
    end
  end
  
  puts "✓ Application creation form validation complete"
  
rescue Selenium::WebDriver::Error::SessionNotCreatedError => e
  puts "⚠ Chrome WebDriver not available: #{e.message}"
  puts "⚠ Skipping browser tests - Chrome/ChromeDriver not installed"
rescue => e
  puts "✗ Error during browser test: #{e.message}"
ensure
  driver&.quit
end

puts "=== Browser Test Complete ==="
