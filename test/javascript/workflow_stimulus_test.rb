require "test_helper"

class WorkflowStimulusTest < ActiveSupport::TestCase
  
  def setup
    # Create test lender and admin user
    @lender = Lender.create!(
      name: "Test Lender",
      lender_type: "lender",
      contact_email: "contact@testlender.com",
      country: "US"
    )
    
    @admin_user = User.create!(
      email: "admin@futureproof.com", 
      password: "password123",
      first_name: "Admin",
      last_name: "User",
      lender: @lender,
      country_of_residence: "US",
      terms_accepted: "1",
      admin: true
    )
    
    # Create email templates
    @welcome_template = EmailTemplate.create!(
      name: "Welcome Email",
      subject: "Welcome!",
      content: "Hello {{user.first_name}}!",
      content_body: "Hello {{user.first_name}}!",
      email_category: "operational",
      template_type: "verification"
    )
    
    @followup_template = EmailTemplate.create!(
      name: "Follow Up", 
      subject: "Follow Up",
      content: "Follow up email",
      content_body: "Follow up email",
      email_category: "operational",
      template_type: "verification"
    )
  end
  
  test "email workflows controller should be properly connected" do
    # Test that the Stimulus controller files exist and are properly structured
    
    email_workflows_controller_file = File.read("#{Rails.root}/app/javascript/controllers/email_workflows_controller.js")
    
    # Check controller structure
    assert_includes email_workflows_controller_file, "import { Controller } from \"@hotwired/stimulus\""
    assert_includes email_workflows_controller_file, "export default class extends Controller"
    assert_includes email_workflows_controller_file, "static targets = [\"tab\", \"tabContent\"]"
    
    # Check required methods exist
    assert_includes email_workflows_controller_file, "switchTab(event)"
    assert_includes email_workflows_controller_file, "loadEmailTemplates()"
    assert_includes email_workflows_controller_file, "loadTemplateLibrary()" 
    
    # Check proper fetch usage
    assert_includes email_workflows_controller_file, "fetch('/admin/email_workflows/email_templates_content'"
    assert_includes email_workflows_controller_file, "fetch('/admin/email_workflows/templates'"
    
    # Check error handling
    assert_includes email_workflows_controller_file, ".catch(error =>"
    assert_includes email_workflows_controller_file, "console.error"
  end
  
  test "workflow templates controller should be properly structured" do
    workflow_templates_controller_file = File.read("#{Rails.root}/app/javascript/controllers/workflow_templates_controller.js")
    
    # Check controller structure
    assert_includes workflow_templates_controller_file, "import { Controller } from \"@hotwired/stimulus\""
    assert_includes workflow_templates_controller_file, "export default class extends Controller"
    
    # Check required methods exist
    assert_includes workflow_templates_controller_file, "createAllTemplates(event)"
    assert_includes workflow_templates_controller_file, "createCategoryTemplates(event)"
    assert_includes workflow_templates_controller_file, "showTemplatePreview(event)"
    assert_includes workflow_templates_controller_file, "closeTemplatePreview()"
    
    # Check form submission handling
    assert_includes workflow_templates_controller_file, "form.method = 'POST'"
    assert_includes workflow_templates_controller_file, "form.action = '/admin/email_workflows/bulk_create'"
    
    # Check CSRF token handling
    assert_includes workflow_templates_controller_file, "document.querySelector('meta[name=\"csrf-token\"]')"
    assert_includes workflow_templates_controller_file, "authenticity_token"
    
    # Check modal handling
    assert_includes workflow_templates_controller_file, "modal.classList.remove('hidden')"
    assert_includes workflow_templates_controller_file, "modal.classList.add('hidden')"
  end
  
  test "controller methods should handle data attributes correctly" do
    email_workflows_controller_file = File.read("#{Rails.root}/app/javascript/controllers/email_workflows_controller.js")
    
    # Check data attribute handling
    assert_includes email_workflows_controller_file, "event.currentTarget.dataset.tab"
    assert_includes email_workflows_controller_file, "templatesContainer.dataset.loaded"
    assert_includes email_workflows_controller_file, "libraryContainer.dataset.loaded"
  end
  
  test "workflow templates controller should handle template creation data" do
    workflow_templates_controller_file = File.read("#{Rails.root}/app/javascript/controllers/workflow_templates_controller.js")
    
    # Check template data handling  
    assert_includes workflow_templates_controller_file, "event.currentTarget.dataset.template"
    assert_includes workflow_templates_controller_file, "event.currentTarget.dataset.category"
    assert_includes workflow_templates_controller_file, "document.querySelector('[data-template-count]')"
    assert_includes workflow_templates_controller_file, "document.querySelector('[data-onboarding-count]')"
    assert_includes workflow_templates_controller_file, "document.querySelector('[data-operational-count]')"
    assert_includes workflow_templates_controller_file, "document.querySelector('[data-end-contract-count]')"
  end
  
  test "controllers should have proper error handling and loading states" do
    email_workflows_controller_file = File.read("#{Rails.root}/app/javascript/controllers/email_workflows_controller.js")
    workflow_templates_controller_file = File.read("#{Rails.root}/app/javascript/controllers/workflow_templates_controller.js")
    
    # Check loading states
    assert_includes email_workflows_controller_file, "Loading templates..."
    assert_includes email_workflows_controller_file, "Loading template library..."
    
    # Check error states
    assert_includes email_workflows_controller_file, "Failed to load email templates"
    assert_includes email_workflows_controller_file, "Failed to load template library"
    
    # Check retry functionality
    assert_includes email_workflows_controller_file, "Retry"
    
    # Check template controller loading states
    assert_includes workflow_templates_controller_file, "Creating..."
    assert_includes workflow_templates_controller_file, "button.disabled = true"
    assert_includes workflow_templates_controller_file, "Loading template preview..."
  end
  
  test "stimulus controllers should use proper CSS classes" do
    email_workflows_css = File.read("#{Rails.root}/app/assets/stylesheets/admin/email_workflows.css")
    
    # Check required CSS classes exist
    assert_includes email_workflows_css, ".hidden"
    assert_includes email_workflows_css, ".tab-button"
    assert_includes email_workflows_css, ".tab-content"
    assert_includes email_workflows_css, ".templates-loading"
    assert_includes email_workflows_css, ".library-loading"
    assert_includes email_workflows_css, ".loading-spinner"
    assert_includes email_workflows_css, ".error-state"
    assert_includes email_workflows_css, ".btn-primary"
    assert_includes email_workflows_css, ".btn-secondary"
    assert_includes email_workflows_css, ".modal"
    assert_includes email_workflows_css, ".modal-overlay"
    assert_includes email_workflows_css, ".modal-content"
    assert_includes email_workflows_css, ".setup-card"
    assert_includes email_workflows_css, ".template-card"
  end
  
  test "view templates should have proper data attributes for stimulus" do
    index_view = File.read("#{Rails.root}/app/views/admin/email_workflows/index.html.erb")
    
    # Check main container has controllers
    assert_includes index_view, 'data-controller="email-workflows workflow-templates"'
    
    # Check tab buttons have proper attributes
    assert_includes index_view, 'data-email-workflows-target="tab"'
    assert_includes index_view, 'data-action="click->email-workflows#switchTab"'
    
    # Check tab content targets
    assert_includes index_view, 'data-email-workflows-target="tabContent"'
    
    templates_view = File.read("#{Rails.root}/app/views/admin/email_workflows/templates.html.erb")
    
    # Check workflow templates controller
    assert_includes templates_view, 'data-controller="workflow-templates"'
    
    # Check template action buttons
    assert_includes templates_view, 'data-action="click->workflow-templates#createAllTemplates"'
    assert_includes templates_view, 'data-action="click->workflow-templates#createCategoryTemplates"'
    assert_includes templates_view, 'data-action="click->workflow-templates#showTemplatePreview"'
    assert_includes templates_view, 'data-action="click->workflow-templates#closeTemplatePreview"'
    
    # Check template data attributes
    assert_includes templates_view, 'data-template-count='
    assert_includes templates_view, 'data-onboarding-count='
    assert_includes templates_view, 'data-operational-count='
    assert_includes templates_view, 'data-end-contract-count='
    assert_includes templates_view, 'data-category='
  end
  
  test "should not have any inline javascript or styles" do
    index_view = File.read("#{Rails.root}/app/views/admin/email_workflows/index.html.erb")
    templates_view = File.read("#{Rails.root}/app/views/admin/email_workflows/templates.html.erb")
    form_view = File.read("#{Rails.root}/app/views/admin/email_workflows/_form.html.erb")
    step_fields_view = File.read("#{Rails.root}/app/views/admin/email_workflows/_workflow_step_fields.html.erb")
    
    views = [index_view, templates_view, form_view, step_fields_view]
    
    views.each_with_index do |view, index|
      view_names = ['index', 'templates', 'form', 'step_fields']
      
      # Should not have inline <script> tags
      assert_not_includes view, "<script>", "#{view_names[index]} view should not have inline scripts"
      
      # Should not have inline <style> tags  
      assert_not_includes view, "<style>", "#{view_names[index]} view should not have inline styles"
      
      # Should not have onclick handlers
      assert_not_includes view, "onclick=", "#{view_names[index]} view should not have onclick handlers"
      
      # Should not have style attributes (except for rare cases)
      style_matches = view.scan(/style\s*=\s*"[^"]*"/).reject { |match| 
        match.include?('display: none') && match.length < 30 # Allow simple display:none
      }
      assert_empty style_matches, "#{view_names[index]} view should not have inline style attributes: #{style_matches}"
    end
  end
  
  test "application.js should not have problematic dynamic imports" do
    application_js = File.read("#{Rails.root}/app/javascript/application.js")
    
    # Should not have dynamic imports
    assert_not_includes application_js, "import(", "application.js should not have dynamic imports"
    assert_not_includes application_js, "admin_email_workflows.js", "application.js should not reference problematic modules"
    assert_not_includes application_js, "workflow_templates.js", "application.js should not reference problematic modules"
    
    # Should have basic imports
    assert_includes application_js, 'import "@hotwired/turbo-rails"'
    assert_includes application_js, 'import "controllers"'
  end
  
  test "controllers should handle form submissions correctly" do
    workflow_templates_controller_file = File.read("#{Rails.root}/app/javascript/controllers/workflow_templates_controller.js")
    
    # Check form creation
    assert_includes workflow_templates_controller_file, "const form = document.createElement('form')"
    
    # Check form attributes
    assert_includes workflow_templates_controller_file, "form.method = 'POST'"
    assert_includes workflow_templates_controller_file, "form.action = '/admin/email_workflows/bulk_create'"
    
    # Check form data
    assert_includes workflow_templates_controller_file, 'name="create_all_templates"'
    assert_includes workflow_templates_controller_file, 'name="create_category_templates"'
    
    # Check form submission
    assert_includes workflow_templates_controller_file, "document.body.appendChild(form)"
    assert_includes workflow_templates_controller_file, "form.submit()"
  end
end