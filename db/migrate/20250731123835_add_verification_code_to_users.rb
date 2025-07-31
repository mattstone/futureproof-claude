class AddVerificationCodeToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :verification_code, :string
    add_column :users, :verification_code_expires_at, :datetime
  end
end
