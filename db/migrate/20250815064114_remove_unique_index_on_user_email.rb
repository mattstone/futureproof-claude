class RemoveUniqueIndexOnUserEmail < ActiveRecord::Migration[8.0]
  def change
    # Remove the old unique index on email column only
    # Keep the new scoped unique index on email + company_id
    remove_index :users, :email
  end
end
