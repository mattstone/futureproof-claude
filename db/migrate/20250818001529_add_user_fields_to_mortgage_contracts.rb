class AddUserFieldsToMortgageContracts < ActiveRecord::Migration[8.0]
  def change
    add_reference :mortgage_contracts, :primary_user, null: true, foreign_key: { to_table: :users }
  end
end
