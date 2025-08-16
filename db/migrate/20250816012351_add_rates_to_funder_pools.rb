class AddRatesToFunderPools < ActiveRecord::Migration[8.0]
  def change
    add_column :funder_pools, :benchmark_rate, :decimal, precision: 5, scale: 2, default: 4.00
    add_column :funder_pools, :margin_rate, :decimal, precision: 5, scale: 2, default: 0.00
  end
end
