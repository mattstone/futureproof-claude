class CreateUserVersions < ActiveRecord::Migration[8.0]
  def change
    create_table :user_versions do |t|
      t.references :user, null: false, foreign_key: true
      t.references :admin_user, null: false, foreign_key: { to_table: :users }
      t.string :action
      t.text :change_details
      t.string :previous_first_name
      t.string :new_first_name
      t.string :previous_last_name
      t.string :new_last_name
      t.string :previous_email
      t.string :new_email
      t.boolean :previous_admin
      t.boolean :new_admin
      t.string :previous_country_of_residence
      t.string :new_country_of_residence
      t.string :previous_mobile_number
      t.string :new_mobile_number
      t.string :previous_mobile_country_code
      t.string :new_mobile_country_code
      t.integer :previous_terms_version
      t.integer :new_terms_version
      t.datetime :previous_confirmed_at
      t.datetime :new_confirmed_at

      t.timestamps
    end
  end
end
