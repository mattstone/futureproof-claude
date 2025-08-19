class AddAddressToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :address, :text
  end
end
