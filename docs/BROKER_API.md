# Broker API Documentation

## Overview

The Broker API provides endpoints for broker authentication, application management, commission tracking, and password management. All endpoints require authentication via Devise session (for web UI) or API tokens (for programmatic access).

**Base URL:** `/broker`
**Authentication:** Devise sessions (web) or Bearer tokens (API)
**Content-Type:** `application/json` (all responses)

---

## Authentication

### Session-Based (Web UI)

```bash
POST /broker/sign_in
Content-Type: application/x-www-form-urlencoded

broker[email]=broker@example.com&broker[password]=password123
```

Response: Sets `_session_id` cookie. Subsequent requests include cookie automatically.

### Password Setup / Reset

Brokers receive email with token link to set initial password.

```bash
GET /broker/password/new?token=RESET_TOKEN
# Shows password setup form

POST /broker/password
token=RESET_TOKEN
password=new_password
password_confirmation=new_password
```

---

## Endpoints

### 1. Applications — List

**GET** `/broker/applications`

Lists all applications for the authenticated broker.

**Authentication:** Required (logged-in broker)

**Query Parameters:**
- `page` (optional): Pagination page number (default: 1)
- `per_page` (optional): Results per page (default: 20)

**Response:**

```json
{
  "applications": [
    {
      "id": 1,
      "status": "submitted",
      "loan_amount": 400000,
      "property_address": "123 Main St, Sydney NSW 2000",
      "applicant_name": "John Doe",
      "created_at": "2026-03-09T10:00:00Z",
      "lender": {
        "id": 1,
        "name": "FutureProof Lenders"
      }
    }
  ],
  "stats": {
    "total": 45,
    "pending": 12,
    "approved": 28,
    "rejected": 5
  },
  "pagination": {
    "page": 1,
    "per_page": 20,
    "total_count": 45
  }
}
```

**Status Codes:**
- `200 OK` — Success
- `401 Unauthorized` — Not logged in
- `403 Forbidden` — No lenders assigned

---

### 2. Applications — Show

**GET** `/broker/applications/:id`

Shows detailed view of a specific application.

