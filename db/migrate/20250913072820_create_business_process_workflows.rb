class CreateBusinessProcessWorkflows < ActiveRecord::Migration[8.0]
  def change
    create_table :business_process_workflows do |t|
      t.string :process_type, null: false
      t.string :name, null: false
      t.text :description
      t.json :workflow_data, default: {}
      t.boolean :active, default: true, null: false

      t.timestamps
    end
    
    # Ensure only one workflow per process type
    add_index :business_process_workflows, :process_type, unique: true
    add_index :business_process_workflows, :active
    
    # Add constraint to ensure valid process types
    execute <<-SQL
      ALTER TABLE business_process_workflows 
      ADD CONSTRAINT check_process_type 
      CHECK (process_type IN ('acquisition', 'conversion', 'standard_operations'))
    SQL
  end
end
