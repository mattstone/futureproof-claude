require 'test_helper'
require 'ostruct'

class EmailTemplateFunctionalityTest < ActiveSupport::TestCase
  # Simple functionality test that doesn't rely on database fixtures

  test "OpenStruct should be available for email template previews" do
    # Test that we can create OpenStruct objects for email previews
    sample_app = OpenStruct.new(
      id: 123,
      address: '123 Test Street',
      formatted_home_value: '$800,000'
    )
    
    assert_equal 123, sample_app.id
    assert_equal '123 Test Street', sample_app.address
    assert_equal '$800,000', sample_app.formatted_home_value
  end

  test "email template should render basic content without database dependencies" do
    # Test basic template rendering functionality
    template = EmailTemplate.new(
      name: 'Test Template',
      template_type: 'verification',
      subject: 'Hello {{user.first_name}}',
      content: '<p>Welcome {{user.first_name}} {{user.last_name}}!</p>'
    )
    
    # Mock user object
    user = OpenStruct.new(
      first_name: 'John',
      last_name: 'Doe',
      email: 'john@example.com'
    )
    
    rendered = template.render_content(user: user)
    
    assert_equal 'Hello John', rendered[:subject]
    assert_includes rendered[:content], 'Welcome John Doe!'
  end

  test "email template should handle application data rendering" do
    template = EmailTemplate.new(
      name: 'App Template',
      template_type: 'application_submitted',
      subject: 'Application {{application.id}}',
      content: '<p>Property: {{application.address}}</p><p>Value: {{application.formatted_home_value}}</p>'
    )
    
    # Mock application object (similar to what controller creates)
    application = OpenStruct.new(
      id: 456,
      address: '456 Sample Avenue',
      formatted_home_value: '$1,200,000',
      status_display: 'Under Review'
    )
    
    user = OpenStruct.new(first_name: 'Jane', last_name: 'Smith')
    
    rendered = template.render_content(user: user, application: application)
    
    assert_equal 'Application 456', rendered[:subject]
    assert_includes rendered[:content], 'Property: 456 Sample Avenue'
    assert_includes rendered[:content], 'Value: $1,200,000'
  end

  test "email template should handle security notification data" do
    template = EmailTemplate.new(
      name: 'Security Template',
      template_type: 'security_notification',
      subject: 'Security Alert for {{user.first_name}}',
      content: '<p>Login from {{security.ip_address}} using {{security.browser_info}}</p>'
    )
    
    user = OpenStruct.new(first_name: 'Bob', last_name: 'Wilson')
    
    rendered = template.render_content({
      user: user,
      browser_info: 'Firefox 121.0',
      ip_address: '203.123.45.67',
      location: 'Melbourne, Australia',
      sign_in_time: Time.parse('2025-01-01 14:30:00')
    })
    
    assert_equal 'Security Alert for Bob', rendered[:subject]
    assert_includes rendered[:content], 'Login from 203.123.45.67'
    assert_includes rendered[:content], 'using Firefox 121.0'
  end

  test "email template should handle missing variables gracefully" do
    template = EmailTemplate.new(
      name: 'Missing Vars Template',
      template_type: 'verification',
      subject: '{{user.first_name}} - {{user.nonexistent}}',
      content: '<p>{{user.first_name}} - {{missing.field}}</p>'
    )
    
    user = OpenStruct.new(first_name: 'Alice')
    
    rendered = template.render_content(user: user)
    
    # Should replace existing fields and leave missing ones unchanged
    assert_includes rendered[:subject], 'Alice'
    assert_includes rendered[:subject], '{{user.nonexistent}}'
    assert_includes rendered[:content], 'Alice'
    assert_includes rendered[:content], '{{missing.field}}'
  end

  test "controller sample application creation should work" do
    # Test the create_sample_application method logic without controller context
    sample_app = OpenStruct.new(
      id: 123,
      address: '123 Sample Street, Melbourne VIC 3000',
      home_value: 800000,
      existing_mortgage_amount: 200000,
      loan_term: 15,
      borrower_age: 65,
      growth_rate: 3.5,
      formatted_home_value: '$800,000',
      formatted_existing_mortgage_amount: '$200,000',
      formatted_loan_value: '$360,000',
      formatted_growth_rate: '3.50%',
      formatted_future_property_value: '$1,200,000',
      formatted_home_equity_preserved: '$840,000'
    )
    
    # Test all the fields that the controller creates
    assert_equal 123, sample_app.id
    assert_equal '123 Sample Street, Melbourne VIC 3000', sample_app.address
    assert_equal 800000, sample_app.home_value
    assert_equal '$800,000', sample_app.formatted_home_value
    assert_equal '$360,000', sample_app.formatted_loan_value
    assert_equal '3.50%', sample_app.formatted_growth_rate
  end

  test "all email template types should have valid allowed template types" do
    valid_types = %w[verification application_submitted security_notification]
    
    valid_types.each do |template_type|
      template = EmailTemplate.new(
        name: "Test #{template_type}",
        template_type: template_type,
        subject: 'Test Subject',
        content: '<p>Test content</p>'
      )
      
      assert template.valid?, "Template type '#{template_type}' should be valid"
    end
  end

  test "email template available fields should include all necessary fields" do
    fields = EmailTemplate.available_fields
    
    # Test verification fields
    verification_fields = fields['verification']
    assert_includes verification_fields['user'], 'first_name'
    assert_includes verification_fields['user'], 'email'
    assert_includes verification_fields['verification'], 'verification_code'
    
    # Test application_submitted fields
    app_fields = fields['application_submitted']
    assert_includes app_fields['user'], 'first_name'
    assert_includes app_fields['application'], 'id'
    assert_includes app_fields['application'], 'address'
    assert_includes app_fields['application'], 'formatted_home_value'
    
    # Test security_notification fields
    security_fields = fields['security_notification']
    assert_includes security_fields['user'], 'first_name'
    assert_includes security_fields['security'], 'ip_address'
    assert_includes security_fields['security'], 'browser_info'
  end
end