class CreateFunderPools < ActiveRecord::Migration[8.0]
  def change
    create_table :funder_pools do |t|
      t.references :funder, null: false, foreign_key: true
      t.string :name, null: false
      t.decimal :amount, precision: 15, scale: 2, null: false, default: 0.0
      t.decimal :allocated, precision: 15, scale: 2, null: false, default: 0.0

      t.timestamps
    end
    
    add_index :funder_pools, :name
    add_index :funder_pools, [:funder_id, :name], unique: true
  end
end
