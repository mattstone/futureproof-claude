class AddConditionTypeToEmailWorkflows < ActiveRecord::Migration[8.0]
  def change
    add_column :email_workflows, :condition_type, :string
  end
end
