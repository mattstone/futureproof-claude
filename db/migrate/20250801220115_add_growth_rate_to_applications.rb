class AddGrowthRateToApplications < ActiveRecord::Migration[8.0]
  def change
    add_column :applications, :growth_rate, :decimal, precision: 5, scale: 2, default: 2.0
  end
end
