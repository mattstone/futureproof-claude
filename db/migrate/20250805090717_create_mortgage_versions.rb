class CreateMortgageVersions < ActiveRecord::Migration[8.0]
  def change
    create_table :mortgage_versions do |t|
      t.references :mortgage, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :action
      t.text :change_details
      t.text :previous_name
      t.text :new_name
      t.integer :previous_mortgage_type
      t.integer :new_mortgage_type
      t.decimal :previous_lvr, precision: 5, scale: 2
      t.decimal :new_lvr, precision: 5, scale: 2

      t.timestamps
    end
  end
end
