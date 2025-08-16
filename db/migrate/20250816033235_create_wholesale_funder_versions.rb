class CreateWholesaleFunderVersions < ActiveRecord::Migration[8.0]
  def change
    create_table :wholesale_funder_versions do |t|
      t.references :wholesale_funder, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :action, null: false
      t.text :change_details
      
      # Track specific fields for wholesale funders
      t.string :previous_name
      t.string :new_name
      t.string :previous_country
      t.string :new_country
      t.string :previous_currency
      t.string :new_currency
      
      t.timestamps
    end
    
    add_index :wholesale_funder_versions, [:wholesale_funder_id, :created_at]
    add_index :wholesale_funder_versions, :action
  end
end
