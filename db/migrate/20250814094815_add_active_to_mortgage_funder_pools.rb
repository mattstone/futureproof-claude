class AddActiveToMortgageFunderPools < ActiveRecord::Migration[8.0]
  def change
    add_column :mortgage_funder_pools, :active, :boolean, null: false, default: true
    add_index :mortgage_funder_pools, :active
  end
end
