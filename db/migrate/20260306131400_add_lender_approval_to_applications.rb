class AddLenderApprovalToApplications < ActiveRecord::Migration[8.1]
  def change
    add_column :applications, :lender_id, :bigint
    add_column :applications, :approved_loan_amount, :decimal, precision: 15, scale: 2
    add_column :applications, :approved_interest_rate, :decimal, precision: 5, scale: 3
    add_column :applications, :approved_term_years, :integer

    add_index :applications, :lender_id
    add_index :applications, [ :lender_id, :status ]
    add_foreign_key :applications, :lenders, column: :lender_id
  end
end
