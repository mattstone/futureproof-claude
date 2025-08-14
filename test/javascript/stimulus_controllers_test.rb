require 'test_helper'

class StimulusControllersTest < ActionDispatch::IntegrationTest
  test "Stimulus controllers exist and are importable" do
    # Check that the controller files exist
    assert File.exist?(Rails.root.join('app/javascript/controllers/application_messages_controller.js'))
    assert File.exist?(Rails.root.join('app/javascript/controllers/contract_messages_controller.js'))
    assert File.exist?(Rails.root.join('app/javascript/controllers/email_template_editor_controller.js'))
    
    # Check that the controllers contain expected exports
    app_messages_content = File.read(Rails.root.join('app/javascript/controllers/application_messages_controller.js'))
    contract_messages_content = File.read(Rails.root.join('app/javascript/controllers/contract_messages_controller.js'))
    email_editor_content = File.read(Rails.root.join('app/javascript/controllers/email_template_editor_controller.js'))
    
    # Application messages controller should have the expected methods
    assert_includes app_messages_content, 'toggleDetails'
    assert_includes app_messages_content, 'toggleMessages'
    assert_includes app_messages_content, 'showReplyForm'
    assert_includes app_messages_content, 'hideReplyForm'
    assert_includes app_messages_content, 'markAsRead'
    assert_includes app_messages_content, 'scrollToHighlightedMessage'
    
    # Contract messages controller should have the expected methods
    assert_includes contract_messages_content, 'toggleDetails'
    assert_includes contract_messages_content, 'toggleMessages'
    assert_includes contract_messages_content, 'showReplyForm'
    assert_includes contract_messages_content, 'hideReplyForm'
    assert_includes contract_messages_content, 'markAsRead'
    
    # Email template editor controller should have the expected methods
    assert_includes email_editor_content, 'switchToHtml'
    assert_includes email_editor_content, 'switchToMarkup'
    assert_includes email_editor_content, 'updatePreview'
    assert_includes email_editor_content, 'toggleFieldHelper'
    assert_includes email_editor_content, 'insertField'
  end
  
  test "importmap includes Stimulus controllers" do
    admin_user = User.create!(
      first_name: 'Admin',
      last_name: 'User',
      email: 'admin.stimulus@test.com',
      password: 'password123',
      password_confirmation: 'password123',
      admin: true,
      country_of_residence: 'Australia',
      mobile_country_code: '+61',
      mobile_number: '412345678',
      confirmed_at: Time.current,
      terms_accepted: true
    )
    
    post user_session_path, params: {
      user: { email: admin_user.email, password: 'password123' }
    }
    
    get new_admin_email_template_path
    assert_response :success
    
    # Should include all our Stimulus controllers in the importmap
    assert_match /application_messages_controller/, response.body
    assert_match /contract_messages_controller/, response.body
    assert_match /email_template_editor_controller/, response.body
  end
end