class CreateWebhooks < ActiveRecord::Migration[8.1]
  def change
    create_table :webhooks do |t|
      t.string :event
      t.string :url
      t.boolean :active
      t.references :lender, null: false, foreign_key: true
      t.string :secret
      t.datetime :created_at
      t.datetime :updated_at
    end
  end
end
