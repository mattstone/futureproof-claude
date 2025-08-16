class RenameFundersToWholesaleFunders < ActiveRecord::Migration[8.0]
  def change
    # Rename the table
    rename_table :funders, :wholesale_funders
    
    # Rename the foreign key column in funder_pools table
    rename_column :funder_pools, :funder_id, :wholesale_funder_id
    
    # The indexes are already renamed by rename_table, so we don't need to rename them again
  end
end
