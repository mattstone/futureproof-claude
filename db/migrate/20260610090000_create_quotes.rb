class CreateQuotes < ActiveRecord::Migration[8.1]
  def change
    create_table :quotes do |t|
      t.references :application, null: false, foreign_key: true
      t.string :product_version, null: false
      t.string :pricing_model
      t.string :mortgage_type
      t.string :region
      t.bigint :home_value, null: false
      t.integer :term_years, null: false
      t.integer :income_payout_term
      t.decimal :annuity_rate, precision: 8, scale: 6
      t.decimal :lvr, precision: 5, scale: 4
      t.bigint :max_loan
      t.bigint :monthly_income, null: false
      t.bigint :annual_income
      t.bigint :total_income
      t.datetime :issued_at, null: false

      t.timestamps
    end

    add_index :quotes, [ :application_id, :issued_at ]
  end
end
