class CreateLenderFunderPoolVersions < ActiveRecord::Migration[8.0]
  def change
    create_table :lender_funder_pool_versions do |t|
      t.references :lender_funder_pool, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :action
      t.text :change_details
      t.boolean :previous_active
      t.boolean :new_active

      t.timestamps
    end
  end
end
