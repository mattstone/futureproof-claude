class WebhookTestService
  def initialize(webhook_endpoint)
    @webhook_endpoint = webhook_endpoint
  end

  def test_webhook
    test_payload = {
      event: 'test',
      timestamp: Time.current.iso8601,
      message: 'This is a test webhook from FutureProof EPM',
      webhook_id: @webhook_endpoint.id
    }

    signature = generate_signature(test_payload)

    response = HTTParty.post(
      @webhook_endpoint.url,
      headers: {
        'Content-Type' => 'application/json',
        'X-Webhook-Signature' => signature,
        'X-Webhook-Event' => 'test',
        'X-Webhook-Delivery' => "test-#{Time.current.to_i}"
      },
      body: test_payload.to_json,
      timeout: 10
    )

    {
      success: response.success?,
      status_code: response.code,
      headers: response.headers,
      body: response.body,
      signature: signature,
      payload: test_payload,
      request_url: @webhook_endpoint.url,
      timestamp: Time.current.iso8601,
      error: nil
    }
  rescue StandardError => e
    {
      success: false,
      status_code: nil,
      headers: {},
      body: nil,
      signature: generate_signature({ event: 'test' }),
      payload: { event: 'test' },
      request_url: @webhook_endpoint.url,
      timestamp: Time.current.iso8601,
      error: "#{e.class}: #{e.message}"
    }
  end

  private

  def generate_signature(payload)
    OpenSSL::HMAC.hexdigest('sha256', @webhook_endpoint.secret, payload.to_json)
  end
end
