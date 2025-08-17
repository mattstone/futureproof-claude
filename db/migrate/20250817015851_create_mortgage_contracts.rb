class CreateMortgageContracts < ActiveRecord::Migration[8.0]
  def change
    create_table :mortgage_contracts do |t|
      t.string :title, null: false
      t.text :content, null: false
      t.integer :version, null: false
      t.datetime :last_updated, null: false
      t.boolean :is_active, default: false, null: false
      t.boolean :is_draft, default: true, null: false
      t.references :created_by, null: true, foreign_key: { to_table: :users }

      t.timestamps
    end
    add_index :mortgage_contracts, :version, unique: true
    add_index :mortgage_contracts, :is_active
    add_index :mortgage_contracts, :is_draft
    add_index :mortgage_contracts, :last_updated
  end
end
