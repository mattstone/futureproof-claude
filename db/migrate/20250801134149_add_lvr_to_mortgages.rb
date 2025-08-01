class AddLvrToMortgages < ActiveRecord::Migration[8.0]
  def change
    add_column :mortgages, :lvr, :decimal, precision: 5, scale: 2, default: 80.0
  end
end
