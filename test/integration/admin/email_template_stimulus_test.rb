require 'test_helper'

class Admin::EmailTemplateStimulusTest < ActionDispatch::IntegrationTest
  def setup
    @admin_user = User.create!(
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
    
    @email_template = EmailTemplate.create!(
      name: 'Stimulus Test Template',
      template_type: 'verification',
      subject: 'Test Subject {{user.first_name}}',
      content: '<p>Hello {{user.first_name}}, your code is {{verification.verification_code}}</p>',
      description: 'Test template for Stimulus functionality',
      is_active: true
    )
    
    post user_session_path, params: {
      user: { email: @admin_user.email, password: 'password123' }
    }
  end

  test "edit page should have Stimulus controller attributes" do
    get edit_admin_email_template_path(@email_template)
    assert_response :success
    
    # Should have main Stimulus controller
    assert_select '[data-controller="email-template-editor"]', count: 1
    
    # Should have form with submit action
    assert_select 'form[data-action*="submit->email-template-editor#formSubmit"]'
    
    # Should have template type field with target and action
    assert_select 'select[data-email-template-editor-target="templateType"]'
    assert_select 'select[data-action*="change->email-template-editor#templateTypeChanged"]'
    
    # Should have subject field with target and action
    assert_select 'input[data-email-template-editor-target="subject"]'
    assert_select 'input[data-action*="input->email-template-editor#subjectChanged"]'
    
    # Should have content textareas with targets and actions
    assert_select 'textarea[data-email-template-editor-target="htmlContent"]'
    assert_select 'textarea[data-action*="input->email-template-editor#contentChanged"]', count: 2
    
    # Should have editor tabs with targets and actions
    assert_select 'button[data-email-template-editor-target="htmlTab"]'
    assert_select 'button[data-action*="click->email-template-editor#switchToHtml"]'
    assert_select 'button[data-email-template-editor-target="markupTab"]'
    assert_select 'button[data-action*="click->email-template-editor#switchToMarkup"]'
    
    # Should have field helper elements
    assert_select '[data-email-template-editor-target="fieldHelper"]'
    assert_select '[data-email-template-editor-target="toggleFieldHelper"]'
    assert_select 'button[data-action*="click->email-template-editor#toggleFieldHelper"]'
    
    # Should have preview elements with targets
    assert_select '[data-email-template-editor-target="subjectPreview"]'
    assert_select '[data-email-template-editor-target="contentPreview"]'
    
    # Should have preview control buttons with targets and actions
    assert_select 'button[data-email-template-editor-target="refreshBtn"]'
    assert_select 'button[data-action*="click->email-template-editor#refreshPreview"]'
    assert_select 'button[data-email-template-editor-target="toggleSampleBtn"]'
    assert_select 'button[data-action*="click->email-template-editor#toggleSampleData"]'
  end

  test "should load Stimulus controller in JavaScript importmap" do
    get edit_admin_email_template_path(@email_template)
    assert_response :success
    
    # Should include the Stimulus controller in the importmap
    assert_match /email_template_editor_controller/, response.body
    assert_match /"controllers\/email_template_editor_controller":/, response.body
  end

  test "AJAX preview should still work with Stimulus controller" do
    post preview_ajax_admin_email_templates_path, params: {
      template_type: 'verification',
      subject: 'Stimulus Test {{user.first_name}}',
      content: '<p>Stimulus preview test {{user.first_name}}</p>',
      use_sample_data: 'true'
    }, xhr: true
    
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert_includes json_response['subject'], 'Stimulus Test Admin'
    assert_includes json_response['content'], 'Stimulus preview test Admin'
  end

  test "form submission should work with Stimulus controller" do
    patch admin_email_template_path(@email_template), params: {
      email_template: {
        name: 'Updated Stimulus Template',
        subject: 'Updated with Stimulus {{user.first_name}}',
        content: '<p>Updated via Stimulus {{user.first_name}}</p>'
      }
    }

    assert_redirected_to admin_email_templates_path
    assert_equal 'Email template updated successfully.', flash[:notice]
    
    @email_template.reload
    assert_equal 'Updated Stimulus Template', @email_template.name
    assert_includes @email_template.subject, 'Updated with Stimulus'
  end
end