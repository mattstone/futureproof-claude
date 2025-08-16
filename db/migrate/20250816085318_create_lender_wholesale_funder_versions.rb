class CreateLenderWholesaleFunderVersions < ActiveRecord::Migration[8.0]
  def change
    create_table :lender_wholesale_funder_versions do |t|
      t.references :lender_wholesale_funder, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :action
      t.text :change_details
      t.boolean :previous_active
      t.boolean :new_active

      t.timestamps
    end
  end
end
