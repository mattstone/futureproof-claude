class AddJurisdictionToBrokers < ActiveRecord::Migration[8.0]
  def change
    add_column :brokers, :jurisdiction, :string, default: "AU"
    add_index :brokers, :jurisdiction
  end
end
