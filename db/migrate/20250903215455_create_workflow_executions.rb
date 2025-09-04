class CreateWorkflowExecutions < ActiveRecord::Migration[8.0]
  def change
    create_table :workflow_executions do |t|
      t.references :workflow, null: false, foreign_key: { to_table: :email_workflows }
      t.references :target, polymorphic: true, null: false
      t.string :status, null: false, default: 'pending'
      t.datetime :started_at
      t.datetime :completed_at
      t.integer :current_step_position, default: 0
      t.json :context, default: {}
      t.text :last_error

      t.timestamps
    end
    
    add_index :workflow_executions, [:workflow_id, :status]
    add_index :workflow_executions, [:target_type, :target_id]
    add_index :workflow_executions, :status
    add_index :workflow_executions, :started_at
  end
end
