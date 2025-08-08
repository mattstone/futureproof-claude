require 'test_helper'

class EmailTemplateTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(
      first_name: 'John',
      last_name: 'Doe',
      email: 'test@example.com',
      password: 'password123',
      password_confirmation: 'password123',
      country_of_residence: 'Australia',
      mobile_country_code: '+61',
      mobile_number: '412345678',
      confirmed_at: Time.current,
      terms_accepted: true
    )
  end

  test "should create email template with valid attributes" do
    template = EmailTemplate.new(
      name: 'Test Template',
      template_type: 'verification',
      subject: 'Test Subject',
      content: '<p>Test content {{user.first_name}}</p>',
      description: 'Test description'
    )
    
    assert template.valid?
    assert template.save
  end

  test "should validate presence of required fields" do
    template = EmailTemplate.new
    
    assert_not template.valid?
    assert_includes template.errors[:name], "can't be blank"
    assert_includes template.errors[:subject], "can't be blank"
    assert_includes template.errors[:content], "can't be blank"
    assert_includes template.errors[:template_type], "can't be blank"
  end

  test "should validate template_type inclusion" do
    template = EmailTemplate.new(
      name: 'Test',
      subject: 'Test',
      content: 'Test',
      template_type: 'invalid_type'
    )
    
    assert_not template.valid?
    assert_includes template.errors[:template_type], "is not included in the list"
  end

  test "should validate name uniqueness" do
    EmailTemplate.create!(
      name: 'Unique Template',
      template_type: 'verification',
      subject: 'Test',
      content: 'Test'
    )
    
    duplicate = EmailTemplate.new(
      name: 'Unique Template',
      template_type: 'application_submitted',
      subject: 'Test',
      content: 'Test'
    )
    
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "has already been taken"
  end

  test "should render verification template with user data" do
    template = EmailTemplate.create!(
      name: 'Email Verification Test',
      template_type: 'verification',
      subject: 'Verify {{user.first_name}}',
      content: '<p>Hello {{user.first_name}} {{user.last_name}}, your code is {{verification.verification_code}}</p>'
    )
    
    rendered = template.render_content({
      user: @user,
      verification_code: '123456',
      expires_at: 15.minutes.from_now
    })
    
    assert_equal 'Verify John', rendered[:subject]
    assert_includes rendered[:content], 'Hello John Doe'
    assert_includes rendered[:content], 'your code is 123456'
  end

  test "should render application_submitted template with application data" do
    application = OpenStruct.new(
      id: 123,
      address: '123 Test St',
      formatted_home_value: '$800,000',
      status_display: 'Processing',
      formatted_created_at: 'January 1, 2025'
    )
    
    template = EmailTemplate.create!(
      name: 'Application Test',
      template_type: 'application_submitted',
      subject: 'Application {{application.id}} submitted',
      content: '<p>Hi {{user.first_name}}, your application for {{application.address}} ({{application.formatted_home_value}}) is {{application.status_display}}</p>'
    )
    
    rendered = template.render_content({
      user: @user,
      application: application
    })
    
    assert_equal 'Application 123 submitted', rendered[:subject]
    assert_includes rendered[:content], 'Hi John'
    assert_includes rendered[:content], '123 Test St'
    assert_includes rendered[:content], '$800,000'
    assert_includes rendered[:content], 'Processing'
  end

  test "should render security_notification template with security data" do
    template = EmailTemplate.create!(
      name: 'Security Test',
      template_type: 'security_notification',
      subject: 'Security Alert for {{user.first_name}}',
      content: '<p>Hi {{user.first_name}}, login from {{security.ip_address}} at {{security.sign_in_time}} using {{security.browser_info}}</p>'
    )
    
    sign_in_time = Time.current
    rendered = template.render_content({
      user: @user,
      browser_info: 'Chrome 120.0',
      ip_address: '192.168.1.1',
      location: 'Sydney, Australia',
      sign_in_time: sign_in_time
    })
    
    assert_equal 'Security Alert for John', rendered[:subject]
    assert_includes rendered[:content], 'Hi John'
    assert_includes rendered[:content], '192.168.1.1'
    assert_includes rendered[:content], 'Chrome 120.0'
    assert_includes rendered[:content], sign_in_time.strftime("%B %d, %Y at %I:%M %p")
  end

  test "should find active template for type" do
    # Create inactive template
    inactive_template = EmailTemplate.create!(
      name: 'Inactive Test',
      template_type: 'verification',
      subject: 'Test',
      content: 'Inactive',
      is_active: false
    )
    
    # Create active template
    active_template = EmailTemplate.create!(
      name: 'Active Test',
      template_type: 'verification',
      subject: 'Test',
      content: 'Active',
      is_active: true
    )
    
    found_template = EmailTemplate.for_type('verification')
    assert_equal active_template.id, found_template.id
    assert_equal 'Active', found_template.content
  end

  test "should create default template when none exists" do
    # Ensure no verification templates exist
    EmailTemplate.where(template_type: 'verification').destroy_all
    
    template = EmailTemplate.for_type('verification')
    
    assert_not_nil template
    assert template.persisted?
    assert_equal 'verification', template.template_type
    assert_equal 'Email Verification', template.name
  end

  test "should return available fields for template types" do
    fields = EmailTemplate.available_fields
    
    assert_includes fields.keys, 'verification'
    assert_includes fields.keys, 'application_submitted'
    assert_includes fields.keys, 'security_notification'
    
    # Check verification fields
    verification_fields = fields['verification']
    assert_includes verification_fields['user'], 'first_name'
    assert_includes verification_fields['verification'], 'verification_code'
    
    # Check application fields
    app_fields = fields['application_submitted']
    assert_includes app_fields['user'], 'first_name'
    assert_includes app_fields['application'], 'id'
    assert_includes app_fields['mortgage'], 'name'
    
    # Check security fields
    security_fields = fields['security_notification']
    assert_includes security_fields['user'], 'first_name'
    assert_includes security_fields['security'], 'browser_info'
  end

  test "should format inline markup" do
    template = EmailTemplate.new(
      name: 'Markup Test',
      template_type: 'verification',
      subject: 'Test',
      content: '<p>This is **bold** and *italic* text</p>'
    )
    
    # Access the private method for testing
    formatted = template.send(:format_inline_markup, 'This is **bold** and *italic* text')
    
    assert_includes formatted, '<strong>bold</strong>'
    assert_includes formatted, '<em>italic</em>'
  end

  test "should sanitize text properly" do
    template = EmailTemplate.new(
      name: 'Sanitize Test',
      template_type: 'verification',
      subject: 'Test',
      content: 'Test'
    )
    
    # Test HTML sanitization
    sanitized = template.send(:sanitize_text, 'Hello <script>alert("xss")</script> world')
    assert_equal 'Hello &lt;script&gt;alert(&quot;xss&quot;)&lt;/script&gt; world', sanitized
  end

  test "should handle missing template variables gracefully" do
    template = EmailTemplate.create!(
      name: 'Missing Vars Test',
      template_type: 'verification',
      subject: 'Hello {{user.first_name}} {{user.missing_field}}',
      content: '<p>{{user.first_name}} - {{nonexistent.field}}</p>'
    )
    
    rendered = template.render_content({ user: @user })
    
    # Should replace existing fields and leave non-existent ones as-is
    assert_includes rendered[:subject], 'Hello John'
    assert_includes rendered[:subject], '{{user.missing_field}}'
    assert_includes rendered[:content], 'John'
    assert_includes rendered[:content], '{{nonexistent.field}}'
  end
end