# Console parity map — every legacy admin action, accounted for

Generated against the live route sets (286 admin actions). Every admin
controller action is listed with its disposition. This is the "no more
content missing" contract: anything marked **CUT** is a deliberate decision
the CTO can reverse; everything else exists in the Console today.

Dispositions:
- **CARRIED** — same capability at the listed console location (often renamed).
- **REPLACED** — capability redesigned; the new mechanism is listed.
- **CUT** — deliberately not carried, with the reason. Reversible on request.

| Legacy admin | Disposition | Console location / reason |
|---|---|---|
| `agent_dashboard#index/show/timeline` | CARRIED | `console/ai_agents` index + show (roster, performance, recent actions). NB: legacy show/timeline were template-only pages — their controller actions never existed. |
| `agent_dashboard#override` | CARRIED | `console/agent_actions#override` (reason required, audited) |
| `agent_lifecycle#*` (8 actions) | CARRIED | `console/ai_agents` show + edit_stage/update_stage/delete_stage — same JSON storage, one clean stage form |
| `agreements#destroy` | CUT | Agreements are legal instruments; `cancel` (audited, state-preserving) is the supported end state |
| `application_documents#index` | REPLACED | Documents tab on the application cockpit |
| `application_documents#create/destroy` | CUT | Admin-side upload/delete of customer documents removed — customers upload; admins verify/reject/auto-verify/request-all (all carried) |
| `applications#new/create` | CUT | Applications are created by customers (or seeds); the legacy form bypassed quote/validation flows |
| `applications#edit/update` | REPLACED | Status edits → Decision panel (approve!/reject with terms); valuation edits → audited valuation form on the cockpit |
| `applications#search` (POST) | REPLACED | DSL index search (GET, shareable URLs) |
| `applications#destroy` | CUT | Applications are regulatory records; rejection is the terminal state |
| `broker_commission_rates#index/show` | REPLACED | Rates listed and managed on the lender page (their parent); the money ledger is `console/broker_commissions` |
| `broker_commission_rates#destroy` | CUT | Rates carry payment history; deactivate (carried) preserves it |
| `broker_lenders#toggle_active` | CARRIED | `console/brokers#toggle_lender` |
| `broker_lenders#add/remove/available` | CARRIED | Assign/remove on the broker page (`assign_lender`/`remove_lender`) |
| `brokers#destroy` | CUT | Brokers have commission/referral history; deactivate (carried) is the offboarding path |
| `business_process_workflows#*` (10) | CUT | **CTO-approved cut list** — EmailWorkflow is the canonical automation system |
| `workflow_forms#*` (7) | CUT | **CTO-approved cut list** — same |
| `contract_clauses#available_clauses` | REPLACED | Server-rendered clause picker on the mortgage-contract page (no AJAX endpoint needed) |
| `contracts#search` (POST) | REPLACED | DSL index search (GET) |
| `core_logic_test#index/search/property_details` | CARRIED | `console/diagnostics` (search + property-details probes) |
| `core_logic_test#autocomplete` | CUT | JSON endpoint that only fed the legacy test page's autocomplete; the search probe covers the diagnostic need |
| `customer_service#index` | CARRIED | `console/service_desk` (health, pipeline aging, unanswered, stalled, escalations, tickets) |
| `dashboard#index` | CARRIED | `console/analytics` (same nine datasets via `Console::AnalyticsPresenter`); signals live on Today |
| `email_templates#test_email` | REPLACED | `send_test` (single, safer path through AdminMailer) |
| `email_templates#preview_ajax` | CUT | Live-preview-while-typing endpoint; the full preview page (carried) renders the real mailer layout |
| `email_workflows#preview` | CUT | The show page lists steps/conditions/executions — the preview page duplicated it |
| `email_workflows#add_step/node_properties/email_templates_content` | REPLACED | One `console--workflow-builder` Stimulus + server-rendered form (replaced 4 glue JS files) |
| `email_workflows#bulk_create` | CUT | Template library creates one-at-a-time with review; bulk-create encouraged unreviewed automations |
| `faqs#reorder` | REPLACED | CSP-safe up/down position swaps |
| `legal_documents#export_compliance_report` | REPLACED | CSV export on the compliance dashboard (same data, one page) |
| `legal_documents#destroy` | CUT | Legal documents are versioned records; archive (carried) is the end state |
| `lender_clauses#new/create/destroy` | REPLACED | Singleton clause edit on the lender page (blank = no clause) |
| `lender_funder_pools#*` / `lender_wholesale_funders#*` | REPLACED | Inline add/toggle/remove on the lender page (plain form posts; the legacy turbo-stream plumbing and its 4 stream templates per action are gone) |
| `lenders#available_wholesale_funders` | REPLACED | Server-rendered picker on the lender page |
| `lenders#destroy` | CUT | Lenders anchor contracts/users; **suspend** (new, audited) is the offboarding path |
| `mortgage_contracts#index` | REPLACED | Versions listed on the mortgage page (drafts + published) |
| `mortgage_contracts#preview` | CUT | The show page renders the document content |
| `mortgage_lenders#*` | CARRIED | Assign/toggle/remove on the mortgage page |
| `privacy_policies#*` / `terms_of_uses#*` / `terms_and_conditions#*` (24) | REPLACED | **Consolidated into LegalDocuments** (Phase 3c migration); public pages read LegalDocument only |
| `users#destroy` | CUT | Users anchor applications/acceptances; lock (carried) is the containment path |
| `wholesale_funder_contracts#*` (6) | REPLACED | Read-only legacy funding documents on the funder page; new funding agreements use the Agreement signature lifecycle |
| `wholesale_funders#search` (POST) | REPLACED | DSL index search (GET) |
| `wholesale_funders#by_jurisdiction` | CUT | JSON endpoint for a legacy dashboard widget; the index has country/currency filters + global stats |
| `wholesale_funders#destroy` | CUT | **Suspend** (new, audited) is the offboarding path |

## Console capabilities with no legacy equivalent
Partner onboarding checklists · agreements wired to partners · lender admin
invitations · partner suspend/reactivate · pool top-ups (audited) · facility
headroom · broker commissions ledger + pay runs · KYC/AML decisioning ·
contract servicing transitions · income-payments ledger · jurisdictional
legal register with bootstrap · route-crawling smoke tests + console:lint.