**Authentication:** Required (broker must have access to application's lender)

**Response:**

```json
{
  "application": {
    "id": 1,
    "status": "accepted",
    "loan_amount": 400000,
    "interest_rate": 5.5,
    "loan_term_years": 30,
    "property_address": "123 Main St, Sydney NSW 2000",
    "applicant": {
      "id": 1,
      "name": "John Doe",
      "email": "john@example.com",
      "phone": "+61 2 1234 5678"
    },
    "distributions": [
      {
        "id": 1,
        "amount": 4944.00,
        "status": "completed",
        "transaction_id": "TXN-001",
        "processed_at": "2026-03-09T14:30:00Z"
      }
    ],
    "created_at": "2026-03-09T10:00:00Z",
    "updated_at": "2026-03-10T09:15:00Z"
  }
}
```

**Status Codes:**
- `200 OK` — Success
- `401 Unauthorized` — Not logged in
- `403 Forbidden` — Broker doesn't have access to this application

---

### 3. Commissions — List

**GET** `/broker/commissions`

Lists commission records for the authenticated broker with optional filtering and export.

**Authentication:** Required (logged-in broker)

**Query Parameters:**
- `period` (optional): Filter by period
  - `month` — Current month (default)
  - `quarter` — Current quarter
  - `year` — Current year
  - Custom: `start_date=YYYY-MM-DD&end_date=YYYY-MM-DD`
- `status` (optional): Filter by status
  - `all` — All commissions (default)
  - `earned` — Earned commissions
  - `pending` — Pending commissions
  - `paid` — Paid commissions
- `format` (optional): Response format
  - `json` — JSON response (default)
  - `csv` — CSV export (text/csv)

**Response (JSON):**

```json
{
  "commissions": [
    {
      "id": 1,
      "application_id": 1,
      "application": {
        "id": 1,
        "applicant": "John Doe"
      },
      "commission_amount": 10000.00,
      "commission_rate": 2.5,
      "status": "earned",
      "earned_date": "2026-03-09T10:00:00Z",
      "paid_date": null
    }
  ],
  "summary": {
    "total_earned": 35000.00,
    "total_pending": 5000.00,
    "total_paid": 30000.00,
    "period": "2026-03 (March 2026)"
  }
}
```

**Response (CSV):**

```csv
Broker Name,Email,Period,Generated Date
John Broker,john@broker.com,2026-03,2026-03-10

Application ID,Applicant,Loan Amount,Rate,Commission,Earned Date,Status
1,John Doe,400000,2.5%,10000.00,2026-03-09,earned
```

**Status Codes:**
- `200 OK` — Success (JSON or CSV)
- `401 Unauthorized` — Not logged in
- `400 Bad Request` — Invalid period or date range

---

### 4. Password — Setup

**GET** `/broker/password/new?token=TOKEN`

Shows password setup form (no JSON response, HTML form).

**Parameters:**
- `token` (required): Password reset token from email

**Status Codes:**
- `200 OK` — Form displayed
- `404 Not Found` — Invalid or expired token

---

### 5. Password — Create

**POST** `/broker/password`

Sets initial password for broker account.

**Request Body:**

```json
{
  "token": "RESET_TOKEN",
  "password": "new_password_123",
  "password_confirmation": "new_password_123"
}
```

**Response:**

```json
{
  "success": true,
  "message": "Password set successfully. You can now sign in.",
  "redirect_to": "/broker/sign_in"
}
```

**Status Codes:**
- `200 OK` — Password set successfully
- `400 Bad Request` — Validation errors (password mismatch, too short)
- `404 Not Found` — Invalid or expired token

**Error Response:**

```json
{
  "success": false,
  "errors": [
    "Password can't be blank",
    "Password confirmation doesn't match Password"
  ]
}
```

---

### 6. Password — Reset Form

**GET** `/broker/password/reset/:token`

Shows password reset form.

**Parameters:**
- `token` (required): Password reset token from email

**Status Codes:**
- `200 OK` — Form displayed
- `404 Not Found` — Invalid or expired token

---

### 7. Password — Update

**PATCH** `/broker/password/:token`

Updates broker password using reset token.

**Request Body:**

```json
{
  "password": "new_password_123",
  "password_confirmation": "new_password_123"
}
```

**Response:**

```json
{
  "success": true,
  "message": "Password reset successfully. You can now sign in.",
  "redirect_to": "/broker/sign_in"
}
```

**Status Codes:**
- `200 OK` — Password updated successfully
- `400 Bad Request` — Validation errors
- `404 Not Found` — Invalid or expired token

---

## Data Models

### Application

```json
{
  "id": 1,
  "status": "accepted|rejected|submitted|processing",
  "loan_amount": 400000,
  "interest_rate": 5.5,
  "loan_term_years": 30,
  "property_address": "string",
  "applicant_name": "string",
  "created_at": "ISO8601 datetime",
  "updated_at": "ISO8601 datetime"
}
```

### BrokerCommission

```json
{
  "id": 1,
  "application_id": 1,
  "commission_amount": 10000.00,
  "commission_rate": 2.5,
  "status": "earned|pending|paid",
  "earned_date": "ISO8601 datetime or null",
  "paid_date": "ISO8601 datetime or null",
  "created_at": "ISO8601 datetime"
}
```

### Broker

```json
{
  "id": 1,
  "email": "broker@example.com",
  "lenders": [
    {
      "id": 1,
      "name": "FutureProof Lenders"
    }
  ],
  "created_at": "ISO8601 datetime"
}
```

---

## Pagination

List endpoints support cursor-based pagination:

**Query Parameters:**
- `page`: Page number (default: 1, min: 1)
- `per_page`: Results per page (default: 20, max: 100)

**Response Header:**
```
X-Total-Count: 45
X-Page: 1
X-Per-Page: 20
X-Total-Pages: 3
```

---

## Error Handling

All errors return JSON with consistent format:

```json
{
  "error": "Error message here",
  "status": 400
}
```

**HTTP Status Codes:**
- `200 OK` — Successful request
- `400 Bad Request` — Validation error
- `401 Unauthorized` — Authentication required
- `403 Forbidden` — Access denied
- `404 Not Found` — Resource not found
- `500 Internal Server Error` — Server error

---

## Authentication & Security

### Session Security
- All endpoints require valid Devise session (`_session_id` cookie)
- Sessions expire after 30 days of inactivity
- CSRF protection enabled (`X-CSRF-Token` header required for state-changing requests)

### Password Tokens
- Tokens are single-use and expire after 24 hours
- Tokens are generated using Rails' secure token mechanism
- Tokens are hashed in database (plaintext never stored)

### Rate Limiting
- 100 requests per minute per broker
- Export endpoints (CSV): 10 requests per minute

---

## Examples

### cURL — List Applications

```bash
curl -X GET https://futureproof.io/broker/applications \
  -H "Cookie: _session_id=abc123" \
  -H "Content-Type: application/json"
```

### cURL — Export Commissions as CSV

```bash
curl -X GET "https://futureproof.io/broker/commissions?format=csv&period=month" \
  -H "Cookie: _session_id=abc123" \
  -o commissions_march_2026.csv
```

### JavaScript — Fetch Applications

```javascript
fetch('/broker/applications')
  .then(response => response.json())
  .then(data => {
    console.log(`Total: ${data.stats.total}`);
    console.log(`Pending: ${data.stats.pending}`);
    console.log(`Approved: ${data.stats.approved}`);
  });
```

---

## Changelog

### Version 1.0 (2026-03-10)

**Initial Release**
- ✅ Applications list & detail endpoints
- ✅ Commission tracking with period filtering
- ✅ CSV export for commissions
- ✅ Password setup & reset workflow
- ✅ Request-level caching (1-hour TTL)
- ✅ Comprehensive error handling

---

## Support

For API issues or questions:
1. Check error messages in response body
2. Review logs at `/admin/broker_logs`
3. Contact support@futureproof.io

---

**Last Updated:** 2026-03-10
**API Version:** 1.0
**Ruby Version:** 3.4.4+
**Rails Version:** 8.1.0+
