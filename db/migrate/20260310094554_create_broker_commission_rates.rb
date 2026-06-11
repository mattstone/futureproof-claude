class CreateBrokerCommissionRates < ActiveRecord::Migration[8.1]
  def change
    create_table :broker_commission_rates do |t|
      t.references :broker, null: false, foreign_key: true
      t.references :lender, null: false, foreign_key: true
      t.decimal :commission_percentage
      t.string :payment_trigger
      t.boolean :active

      t.timestamps
    end
  end
end
