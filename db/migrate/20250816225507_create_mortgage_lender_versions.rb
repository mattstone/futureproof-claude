class CreateMortgageLenderVersions < ActiveRecord::Migration[8.0]
  def change
    create_table :mortgage_lender_versions do |t|
      t.references :mortgage_lender, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :action
      t.text :change_details
      t.boolean :previous_active
      t.boolean :new_active

      t.timestamps
    end
  end
end
