class AddDeliveryStatusToWebhookDeliveries < ActiveRecord::Migration[8.1]
  def change
    add_column :webhook_deliveries, :delivery_status, :integer, default: 0
    add_index :webhook_deliveries, :delivery_status
    add_index :webhook_deliveries, :created_at
  end
end
