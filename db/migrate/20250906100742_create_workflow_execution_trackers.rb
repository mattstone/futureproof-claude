class CreateWorkflowExecutionTrackers < ActiveRecord::Migration[8.0]
  def change
    create_table :workflow_execution_trackers do |t|
      t.references :email_workflow, null: false, foreign_key: true
      t.references :target, polymorphic: true, null: false
      t.string :trigger_type, null: false
      t.string :trigger_key, null: false
      t.datetime :executed_at, null: false
      t.boolean :run_once, default: false

      t.timestamps
    end
    
    # Add indexes for efficient queries
    add_index :workflow_execution_trackers, [:email_workflow_id, :target_type, :target_id, :trigger_key], 
              unique: true, name: 'index_workflow_execution_uniqueness'
    add_index :workflow_execution_trackers, [:trigger_type, :executed_at]
    add_index :workflow_execution_trackers, [:target_type, :target_id]
  end
end
