class CreateMortgageFunderPools < ActiveRecord::Migration[8.0]
  def change
    create_table :mortgage_funder_pools do |t|
      t.references :mortgage, null: false, foreign_key: true
      t.references :funder_pool, null: false, foreign_key: true

      t.timestamps
    end
    
    add_index :mortgage_funder_pools, [:mortgage_id, :funder_pool_id], unique: true, name: 'index_mortgage_funder_pools_on_mortgage_and_pool'
  end
end
