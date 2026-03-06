class CreateDistributions < ActiveRecord::Migration[8.1]
  def change
    create_table :distributions do |t|
      t.bigint :application_id, null: false
      t.bigint :mortgage_id
      t.decimal :amount, precision: 15, scale: 2, null: false
      t.decimal :lender_margin, precision: 10, scale: 2
      t.date :distribution_date, null: false
      t.integer :status, default: 0  # pending, processing, completed, failed
      t.string :payment_method  # ach, wire, check, etc
      t.string :transaction_id
      t.text :notes
      t.datetime :processed_at
      t.datetime :failed_at

      t.timestamps
    end

    add_foreign_key :distributions, :applications
    add_foreign_key :distributions, :mortgages, column: :mortgage_id
    add_index :distributions, :application_id
    add_index :distributions, :mortgage_id
    add_index :distributions, :distribution_date
    add_index :distributions, :status
    add_index :distributions, [:application_id, :distribution_date]
  end
end
