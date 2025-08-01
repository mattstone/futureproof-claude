class UpdateSecurityTrackingToBrowserSignatures < ActiveRecord::Migration[8.0]
  def change
    # Remove IP-based columns
    remove_column :users, :known_ip_addresses, :text
    remove_column :users, :last_sign_in_ip, :string
    
    # Add browser signature-based columns
    add_column :users, :known_browser_signatures, :text
    add_column :users, :last_browser_signature, :string
    add_column :users, :last_browser_info, :text
  end
end
