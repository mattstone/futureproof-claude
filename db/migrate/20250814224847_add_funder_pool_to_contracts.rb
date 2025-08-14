class AddFunderPoolToContracts < ActiveRecord::Migration[8.0]
  def change
    add_reference :contracts, :funder_pool, null: true, foreign_key: true
    add_column :contracts, :allocated_amount, :decimal, precision: 15, scale: 2
  end
end
