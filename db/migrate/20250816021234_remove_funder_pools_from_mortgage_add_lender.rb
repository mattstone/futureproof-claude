class RemoveFunderPoolsFromMortgageAddLender < ActiveRecord::Migration[8.0]
  def up
    # Add lender reference to mortgages
    add_reference :mortgages, :lender, null: true, foreign_key: true
    
    # Drop the mortgage_funder_pools table
    drop_table :mortgage_funder_pools
  end
  
  def down
    # Recreate the mortgage_funder_pools table
    create_table :mortgage_funder_pools do |t|
      t.references :mortgage, null: false, foreign_key: true
      t.references :funder_pool, null: false, foreign_key: true
      t.boolean :active, default: true, null: false
      t.timestamps
    end
    
    add_index :mortgage_funder_pools, [:mortgage_id, :funder_pool_id], unique: true, name: 'index_mortgage_funder_pools_on_mortgage_and_pool'
    add_index :mortgage_funder_pools, :active
    
    # Remove lender reference from mortgages
    remove_reference :mortgages, :lender, foreign_key: true
  end
end
