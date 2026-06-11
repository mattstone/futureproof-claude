# Legal Documents Management System

## Overview

The Legal Documents Management System provides centralized management of all legal documents across jurisdictions and party types, including:

- **Privacy Policies**
- **Terms & Conditions**
- **Customer Contracts**
- **Lender Agreements**
- **Wholesale Funder Contracts**
- **Broker Agreements**
- **Investment Provider Contracts**
- **Key Facts Sheets**
- **Disclosure Statements**
- **Risk Warning Documents**

## Key Features

### ✅ Multi-Jurisdiction Support
- **Australia (AU)** - ASIC compliance
- **United States (US)** - CCPA/state law compliance
- **New Zealand (NZ)** - Privacy Act 2020
- **United Kingdom (UK)** - UK GDPR/DPA 2018

### ✅ Party-Type Management
- **Universal** - applies to all parties
- **Customer** - specific to borrowers
- **Lender** - for wholesale funders/lenders
- **Broker** - for broker partners
- **Wholesale Funder** - for funders/capital partners
- **Investment Provider** - for portfolio managers

### ✅ Document Lifecycle
1. **Draft** - Being written, internal only
2. **In Review** - Published for admin review
3. **Approved** - Legally reviewed, ready to activate
4. **Active** - Currently in effect, customers see this version
5. **Archived** - Superseded but kept for records
6. **Retired** - End-of-life, no longer used

### ✅ Version Control
- Automatic versioning (1.0 → 1.1 → 2.0 format)
- Tracks all changes with audit trail
- Diff view to see what changed
- Effective dates for phased rollouts

### ✅ Acceptance Tracking
- Record when users/lenders accept documents
- Track acceptance by date, type (explicit/implicit/required)
- Mark documents as superseded when new versions activate
- Compliance reporting

### ✅ E-Signature Ready
- Signature capture support (electronic, wet signature, witnessed)
- Integration hooks for DocuSign, Adobe Sign
- Audit trail of signatories

### ✅ Template System
- Pre-built templates for all jurisdictions
- Variable substitution ({{variable}} format)
- Quick document generation
- Instructions for customization

## Database Schema

### LegalDocument
```
- id (primary key)
- document_type (enum: privacy_policy, terms_conditions, customer_contract, etc.)
- jurisdiction (enum: AU, US, NZ, UK)
- party_type (enum: universal, customer, lender, broker, wholesale_funder, investment_provider)
- title (string)
- content (text - markdown)
- version (string - semantic: "1.0", "1.1", "2.0")
- effective_from (datetime)
- effective_to (datetime - nullable, allows phased retirement)
- is_active (boolean - only one active per document_type/jurisdiction/party_type)
- is_draft (boolean)
- status (enum: draft, in_review, approved, active, archived, retired)
- timestamps
- indexes: lookup by type/jurisdiction/party, active status, effective dates
```

### LegalDocumentVersion (Audit Trail)
```
- id
- legal_document_id (FK)
- admin_user_id (FK)
- action (created, updated, published, approved, activated, deactivated, archived)
- change_details (text)
- previous_content (text - optional, for diffs)
- new_content (text - optional, for diffs)
- timestamps
```

### LegalDocumentAcceptance (Compliance Tracking)
```
- id
- legal_document_id (FK)
- user_id (FK - optional)
- lender_id (FK - optional)
- application_id (FK - optional)
- accepted_at (datetime)
- acceptance_type (explicit, implicit, required_for_application)
- notes (text)
- timestamps
- at least one of user/lender/application must be present
```

### LegalDocumentSignature (E-Signature)
```
- id
- legal_document_acceptance_id (FK)
- signer_name (string)
- signer_email (string)
- signature_method (electronic, wet_signature, witnessed)
- signature_provider (docusign, adobe_sign, manual)
- signature_data (text - base64 or reference)
- signed_at (datetime)
- ip_address (string)
- user_agent (string)
- timestamps
```

