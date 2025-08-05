class CreateApplicationMessages < ActiveRecord::Migration[8.0]
  def change
    create_table :application_messages do |t|
      t.references :application, null: false, foreign_key: true
      t.references :sender, polymorphic: true, null: false
      t.string :message_type
      t.string :subject
      t.text :content
      t.string :status
      t.datetime :sent_at
      t.datetime :read_at
      t.references :parent_message, null: true, foreign_key: { to_table: :application_messages }

      t.timestamps
    end
  end
end
