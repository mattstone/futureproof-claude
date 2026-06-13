class RenameApplicationFieldsToEpm < ActiveRecord::Migration[8.1]
  def change
    # Rename traditional mortgage fields to EPM terminology
    rename_column :applications, :approved_loan_amount, :equity_investment_amount
    rename_column :applications, :approved_interest_rate, :equity_percentage
    rename_column :applications, :approved_term_years, :participation_term_years

    # Also rename the general loan fields for consistency
    rename_column :applications, :loan_term, :investment_term
  end
end