### LegalDocumentTemplate
```
- id
- document_type (string)
- jurisdiction (string)
- party_type (string)
- template_name (string)
- template_content (text - with {{variable}} placeholders)
- instructions (text - how to customize)
- sort_order (integer)
- is_active (boolean)
- timestamps
- unique: document_type + jurisdiction + party_type + template_name
```

## Usage Examples

### 1. Setup Jurisdiction (Admin)

```ruby
admin_user = User.where(admin: true).first
LegalDocumentService.setup_jurisdiction("AU", admin_user)
# Creates privacy policy, terms & conditions, customer contracts, lender agreements from templates
```

### 2. Create Document from Template

```ruby
template = LegalDocumentTemplate.find_for("privacy_policy", "US", "universal")
doc = template.create_document({
  abn: "51 234 567 890",
  contact_address: "Level 10, 123 Collins Street, Melbourne VIC 3000"
})

# Or use service
doc = LegalDocumentService.clone_to_jurisdiction(
  LegalDocument.current_for("privacy_policy", "AU"),
  "NZ",
  { jurisdiction_specific_text: "..." },
  admin_user
)
```

### 3. Publish & Activate

```ruby
doc.current_admin_user = admin_user
doc.publish!    # Move to in_review status
doc.approve!    # Legal team approves
doc.activate!   # Make active (deactivates other versions automatically)
```

### 4. Require User Acceptance

```ruby
# Single document
user.accept!(document, "explicit")

# Bulk accept for application
LegalDocumentService.require_documents_for_application(application, user)

# Check acceptance
user.accepted?(document)  # => true
user.acceptance_of(document)  # => acceptance record
```

### 5. Check Compliance

```ruby
# Check if all required documents are accepted
LegalDocumentService.all_required_documents_accepted?(application)  # => true/false

# Get acceptance summary
LegalDocumentService.acceptance_summary(application)
# => {
#   jurisdiction: "AU",
#   total_documents: 5,
#   accepted: [...],
#   pending: [...],
#   superseded: [...]
# }

# Check jurisdiction compliance
LegalDocumentService.jurisdiction_compliance_status("AU")
# => {
#   jurisdiction: "AU",
#   total_active: 7,
#   coverage: { privacy_policy: true, terms_conditions: true, ... },
#   compliance_score: 85.5
# }
```

### 6. Track Acceptances

```ruby
# Get all users who accepted a document
doc.legal_document_acceptances.for_user(user_id)

# Find who hasn't accepted yet (compliance gap analysis)
acceptance = user.acceptance_of(doc)
if acceptance && acceptance.document_version != doc.version
  # User accepted old version, needs to re-accept new version
end

# Signature tracking
acceptance.sign!(signature_method: "electronic", ip_address: "192.168.1.1")
acceptance.signed?  # => true
acceptance.latest_signature  # => signature record with audit info
```

### 7. Admin Dashboard

#### List & Filter
```ruby
GET /admin/legal_documents                    # All documents
GET /admin/legal_documents?jurisdiction=AU   # By jurisdiction
GET /admin/legal_documents?document_type=privacy_policy
GET /admin/legal_documents?party_type=lender
```

#### View Document
```ruby
GET /admin/legal_documents/:id
# Shows: content, versions (audit trail), acceptances, changes from previous version
```

#### Edit & Version
```ruby
PATCH /admin/legal_documents/:id
# Updates content, auto-creates version record
# Creates new semantic version (1.0 → 1.1)
```

#### Compliance Dashboard
```ruby
GET /admin/legal_documents/compliance_dashboard
# Shows: jurisdiction coverage, active documents, compliance scores
```

#### Setup Jurisdiction
```ruby
POST /admin/legal_documents/setup_jurisdiction?jurisdiction=NZ
# Creates all template-based documents for a jurisdiction
```

