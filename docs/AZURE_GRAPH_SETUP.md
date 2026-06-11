# Microsoft Graph API Setup for Email Ingestion

## Overview

FutureProof uses Microsoft Graph API to read incoming support emails from
`matt.stone@futureprooffinancial.co` and create support tickets automatically.

## Azure AD App Registration

### Step 1: Register the App

1. Go to [Azure Portal](https://portal.azure.com) → Azure Active Directory → App registrations
2. Click **New registration**
3. Name: `FutureProof Email Ingestion`
4. Supported account types: **Single tenant** (this organization only)
5. Redirect URI: Leave blank (not needed for daemon/service apps)
6. Click **Register**

### Step 2: Note the IDs

From the app's Overview page, copy:
- **Application (client) ID** → this is your `client_id`
- **Directory (tenant) ID** → this is your `tenant_id`

### Step 3: Create Client Secret

1. Go to **Certificates & secrets** → **Client secrets** → **New client secret**
2. Description: `FutureProof Production`
3. Expires: 24 months (set a calendar reminder to rotate)
4. Copy the **Value** immediately — it won't be shown again → this is your `client_secret`

### Step 4: Grant API Permissions

1. Go to **API permissions** → **Add a permission** → **Microsoft Graph**
2. Choose **Application permissions** (not delegated)
3. Add these permissions:
   - `Mail.Read` — Read mail in all mailboxes
   - `Mail.ReadWrite` — Read and write mail (to mark as read)
   - `Mail.Send` — Send mail as any user (optional, for sending replies via Graph)
4. Click **Grant admin consent for [your org]** — requires Global Admin

### Step 5: Restrict to Specific Mailbox (Recommended)

By default, application permissions grant access to ALL mailboxes. To restrict to only
`matt.stone@futureprooffinancial.co`:

1. Connect to Exchange Online PowerShell:
   ```powershell
   Connect-ExchangeOnline -UserPrincipalName admin@futureprooffinancial.co
   ```

2. Create a mail-enabled security group (e.g., `FutureProof-Email-Ingestion`) and add
   `matt.stone@futureprooffinancial.co` to it.

3. Create an application access policy:
   ```powershell
   New-ApplicationAccessPolicy -AppId "<client_id>" `
     -PolicyScopeGroupId "FutureProof-Email-Ingestion" `
     -AccessRight RestrictAccess `
     -Description "Restrict to support mailbox only"
   ```

4. Test the policy:
   ```powershell
   Test-ApplicationAccessPolicy -Identity matt.stone@futureprooffinancial.co -AppId "<client_id>"
   ```

## Rails Credentials Configuration

Add to Rails credentials (`rails credentials:edit`):

```yaml
microsoft_graph:
  tenant_id: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  client_id: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  client_secret: "your-client-secret-value"
  user_email: "matt.stone@futureprooffinancial.co"
  subject_filter_prefix: "test:"
```

The `subject_filter_prefix` is set to `"test:"` during development — only emails with
subjects starting with `test:` will be processed. Remove or set to `""` when ready to
process all incoming emails.

## How It Works

1. **EmailIngestionJob** runs every 3-5 minutes (via Solid Queue)
2. **MicrosoftGraphService** authenticates via OAuth2 client credentials flow
3. Fetches unread emails matching the subject filter
4. For each email:
   - If subject contains `[FP-XXXXX]` → adds reply to existing ticket
   - If sender email matches a User → creates ticket linked to customer
   - Otherwise → creates ticket as "New Contact"
5. Email attachments are downloaded and stored via ActiveStorage
6. Email is marked as read in the mailbox

## Testing Without Azure

When `microsoft_graph.client_id` is not set in credentials, the system uses
`MockMicrosoftGraphService` which returns sample emails for development.

You can also seed test data with:
```bash
rails support:seed
```

## Security Notes

- Client secret should be rotated every 12-24 months
- Application access policy restricts access to the support mailbox only
- All Graph API calls use TLS
- Email content is stored in the database — ensure DB encryption at rest
- Attachment files are stored via ActiveStorage (configure appropriate storage service)
