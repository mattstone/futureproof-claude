class AddBorrowerDetailsToApplications < ActiveRecord::Migration[8.0]
  def change
    add_column :applications, :borrower_age, :integer
    add_column :applications, :borrower_names, :text
    add_column :applications, :company_name, :string
  end
end
