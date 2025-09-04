class CreateWorkflowStepExecutions < ActiveRecord::Migration[8.0]
  def change
    create_table :workflow_step_executions do |t|
      t.references :execution, null: false, foreign_key: { to_table: :workflow_executions }
      t.references :step, null: false, foreign_key: { to_table: :workflow_steps }
      t.string :status, null: false, default: 'pending'
      t.datetime :started_at
      t.datetime :completed_at
      t.json :result, default: {}
      t.text :error_message

      t.timestamps
    end
    
    add_index :workflow_step_executions, [:execution_id, :step_id], unique: true
    add_index :workflow_step_executions, :status
    add_index :workflow_step_executions, :started_at
  end
end
