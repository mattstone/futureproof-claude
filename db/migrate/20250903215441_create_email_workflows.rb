class CreateEmailWorkflows < ActiveRecord::Migration[8.0]
  def change
    create_table :email_workflows do |t|
      t.string :name, null: false
      t.text :description
      t.boolean :active, default: true, null: false
      t.string :trigger_type, null: false
      t.json :trigger_conditions, default: {}
      t.references :created_by, null: false, foreign_key: { to_table: :users }

      t.timestamps
    end
    
    add_index :email_workflows, [:trigger_type, :active]
  end
end
