class CreateLenderVersions < ActiveRecord::Migration[8.0]
  def change
    create_table :lender_versions do |t|
      t.references :lender, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :action, null: false
      t.text :change_details
      
      # Track specific fields for lenders
      t.string :previous_name
      t.string :new_name
      t.integer :previous_lender_type
      t.integer :new_lender_type
      t.string :previous_contact_email
      t.string :new_contact_email
      t.string :previous_country
      t.string :new_country
      
      t.timestamps
    end
    
    add_index :lender_versions, [:lender_id, :created_at]
    add_index :lender_versions, :action
  end
end
