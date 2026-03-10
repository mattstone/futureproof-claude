class CreateWebhookDeliveries < ActiveRecord::Migration[8.1]
  def change
    create_table :webhook_deliveries do |t|
      t.references :webhook, null: false, foreign_key: true
      t.string :event
      t.jsonb :payload
      t.integer :response_code
      t.text :response_body
      t.datetime :delivered_at
      t.datetime :failed_at
      t.integer :retry_count
      t.datetime :created_at

    end
  end
end
