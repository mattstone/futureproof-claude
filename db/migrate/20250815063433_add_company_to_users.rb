class AddCompanyToUsers < ActiveRecord::Migration[8.0]
  def change
    add_reference :users, :company, null: true, foreign_key: true
    add_index :users, [:email, :company_id], unique: true, name: 'index_users_on_email_and_company_id'
    
    # Update existing users to belong to the master company
    reversible do |dir|
      dir.up do
        # Find the master company (Futureproof Financial)
        master_company = execute("SELECT id FROM companies WHERE company_type = 0 LIMIT 1").first
        
        if master_company
          master_company_id = master_company['id']
          execute("UPDATE users SET company_id = #{master_company_id} WHERE company_id IS NULL")
        end
      end
    end
    
    # Now make company_id required
    change_column_null :users, :company_id, false
  end
end
