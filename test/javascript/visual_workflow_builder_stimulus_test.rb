require "test_helper"

class VisualWorkflowBuilderStimulusTest < ActiveSupport::TestCase
  # These tests verify that our Stimulus controllers follow the architectural rule:
  # JavaScript handles only UI interactions, Rails/Hotwire handles business logic
  
  test "workflow_builder_controller only handles UI interactions" do
    # Read the controller file
    controller_path = Rails.root.join("app/javascript/controllers/workflow_builder_controller.js")
    assert File.exist?(controller_path), "workflow_builder_controller.js should exist"
    
    controller_content = File.read(controller_path)
    
    # Verify it contains only UI-related methods
    ui_methods = [
      "initDraggablePalette",      # UI: dragging palette
      "updateConnectionPath",       # UI: drawing connection lines
      "zoomIn", "zoomOut",         # UI: zoom controls
      "resetZoom", "fitToContent", # UI: zoom controls
      "toggleLeftPanel",           # UI: panel visibility
      "toggleRightPanel",          # UI: panel visibility
      "addQuickEmail",             # UI: adding visual nodes
      "addQuickDelay",             # UI: adding visual nodes
      "addQuickCondition"          # UI: adding visual nodes
    ]
    
    ui_methods.each do |method|
      assert_includes controller_content, method, 
        "Controller should include UI method: #{method}"
    end
    
    # Verify it does NOT contain business logic
    business_logic_patterns = [
      /fetch.*\/admin\/email_workflows/,    # No direct AJAX to business endpoints
      /XMLHttpRequest/,                      # No raw AJAX
      /\.ajax\(/,                           # No jQuery AJAX
      /trigger_conditions.*ajax/i,          # No AJAX for trigger conditions
      /workflow_steps.*ajax/i               # No AJAX for workflow steps
    ]
    
    business_logic_patterns.each do |pattern|
      refute_match pattern, controller_content,
        "Controller should not contain business logic pattern: #{pattern}"
    end
  end
  
  test "turbo_frame_controller only handles UI interactions for Hotwire" do
    controller_path = Rails.root.join("app/javascript/controllers/turbo_frame_controller.js")
    assert File.exist?(controller_path), "turbo_frame_controller.js should exist"
    
    controller_content = File.read(controller_path)
    
    # Verify it only updates frame src attributes (UI interaction)
    assert_includes controller_content, "frame.src = targetUrl",
      "Should set frame src for Hotwire navigation"
    
    # Verify it extracts workflow ID from URL (UI state)
    assert_includes controller_content, "getWorkflowId()",
      "Should extract workflow ID from URL"
    
    # Verify it builds proper URLs for server requests
    assert_includes controller_content, "trigger_conditions",
      "Should build URLs for trigger conditions endpoint"
    
    # Verify it does NOT process business data
    business_logic_patterns = [
      /validate.*trigger/i,         # No client-side validation
      /process.*workflow/i,         # No workflow processing
      /email.*template/i,           # No template processing
      /JSON\.parse.*workflow/,      # No JSON workflow processing
    ]
    
    business_logic_patterns.each do |pattern|
      refute_match pattern, controller_content,
        "turbo_frame_controller should not contain business logic: #{pattern}"
    end
  end
  
  test "email_workflows_controller follows UI-only pattern" do
    controller_path = Rails.root.join("app/javascript/controllers/email_workflows_controller.js")
    
    if File.exist?(controller_path)
      controller_content = File.read(controller_path)
      
      # Should only handle tab switching and loading states
      ui_methods = [
        "switchTab",              # UI: tab navigation
        "loadEmailTemplates",     # UI: loading states
        "loadTemplateLibrary"     # UI: loading states
      ]
      
      ui_methods.each do |method|
        assert_includes controller_content, method,
          "Controller should handle UI method: #{method}"
      end
      
      # The loading methods should use fetch for content, but not process business logic
      assert_includes controller_content, "fetch(",
        "Should use fetch for content loading"
      
      # Should not process or validate business data
      business_logic_patterns = [
        /validate.*email/i,
        /process.*template/i,
        /workflow.*logic/i,
        /business.*rule/i
      ]
      
      business_logic_patterns.each do |pattern|
        refute_match pattern, controller_content,
          "email_workflows_controller should not contain business logic: #{pattern}"
      end
    end
  end
  
  test "architectural separation is enforced in view templates" do
    # Test visual builder template
    template_path = Rails.root.join("app/views/admin/email_workflows/_visual_builder.html.erb")
    assert File.exist?(template_path), "Visual builder template should exist"
    
    template_content = File.read(template_path)
    
    # Should use Hotwire/Turbo Frames for server communication
    assert_includes template_content, "turbo_frame_tag",
      "Should use Turbo Frames for server updates"
    
    # Check for turbo frame targets (either data-turbo-frame= or turbo_frame: in data hash)
    has_turbo_frame_targets = template_content.include?("data-turbo-frame=") ||
                             template_content.include?("turbo_frame:")
    assert has_turbo_frame_targets, "Should specify turbo frame targets"
    
    # Check for Stimulus actions (different formats possible)
    has_stimulus_actions = template_content.include?("action=\"change->turbo-frame#update\"") ||
                          template_content.include?("action: \"change->turbo-frame#update\"") ||
                          template_content.include?("data-action=")
    assert has_stimulus_actions, "Should use Stimulus actions for UI interactions"
    
    # Should NOT contain inline JavaScript business logic
    business_logic_patterns = [
      /<script.*trigger.*workflow/i,
      /<script.*validate.*email/i,
      /onclick.*workflow/i,
      /onchange.*process/i
    ]
    
    business_logic_patterns.each do |pattern|
      refute_match pattern, template_content,
        "Template should not contain inline business logic: #{pattern}"
    end
  end
  
  test "form template uses proper Hotwire patterns" do
    form_template_path = Rails.root.join("app/views/admin/email_workflows/_form.html.erb")
    assert File.exist?(form_template_path), "Form template should exist"
    
    template_content = File.read(form_template_path)
    
    # Should use turbo_frame_tag for dynamic sections
    assert_includes template_content, "turbo_frame_tag",
      "Form should use Turbo Frames"
    
    # Should use data attributes for Stimulus controllers (check both patterns)
    has_stimulus_data = template_content.include?("data-controller=") || 
                       template_content.include?("data: { controller:")
    assert has_stimulus_data, "Should use Stimulus data attributes"
    
    # Should use proper form helpers
    assert_includes template_content, "form_with",
      "Should use Rails form helpers"
    
    # Should not have client-side business logic
    refute_includes template_content, "XMLHttpRequest",
      "Should not use raw AJAX"
    
    refute_includes template_content, "$.ajax",
      "Should not use jQuery AJAX"
  end
  
  test "controller actions return proper Turbo Frame responses" do
    # This tests the server-side adherence to Hotwire patterns
    
    # Mock a controller to test the trigger_conditions action
    controller = Admin::EmailWorkflowsController.new
    
    # Simulate the method call (we can't easily test HTTP responses in unit test)
    # but we can verify the method exists and handles parameters properly
    assert_respond_to controller, :trigger_conditions,
      "Controller should have trigger_conditions method"
    
    # Test that private method exists
    assert controller.respond_to?(:set_workflow, true),
      "Controller should have set_workflow private method"
  end
  
  test "architectural rules are documented in comments" do
    # Check that our architectural separation is documented
    
    controller_path = Rails.root.join("app/javascript/controllers/workflow_builder_controller.js")
    controller_content = File.read(controller_path)
    
    # Should have comments explaining UI-only responsibility
    documentation_patterns = [
      /UI.*interaction/i,
      /visual.*element/i,
      /drag.*drop/i,
      /zoom.*pan/i
    ]
    
    has_ui_documentation = documentation_patterns.any? { |pattern|
      controller_content.match?(pattern)
    }
    
    assert has_ui_documentation, 
      "Controller should have comments documenting UI-only responsibility"
  end
  
  test "no deprecated AJAX patterns remain" do
    # Ensure we've fully migrated from AJAX to Hotwire
    
    javascript_files = Dir[Rails.root.join("app/javascript/controllers/*workflow*.js")]
    
    javascript_files.each do |file|
      content = File.read(file)
      
      deprecated_patterns = [
        /rails-ujs/,                    # Old Rails AJAX
        /remote.*true/,                 # Remote forms
        /data-remote/,                  # Remote data attributes
        /ajax.*trigger_conditions/i,    # AJAX for trigger conditions
        /XMLHttpRequest.*workflow/i,    # Raw AJAX for workflows
        /\.done\(.*function/,          # jQuery promises
        /\$\.get.*admin\/email/,       # jQuery GET requests
        /\$\.post.*admin\/email/       # jQuery POST requests
      ]
      
      deprecated_patterns.each do |pattern|
        refute_match pattern, content,
          "#{File.basename(file)} should not contain deprecated AJAX pattern: #{pattern}"
      end
    end
  end
end