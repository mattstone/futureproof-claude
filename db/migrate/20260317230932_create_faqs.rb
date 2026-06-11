class CreateFaqs < ActiveRecord::Migration[8.1]
  def change
    create_table :faqs do |t|
      t.string :jurisdiction, null: false
      t.string :question, null: false
      t.text :answer, null: false
      t.integer :position, null: false, default: 0
      t.boolean :published, null: false, default: false

      t.timestamps
    end

    add_index :faqs, [:jurisdiction, :position]
    add_index :faqs, [:jurisdiction, :published]
  end
end
