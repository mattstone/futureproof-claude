class AddTermsVersionToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :terms_version, :integer, null: true
    add_index :users, :terms_version
  end
end
