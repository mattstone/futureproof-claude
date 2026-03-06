class AddRegionToApplications < ActiveRecord::Migration[8.1]
  def change
    add_column :applications, :region, :string, default: "us"
    add_index :applications, :region
  end
end
