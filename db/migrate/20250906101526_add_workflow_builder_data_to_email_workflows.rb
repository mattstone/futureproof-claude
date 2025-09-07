class AddWorkflowBuilderDataToEmailWorkflows < ActiveRecord::Migration[8.0]
  def change
    add_column :email_workflows, :workflow_builder_data, :json
  end
end
