class CreateWebhookEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :webhook_events do |t|
      t.references :webhook_endpoint, null: false, foreign_key: true
      t.string :event_type
      t.jsonb :payload
      t.datetime :delivered_at
      t.text :error_message
      t.integer :attempt_count

      t.timestamps
    end
  end
end
