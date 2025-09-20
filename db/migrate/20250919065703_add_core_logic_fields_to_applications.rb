class AddCoreLogicFieldsToApplications < ActiveRecord::Migration[8.0]
  def change
    add_column :applications, :property_id, :string
    add_column :applications, :property_type, :string
    add_column :applications, :property_images, :text
    add_column :applications, :property_valuation_low, :integer
    add_column :applications, :property_valuation_middle, :integer
    add_column :applications, :property_valuation_high, :integer
    add_column :applications, :corelogic_data, :text
  end
end