#### Acceptance Tracking
```ruby
GET /admin/legal_documents/acceptance_tracking?document_type=privacy_policy&jurisdiction=AU
# Shows: who accepted, when, acceptance rate, trends
```

#### Export Report
```ruby
GET /admin/legal_documents/export_compliance_report
# Returns: CSV/JSON with all jurisdiction compliance data
```

## API Endpoints

### List/Filter
```
GET /admin/legal_documents
GET /admin/legal_documents?jurisdiction=AU&document_type=privacy_policy&party_type=customer
```

### CRUD
```
GET /admin/legal_documents/new          # Form
POST /admin/legal_documents             # Create
GET /admin/legal_documents/:id          # Show
GET /admin/legal_documents/:id/edit     # Form
PATCH /admin/legal_documents/:id        # Update
```

### Actions
```
PATCH /admin/legal_documents/:id/publish      # Send to review
PATCH /admin/legal_documents/:id/approve      # Legal approval
PATCH /admin/legal_documents/:id/activate     # Make active
PATCH /admin/legal_documents/:id/archive      # Retire

GET /admin/legal_documents/compliance_dashboard
GET /admin/legal_documents/templates
POST /admin/legal_documents/setup_jurisdiction
GET /admin/legal_documents/export_compliance_report
GET /admin/legal_documents/acceptance_tracking
```

## Workflows

### Document Lifecycle
```
Draft → Publish → In Review → Approve → Activate → Archived/Retired
         (admin)  (admin)    (legal)   (admin)
```

### Customer Onboarding
```
1. Application created
2. LegalDocumentService.require_documents_for_application(app, user)
   - Marks privacy policy + terms & conditions as required
3. User sees acceptance dialog on portal
4. User clicks "I Accept"
5. LegalDocumentAcceptance.create! with acceptance_type: "explicit"
6. Check: LegalDocumentService.all_required_documents_accepted?(app)
7. If true, user can proceed; if false, show acceptance reminder
```

### Multi-Version Management
```
v1.0 Active
  ↓
Create v1.1 (minor update - rephrasing)
Publish → Approve → Activate
  ↓
v1.0 archived, v1.1 now active
Users who accepted v1.0 see "new version available"
Can track who has accepted which version
```

### Jurisdiction Rollout
```
1. AU documents active and tested
2. Clone to NZ jurisdiction:
   LegalDocumentService.clone_to_jurisdiction(au_doc, "NZ", {...}, admin)
3. Review for NZ-specific requirements
4. Publish → Approve → Activate
5. Repeat for US, UK
```

## Audit & Compliance

### Change Tracking
Every update creates a `LegalDocumentVersion` record:
```ruby
legal_document.legal_document_versions
# [
#   { action: "created", change: "Created Privacy Policy v1.0", by: "Admin 1", at: "2026-03-11 08:00" },
#   { action: "updated", change: "Content updated", by: "Admin 2", at: "2026-03-11 09:15" },
#   { action: "published", change: "Published for review", by: "Admin 1", at: "2026-03-11 10:00" },
#   { action: "approved", change: "Document approved", by: "Legal Team", at: "2026-03-11 14:00" },
#   { action: "activated", change: "Activated v1.0", by: "Admin 1", at: "2026-03-11 15:00" }
# ]
```

### Acceptance Audit Trail
```ruby
acceptance.created_at           # When user accepted
acceptance.user.name            # Who accepted
acceptance.legal_document.version  # Which version
acceptance.legal_document_signatures  # E-signature records
```

### Compliance Reports
```ruby
LegalDocumentService.jurisdiction_compliance_status("AU")
# Reports on: total active docs, coverage of all document types, compliance score

LegalDocumentService.acceptance_summary(application)
# Reports on: who has accepted what, pending acceptances, superseded versions
```

## Security & Best Practices

### ✅ Field Encryption
Content stored in PostgreSQL. Consider encryption at rest for sensitive jurisdictional variants.

### ✅ Access Control
- Only admins can create/edit documents
- Only legal team can approve
- View audit trail requires admin access
- Acceptance records are user-scoped (users can only see their own)

