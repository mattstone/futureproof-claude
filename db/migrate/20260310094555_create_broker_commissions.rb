class CreateBrokerCommissions < ActiveRecord::Migration[8.1]
  def change
    create_table :broker_commissions do |t|
      t.references :broker, null: false, foreign_key: true
      t.references :application, null: false, foreign_key: true
      t.decimal :commission_amount
      t.decimal :commission_rate
      t.datetime :earned_date
      t.datetime :paid_date
      t.string :status

      t.timestamps
    end
  end
end
