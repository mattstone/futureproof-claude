class CreateContractVersions < ActiveRecord::Migration[8.0]
  def change
    create_table :contract_versions do |t|
      t.references :contract, null: false, foreign_key: true
      t.references :admin_user, null: false, foreign_key: { to_table: :users }
      t.string :action
      t.text :change_details
      t.string :previous_status
      t.string :new_status
      t.datetime :previous_start_date
      t.datetime :new_start_date
      t.datetime :previous_end_date
      t.datetime :new_end_date
      t.integer :previous_application_id
      t.integer :new_application_id

      t.timestamps
    end
  end
end
