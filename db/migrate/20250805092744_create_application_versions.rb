class CreateApplicationVersions < ActiveRecord::Migration[8.0]
  def change
    create_table :application_versions do |t|
      t.references :application, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :action
      t.text :change_details
      t.integer :previous_status
      t.integer :new_status
      t.text :previous_address
      t.text :new_address
      t.bigint :previous_home_value
      t.bigint :new_home_value
      t.bigint :previous_existing_mortgage_amount
      t.bigint :new_existing_mortgage_amount
      t.integer :previous_borrower_age
      t.integer :new_borrower_age
      t.integer :previous_ownership_status
      t.integer :new_ownership_status

      t.timestamps
    end
  end
end
