require 'test_helper'

class Admin::WysiwygEditorTest < ActionDispatch::IntegrationTest
  self.use_transactional_tests = true
  
  # Override fixtures to use none
  self.fixture_paths = []
  self.set_fixture_class({})
  
  # Disable fixture loading
  def load_fixtures(*); end
  
  setup do
    # Create a mock mailer to prevent actual email sending during tests
    mock_mail = Object.new
    def mock_mail.deliver_now; end
    ApplicationMailer.define_singleton_method(:message_notification) { |_| mock_mail }
    
    @admin = User.create!(
      email: 'admin@example.com',
      password: 'password123',
      first_name: 'Admin',
      last_name: 'User',
      admin: true,
      terms_accepted: true,
      terms_version: 1
    )
    
    @customer = User.create!(
      email: 'john.doe@example.com',
      password: 'password123',
      first_name: 'John',
      last_name: 'Doe',
      admin: false,
      terms_accepted: true,
      terms_version: 1,
      country_of_residence: 'Australia'
    )
    
    @application = Application.create!(
      user: @customer,
      address: '123 Main Street, Sydney, NSW 2000',
      home_value: 1500000,
      status: 'submitted',
      ownership_status: 'individual',
      property_state: 'primary_residence',
      borrower_age: 35
    )
    
    @ai_agent = AiAgent.create!(
      name: 'motoko',
      agent_type: 'applications',
      description: 'Application processing specialist',
      avatar_filename: 'Motoko.png',
      is_active: true
    )
    
    # Sign in as admin
    post user_session_path, params: {
      user: {
        email: @admin.email,
        password: 'password123'
      }
    }
  end
  
  test "should display WYSIWYG toolbar with formatting buttons" do
    get admin_application_path(@application)
    assert_response :success
    
    # Check for WYSIWYG toolbar
    assert_select '.wysiwyg-toolbar', count: 1
    
    # Check for formatting buttons
    assert_select '.toolbar-btn[title="Bold"]', count: 1
    assert_select '.toolbar-btn[title="Italic"]', count: 1
    assert_select '.toolbar-btn[title="Bullet Point"]', count: 1
    assert_select '.toolbar-btn[title="Numbered List"]', count: 1
    assert_select '.toolbar-btn[title="Line Break"]', count: 1
    
    # Check that buttons have correct onclick handlers
    assert_select '.toolbar-btn[onclick*="applyMarkup"]', count: 4
    assert_select '.toolbar-btn[onclick*="insertLineBreak"]', count: 1
  end
  
  test "should have enhanced message textarea with proper styling" do
    get admin_application_path(@application)
    assert_response :success
    
    # Check for message textarea
    assert_select 'textarea[name="application_message[content]"]', count: 1 do
      assert_select '[class*="markup-editor"]'
      assert_select '[rows="8"]'  # Increased from 6 to 8 for better editing experience
    end
    
    # Check for updated placeholder text
    textarea_element = css_select('textarea[name="application_message[content]"]').first
    placeholder = textarea_element['placeholder']
    assert_includes placeholder, 'Select text and use the formatting buttons above'
  end
  
  test "should include WYSIWYG JavaScript functions" do
    get admin_application_path(@application)
    assert_response :success
    
    # Check that the JavaScript functions are included in the response
    assert_includes response.body, 'function applyMarkup'
    assert_includes response.body, 'function insertLineBreak'
    assert_includes response.body, 'Ctrl+B for bold'
    assert_includes response.body, 'Ctrl+I for italic'
  end
  
  test "should maintain existing field helper functionality" do
    get admin_application_path(@application)
    assert_response :success
    
    # Verify Quick Insert section is still present and functional
    assert_select '.field-helpers', count: 1
    assert_select '.field-helpers h4', text: 'Quick Insert:'
    assert_select '.helper-btn', count: 4
    
    # Check that insertField function is still available
    assert_includes response.body, 'function insertField'
    
    # Verify helper buttons have correct onclick handlers
    assert_select '.helper-btn[onclick*="insertField"]', count: 4
  end
  
  test "should work with both show and edit views" do
    # Test show view
    get admin_application_path(@application)
    assert_response :success
    assert_select '.wysiwyg-toolbar', count: 1
    
    # Test edit view  
    get edit_admin_application_path(@application)
    assert_response :success
    assert_select '.wysiwyg-toolbar', count: 1
  end
  
  test "should display live preview section" do
    get admin_application_path(@application)
    assert_response :success
    
    # Check for live preview section
    assert_select '.live-preview-section', count: 1
    assert_select '.live-preview-label', text: 'Live Preview', count: 1
    assert_select '#message-preview', count: 1
    
    # Check preview structure
    assert_select '.preview-header', count: 1
    assert_select '#preview-avatar', count: 1
    assert_select '#preview-sender-name', count: 1
    assert_select '#preview-sender-role', count: 1
    assert_select '#preview-subject', count: 1
    assert_select '#preview-content', count: 1
  end
  
  test "should include live preview JavaScript functions" do
    get admin_application_path(@application)
    assert_response :success
    
    # Check for live preview JavaScript functions
    assert_includes response.body, 'function initializeLivePreview'
    assert_includes response.body, 'function updatePreview'
    assert_includes response.body, 'function updatePreviewAgent'
    assert_includes response.body, 'function processTemplateVariables'
    assert_includes response.body, 'function markupToHtml'
  end
  
  test "should include application data for template variables" do
    get admin_application_path(@application)
    assert_response :success
    
    # Check that application data is exposed to JavaScript
    assert_includes response.body, 'window.applicationData'
    assert_includes response.body, 'window.applicationUserData'
    
    # Verify some application data is present
    assert_includes response.body, @application.address
    assert_includes response.body, @application.user.first_name
    assert_includes response.body, @application.user.email
  end
  
  test "should have proper CSS styling for live preview" do
    get admin_application_path(@application)
    assert_response :success
    
    # Check for live preview CSS classes in the response
    assert_includes response.body, '.live-preview-section'
    assert_includes response.body, '.message-preview'
    assert_includes response.body, '.preview-header'
    assert_includes response.body, '.preview-sender'
  end
end