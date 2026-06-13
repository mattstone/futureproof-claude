class CreateBorrowerMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :borrower_messages do |t|
      t.references :application, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :lender, foreign_key: true
      t.text :message, null: false
      t.string :sender_type, null: false # 'borrower' or 'lender'
      t.datetime :read_at
      t.timestamps
    end

    add_index :borrower_messages, [ :application_id, :created_at ]
  end
end
