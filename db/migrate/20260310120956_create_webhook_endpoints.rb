class CreateWebhookEndpoints < ActiveRecord::Migration[8.1]
  def change
    create_table :webhook_endpoints do |t|
      t.references :lender, null: false, foreign_key: true
      t.string :url
      t.string :secret
      t.text :events
      t.boolean :active
      t.datetime :last_triggered_at

      t.timestamps
    end
  end
end
