class CreateEmailTemplates < ActiveRecord::Migration[8.0]
  def change
    create_table :email_templates do |t|
      t.string :name, null: false
      t.string :subject, null: false
      t.text :content, null: false
      t.string :template_type, null: false
      t.boolean :is_active, default: true, null: false
      t.text :description

      t.timestamps
    end
    add_index :email_templates, :name, unique: true
    add_index :email_templates, :template_type
    add_index :email_templates, :is_active
  end
end
