class RenameCompaniesToLenders < ActiveRecord::Migration[8.0]
  def change
    # Rename the table
    rename_table :companies, :lenders
    
    # Rename the foreign key column in users table
    rename_column :users, :company_id, :lender_id
    
    # Rename the enum values to reflect lender types
    # master -> futureproof, broker -> lender
    # We'll update the enum values in the model, but the database values stay the same
    
    # Update indexes (some were already renamed by rename_table)
    # Only rename the ones that need different names
    begin
      rename_index :lenders, 'index_lenders_on_company_type', 'index_lenders_on_lender_type'
    rescue ActiveRecord::StatementInvalid
      # Index might have already been renamed
    end
    
    # Rename the column in lenders table to reflect new terminology
    rename_column :lenders, :company_type, :lender_type
  end
end
