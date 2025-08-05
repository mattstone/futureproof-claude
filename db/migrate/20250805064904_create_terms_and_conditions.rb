class CreateTermsAndConditions < ActiveRecord::Migration[8.0]
  def change
    create_table :terms_and_conditions do |t|
      t.string :title, null: false
      t.text :content, null: false
      t.integer :version, null: false
      t.datetime :last_updated, null: false
      t.boolean :is_active, default: false, null: false
      t.references :created_by, null: true, foreign_key: { to_table: :users }

      t.timestamps
    end
    
    add_index :terms_and_conditions, :version, unique: true
    add_index :terms_and_conditions, :is_active
    add_index :terms_and_conditions, :last_updated
  end
end
