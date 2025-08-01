class AddSuperFundNameToApplications < ActiveRecord::Migration[8.0]
  def change
    add_column :applications, :super_fund_name, :string
  end
end
