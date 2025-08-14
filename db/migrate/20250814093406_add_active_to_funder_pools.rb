class AddActiveToFunderPools < ActiveRecord::Migration[8.0]
  def change
    add_column :funder_pools, :active, :boolean, null: false, default: true
    add_index :funder_pools, :active
  end
end
