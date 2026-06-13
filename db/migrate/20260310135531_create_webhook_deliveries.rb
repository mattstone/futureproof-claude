class CreateWebhookDeliveries < ActiveRecord::Migration[8.1]
  def change
    create_table :webhook_deliveries do |t|
      t.references :webhook, null: false, foreign_key: true
      t.string :event
      t.jsonb :payload
      t.integer :delivery_status, default: 0  # 0=pending, 1=processing, 2=delivered, 3=failed
      t.integer :response_code
      t.text :response_body
      t.datetime :delivered_at
      t.datetime :failed_at
      t.integer :retry_count, default: 0
      t.datetime :created_at
    end

    add_index :webhook_deliveries, :delivery_status
    add_index :webhook_deliveries, :created_at
  end
end
