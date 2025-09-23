class AddExistingMortgageLenderToApplications < ActiveRecord::Migration[8.0]
  def change
    add_column :applications, :existing_mortgage_lender, :string
  end
end
