class AddDemoFlagToBusinessRecords < ActiveRecord::Migration[8.1]
  def change
    add_column :contracts, :demo, :boolean, default: false, null: false
    add_column :funder_pools, :demo, :boolean, default: false, null: false
    add_column :wholesale_funders, :demo, :boolean, default: false, null: false

    add_index :contracts, :demo
  end
end
