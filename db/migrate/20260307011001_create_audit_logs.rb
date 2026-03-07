class CreateAuditLogs < ActiveRecord::Migration[7.1]
  def change
    create_table :audit_logs do |t|
      t.references :user, null: false, foreign_key: true
      t.references :application, null: true, foreign_key: true
      t.integer :kyc_verification_id

      t.string :action, null: false
      t.string :resource_type
      t.string :resource_id
      t.text :changes
      t.string :reason
      t.text :notes

      t.string :region, limit: 2
      t.string :ip_address

      t.timestamps
    end

    add_index :audit_logs, [:user_id, :created_at]
    add_index :audit_logs, [:resource_type, :created_at]
    add_index :audit_logs, :action
    add_index :audit_logs, :created_at
  end
end
