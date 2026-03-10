class WebhookDeliveryService
  attr_reader :webhook_endpoint, :webhook_event

  def initialize(webhook_event)
    @webhook_event = webhook_event
    @webhook_endpoint = webhook_event.webhook_endpoint
  end

  def deliver
    raise "Webhook endpoint not found" unless webhook_endpoint
    
    signature = generate_signature
    
    response = HTTParty.post(
      webhook_endpoint.url,
      headers: {
        'Content-Type' => 'application/json',
        'X-Webhook-Signature' => signature,
        'X-Webhook-Event' => webhook_event.event_type,
        'X-Webhook-Delivery' => webhook_event.id
      },
      body: webhook_event.payload.to_json,
      timeout: 10
    )

    if response.success?
      webhook_event.mark_delivered!
      Rails.logger.info("Webhook delivered: #{webhook_event.id} to #{webhook_endpoint.url}")
      true
    else
      error_msg = "HTTP #{response.code}: #{response.body[0..200]}"
      webhook_event.mark_failed!(error_msg)
      Rails.logger.error("Webhook failed: #{webhook_event.id} - #{error_msg}")
      false
    end
  rescue StandardError => e
    error_msg = "#{e.class}: #{e.message[0..200]}"
    webhook_event.mark_failed!(error_msg)
    Rails.logger.error("Webhook error: #{webhook_event.id} - #{error_msg}")
    false
  end

  private

  def generate_signature
    payload = webhook_event.payload.to_json
    OpenSSL::HMAC.hexdigest('sha256', webhook_endpoint.secret, payload)
  end
end
