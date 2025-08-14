class RemoveActiveFromFunderPools < ActiveRecord::Migration[8.0]
  def change
    remove_index :funder_pools, :active
    remove_column :funder_pools, :active, :boolean
  end
end
