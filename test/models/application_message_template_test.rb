require 'test_helper'

class ApplicationMessageTemplateTest < ActiveSupport::TestCase
  self.use_transactional_tests = true
  
  # Override fixtures to use none
  self.fixture_paths = []
  self.set_fixture_class({})
  
  # Disable fixture loading
  def load_fixtures(*); end
  
  setup do
    @user = User.create!(
      first_name: 'John',
      last_name: 'Doe', 
      email: 'john.doe@example.com',
      password: 'password123',
      admin: false,
      terms_accepted: true,
      terms_version: 1,
      country_of_residence: 'Australia'
    )
    
    @application = Application.create!(
      user: @user,
      address: '123 Main Street, Sydney, NSW 2000',
      home_value: 1500000,
      status: 'submitted',
      ownership_status: 'individual',
      property_state: 'primary_residence',
      borrower_age: 45,
      existing_mortgage_amount: 500000
    )
    
    @ai_agent = AiAgent.create!(
      name: 'motoko',
      agent_type: 'applications',
      description: 'Application processing specialist',
      avatar_filename: 'Motoko.png',
      is_active: true
    )
    
    @admin = User.create!(
      first_name: 'Admin',
      last_name: 'User',
      email: 'admin@example.com',
      password: 'password123',
      admin: true,
      terms_accepted: true,
      terms_version: 1
    )
  end
  
  test "should replace user template variables in message content" do
    message = @application.application_messages.create!(
      subject: 'Hello {{user.first_name}}!',
      content: 'Dear {{user.first_name}} {{user.last_name}}, welcome! Your email is {{user.email}}.',
      sender: @admin,
      ai_agent: @ai_agent,
      message_type: 'admin_to_customer',
      status: 'draft'
    )
    
    assert_equal 'Hello John!', message.processed_subject
    assert_includes message.content_html, 'Dear John Doe, welcome! Your email is john.doe@example.com.'
  end
  
  test "should replace application template variables in message content" do
    message = @application.application_messages.create!(
      subject: 'Application {{application.id}} Update',
      content: 'Your application for {{application.address}} with value {{application.home_value}} is {{application.status_display}}.',
      sender: @admin,
      ai_agent: @ai_agent,
      message_type: 'admin_to_customer',
      status: 'draft'
    )
    
    assert_equal "Application #{@application.id} Update", message.processed_subject
    assert_includes message.content_html, "Your application for 123 Main Street, Sydney, NSW 2000 with value 1500000 is Submitted."
  end
  
  test "should replace formatted application values" do
    # Add formatted_home_value method to Application for testing
    @application.define_singleton_method(:formatted_home_value) { "$1,500,000" }
    @application.define_singleton_method(:formatted_existing_mortgage_amount) { "$500,000" }
    
    message = @application.application_messages.create!(
      subject: 'Property Value {{application.formatted_home_value}}',
      content: 'Home value: {{application.formatted_home_value}}, Existing mortgage: {{application.formatted_existing_mortgage_amount}}',
      sender: @admin,
      ai_agent: @ai_agent,
      message_type: 'admin_to_customer',
      status: 'draft'
    )
    
    assert_equal 'Property Value $1,500,000', message.processed_subject
    assert_includes message.content_html, 'Home value: $1,500,000, Existing mortgage: $500,000'
  end
  
  test "should handle application reference numbers" do
    message = @application.application_messages.create!(
      subject: 'Reference #{{application.reference_number}}',
      content: 'Your application reference number is {{application.reference_number}}',
      sender: @admin,
      ai_agent: @ai_agent,
      message_type: 'admin_to_customer',
      status: 'draft'
    )
    
    expected_reference = @application.id.to_s.rjust(6, '0')
    assert_equal "Reference ##{expected_reference}", message.processed_subject
    assert_includes message.content_html, "Your application reference number is #{expected_reference}"
  end
  
  test "should handle borrower age and status display" do
    message = @application.application_messages.create!(
      subject: 'Age {{application.borrower_age}} Status {{application.status_display}}',
      content: 'Borrower age: {{application.borrower_age}}, Status: {{application.status_display}}',
      sender: @admin,
      ai_agent: @ai_agent,
      message_type: 'admin_to_customer',
      status: 'draft'
    )
    
    assert_equal 'Age 45 Status Submitted', message.processed_subject
    assert_includes message.content_html, 'Borrower age: 45, Status: Submitted'
  end
  
  test "should handle user country of residence" do
    message = @application.application_messages.create!(
      subject: 'Hello from {{user.country_of_residence}}',
      content: 'Your country: {{user.country_of_residence}}, Full name: {{user.full_name}}',
      sender: @admin,
      ai_agent: @ai_agent,
      message_type: 'admin_to_customer',
      status: 'draft'
    )
    
    assert_equal 'Hello from Australia', message.processed_subject
    assert_includes message.content_html, 'Your country: Australia, Full name: John Doe'
  end
  
  test "should handle mortgage template variables when mortgage is present" do
    mortgage = Mortgage.create!(
      name: 'Reverse Mortgage Pro',
      mortgage_type: 'interest_only'
    )
    
    # Add lvr method to mortgage for testing
    mortgage.define_singleton_method(:lvr) { 60 }
    mortgage.define_singleton_method(:mortgage_type_display) { 'Reverse Mortgage' }
    
    @application.update!(mortgage: mortgage)
    
    message = @application.application_messages.create!(
      subject: '{{mortgage.name}} - {{mortgage.lvr}}% LVR',
      content: 'Product: {{mortgage.name}}, LVR: {{mortgage.lvr}}%, Type: {{mortgage.mortgage_type_display}}, Rate: {{mortgage.interest_rate}}%',
      sender: @admin,
      ai_agent: @ai_agent,
      message_type: 'admin_to_customer',
      status: 'draft'
    )
    
    assert_equal 'Reverse Mortgage Pro - 60% LVR', message.processed_subject
    assert_includes message.content_html, 'Product: Reverse Mortgage Pro, LVR: 60%, Type: Reverse Mortgage, Rate: 7.45%'
  end
  
  test "should handle loan-related fields when present" do
    # Add loan-related methods to application for testing
    @application.define_singleton_method(:loan_value) { 900000 }
    @application.define_singleton_method(:formatted_loan_value) { "$900,000" }
    @application.define_singleton_method(:loan_term) { 25 }
    @application.define_singleton_method(:growth_rate) { 3.5 }
    @application.define_singleton_method(:formatted_growth_rate) { "3.5%" }
    
    message = @application.application_messages.create!(
      subject: 'Loan {{application.formatted_loan_value}} for {{application.loan_term}} years',
      content: 'Loan: {{application.loan_value}}, Term: {{application.loan_term}} years, Growth: {{application.formatted_growth_rate}}',
      sender: @admin,
      ai_agent: @ai_agent,
      message_type: 'admin_to_customer',
      status: 'draft'
    )
    
    assert_equal 'Loan $900,000 for 25 years', message.processed_subject
    assert_includes message.content_html, 'Loan: 900000, Term: 25 years, Growth: 3.5%'
  end
  
  test "should preserve unmatched template variables" do
    message = @application.application_messages.create!(
      subject: 'Hello {{user.first_name}} - {{unknown.field}}',
      content: 'Known: {{user.first_name}}, Unknown: {{missing.field}}, Invalid: {{application.nonexistent}}',
      sender: @admin,
      ai_agent: @ai_agent,
      message_type: 'admin_to_customer',
      status: 'draft'
    )
    
    # Should replace known variables but preserve unknown ones
    assert_equal 'Hello John - {{unknown.field}}', message.processed_subject
    processed_content = message.content_html
    assert_includes processed_content, 'Known: John'
    assert_includes processed_content, 'Unknown: {{missing.field}}'
    assert_includes processed_content, 'Invalid: {{application.nonexistent}}'
  end
  
  test "should handle empty and nil values gracefully" do
    @application.update!(existing_mortgage_amount: nil)
    
    # Create a simple application in created status to avoid validation issues
    simple_app = Application.create!(
      user: @user,
      address: 'Test Address',
      home_value: 1000000,
      status: 'created',  # This bypasses borrower_age validation
      ownership_status: 'individual',
      property_state: 'primary_residence'
    )
    
    message = simple_app.application_messages.create!(
      subject: '{{application.borrower_age}} - {{application.existing_mortgage_amount}}',
      content: 'Age: {{application.borrower_age}}, Mortgage: {{application.existing_mortgage_amount}}, Unknown: {{application.nonexistent_field}}',
      sender: @admin,
      ai_agent: @ai_agent,
      message_type: 'admin_to_customer',
      status: 'draft'
    )
    
    # Should handle nil values gracefully (convert to string)
    # Note: borrower_age defaults to 0, existing_mortgage_amount defaults to 0.0
    assert_equal '0 - 0.0', message.processed_subject
    processed_content = message.content_html
    assert_includes processed_content, 'Age: 0, Mortgage: 0.0, Unknown: {{application.nonexistent_field}}'
  end
  
  test "should work with markup formatting" do
    message = @application.application_messages.create!(
      subject: 'Welcome {{user.first_name}}',
      content: '**Hello {{user.first_name}}!**\n\nYour application for {{application.address}} is *{{application.status_display}}*.\n\n- Reference: {{application.reference_number}}\n- Value: {{application.home_value}}',
      sender: @admin,
      ai_agent: @ai_agent,
      message_type: 'admin_to_customer',
      status: 'draft'
    )
    
    assert_equal 'Welcome John', message.processed_subject
    
    processed_html = message.content_html
    # Should have both template replacement and markup processing
    assert_includes processed_html, '<strong>Hello John!</strong>'
    assert_includes processed_html, 'Your application for 123 Main Street, Sydney, NSW 2000 is <em>Submitted</em>'
    assert_includes processed_html, '<li>Reference: ' + @application.id.to_s.rjust(6, '0') + '</li>'
    assert_includes processed_html, '<li>Value: 1500000</li>'
  end
  
  test "should be case insensitive for template variables" do
    message = @application.application_messages.create!(
      subject: '{{USER.FIRST_NAME}} - {{Application.Address}}',
      content: '{{user.FIRST_NAME}} at {{APPLICATION.address}}',
      sender: @admin,
      ai_agent: @ai_agent,
      message_type: 'admin_to_customer',
      status: 'draft'
    )
    
    assert_equal 'John - 123 Main Street, Sydney, NSW 2000', message.processed_subject
    assert_includes message.content_html, 'John at 123 Main Street, Sydney, NSW 2000'
  end
  
  test "should handle multiple instances of same variable" do
    message = @application.application_messages.create!(
      subject: '{{user.first_name}} {{user.first_name}} {{user.first_name}}',
      content: 'Hello {{user.first_name}}, yes {{user.first_name}}, this is for {{user.first_name}}!',
      sender: @admin,
      ai_agent: @ai_agent,
      message_type: 'admin_to_customer',
      status: 'draft'
    )
    
    assert_equal 'John John John', message.processed_subject
    assert_includes message.content_html, 'Hello John, yes John, this is for John!'
  end
end