### ✅ Version Control
- Never delete documents (archive instead)
- Always create new version on content change
- Semantic versioning for clarity
- Effective dates allow phased rollouts

### ✅ Regulatory Compliance
- Jurisdiction-specific content management
- Audit trail for regulatory inspection
- Acceptance tracking for proof of consent
- E-signature ready for digital compliance

## Configuration

### Document Types
```ruby
LegalDocument::DOCUMENT_TYPES = {
  privacy_policy: "Privacy Policy",
  terms_conditions: "Terms & Conditions",
  customer_contract: "Customer Mortgage Contract",
  lender_contract: "Lender Agreement",
  wholesale_funder_contract: "Wholesale Funder Agreement",
  broker_contract: "Broker Agreement",
  investment_provider_contract: "Investment Provider Agreement",
  key_facts_sheet: "Key Facts Sheet",
  disclosure_statement: "Disclosure Statement",
  risk_warning: "Risk Warning Document"
}
```

### Jurisdictions
```ruby
LegalDocument::JURISDICTIONS = %w[AU US NZ UK]
```

### Party Types
```ruby
LegalDocument::PARTY_TYPES = %w[universal customer lender broker wholesale_funder investment_provider]
```

## Future Enhancements

1. **E-Signature Integration**
   - DocuSign/Adobe Sign webhook handlers
   - Automated signature requests
   - Multi-party signing workflows

2. **PDF Generation**
   - Export documents as branded PDFs
   - Watermark with version/jurisdiction
   - Include acceptance attestation

3. **Translation Management**
   - Multi-language support per jurisdiction
   - Automated translation workflows
   - Translation audit trails

4. **Smart Diff & Comparison**
   - Visual side-by-side version comparison
   - Highlight only changes (not entire document)
   - Change rationale tracking

5. **Conditional Content**
   - Show different sections based on jurisdiction/party
   - Customer-specific contract terms
   - Dynamic variable insertion

6. **Integration Points**
   - Webhook notifications on acceptance
   - CRM sync (Salesforce, HubSpot)
   - Document delivery via email
   - Slack notifications for admin actions

## Troubleshooting

### Q: When I activate a new version, the old one isn't deactivated
A: The `activate!` method should auto-deactivate others. Check if transactions are being properly committed.

### Q: Users can't see the document on the portal
A: Check:
1. Document is `is_active: true`
2. `effective_from` <= Time.current
3. `effective_to` is nil or > Time.current
4. Party type matches (universal or customer)
5. Jurisdiction matches application jurisdiction

### Q: How do I handle translation of legal documents?
A: Currently, create separate documents per language (e.g., "Privacy Policy - Australia (EN)", "Privacy Policy - Australia (FR)"). Future version will support translation management.

### Q: Can I schedule a document to become active at a future date?
A: Yes, set `effective_from` to future date and `activate!` it. The system will check `effective?` before displaying.

## Support

For questions or issues:
- Review `docs/LEGAL_DOCUMENTS_SYSTEM.md` (this file)
- Check `app/services/legal_document_service.rb` for available methods
- Review admin controller at `app/controllers/admin/legal_documents_controller.rb`
- Models: `app/models/legal_document.rb`, `legal_document_version.rb`, `legal_document_acceptance.rb`, `legal_document_template.rb`, `legal_document_signature.rb`

## Changelog

### 2026-03-11 (Initial Release)
- ✅ Legal document CRUD with versioning
- ✅ Multi-jurisdiction + party-type support
- ✅ Document lifecycle (draft → active → archived)
- ✅ Acceptance tracking with audit trail
- ✅ Template system for quick setup
- ✅ Admin dashboard + compliance reporting
- ✅ E-signature ready (stub implementation)
- ✅ Service layer for bulk operations
- ✅ All 4 jurisdictions seeded with templates (AU, US, NZ, UK)
