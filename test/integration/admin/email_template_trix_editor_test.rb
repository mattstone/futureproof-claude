require "test_helper"

class Admin::EmailTemplateTrixEditorTest < ActionDispatch::IntegrationTest
  setup do
    @admin_user = users(:admin_user)
    @email_template = EmailTemplate.create!(
      name: 'Test Verification',
      template_type: 'verification',
      email_category: 'operational',
      subject: 'Test Subject',
      content: 'Test content',
      content_body: 'Test body content'
    )
    sign_in @admin_user
  end

  test "email template edit page renders with Trix editor" do
    get edit_admin_email_template_path(@email_template)
    
    assert_response :success
    
    # Check for Trix editor presence
    assert_select "trix-editor", count: 1
    
    # Check that old TinyMCE is gone
    assert_select "[data-tinymce-target='editor']", count: 0
    
    # Check for form fields
    assert_select "input[name='email_template[name]']"
    assert_select "input[name='email_template[subject]']"
    assert_select "select[name='email_template[template_type]']"
    assert_select "select[name='email_template[email_category]']"
  end

  test "email template new page renders with Trix editor" do
    get new_admin_email_template_path
    
    assert_response :success
    
    # Check for Trix editor presence
    assert_select "trix-editor", count: 1
  end
end
