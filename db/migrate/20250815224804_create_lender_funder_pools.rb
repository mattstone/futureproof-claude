class CreateLenderFunderPools < ActiveRecord::Migration[8.0]
  def change
    create_table :lender_funder_pools do |t|
      t.references :lender, null: false, foreign_key: true
      t.references :funder_pool, null: false, foreign_key: true
      t.boolean :active, default: true, null: false

      t.timestamps
    end
    
    add_index :lender_funder_pools, [:lender_id, :funder_pool_id], 
              unique: true, name: 'index_lender_funder_pools_uniqueness'
  end
end
