class CreateTermsOfUseVersions < ActiveRecord::Migration[8.0]
  def change
    create_table :terms_of_use_versions do |t|
      t.references :terms_of_use, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :action, null: false
      t.text :change_details
      t.text :previous_content
      t.text :new_content

      t.timestamps
    end
    
    add_index :terms_of_use_versions, [:terms_of_use_id, :created_at]
  end
end
