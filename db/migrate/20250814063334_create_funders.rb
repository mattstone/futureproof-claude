class CreateFunders < ActiveRecord::Migration[8.0]
  def change
    create_table :funders do |t|
      t.string :name, null: false
      t.string :country, null: false, default: 'Australia'
      t.string :currency, null: false, default: 'AUD'

      t.timestamps
    end
    
    add_index :funders, :name
    add_index :funders, :country
    add_index :funders, :currency
  end
end
