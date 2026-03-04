class CreateAgentPerformance < ActiveRecord::Migration[8.0]
  def change
    create_table :agent_performances do |t|
      t.string :agent_name, null: false
      t.string :agent_type, null: false  # ai, human
      t.string :status, default: "idle"  # idle, processing, on_break, offline
      t.integer :tasks_completed_today, default: 0
      t.integer :tasks_completed_week, default: 0
      t.integer :tasks_completed_month, default: 0
      t.float :avg_resolution_minutes, default: 0
      t.float :satisfaction_score, default: 0  # 0-100
      t.float :quality_score, default: 0       # 0-100
      t.string :current_task
      t.datetime :last_active_at
      t.jsonb :metadata, default: {}
      t.timestamps
    end

    create_table :agent_tasks do |t|
      t.references :agent_performance, foreign_key: true
      t.string :task_type, null: false  # application_review, document_verify, customer_query, compliance_check, report_generation
      t.string :status, default: "pending"  # pending, in_progress, completed, escalated
      t.string :description
      t.string :priority, default: "normal"  # low, normal, high, urgent
      t.float :resolution_minutes
      t.text :outcome
      t.jsonb :metadata, default: {}
      t.datetime :started_at
      t.datetime :completed_at
      t.timestamps
    end

    add_index :agent_performances, :agent_type
    add_index :agent_performances, :status
    add_index :agent_tasks, :status
    add_index :agent_tasks, :task_type
    add_index :agent_tasks, :completed_at
  end
end
