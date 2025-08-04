class SetDefaultForExistingMortgageAmount < ActiveRecord::Migration[8.0]
  def up
    # Update existing nil values to 0
    execute "UPDATE applications SET existing_mortgage_amount = 0 WHERE existing_mortgage_amount IS NULL"
    
    # Set default value for future records
    change_column_default :applications, :existing_mortgage_amount, 0
  end

  def down
    # Remove default value
    change_column_default :applications, :existing_mortgage_amount, nil
  end
end
