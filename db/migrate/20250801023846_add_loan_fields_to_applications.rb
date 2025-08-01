class AddLoanFieldsToApplications < ActiveRecord::Migration[8.0]
  def change
    add_column :applications, :loan_term, :integer
    add_column :applications, :income_payout_term, :integer
    add_reference :applications, :mortgage, null: true, foreign_key: true
  end
end
