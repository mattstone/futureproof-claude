class CreateInvestmentPartners < ActiveRecord::Migration[8.1]
  def change
    create_table :investment_partners do |t|
      t.string :name, null: false
      t.string :region, null: false
      t.string :licence_number, null: false
      t.decimal :aum, precision: 15, scale: 2, default: 0.0
      t.string :portfolio_strategy
      t.decimal :fee_rate, precision: 5, scale: 2, default: 0.0
      t.string :status, default: "active"
      t.references :wholesale_funder, null: false, foreign_key: true

      t.timestamps
    end

    add_index :investment_partners, :region
    add_index :investment_partners, :status
    add_index :investment_partners, :licence_number, unique: true
  end
end
