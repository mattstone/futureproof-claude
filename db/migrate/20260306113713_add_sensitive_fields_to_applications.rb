class AddSensitiveFieldsToApplications < ActiveRecord::Migration[8.1]
  def change
    add_column :applications, :government_id, :string
    add_column :applications, :credit_score, :string
    add_column :applications, :bank_account_number, :string
  end
end
