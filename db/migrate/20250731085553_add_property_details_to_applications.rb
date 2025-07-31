class AddPropertyDetailsToApplications < ActiveRecord::Migration[8.0]
  def change
    add_column :applications, :ownership_status, :integer, default: 0, null: false
    add_column :applications, :property_state, :integer, default: 0, null: false
    add_column :applications, :has_existing_mortgage, :boolean, default: false, null: false
    add_column :applications, :existing_mortgage_amount, :decimal, precision: 12, scale: 2
  end
end
