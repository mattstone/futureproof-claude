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
    application = Struct.new(
      :id, :address, :formatted_home_value, :status_display, :formatted_created_at,
      :home_value, :existing_mortgage_amount, :formatted_existing_mortgage_amount,
      :loan_value, :formatted_loan_value, :borrower_age, :loan_term, :growth_rate,
      :formatted_growth_rate, :future_property_value, :formatted_future_property_value,
      :home_equity_preserved, :formatted_home_equity_preserved
    ).new(
      123, '123 Test St', '$800,000', 'Processing', 'January 1, 2025',
      800000, 200000, '$200,000', 600000, '$600,000', 65, 25, 3.5,
      '3.50%', 1200000, '$1,200,000', 1000000, '$1,000,000'
    )
    
    template = EmailTemplate.create!(
      name: 'Application Test',
      template_type: 'application_submitted',
      subject: 'Application {{application.id}} submitted',
      content: '<p>Hi {{user.first_name}}, your application for {{application.address}} ({{application.formatted_home_value}}) has loan value {{application.formatted_loan_value}}</p>'
    )
    
    rendered = template.render_content({
      user: @user,
      application: application
    })
    
    assert_equal 'Application 123 submitted', rendered[:subject]
    assert_includes rendered[:content], 'Hi John'
    assert_includes rendered[:content], '123 Test St'
    assert_includes rendered[:content], '$800,000'
    assert_includes rendered[:content], '$600,000'
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

  # Additional Edge Cases and Production Quality Tests
  test "should handle audit logging properly" do
    template = EmailTemplate.new(
      name: 'Audit Test',
      template_type: 'verification',
      subject: 'Test',
      content: '<p>Test</p>',
      current_user: @user
    )
    
    assert_difference('EmailTemplateVersion.count') do
      template.save!
    end
    
    version = template.email_template_versions.first
    assert_equal @user, version.user
    assert_equal 'created', version.action
    assert_includes version.change_details, 'Audit Test'
  end

  test "should track activation changes in audit log" do
    template = EmailTemplate.create!(
      name: 'Activation Test',
      template_type: 'verification',
      subject: 'Test',
      content: '<p>Test</p>',
      is_active: false,
      current_user: @user
    )
    
    assert_difference('EmailTemplateVersion.count') do
      template.update!(is_active: true)
    end
    
    version = template.email_template_versions.order(:created_at).last
    assert_equal @user, version.user
    assert_equal 'activated', version.action
  end

  test "should handle very long content" do
    long_content = '<p>' + 'Lorem ipsum dolor sit amet. ' * 1000 + '</p>'
    
    template = EmailTemplate.new(
      name: 'Long Content Test',
      template_type: 'verification',
      subject: 'Test with very long subject line ' * 10,
      content: long_content
    )
    
    assert template.valid?
    assert template.save
    
    rendered = template.render_content(user: @user)
    assert rendered[:content].length > 10000
  end

  test "should handle special characters and unicode" do
    unicode_template = EmailTemplate.create!(
      name: 'Unicode Test 🎉',
      template_type: 'verification',
      subject: 'Hello {{user.first_name}} 🎉 with émojis and spéciål chars',
      content: '<p>Wëlcømë {{user.first_name}}! 🎯 Your vërification côde îs {{verification.verification_code}}</p>'
    )
    
    user_with_unicode = User.create!(
      first_name: 'Jörg',
      last_name: 'Müller',
      email: 'jorg@example.com',
      password: 'password123',
      password_confirmation: 'password123',
      country_of_residence: 'Germany',
      mobile_country_code: '+49',
      mobile_number: '1234567890',
      confirmed_at: Time.current,
      terms_accepted: true
    )
    
    rendered = unicode_template.render_content({
      user: user_with_unicode,
      verification_code: '123456'
    })
    
    assert_includes rendered[:subject], 'Jörg 🎉'
    assert_includes rendered[:content], 'Wëlcømë Jörg'
    assert_includes rendered[:content], '123456'
  end

  test "should handle empty and nil data gracefully" do
    template = EmailTemplate.create!(
      name: 'Empty Data Test',
      template_type: 'verification',
      subject: 'Test {{user.first_name}}',
      content: '<p>Hello {{user.first_name}}</p>'
    )
    
    # Test with empty data
    rendered = template.render_content({})
    assert_includes rendered[:subject], '{{user.first_name}}'
    assert_includes rendered[:content], '{{user.first_name}}'
    
    # Test with nil data
    rendered = template.render_content(nil)
    assert_includes rendered[:subject], '{{user.first_name}}'
    assert_includes rendered[:content], '{{user.first_name}}'
  end

  test "should handle malformed placeholder syntax" do
    template = EmailTemplate.create!(
      name: 'Malformed Test',
      template_type: 'verification',
      subject: 'Test {user.first_name} {{user.first_name {{incomplete',
      content: '<p>{single} {{double}} {{{triple}}} {{user.first_name}}</p>'
    )
    
    rendered = template.render_content(user: @user)
    
    # Should only replace well-formed placeholders
    assert_includes rendered[:content], 'John'
    assert_includes rendered[:content], '{single}'
    assert_includes rendered[:content], '{{{triple}}}'
  end

  test "should create default templates for all types" do
    types = %w[verification application_submitted security_notification]
    
    types.each do |type|
      # Clean up existing templates
      EmailTemplate.where(template_type: type).destroy_all
      
      template = EmailTemplate.create_default_for_type(type)
      
      assert_not_nil template
      assert template.persisted?
      assert_equal type, template.template_type
      assert_not template.name.blank?
      assert_not template.subject.blank?
      assert_not template.content.blank?
      
      # Should contain appropriate placeholders
      case type
      when 'verification'
        assert_includes template.content, '{{user'
        assert_includes template.content, '{{verification'
      when 'application_submitted'
        assert_includes template.content, '{{user'
        assert_includes template.content, '{{application'
        assert_includes template.content, '{{mortgage'
      when 'security_notification'
        assert_includes template.content, '{{user'
        assert_includes template.content, '{{security'
      end
    end
  end

  test "should handle markup conversion edge cases" do
    template = EmailTemplate.new(
      name: 'Markup Edge Cases',
      template_type: 'verification',
      subject: 'Test',
      content: 'Test'
    )
    
    # Test empty content
    assert_equal "", template.markup_to_html("")
    assert_equal "", template.markup_to_html(nil)
    
    # Test complex markup
    complex_markup = <<~MARKUP
      ## Main Title
      
      ### Subtitle with **bold** inside
      
      Regular paragraph with *italic* and **bold** text.
      
      - First item with **bold**
      - Second item with *italic*
      - Third item plain
      
      Another paragraph after list.
      
      ## Another Section
      Text here.
    MARKUP
    
    html = template.markup_to_html(complex_markup)
    
    assert_includes html, '<h2'
    assert_includes html, '<h3'
    assert_includes html, '<ul'
    assert_includes html, '<li'
    assert_includes html, '<strong>bold</strong>'
    assert_includes html, '<em>italic</em>'
    assert html.scan(/<h2/).length == 2 # Two h2 sections
  end

  test "should handle concurrent template operations safely" do
    # Test that concurrent operations don't create inconsistent state
    template1 = EmailTemplate.create!(
      name: 'Concurrent Test 1',
      template_type: 'verification',
      subject: 'Test 1',
      content: '<p>Test 1</p>',
      is_active: true
    )
    
    template2 = EmailTemplate.create!(
      name: 'Concurrent Test 2',
      template_type: 'verification',
      subject: 'Test 2',
      content: '<p>Test 2</p>',
      is_active: false
    )
    
    # Simulate concurrent activation
    EmailTemplate.transaction do
      EmailTemplate.where(template_type: 'verification').update_all(is_active: false)
      template2.update!(is_active: true)
    end
    
    template1.reload
    template2.reload
    
    # Should maintain consistency
    active_count = EmailTemplate.where(template_type: 'verification', is_active: true).count
    assert_equal 1, active_count
    assert template2.is_active?
    assert_not template1.is_active?
  end

  test "should validate content length constraints" do
    # Test very long content within reasonable limits
    very_long_content = '<p>' + 'a' * 50000 + '</p>'
    
    template = EmailTemplate.new(
      name: 'Length Test',
      template_type: 'verification',
      subject: 'Test',
      content: very_long_content
    )
    
    # Should handle long content gracefully
    assert template.valid?
  end

  test "should handle case-insensitive placeholder replacement" do
    template = EmailTemplate.create!(
      name: 'Case Test',
      template_type: 'verification',
      subject: 'Test {{USER.FIRST_NAME}} and {{user.first_name}}',
      content: '<p>{{User.First_Name}} and {{user.first_name}}</p>'
    )
    
    rendered = template.render_content(user: @user)
    
    # Current implementation is case-insensitive for placeholders
    assert_includes rendered[:subject], 'John'
    assert_includes rendered[:content], 'John'
  end
end