class AddTotalAllocatedAmountToWholesaleFunders < ActiveRecord::Migration[8.1]
  def change
    add_column :wholesale_funders, :total_allocated_amount, :decimal, 
               precision: 15, scale: 2, null: false, default: 0
  end
end
