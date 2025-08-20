class CreateApplicationChecklists < ActiveRecord::Migration[8.0]
  def change
    create_table :application_checklists do |t|
      t.references :application, null: false, foreign_key: true
      t.string :name, null: false
      t.boolean :completed, default: false, null: false
      t.datetime :completed_at
      t.references :completed_by, null: true, foreign_key: { to_table: :users }
      t.integer :position, default: 0, null: false

      t.timestamps
    end
    
    add_index :application_checklists, [:application_id, :position]
  end
end
