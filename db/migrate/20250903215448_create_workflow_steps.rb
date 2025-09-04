class CreateWorkflowSteps < ActiveRecord::Migration[8.0]
  def change
    create_table :workflow_steps do |t|
      t.references :workflow, null: false, foreign_key: { to_table: :email_workflows }
      t.string :step_type, null: false
      t.integer :position, null: false
      t.json :configuration, default: {}
      t.string :name
      t.text :description

      t.timestamps
    end
    
    add_index :workflow_steps, [:workflow_id, :position], unique: true
    add_index :workflow_steps, :step_type
  end
end
