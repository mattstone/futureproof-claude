class AddFinancialFieldsToContracts < ActiveRecord::Migration[8.0]
  def change
    add_column :contracts, :offset_balance, :decimal, precision: 12, scale: 2, default: 0
    add_column :contracts, :investment_balance, :decimal, precision: 12, scale: 2, default: 0
    add_column :contracts, :monthly_payment, :decimal, precision: 10, scale: 2, default: 0
    add_column :contracts, :total_payments_made, :decimal, precision: 12, scale: 2, default: 0
    add_column :contracts, :investment_return_rate, :decimal, precision: 8, scale: 4, default: 0
    add_column :contracts, :cost_of_capital_rate, :decimal, precision: 8, scale: 4, default: 0
  end
end
