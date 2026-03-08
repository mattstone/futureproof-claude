class AddFieldsToBrokers < ActiveRecord::Migration[8.0]
  def change
    add_column :brokers, :name, :string
    add_column :brokers, :phone, :string
    add_column :brokers, :active, :boolean, default: true
  end
end
