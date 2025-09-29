class AddCompositeIndexes < ActiveRecord::Migration[8.0]
  def change
    # Add composite indexes for common application queries
    add_index :applications, [:mortgage_id, :status], name: 'index_applications_on_mortgage_id_and_status'
    add_index :applications, [:user_id, :status], name: 'index_applications_on_user_id_and_status'

    # Add composite indexes for user queries
    add_index :users, [:lender_id, :admin], name: 'index_users_on_lender_id_and_admin'
  end
end
