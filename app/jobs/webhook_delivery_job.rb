class WebhookDeliveryJob < ApplicationJob
  queue_as :default

  def perform(webhook_event_id)
    webhook_event = WebhookEvent.find(webhook_event_id)
    service = WebhookDeliveryService.new(webhook_event)
    service.deliver
  end
end
