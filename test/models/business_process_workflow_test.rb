require "test_helper"

class BusinessProcessWorkflowTest < ActiveSupport::TestCase
  test "should have 3 valid process types" do
    assert_equal %w[acquisition conversion standard_operations], BusinessProcessWorkflow.process_types.keys
  end

  test "should validate presence of required fields" do
    workflow = BusinessProcessWorkflow.new
    refute workflow.valid?
    assert_includes workflow.errors[:process_type], "can't be blank"
    assert_includes workflow.errors[:name], "can't be blank"
    assert_includes workflow.errors[:workflow_data], "can't be blank"
  end

  test "should validate uniqueness of process_type" do
    existing = business_process_workflows(:acquisition)
    duplicate = BusinessProcessWorkflow.new(
      process_type: 'acquisition',
      name: 'Duplicate',
      workflow_data: { triggers: {} }
    )
    refute duplicate.valid?
    assert_includes duplicate.errors[:process_type], "has already been taken"
  end

  test "should validate workflow_data structure" do
    workflow = BusinessProcessWorkflow.new(
      process_type: 'conversion',
      name: 'Test',
      workflow_data: { invalid: 'structure' }
    )
    refute workflow.valid?
    assert_includes workflow.errors[:workflow_data], "triggers must be a hash"
  end

  test "should validate trigger structure" do
    workflow = BusinessProcessWorkflow.new(
      process_type: 'conversion',
      name: 'Test',
      workflow_data: {
        triggers: {
          'test_trigger' => { invalid: 'structure' }
        }
      }
    )
    refute workflow.valid?
    assert_includes workflow.errors[:workflow_data], "trigger 'test_trigger' must have nodes array"
    assert_includes workflow.errors[:workflow_data], "trigger 'test_trigger' must have connections array"
  end

  test "should create default workflows" do
    BusinessProcessWorkflow.delete_all
    BusinessProcessWorkflow.ensure_default_workflows!
    
    assert_equal 3, BusinessProcessWorkflow.count
    assert BusinessProcessWorkflow.exists?(process_type: 'acquisition')
    assert BusinessProcessWorkflow.exists?(process_type: 'conversion')
    assert BusinessProcessWorkflow.exists?(process_type: 'standard_operations')
  end

  test "should not duplicate default workflows" do
    initial_count = BusinessProcessWorkflow.count
    BusinessProcessWorkflow.ensure_default_workflows!
    assert_equal initial_count, BusinessProcessWorkflow.count
  end

  test "should manage triggers correctly" do
    workflow = business_process_workflows(:conversion)
    
    # Add trigger
    trigger_data = {
      'nodes' => [{'id' => 'test', 'type' => 'trigger'}],
      'connections' => []
    }
    workflow.add_trigger('test_trigger', trigger_data)
    
    assert workflow.trigger_exists?('test_trigger')
    assert_equal trigger_data['nodes'], workflow.trigger_data('test_trigger')['nodes']
    assert_includes workflow.triggers.keys, 'test_trigger'
    
    # Remove trigger
    workflow.remove_trigger('test_trigger')
    refute workflow.trigger_exists?('test_trigger')
    assert_empty workflow.triggers
  end

  test "should have working scopes" do
    active_count = BusinessProcessWorkflow.active.count
    inactive_count = BusinessProcessWorkflow.inactive.count
    
    assert_equal BusinessProcessWorkflow.count, active_count + inactive_count
    assert_operator active_count, :>, 0
  end

  test "trigger data should include required structure" do
    workflow = business_process_workflows(:acquisition)
    trigger_data = workflow.trigger_data('user_registration')
    
    assert trigger_data.key?('nodes')
    assert trigger_data.key?('connections')
    assert trigger_data['nodes'].is_a?(Array)
    assert trigger_data['connections'].is_a?(Array)
  end
end
