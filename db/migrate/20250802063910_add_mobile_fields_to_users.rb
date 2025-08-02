class AddMobileFieldsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :mobile_country_code, :string
    add_column :users, :mobile_number, :string
  end
end
