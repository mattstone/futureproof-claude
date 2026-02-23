class CreateApplicationDocuments < ActiveRecord::Migration[8.1]
  def change
    create_table :application_documents do |t|
      t.references :application, null: false, foreign_key: true
      t.string :document_type, null: false
      t.string :status, default: "pending"
      t.string :name
      t.text :notes
      t.string :rejection_reason
      t.string :verified_by
      t.datetime :verified_at
      t.datetime :requested_at
      t.datetime :uploaded_at
      t.datetime :expires_at
      t.timestamps
    end

    add_index :application_documents, [:application_id, :document_type]
    add_index :application_documents, :status
  end
end
