class AddMortgageToMortgageContracts < ActiveRecord::Migration[8.0]
  def change
    add_reference :mortgage_contracts, :mortgage, null: true, foreign_key: true
  end
end
