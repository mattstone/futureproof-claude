class CreateKycSubmissions < ActiveRecord::Migration[8.1]
  def change
    create_table :kyc_submissions do |t|
      t.references :application, null: false, foreign_key: true
      t.integer :status
      t.string :verification_type
      t.datetime :submitted_at
      t.datetime :verified_at
      t.string :verified_by
      t.string :document_url
      t.text :notes
      t.datetime :created_at
      t.datetime :updated_at

    end
  end
end
