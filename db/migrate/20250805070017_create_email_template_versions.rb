class CreateEmailTemplateVersions < ActiveRecord::Migration[8.0]
  def change
    create_table :email_template_versions do |t|
      t.references :email_template, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :action
      t.text :change_details
      t.text :previous_content
      t.text :new_content
      t.string :previous_subject
      t.string :new_subject

      t.timestamps
    end
  end
end
