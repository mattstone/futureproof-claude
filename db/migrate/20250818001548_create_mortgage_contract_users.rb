class CreateMortgageContractUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :mortgage_contract_users do |t|
      t.references :mortgage_contract, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
    
    add_index :mortgage_contract_users, [:mortgage_contract_id, :user_id], unique: true, name: 'index_mortgage_contract_users_unique'
  end
end
