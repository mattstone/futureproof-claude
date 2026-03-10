# Webhook System Documentation

## Overview

The FutureProof EPM webhook system enables real-time notifications to external systems when events occur in the platform. Lenders can register webhook endpoints and receive HTTP POST requests with signed payloads.

## Features

- ✅ Multiple webhook endpoints per lender
- ✅ Event filtering (choose which events to subscribe to)
- ✅ HMAC-SHA256 signature verification
- ✅ Automatic retry with exponential backoff (3 attempts)
- ✅ Delivery history tracking
- ✅ Test webhook functionality
- ✅ Error logging and notification

## Supported Events

- `application_created` — New application submitted
- `application_approved` — Application approved by lender
- `application_rejected` — Application rejected by lender
- `distribution_completed` — Monthly income payment completed

## API Payload Format

### Event Payload Structure

```json
{
  "event": "application_created",
  "timestamp": "2026-03-10T12:30:00Z",
  "application": {
    "id": 123,
    "borrower_name": "John Doe",
    "borrower_email": "john@example.com",
    "property_address": "123 Main St",
    "loan_amount": 500000,
    "property_value": 1000000,
    "ltv_ratio": 0.5,
    "status": "processing"
  }
}
```

### Webhook Headers

```
Content-Type: application/json
X-Webhook-Event: application_created
X-Webhook-Signature: <HMAC-SHA256 signature>
X-Webhook-Delivery: <unique delivery id>
```

## Signature Verification

Each webhook request includes an `X-Webhook-Signature` header containing an HMAC-SHA256 signature of the payload. To verify:

```ruby
require 'openssl'

signature = request.headers['X-Webhook-Signature']
secret = your_webhook_secret
payload = request.raw_post

expected_signature = OpenSSL::HMAC.hexdigest('sha256', secret, payload)
verified = ActiveSupport::SecurityUtils.secure_compare(signature, expected_signature)
```

## Retry Policy

Failed webhooks are automatically retried with exponential backoff:

- Attempt 1: Immediate
- Attempt 2: 1 minute delay
- Attempt 3: 4 minutes delay
- Attempt 4: 16 minutes delay

After 3 failed attempts, the webhook is marked as failed. Manual retry is available via the delivery log.

## Webhook Management UI

### Register a Webhook

1. Navigate to **Lender Dashboard** → **Webhooks**
2. Click **New Webhook**
3. Enter webhook URL (must be HTTPS)
4. Select events to subscribe to
5. Click **Create Webhook**

The system auto-generates a unique secret for signature verification.

### Test a Webhook

1. Click **Test** on any webhook endpoint
2. Review the test payload
3. Check your endpoint's response
4. View signature details

### View Delivery History

1. Click **Logs** on any webhook endpoint
2. See status, timestamp, and response codes
3. Click **Retry** for failed deliveries
4. Review error messages if applicable

## Database Schema

### webhook_endpoints

| Column | Type | Notes |
|--------|------|-------|
| id | bigint | Primary key |
| user_id | bigint | Lender who owns the endpoint |
| url | string | HTTPS endpoint URL |
| secret | string | 64-char hex for HMAC signing |
| events | text | Comma-separated event types |
| active | boolean | Enable/disable endpoint |
| last_triggered_at | datetime | Last webhook sent |
| created_at | datetime | |
| updated_at | datetime | |

### webhook_events

| Column | Type | Notes |
|--------|------|-------|
| id | bigint | Primary key |
| webhook_endpoint_id | bigint | Associated endpoint |
| event_type | string | Type of event |
| payload | jsonb | Full event payload |
| status | integer | 0=pending, 1=delivered, 2=failed |
| delivered_at | datetime | When successfully delivered |
| error_message | text | Error details if failed |
| attempt_count | integer | Number of delivery attempts |
| created_at | datetime | |
| updated_at | datetime | |

## Code Examples

### Ruby (Rails)

```ruby
# Register a webhook
user = User.find(1)
endpoint = user.webhook_endpoints.create!(
  url: 'https://example.com/webhooks',
  events: ['application_created', 'distribution_completed']
)

# Trigger webhook when application is created
app = Application.create!(...)
app.trigger_application_created_webhook

# View delivery history
endpoint.webhook_events.where(status: :failed)
```

### JavaScript (Verification)

```javascript
const crypto = require('crypto');

function verifyWebhook(signature, secret, payload) {
  const expected = crypto
    .createHmac('sha256', secret)
    .update(payload)
    .digest('hex');
  
  return crypto.timingSafeEqual(
    Buffer.from(signature),
    Buffer.from(expected)
  );
}
```

### Python (Verification)

```python
import hmac
import hashlib

def verify_webhook(signature, secret, payload):
    expected = hmac.new(
        secret.encode(),
        payload.encode(),
        hashlib.sha256
    ).hexdigest()
    
    return hmac.compare_digest(signature, expected)
```

## Testing

### Using RequestBin (Free)

1. Visit https://requestbin.com
2. Create new bin (get URL)
3. Register webhook with RequestBin URL
4. Send test webhook from FutureProof
5. View payload in RequestBin UI

### Using Webhook.cool

Similar to RequestBin:
1. Visit https://webhook.cool
2. Create endpoint
3. Register with FutureProof
4. Test and inspect payloads

### Using ngrok (Local)

```bash
# Start ngrok tunnel
ngrok http 3000

# Use ngrok URL as webhook endpoint
https://abc123.ngrok.io/webhooks
```

## Troubleshooting

### Webhook not triggering?
- Check endpoint is active (green status badge)
- Verify event is subscribed to
- Check delivery log for status

### "Connection refused" error?
- Ensure endpoint URL is publicly accessible
- Verify HTTPS certificate is valid
- Check firewall/network policies

### "Timeout" error?
- Webhook timeout is 10 seconds
- Ensure endpoint responds within timeout
- Return 2xx status code quickly

### Signature verification fails?
- Verify secret is correct (view in Edit Webhook)
- Use raw request body (not parsed JSON)
- Ensure HMAC-SHA256 algorithm

## Best Practices

1. **Verify signatures** — Always verify X-Webhook-Signature before processing
2. **Return quickly** — Respond within 10 seconds; process async if needed
3. **Handle retries** — Implement idempotency; track processed webhook IDs
4. **Monitor logs** — Regularly check delivery history for failures
5. **Use HTTPS only** — All endpoints must use HTTPS
6. **Rotate secrets** — Periodically regenerate secrets for security
7. **Log payloads** — Store webhook payloads for debugging (without sensitive data)

## Limits

- Max 100 webhook endpoints per lender
- Max 30-day retention of webhook event logs
- 10-second request timeout per webhook
- Max 3 automatic retries per webhook

## Support

For webhook-related questions, contact support@futureprooffinancial.co or visit the lender dashboard help section.
