class CreateTermsOfUses < ActiveRecord::Migration[8.0]
  def change
    create_table :terms_of_uses do |t|
      t.string :title, null: false
      t.text :content, null: false
      t.datetime :last_updated, null: false
      t.boolean :is_active, default: false, null: false

      t.timestamps
    end
    
    add_index :terms_of_uses, :is_active
    add_index :terms_of_uses, :last_updated
  end
end
