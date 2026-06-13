# Service for delivering webhook events with signature verification and retry logic
require "net/http"
require "json"
require "openssl"

class WebhookService
  MAX_RETRIES = 3
  TIMEOUT = 10
  SIGNATURE_HEADER = "X-Webhook-Signature"
  TIMESTAMP_HEADER = "X-Webhook-Timestamp"

  def initialize(webhook)
    @webhook = webhook
  end

  # Deliver webhook payload with signature
  def deliver(payload)
    delivery = create_delivery(payload)

    begin
      response = send_webhook(delivery)
      handle_response(delivery, response)
    rescue Timeout::Error, StandardError => e
      handle_error(delivery, e)
    end

    delivery
  end

  # Retry failed deliveries
  def self.retry_failed
    WebhookDelivery.retryable.find_each { |delivery| new(delivery.webhook).deliver_retry(delivery) }
  end

  # Retry a specific delivery
  def deliver_retry(delivery)
    begin
      response = send_webhook(delivery)
      handle_response(delivery, response)
    rescue Timeout::Error, StandardError => e
      handle_error(delivery, e)
    end

    delivery
  end

  private

  def create_delivery(payload)
    @webhook.webhook_deliveries.create!(
      event: payload[:event] || @webhook.event,
      payload: payload,
      delivery_status: :pending,
      retry_count: 0
    )
  end

  def send_webhook(delivery)
    uri = URI(@webhook.url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.read_timeout = TIMEOUT
    http.open_timeout = TIMEOUT

    request = Net::HTTP::Post.new(uri.request_uri)
    request.content_type = "application/json"
    request["User-Agent"] = "FutureProof-Webhook/1.0"

    # Add authentication headers
    timestamp = Time.current.to_i.to_s
    signature = generate_signature(delivery.payload, timestamp)
    request[SIGNATURE_HEADER] = signature
    request[TIMESTAMP_HEADER] = timestamp

    request.body = delivery.payload.to_json

    http.request(request)
  end

  def generate_signature(payload, timestamp)
    message = "#{timestamp}.#{payload.to_json}"
    digest = OpenSSL::Digest.new("sha256")
    signature = OpenSSL::HMAC.hexdigest(digest, @webhook.secret, message)
    "sha256=#{signature}"
  end

  def handle_response(delivery, response)
    case response.code.to_i
    when 200..299
      delivery.mark_delivered(response.code, response.body)
      Rails.logger.info("Webhook #{@webhook.id} delivered successfully: #{response.code}")
    else
      delivery.mark_failed(response.code, response.body)
      Rails.logger.warn("Webhook #{@webhook.id} failed: #{response.code} - #{response.body}")
    end
  end

  def handle_error(delivery, error)
    delivery.mark_failed(nil, error.message)
    Rails.logger.error("Webhook #{@webhook.id} error: #{error.class} - #{error.message}")
  end
end
