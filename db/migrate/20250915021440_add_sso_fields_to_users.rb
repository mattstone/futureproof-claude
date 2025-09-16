class AddSsoFieldsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :sso_provider, :string
    add_column :users, :sso_uid, :string
    add_index :users, [:sso_provider, :sso_uid, :lender_id],
              unique: true, name: 'index_users_on_sso_and_lender'
  end
end
