class AddDefaultToBorrowerAge < ActiveRecord::Migration[8.0]
  def up
    # Set default value for borrower_age column
    change_column_default :applications, :borrower_age, 0
    
    # Update existing records that have null borrower_age
    Application.where(borrower_age: nil).update_all(borrower_age: 0)
  end

  def down
    # Remove the default value
    change_column_default :applications, :borrower_age, nil
  end
end
