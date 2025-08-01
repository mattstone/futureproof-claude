class AddSecurityTrackingToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :known_ip_addresses, :text
    add_column :users, :last_sign_in_ip, :string
  end
end
