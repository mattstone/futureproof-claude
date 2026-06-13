class CreateAgreements < ActiveRecord::Migration[8.1]
  def change
    create_table :agreements do |t|
      t.references :legal_document, null: false, foreign_key: true
      t.string :agreeable_type, null: false
      t.bigint :agreeable_id, null: false
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.string :title, null: false
      t.integer :status, null: false, default: 0
      t.text :content
      t.string :jurisdiction, null: false
      t.string :version
      t.datetime :sent_at
      t.datetime :executed_at
      t.datetime :expires_at
      t.text :notes
      t.timestamps
    end

    add_index :agreements, [ :agreeable_type, :agreeable_id ]
    add_index :agreements, :status

    create_table :agreement_signatures do |t|
      t.references :agreement, null: false, foreign_key: true
      t.string :signer_role, null: false
      t.string :signer_name, null: false
      t.string :signer_email, null: false
      t.string :signer_title
      t.string :signature_method, null: false, default: "typed"
      t.string :typed_signature, null: false
      t.string :ip_address
      t.string :user_agent
      t.datetime :signed_at, null: false
      t.timestamps
    end

    add_index :agreement_signatures, [ :agreement_id, :signer_role ], unique: true
  end
end
