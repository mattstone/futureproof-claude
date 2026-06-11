class AddPaymentPeriodToDistributions < ActiveRecord::Migration[8.1]
  def change
    add_column :distributions, :payment_period_month, :integer
    add_column :distributions, :payment_period_year, :integer
  end
end
