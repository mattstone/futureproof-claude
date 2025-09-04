class CreateScheduledWorkflowJobs < ActiveRecord::Migration[8.0]
  def change
    create_table :scheduled_workflow_jobs do |t|
      t.references :execution, null: false, foreign_key: { to_table: :workflow_executions }
      t.references :step, null: false, foreign_key: { to_table: :workflow_steps }
      t.datetime :scheduled_for, null: false
      t.integer :attempts, default: 0, null: false
      t.text :last_error
      t.string :status, null: false, default: 'scheduled'

      t.timestamps
    end
    
    add_index :scheduled_workflow_jobs, :scheduled_for
    add_index :scheduled_workflow_jobs, [:status, :scheduled_for]
    add_index :scheduled_workflow_jobs, [:execution_id, :step_id]
  end
end
