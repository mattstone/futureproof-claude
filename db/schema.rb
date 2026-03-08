# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_03_08_170615) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "action_text_rich_texts", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "agent_actions", force: :cascade do |t|
    t.string "action_type", null: false
    t.bigint "actionable_id"
    t.string "actionable_type"
    t.bigint "ai_agent_id", null: false
    t.float "confidence"
    t.jsonb "context", default: {}
    t.datetime "created_at", null: false
    t.string "decision"
    t.string "overridden_by"
    t.text "override_reason"
    t.text "reasoning"
    t.jsonb "result", default: {}
    t.string "status", default: "completed"
    t.datetime "updated_at", null: false
    t.index ["action_type"], name: "index_agent_actions_on_action_type"
    t.index ["actionable_type", "actionable_id"], name: "index_agent_actions_on_actionable_type_and_actionable_id"
    t.index ["ai_agent_id"], name: "index_agent_actions_on_ai_agent_id"
  end

  create_table "agent_performances", force: :cascade do |t|
    t.string "agent_name", null: false
    t.string "agent_type", null: false
    t.float "avg_resolution_minutes", default: 0.0
    t.datetime "created_at", null: false
    t.string "current_task"
    t.datetime "last_active_at"
    t.jsonb "metadata", default: {}
    t.float "quality_score", default: 0.0
    t.float "satisfaction_score", default: 0.0
    t.string "status", default: "idle"
    t.integer "tasks_completed_month", default: 0
    t.integer "tasks_completed_today", default: 0
    t.integer "tasks_completed_week", default: 0
    t.datetime "updated_at", null: false
    t.index ["agent_type"], name: "index_agent_performances_on_agent_type"
    t.index ["status"], name: "index_agent_performances_on_status"
  end

  create_table "agent_tasks", force: :cascade do |t|
    t.bigint "agent_performance_id"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.string "description"
    t.jsonb "metadata", default: {}
    t.text "outcome"
    t.string "priority", default: "normal"
    t.float "resolution_minutes"
    t.datetime "started_at"
    t.string "status", default: "pending"
    t.string "task_type", null: false
    t.datetime "updated_at", null: false
    t.index ["agent_performance_id"], name: "index_agent_tasks_on_agent_performance_id"
    t.index ["completed_at"], name: "index_agent_tasks_on_completed_at"
    t.index ["status"], name: "index_agent_tasks_on_status"
    t.index ["task_type"], name: "index_agent_tasks_on_task_type"
  end

  create_table "ai_agents", force: :cascade do |t|
    t.jsonb "agent_config", default: {}
    t.string "agent_type", null: false
    t.string "avatar_filename", null: false
    t.jsonb "business_rules", default: {}
    t.jsonb "communication_style", default: {}
    t.datetime "created_at", null: false
    t.text "description"
    t.string "greeting_style"
    t.jsonb "handoff_rules", default: {}
    t.boolean "is_active", default: true
    t.jsonb "lifecycle_stages", default: []
    t.string "name", null: false
    t.string "role_title"
    t.text "specialties"
    t.datetime "updated_at", null: false
    t.index ["agent_config"], name: "index_ai_agents_on_agent_config", using: :gin
    t.index ["agent_type"], name: "index_ai_agents_on_agent_type"
    t.index ["business_rules"], name: "index_ai_agents_on_business_rules", using: :gin
    t.index ["is_active"], name: "index_ai_agents_on_is_active"
    t.index ["lifecycle_stages"], name: "index_ai_agents_on_lifecycle_stages", using: :gin
  end

  create_table "application_checklists", force: :cascade do |t|
    t.bigint "application_id", null: false
    t.boolean "completed", default: false, null: false
    t.datetime "completed_at"
    t.bigint "completed_by_id"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["application_id", "position"], name: "index_application_checklists_on_application_id_and_position"
    t.index ["application_id"], name: "index_application_checklists_on_application_id"
    t.index ["completed_by_id"], name: "index_application_checklists_on_completed_by_id"
  end

  create_table "application_documents", force: :cascade do |t|
    t.bigint "application_id", null: false
    t.datetime "created_at", null: false
    t.string "document_type", null: false
    t.datetime "expires_at"
    t.string "name"
    t.text "notes"
    t.string "rejection_reason"
    t.datetime "requested_at"
    t.string "status", default: "pending"
    t.datetime "updated_at", null: false
    t.datetime "uploaded_at"
    t.datetime "verified_at"
    t.string "verified_by"
    t.index ["application_id", "document_type"], name: "idx_on_application_id_document_type_75d76ae979"
    t.index ["application_id"], name: "index_application_documents_on_application_id"
    t.index ["status"], name: "index_application_documents_on_status"
  end

  create_table "application_messages", force: :cascade do |t|
    t.bigint "ai_agent_id"
    t.bigint "application_id", null: false
    t.text "content"
    t.datetime "created_at", null: false
    t.string "message_type"
    t.bigint "parent_message_id"
    t.datetime "read_at"
    t.bigint "sender_id", null: false
    t.string "sender_type", null: false
    t.datetime "sent_at"
    t.string "status"
    t.string "subject"
    t.datetime "updated_at", null: false
    t.index ["ai_agent_id"], name: "index_application_messages_on_ai_agent_id"
    t.index ["application_id", "status"], name: "index_application_messages_on_application_id_and_status"
    t.index ["application_id"], name: "index_application_messages_on_application_id"
    t.index ["parent_message_id"], name: "index_application_messages_on_parent_message_id"
    t.index ["sender_type", "sender_id"], name: "index_application_messages_on_sender"
    t.index ["status", "message_type"], name: "index_application_messages_on_status_and_message_type"
  end

  create_table "application_versions", force: :cascade do |t|
    t.string "action"
    t.bigint "application_id", null: false
    t.text "change_details"
    t.datetime "created_at", null: false
    t.text "new_address"
    t.integer "new_borrower_age"
    t.bigint "new_existing_mortgage_amount"
    t.bigint "new_home_value"
    t.integer "new_ownership_status"
    t.integer "new_status"
    t.text "previous_address"
    t.integer "previous_borrower_age"
    t.bigint "previous_existing_mortgage_amount"
    t.bigint "previous_home_value"
    t.integer "previous_ownership_status"
    t.integer "previous_status"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["application_id"], name: "index_application_versions_on_application_id"
    t.index ["user_id"], name: "index_application_versions_on_user_id"
  end

  create_table "applications", force: :cascade do |t|
    t.string "address"
    t.string "bank_account_number"
    t.integer "borrower_age", default: 0
    t.text "borrower_names"
    t.bigint "broker_id"
    t.string "company_name"
    t.text "corelogic_data"
    t.datetime "created_at", null: false
    t.string "credit_score"
    t.decimal "equity_investment_amount", precision: 15, scale: 2
    t.decimal "equity_percentage", precision: 5, scale: 3
    t.decimal "existing_mortgage_amount", precision: 12, scale: 2, default: "0.0"
    t.string "existing_mortgage_lender"
    t.string "government_id"
    t.decimal "growth_rate", precision: 5, scale: 2, default: "2.0"
    t.boolean "has_existing_mortgage", default: false, null: false
    t.integer "home_value"
    t.integer "income_payout_term"
    t.integer "investment_term"
    t.bigint "lender_id"
    t.bigint "mortgage_id"
    t.integer "ownership_status", default: 0, null: false
    t.integer "participation_term_years"
    t.string "property_id"
    t.text "property_images"
    t.integer "property_state", default: 0, null: false
    t.string "property_type"
    t.integer "property_valuation_high"
    t.integer "property_valuation_low"
    t.integer "property_valuation_middle"
    t.bigint "referral_partner_id"
    t.string "region", default: "US"
    t.text "rejected_reason"
    t.integer "status", default: 0, null: false
    t.string "super_fund_name"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["broker_id"], name: "index_applications_on_broker_id"
    t.index ["lender_id", "status"], name: "index_applications_on_lender_id_and_status"
    t.index ["lender_id"], name: "index_applications_on_lender_id"
    t.index ["mortgage_id", "status"], name: "index_applications_on_mortgage_id_and_status"
    t.index ["mortgage_id"], name: "index_applications_on_mortgage_id"
    t.index ["referral_partner_id"], name: "index_applications_on_referral_partner_id"
    t.index ["region"], name: "index_applications_on_region"
    t.index ["user_id", "status"], name: "index_applications_on_user_id_and_status"
    t.index ["user_id"], name: "index_applications_on_user_id"
  end

  create_table "audit_logs", force: :cascade do |t|
    t.string "action", null: false
    t.bigint "application_id"
    t.text "changes"
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.integer "kyc_verification_id"
    t.text "notes"
    t.string "reason"
    t.string "region", limit: 2
    t.string "resource_id"
    t.string "resource_type"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["action"], name: "index_audit_logs_on_action"
    t.index ["application_id"], name: "index_audit_logs_on_application_id"
    t.index ["created_at"], name: "index_audit_logs_on_created_at"
    t.index ["resource_type", "created_at"], name: "index_audit_logs_on_resource_type_and_created_at"
    t.index ["user_id", "created_at"], name: "index_audit_logs_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_audit_logs_on_user_id"
  end

  create_table "broker_lenders", force: :cascade do |t|
    t.integer "access_level"
    t.boolean "active", default: true
    t.bigint "broker_id", null: false
    t.datetime "created_at", null: false
    t.bigint "lender_id", null: false
    t.datetime "updated_at", null: false
    t.index ["broker_id", "lender_id"], name: "index_broker_lenders_on_broker_id_and_lender_id", unique: true
    t.index ["broker_id"], name: "index_broker_lenders_on_broker_id"
    t.index ["lender_id"], name: "index_broker_lenders_on_lender_id"
  end

  create_table "brokers", force: :cascade do |t|
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "name"
    t.string "phone"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_brokers_on_email", unique: true
    t.index ["reset_password_token"], name: "index_brokers_on_reset_password_token", unique: true
  end

  create_table "business_process_workflows", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.string "process_type", null: false
    t.datetime "updated_at", null: false
    t.json "workflow_data", default: {}
    t.index ["active"], name: "index_business_process_workflows_on_active"
    t.index ["process_type"], name: "index_business_process_workflows_on_process_type", unique: true
    t.check_constraint "process_type::text = ANY (ARRAY['acquisition'::character varying::text, 'conversion'::character varying::text, 'standard_operations'::character varying::text])", name: "check_process_type"
  end

  create_table "chat_agents", force: :cascade do |t|
    t.string "agent_type", null: false
    t.string "avatar_emoji", default: "🤖"
    t.jsonb "capabilities", default: {}
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.jsonb "region_support", default: ["us", "au", "nz", "uk"]
    t.string "status", default: "active"
    t.text "system_prompt"
    t.datetime "updated_at", null: false
    t.index ["agent_type"], name: "index_chat_agents_on_agent_type"
    t.index ["status"], name: "index_chat_agents_on_status"
  end

  create_table "chat_conversations", force: :cascade do |t|
    t.bigint "chat_agent_id"
    t.datetime "created_at", null: false
    t.jsonb "metadata", default: {}
    t.string "region", default: "us"
    t.string "status", default: "active"
    t.string "subject"
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["chat_agent_id"], name: "index_chat_conversations_on_chat_agent_id"
    t.index ["region"], name: "index_chat_conversations_on_region"
    t.index ["status"], name: "index_chat_conversations_on_status"
    t.index ["user_id"], name: "index_chat_conversations_on_user_id"
  end

  create_table "chat_messages", force: :cascade do |t|
    t.bigint "chat_conversation_id", null: false
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.jsonb "metadata", default: {}
    t.string "role", null: false
    t.datetime "updated_at", null: false
    t.index ["chat_conversation_id"], name: "index_chat_messages_on_chat_conversation_id"
    t.index ["role"], name: "index_chat_messages_on_role"
  end

  create_table "clause_positions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.integer "display_order", default: 0, null: false
    t.boolean "is_active", default: true, null: false
    t.string "name", null: false
    t.string "section_identifier", null: false
    t.datetime "updated_at", null: false
    t.index ["display_order"], name: "index_clause_positions_on_display_order"
    t.index ["is_active"], name: "index_clause_positions_on_is_active"
    t.index ["section_identifier"], name: "index_clause_positions_on_section_identifier", unique: true
  end

  create_table "contract_clause_usages", force: :cascade do |t|
    t.datetime "added_at", null: false
    t.bigint "added_by_id"
    t.text "clause_content_snapshot", null: false
    t.bigint "clause_position_id", null: false
    t.integer "clause_version_at_usage", null: false
    t.integer "contract_version_at_usage", null: false
    t.datetime "created_at", null: false
    t.boolean "is_active", default: true, null: false
    t.bigint "lender_clause_id", null: false
    t.bigint "mortgage_contract_id", null: false
    t.datetime "removed_at"
    t.bigint "removed_by_id"
    t.text "substituted_content"
    t.datetime "updated_at", null: false
    t.index ["added_at"], name: "index_contract_clause_usages_on_added_at"
    t.index ["added_by_id"], name: "index_contract_clause_usages_on_added_by_id"
    t.index ["clause_position_id", "is_active"], name: "idx_on_clause_position_id_is_active_4e4d8a7168"
    t.index ["clause_position_id"], name: "index_contract_clause_usages_on_clause_position_id"
    t.index ["lender_clause_id", "contract_version_at_usage"], name: "idx_on_lender_clause_id_contract_version_at_usage_76bd2e174b"
    t.index ["lender_clause_id"], name: "index_contract_clause_usages_on_lender_clause_id"
    t.index ["mortgage_contract_id", "is_active"], name: "idx_on_mortgage_contract_id_is_active_61a44de2f7"
    t.index ["mortgage_contract_id"], name: "index_contract_clause_usages_on_mortgage_contract_id"
    t.index ["removed_by_id"], name: "index_contract_clause_usages_on_removed_by_id"
  end

  create_table "contract_messages", force: :cascade do |t|
    t.bigint "ai_agent_id"
    t.text "content"
    t.bigint "contract_id", null: false
    t.datetime "created_at", null: false
    t.string "message_type"
    t.bigint "parent_message_id"
    t.datetime "read_at"
    t.bigint "sender_id", null: false
    t.string "sender_type", null: false
    t.datetime "sent_at"
    t.string "status"
    t.string "subject"
    t.datetime "updated_at", null: false
    t.index ["ai_agent_id"], name: "index_contract_messages_on_ai_agent_id"
    t.index ["contract_id", "status"], name: "index_contract_messages_on_contract_id_and_status"
    t.index ["contract_id"], name: "index_contract_messages_on_contract_id"
    t.index ["parent_message_id"], name: "index_contract_messages_on_parent_message_id"
    t.index ["sender_type", "sender_id"], name: "index_contract_messages_on_sender"
    t.index ["status", "message_type"], name: "index_contract_messages_on_status_and_message_type"
  end

  create_table "contract_versions", force: :cascade do |t|
    t.string "action"
    t.bigint "admin_user_id", null: false
    t.text "change_details"
    t.bigint "contract_id", null: false
    t.datetime "created_at", null: false
    t.integer "new_application_id"
    t.datetime "new_end_date"
    t.datetime "new_start_date"
    t.string "new_status"
    t.integer "previous_application_id"
    t.datetime "previous_end_date"
    t.datetime "previous_start_date"
    t.string "previous_status"
    t.datetime "updated_at", null: false
    t.index ["admin_user_id"], name: "index_contract_versions_on_admin_user_id"
    t.index ["contract_id"], name: "index_contract_versions_on_contract_id"
  end

  create_table "contracts", force: :cascade do |t|
    t.decimal "allocated_amount", precision: 15, scale: 2
    t.bigint "application_id", null: false
    t.decimal "cost_of_capital_rate", precision: 8, scale: 4, default: "0.0"
    t.datetime "created_at", null: false
    t.date "end_date", null: false
    t.bigint "funder_pool_id"
    t.decimal "investment_balance", precision: 12, scale: 2, default: "0.0"
    t.decimal "investment_return_rate", precision: 8, scale: 4, default: "0.0"
    t.bigint "lender_id"
    t.decimal "monthly_payment", precision: 10, scale: 2, default: "0.0"
    t.bigint "mortgage_contract_id"
    t.decimal "offset_balance", precision: 12, scale: 2, default: "0.0"
    t.date "start_date", null: false
    t.integer "status", default: 0, null: false
    t.decimal "total_payments_made", precision: 12, scale: 2, default: "0.0"
    t.datetime "updated_at", null: false
    t.index ["application_id"], name: "index_contracts_on_application_id", unique: true
    t.index ["funder_pool_id"], name: "index_contracts_on_funder_pool_id"
    t.index ["lender_id"], name: "index_contracts_on_lender_id"
    t.index ["mortgage_contract_id"], name: "index_contracts_on_mortgage_contract_id"
  end

  create_table "distributions", force: :cascade do |t|
    t.decimal "amount", precision: 15, scale: 2, null: false
    t.bigint "application_id", null: false
    t.datetime "created_at", null: false
    t.date "distribution_date", null: false
    t.datetime "failed_at"
    t.decimal "lender_margin", precision: 10, scale: 2
    t.bigint "mortgage_id"
    t.text "notes"
    t.string "payment_method"
    t.integer "payment_period_month"
    t.integer "payment_period_year"
    t.datetime "processed_at"
    t.integer "status", default: 0
    t.string "transaction_id"
    t.datetime "updated_at", null: false
    t.index ["application_id", "distribution_date"], name: "index_distributions_on_application_id_and_distribution_date"
    t.index ["application_id"], name: "index_distributions_on_application_id"
    t.index ["distribution_date"], name: "index_distributions_on_distribution_date"
    t.index ["mortgage_id"], name: "index_distributions_on_mortgage_id"
    t.index ["status"], name: "index_distributions_on_status"
  end

  create_table "email_template_versions", force: :cascade do |t|
    t.string "action"
    t.text "change_details"
    t.datetime "created_at", null: false
    t.bigint "email_template_id", null: false
    t.text "new_content"
    t.string "new_subject"
    t.text "previous_content"
    t.string "previous_subject"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["email_template_id"], name: "index_email_template_versions_on_email_template_id"
    t.index ["user_id"], name: "index_email_template_versions_on_user_id"
  end

  create_table "email_templates", force: :cascade do |t|
    t.text "content", null: false
    t.text "content_body"
    t.datetime "created_at", null: false
    t.text "description"
    t.string "email_category", default: "operational", null: false
    t.boolean "is_active", default: true, null: false
    t.string "name", null: false
    t.string "subject", null: false
    t.string "template_type", null: false
    t.datetime "updated_at", null: false
    t.index ["email_category"], name: "index_email_templates_on_email_category"
    t.index ["is_active"], name: "index_email_templates_on_is_active"
    t.index ["name"], name: "index_email_templates_on_name", unique: true
    t.index ["template_type"], name: "index_email_templates_on_template_type"
  end

  create_table "email_workflows", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "condition_type"
    t.datetime "created_at", null: false
    t.bigint "created_by_id", null: false
    t.text "description"
    t.string "name", null: false
    t.json "trigger_conditions", default: {}
    t.string "trigger_type", null: false
    t.datetime "updated_at", null: false
    t.json "workflow_builder_data"
    t.index ["created_by_id"], name: "index_email_workflows_on_created_by_id"
    t.index ["trigger_type", "active"], name: "index_email_workflows_on_trigger_type_and_active"
  end

  create_table "funder_pool_versions", force: :cascade do |t|
    t.string "action", null: false
    t.text "change_details"
    t.datetime "created_at", null: false
    t.bigint "funder_pool_id", null: false
    t.decimal "new_allocated", precision: 15, scale: 2
    t.decimal "new_amount", precision: 15, scale: 2
    t.decimal "new_benchmark_rate", precision: 5, scale: 2
    t.decimal "new_margin_rate", precision: 5, scale: 2
    t.string "new_name"
    t.decimal "previous_allocated", precision: 15, scale: 2
    t.decimal "previous_amount", precision: 15, scale: 2
    t.decimal "previous_benchmark_rate", precision: 5, scale: 2
    t.decimal "previous_margin_rate", precision: 5, scale: 2
    t.string "previous_name"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["action"], name: "index_funder_pool_versions_on_action"
    t.index ["funder_pool_id", "created_at"], name: "index_funder_pool_versions_on_funder_pool_id_and_created_at"
    t.index ["funder_pool_id"], name: "index_funder_pool_versions_on_funder_pool_id"
    t.index ["user_id"], name: "index_funder_pool_versions_on_user_id"
  end

  create_table "funder_pools", force: :cascade do |t|
    t.decimal "allocated", precision: 15, scale: 2, default: "0.0", null: false
    t.decimal "amount", precision: 15, scale: 2, default: "0.0", null: false
    t.decimal "benchmark_rate", precision: 5, scale: 2, default: "4.0"
    t.datetime "created_at", null: false
    t.decimal "margin_rate", precision: 5, scale: 2, default: "0.0"
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.bigint "wholesale_funder_id", null: false
    t.index ["name"], name: "index_funder_pools_on_name"
    t.index ["wholesale_funder_id", "name"], name: "index_funder_pools_on_wholesale_funder_id_and_name", unique: true
    t.index ["wholesale_funder_id"], name: "index_funder_pools_on_wholesale_funder_id"
  end

  create_table "investment_partners", force: :cascade do |t|
    t.decimal "aum", precision: 15, scale: 2, default: "0.0"
    t.datetime "created_at", null: false
    t.decimal "fee_rate", precision: 5, scale: 2, default: "0.0"
    t.string "licence_number", null: false
    t.string "name", null: false
    t.string "portfolio_strategy"
    t.string "region", null: false
    t.string "status", default: "active"
    t.datetime "updated_at", null: false
    t.bigint "wholesale_funder_id", null: false
    t.index ["licence_number"], name: "index_investment_partners_on_licence_number", unique: true
    t.index ["region"], name: "index_investment_partners_on_region"
    t.index ["status"], name: "index_investment_partners_on_status"
    t.index ["wholesale_funder_id"], name: "index_investment_partners_on_wholesale_funder_id"
  end

  create_table "lender_clause_versions", force: :cascade do |t|
    t.string "action", null: false
    t.text "change_details"
    t.datetime "created_at", null: false
    t.bigint "lender_clause_id", null: false
    t.text "new_content"
    t.text "previous_content"
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["action"], name: "index_lender_clause_versions_on_action"
    t.index ["lender_clause_id", "created_at"], name: "idx_on_lender_clause_id_created_at_bdf14e14bc"
    t.index ["lender_clause_id"], name: "index_lender_clause_versions_on_lender_clause_id"
    t.index ["user_id"], name: "index_lender_clause_versions_on_user_id"
  end

  create_table "lender_clauses", force: :cascade do |t|
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.bigint "created_by_id"
    t.text "description"
    t.boolean "is_active", default: false, null: false
    t.boolean "is_draft", default: true, null: false
    t.datetime "last_updated", null: false
    t.bigint "lender_id", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.integer "version", default: 1, null: false
    t.index ["created_by_id"], name: "index_lender_clauses_on_created_by_id"
    t.index ["is_active", "is_draft"], name: "index_lender_clauses_on_is_active_and_is_draft"
    t.index ["last_updated"], name: "index_lender_clauses_on_last_updated"
    t.index ["lender_id", "title"], name: "index_lender_clauses_on_lender_and_title"
    t.index ["lender_id", "version"], name: "index_lender_clauses_on_lender_id_and_version", unique: true
    t.index ["lender_id"], name: "index_lender_clauses_on_lender_id"
  end

  create_table "lender_funder_pool_versions", force: :cascade do |t|
    t.string "action"
    t.text "change_details"
    t.datetime "created_at", null: false
    t.bigint "lender_funder_pool_id", null: false
    t.boolean "new_active"
    t.boolean "previous_active"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["lender_funder_pool_id"], name: "index_lender_funder_pool_versions_on_lender_funder_pool_id"
    t.index ["user_id"], name: "index_lender_funder_pool_versions_on_user_id"
  end

  create_table "lender_funder_pools", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.bigint "funder_pool_id", null: false
    t.bigint "lender_id", null: false
    t.datetime "updated_at", null: false
    t.index ["funder_pool_id"], name: "index_lender_funder_pools_on_funder_pool_id"
    t.index ["lender_id", "funder_pool_id"], name: "index_lender_funder_pools_uniqueness", unique: true
    t.index ["lender_id"], name: "index_lender_funder_pools_on_lender_id"
  end

  create_table "lender_versions", force: :cascade do |t|
    t.string "action", null: false
    t.text "change_details"
    t.datetime "created_at", null: false
    t.bigint "lender_id", null: false
    t.string "new_contact_email"
    t.string "new_country"
    t.integer "new_lender_type"
    t.string "new_name"
    t.string "previous_contact_email"
    t.string "previous_country"
    t.integer "previous_lender_type"
    t.string "previous_name"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["action"], name: "index_lender_versions_on_action"
    t.index ["lender_id", "created_at"], name: "index_lender_versions_on_lender_id_and_created_at"
    t.index ["lender_id"], name: "index_lender_versions_on_lender_id"
    t.index ["user_id"], name: "index_lender_versions_on_user_id"
  end

  create_table "lender_wholesale_funder_versions", force: :cascade do |t|
    t.string "action"
    t.text "change_details"
    t.datetime "created_at", null: false
    t.bigint "lender_wholesale_funder_id", null: false
    t.boolean "new_active"
    t.boolean "previous_active"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["lender_wholesale_funder_id"], name: "idx_on_lender_wholesale_funder_id_1651cbe225"
    t.index ["user_id"], name: "index_lender_wholesale_funder_versions_on_user_id"
  end

  create_table "lender_wholesale_funders", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.bigint "lender_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "wholesale_funder_id", null: false
    t.index ["lender_id", "wholesale_funder_id"], name: "index_lender_wholesale_funders_uniqueness", unique: true
    t.index ["lender_id"], name: "index_lender_wholesale_funders_on_lender_id"
    t.index ["wholesale_funder_id"], name: "index_lender_wholesale_funders_on_wholesale_funder_id"
  end

  create_table "lenders", force: :cascade do |t|
    t.text "address"
    t.string "contact_email", null: false
    t.string "contact_telephone"
    t.string "contact_telephone_country_code", default: "+61"
    t.string "country", default: "Australia", null: false
    t.datetime "created_at", null: false
    t.text "custom_clause_content"
    t.integer "lender_type", null: false
    t.string "name", null: false
    t.string "postcode"
    t.datetime "updated_at", null: false
    t.index ["lender_type"], name: "index_lenders_on_lender_type"
    t.index ["name"], name: "index_lenders_on_name"
  end

  create_table "mortgage_contract_users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "mortgage_contract_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["mortgage_contract_id", "user_id"], name: "index_mortgage_contract_users_unique", unique: true
    t.index ["mortgage_contract_id"], name: "index_mortgage_contract_users_on_mortgage_contract_id"
    t.index ["user_id"], name: "index_mortgage_contract_users_on_user_id"
  end

  create_table "mortgage_contract_versions", force: :cascade do |t|
    t.string "action"
    t.text "change_details"
    t.datetime "created_at", null: false
    t.bigint "mortgage_contract_id", null: false
    t.text "new_content"
    t.text "previous_content"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["mortgage_contract_id"], name: "index_mortgage_contract_versions_on_mortgage_contract_id"
    t.index ["user_id"], name: "index_mortgage_contract_versions_on_user_id"
  end

  create_table "mortgage_contracts", force: :cascade do |t|
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.bigint "created_by_id"
    t.boolean "is_active", default: false, null: false
    t.boolean "is_draft", default: true, null: false
    t.datetime "last_updated", null: false
    t.bigint "mortgage_id"
    t.bigint "primary_user_id"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.integer "version", null: false
    t.index ["created_by_id"], name: "index_mortgage_contracts_on_created_by_id"
    t.index ["is_active"], name: "index_mortgage_contracts_on_is_active"
    t.index ["is_draft"], name: "index_mortgage_contracts_on_is_draft"
    t.index ["last_updated"], name: "index_mortgage_contracts_on_last_updated"
    t.index ["mortgage_id"], name: "index_mortgage_contracts_on_mortgage_id"
    t.index ["primary_user_id"], name: "index_mortgage_contracts_on_primary_user_id"
    t.index ["version"], name: "index_mortgage_contracts_on_version", unique: true
  end

  create_table "mortgage_lender_versions", force: :cascade do |t|
    t.string "action"
    t.text "change_details"
    t.datetime "created_at", null: false
    t.bigint "mortgage_lender_id", null: false
    t.boolean "new_active"
    t.boolean "previous_active"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["mortgage_lender_id"], name: "index_mortgage_lender_versions_on_mortgage_lender_id"
    t.index ["user_id"], name: "index_mortgage_lender_versions_on_user_id"
  end

  create_table "mortgage_lenders", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.bigint "lender_id", null: false
    t.bigint "mortgage_id", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_mortgage_lenders_on_active"
    t.index ["lender_id", "mortgage_id"], name: "index_mortgage_lenders_on_lender_id_and_mortgage_id"
    t.index ["lender_id"], name: "index_mortgage_lenders_on_lender_id"
    t.index ["mortgage_id", "lender_id"], name: "index_mortgage_lenders_on_mortgage_id_and_lender_id", unique: true
    t.index ["mortgage_id"], name: "index_mortgage_lenders_on_mortgage_id"
  end

  create_table "mortgage_versions", force: :cascade do |t|
    t.string "action"
    t.text "change_details"
    t.datetime "created_at", null: false
    t.bigint "mortgage_id", null: false
    t.decimal "new_lvr", precision: 5, scale: 2
    t.integer "new_mortgage_type"
    t.text "new_name"
    t.decimal "previous_lvr", precision: 5, scale: 2
    t.integer "previous_mortgage_type"
    t.text "previous_name"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["mortgage_id"], name: "index_mortgage_versions_on_mortgage_id"
    t.index ["user_id"], name: "index_mortgage_versions_on_user_id"
  end

  create_table "mortgages", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.decimal "lvr", precision: 5, scale: 2, default: "80.0"
    t.integer "mortgage_type"
    t.text "name"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["status"], name: "index_mortgages_on_status"
  end

  create_table "privacy_policies", force: :cascade do |t|
    t.text "content"
    t.datetime "created_at", null: false
    t.boolean "is_active"
    t.datetime "last_updated"
    t.string "title"
    t.datetime "updated_at", null: false
    t.integer "version"
  end

  create_table "privacy_policy_versions", force: :cascade do |t|
    t.string "action"
    t.text "change_details"
    t.datetime "created_at", null: false
    t.text "new_content"
    t.text "previous_content"
    t.bigint "privacy_policy_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["privacy_policy_id"], name: "index_privacy_policy_versions_on_privacy_policy_id"
    t.index ["user_id"], name: "index_privacy_policy_versions_on_user_id"
  end

  create_table "referral_partners", force: :cascade do |t|
    t.decimal "commission_rate", precision: 5, scale: 2, default: "0.0"
    t.string "company"
    t.string "contact_email"
    t.datetime "created_at", null: false
    t.bigint "lender_id", null: false
    t.string "licence_number", null: false
    t.string "name", null: false
    t.string "phone"
    t.string "region", null: false
    t.string "status", default: "active"
    t.datetime "updated_at", null: false
    t.index ["lender_id"], name: "index_referral_partners_on_lender_id"
    t.index ["licence_number"], name: "index_referral_partners_on_licence_number"
    t.index ["region"], name: "index_referral_partners_on_region"
    t.index ["status"], name: "index_referral_partners_on_status"
  end

  create_table "scheduled_workflow_jobs", force: :cascade do |t|
    t.integer "attempts", default: 0, null: false
    t.datetime "created_at", null: false
    t.bigint "execution_id", null: false
    t.text "last_error"
    t.datetime "scheduled_for", null: false
    t.string "status", default: "scheduled", null: false
    t.bigint "step_id", null: false
    t.datetime "updated_at", null: false
    t.index ["execution_id", "step_id"], name: "index_scheduled_workflow_jobs_on_execution_id_and_step_id"
    t.index ["execution_id"], name: "index_scheduled_workflow_jobs_on_execution_id"
    t.index ["scheduled_for"], name: "index_scheduled_workflow_jobs_on_scheduled_for"
    t.index ["status", "scheduled_for"], name: "index_scheduled_workflow_jobs_on_status_and_scheduled_for"
    t.index ["step_id"], name: "index_scheduled_workflow_jobs_on_step_id"
  end

  create_table "solid_cache_entries", force: :cascade do |t|
    t.integer "byte_size", null: false
    t.datetime "created_at", null: false
    t.binary "key", null: false
    t.bigint "key_hash", null: false
    t.binary "value", null: false
    t.index ["byte_size"], name: "index_solid_cache_entries_on_byte_size"
    t.index ["key_hash", "byte_size"], name: "index_solid_cache_entries_on_key_hash_and_byte_size"
    t.index ["key_hash"], name: "index_solid_cache_entries_on_key_hash", unique: true
  end

  create_table "terms_and_condition_versions", force: :cascade do |t|
    t.string "action"
    t.text "change_details"
    t.datetime "created_at", null: false
    t.text "new_content"
    t.text "previous_content"
    t.bigint "terms_and_condition_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["terms_and_condition_id"], name: "index_terms_and_condition_versions_on_terms_and_condition_id"
    t.index ["user_id"], name: "index_terms_and_condition_versions_on_user_id"
  end

  create_table "terms_and_conditions", force: :cascade do |t|
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.bigint "created_by_id"
    t.boolean "is_active", default: false, null: false
    t.datetime "last_updated", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.integer "version", null: false
    t.index ["created_by_id"], name: "index_terms_and_conditions_on_created_by_id"
    t.index ["is_active"], name: "index_terms_and_conditions_on_is_active"
    t.index ["last_updated"], name: "index_terms_and_conditions_on_last_updated"
    t.index ["version"], name: "index_terms_and_conditions_on_version", unique: true
  end

  create_table "terms_of_use_versions", force: :cascade do |t|
    t.string "action", null: false
    t.text "change_details"
    t.datetime "created_at", null: false
    t.text "new_content"
    t.text "previous_content"
    t.bigint "terms_of_use_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["terms_of_use_id", "created_at"], name: "index_terms_of_use_versions_on_terms_of_use_id_and_created_at"
    t.index ["terms_of_use_id"], name: "index_terms_of_use_versions_on_terms_of_use_id"
    t.index ["user_id"], name: "index_terms_of_use_versions_on_user_id"
  end

  create_table "terms_of_uses", force: :cascade do |t|
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.boolean "is_active", default: false, null: false
    t.datetime "last_updated", null: false
    t.text "sections"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.integer "version", default: 1, null: false
    t.index ["is_active"], name: "index_terms_of_uses_on_is_active"
    t.index ["last_updated"], name: "index_terms_of_uses_on_last_updated"
    t.index ["version"], name: "index_terms_of_uses_on_version"
  end

  create_table "user_versions", force: :cascade do |t|
    t.string "action"
    t.bigint "admin_user_id", null: false
    t.text "change_details"
    t.datetime "created_at", null: false
    t.boolean "new_admin"
    t.datetime "new_confirmed_at"
    t.string "new_country_of_residence"
    t.string "new_email"
    t.string "new_first_name"
    t.string "new_last_name"
    t.string "new_mobile_country_code"
    t.string "new_mobile_number"
    t.integer "new_terms_version"
    t.boolean "previous_admin"
    t.datetime "previous_confirmed_at"
    t.string "previous_country_of_residence"
    t.string "previous_email"
    t.string "previous_first_name"
    t.string "previous_last_name"
    t.string "previous_mobile_country_code"
    t.string "previous_mobile_number"
    t.integer "previous_terms_version"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["admin_user_id"], name: "index_user_versions_on_admin_user_id"
    t.index ["user_id"], name: "index_user_versions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.text "address"
    t.boolean "admin", default: false, null: false
    t.datetime "confirmation_sent_at"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.string "country_of_residence", default: "Australia"
    t.datetime "created_at", null: false
    t.datetime "current_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.integer "failed_attempts", default: 0, null: false
    t.string "first_name"
    t.boolean "is_test", default: false, null: false
    t.text "known_browser_signatures"
    t.text "last_browser_info"
    t.string "last_browser_signature"
    t.string "last_name"
    t.datetime "last_sign_in_at"
    t.string "last_sign_in_ip"
    t.bigint "lender_id"
    t.datetime "locked_at"
    t.string "mobile_country_code"
    t.string "mobile_number"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.integer "sign_in_count", default: 0, null: false
    t.string "sso_provider"
    t.string "sso_uid"
    t.boolean "terms_accepted", default: false, null: false
    t.integer "terms_version"
    t.string "unconfirmed_email"
    t.string "unlock_token"
    t.datetime "updated_at", null: false
    t.string "verification_code"
    t.datetime "verification_code_expires_at"
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email", "lender_id"], name: "index_users_on_email_and_lender_id", unique: true
    t.index ["is_test"], name: "index_users_on_is_test"
    t.index ["lender_id", "admin"], name: "index_users_on_lender_id_and_admin"
    t.index ["lender_id"], name: "index_users_on_lender_id"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["sso_provider", "sso_uid", "lender_id"], name: "index_users_on_sso_and_lender", unique: true
    t.index ["terms_version"], name: "index_users_on_terms_version"
    t.index ["unlock_token"], name: "index_users_on_unlock_token", unique: true
  end

  create_table "versions", force: :cascade do |t|
    t.datetime "created_at"
    t.string "event", null: false
    t.bigint "item_id", null: false
    t.string "item_type", null: false
    t.text "object"
    t.text "object_changes"
    t.string "whodunnit"
    t.index ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id"
  end

  create_table "wholesale_funder_contracts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "html_content", null: false
    t.string "jurisdiction", null: false
    t.string "party_type", null: false
    t.datetime "updated_at", null: false
    t.string "version", default: "1.0"
    t.bigint "wholesale_funder_id", null: false
    t.index ["wholesale_funder_id", "jurisdiction", "party_type"], name: "index_wf_contracts_unique", unique: true
    t.index ["wholesale_funder_id"], name: "index_wholesale_funder_contracts_on_wholesale_funder_id"
  end

  create_table "wholesale_funder_versions", force: :cascade do |t|
    t.string "action", null: false
    t.text "change_details"
    t.datetime "created_at", null: false
    t.string "new_country"
    t.string "new_currency"
    t.string "new_name"
    t.string "previous_country"
    t.string "previous_currency"
    t.string "previous_name"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.bigint "wholesale_funder_id", null: false
    t.index ["action"], name: "index_wholesale_funder_versions_on_action"
    t.index ["user_id"], name: "index_wholesale_funder_versions_on_user_id"
    t.index ["wholesale_funder_id", "created_at"], name: "idx_on_wholesale_funder_id_created_at_9a95a5b8cc"
    t.index ["wholesale_funder_id"], name: "index_wholesale_funder_versions_on_wholesale_funder_id"
  end

  create_table "wholesale_funders", force: :cascade do |t|
    t.string "country", default: "Australia", null: false
    t.datetime "created_at", null: false
    t.string "currency", default: "AUD", null: false
    t.string "name", null: false
    t.decimal "total_allocated_amount", precision: 15, scale: 2, default: "0.0", null: false
    t.datetime "updated_at", null: false
    t.index ["country"], name: "index_wholesale_funders_on_country"
    t.index ["currency"], name: "index_wholesale_funders_on_currency"
    t.index ["name"], name: "index_wholesale_funders_on_name"
  end

  create_table "workflow_execution_trackers", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "email_workflow_id", null: false
    t.datetime "executed_at", null: false
    t.boolean "run_once", default: false
    t.bigint "target_id", null: false
    t.string "target_type", null: false
    t.string "trigger_key", null: false
    t.string "trigger_type", null: false
    t.datetime "updated_at", null: false
    t.index ["email_workflow_id", "target_type", "target_id", "trigger_key"], name: "index_workflow_execution_uniqueness", unique: true
    t.index ["email_workflow_id"], name: "index_workflow_execution_trackers_on_email_workflow_id"
    t.index ["target_type", "target_id"], name: "index_workflow_execution_trackers_on_target"
    t.index ["target_type", "target_id"], name: "index_workflow_execution_trackers_on_target_type_and_target_id"
    t.index ["trigger_type", "executed_at"], name: "idx_on_trigger_type_executed_at_3e8d80a085"
  end

  create_table "workflow_executions", force: :cascade do |t|
    t.datetime "completed_at"
    t.json "context", default: {}
    t.datetime "created_at", null: false
    t.integer "current_step_position", default: 0
    t.text "last_error"
    t.datetime "started_at"
    t.string "status", default: "pending", null: false
    t.bigint "target_id", null: false
    t.string "target_type", null: false
    t.datetime "updated_at", null: false
    t.bigint "workflow_id", null: false
    t.index ["started_at"], name: "index_workflow_executions_on_started_at"
    t.index ["status"], name: "index_workflow_executions_on_status"
    t.index ["target_type", "target_id"], name: "index_workflow_executions_on_target"
    t.index ["target_type", "target_id"], name: "index_workflow_executions_on_target_type_and_target_id"
    t.index ["workflow_id", "status"], name: "index_workflow_executions_on_workflow_id_and_status"
    t.index ["workflow_id"], name: "index_workflow_executions_on_workflow_id"
  end

  create_table "workflow_step_executions", force: :cascade do |t|
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.text "error_message"
    t.bigint "execution_id", null: false
    t.json "result", default: {}
    t.datetime "started_at"
    t.string "status", default: "pending", null: false
    t.bigint "step_id", null: false
    t.datetime "updated_at", null: false
    t.index ["execution_id", "step_id"], name: "index_workflow_step_executions_on_execution_id_and_step_id", unique: true
    t.index ["execution_id"], name: "index_workflow_step_executions_on_execution_id"
    t.index ["started_at"], name: "index_workflow_step_executions_on_started_at"
    t.index ["status"], name: "index_workflow_step_executions_on_status"
    t.index ["step_id"], name: "index_workflow_step_executions_on_step_id"
  end

  create_table "workflow_steps", force: :cascade do |t|
    t.json "configuration", default: {}
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name"
    t.integer "position", null: false
    t.string "step_type", null: false
    t.datetime "updated_at", null: false
    t.bigint "workflow_id", null: false
    t.index ["step_type"], name: "index_workflow_steps_on_step_type"
    t.index ["workflow_id", "position"], name: "index_workflow_steps_on_workflow_id_and_position", unique: true
    t.index ["workflow_id"], name: "index_workflow_steps_on_workflow_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "agent_actions", "ai_agents"
  add_foreign_key "agent_tasks", "agent_performances"
  add_foreign_key "application_checklists", "applications"
  add_foreign_key "application_checklists", "users", column: "completed_by_id"
  add_foreign_key "application_documents", "applications"
  add_foreign_key "application_messages", "ai_agents"
  add_foreign_key "application_messages", "application_messages", column: "parent_message_id"
  add_foreign_key "application_messages", "applications"
  add_foreign_key "application_versions", "applications"
  add_foreign_key "application_versions", "users"
  add_foreign_key "applications", "brokers"
  add_foreign_key "applications", "lenders"
  add_foreign_key "applications", "mortgages"
  add_foreign_key "applications", "referral_partners"
  add_foreign_key "applications", "users"
  add_foreign_key "audit_logs", "applications"
  add_foreign_key "audit_logs", "users"
  add_foreign_key "broker_lenders", "brokers"
  add_foreign_key "broker_lenders", "lenders"
  add_foreign_key "chat_conversations", "chat_agents"
  add_foreign_key "chat_conversations", "users"
  add_foreign_key "chat_messages", "chat_conversations"
  add_foreign_key "contract_clause_usages", "clause_positions"
  add_foreign_key "contract_clause_usages", "lender_clauses"
  add_foreign_key "contract_clause_usages", "mortgage_contracts"
  add_foreign_key "contract_clause_usages", "users", column: "added_by_id"
  add_foreign_key "contract_clause_usages", "users", column: "removed_by_id"
  add_foreign_key "contract_messages", "ai_agents"
  add_foreign_key "contract_messages", "contract_messages", column: "parent_message_id"
  add_foreign_key "contract_messages", "contracts"
  add_foreign_key "contract_versions", "contracts"
  add_foreign_key "contract_versions", "users", column: "admin_user_id"
  add_foreign_key "contracts", "applications"
  add_foreign_key "contracts", "funder_pools"
  add_foreign_key "contracts", "lenders"
  add_foreign_key "contracts", "mortgage_contracts"
  add_foreign_key "distributions", "applications"
  add_foreign_key "distributions", "mortgages"
  add_foreign_key "email_template_versions", "email_templates"
  add_foreign_key "email_template_versions", "users"
  add_foreign_key "email_workflows", "users", column: "created_by_id"
  add_foreign_key "funder_pool_versions", "funder_pools"
  add_foreign_key "funder_pool_versions", "users"
  add_foreign_key "funder_pools", "wholesale_funders"
  add_foreign_key "investment_partners", "wholesale_funders"
  add_foreign_key "lender_clause_versions", "lender_clauses"
  add_foreign_key "lender_clause_versions", "users"
  add_foreign_key "lender_clauses", "lenders"
  add_foreign_key "lender_clauses", "users", column: "created_by_id"
  add_foreign_key "lender_funder_pool_versions", "lender_funder_pools"
  add_foreign_key "lender_funder_pool_versions", "users"
  add_foreign_key "lender_funder_pools", "funder_pools"
  add_foreign_key "lender_funder_pools", "lenders"
  add_foreign_key "lender_versions", "lenders"
  add_foreign_key "lender_versions", "users"
  add_foreign_key "lender_wholesale_funder_versions", "lender_wholesale_funders"
  add_foreign_key "lender_wholesale_funder_versions", "users"
  add_foreign_key "lender_wholesale_funders", "lenders"
  add_foreign_key "lender_wholesale_funders", "wholesale_funders"
  add_foreign_key "mortgage_contract_users", "mortgage_contracts"
  add_foreign_key "mortgage_contract_users", "users"
  add_foreign_key "mortgage_contract_versions", "mortgage_contracts"
  add_foreign_key "mortgage_contract_versions", "users"
  add_foreign_key "mortgage_contracts", "mortgages"
  add_foreign_key "mortgage_contracts", "users", column: "created_by_id"
  add_foreign_key "mortgage_contracts", "users", column: "primary_user_id"
  add_foreign_key "mortgage_lender_versions", "mortgage_lenders"
  add_foreign_key "mortgage_lender_versions", "users"
  add_foreign_key "mortgage_lenders", "lenders"
  add_foreign_key "mortgage_lenders", "mortgages"
  add_foreign_key "mortgage_versions", "mortgages"
  add_foreign_key "mortgage_versions", "users"
  add_foreign_key "privacy_policy_versions", "privacy_policies"
  add_foreign_key "privacy_policy_versions", "users"
  add_foreign_key "referral_partners", "lenders"
  add_foreign_key "scheduled_workflow_jobs", "workflow_executions", column: "execution_id"
  add_foreign_key "scheduled_workflow_jobs", "workflow_steps", column: "step_id"
  add_foreign_key "terms_and_condition_versions", "terms_and_conditions"
  add_foreign_key "terms_and_condition_versions", "users"
  add_foreign_key "terms_and_conditions", "users", column: "created_by_id"
  add_foreign_key "terms_of_use_versions", "terms_of_uses"
  add_foreign_key "terms_of_use_versions", "users"
  add_foreign_key "user_versions", "users"
  add_foreign_key "user_versions", "users", column: "admin_user_id"
  add_foreign_key "users", "lenders"
  add_foreign_key "wholesale_funder_contracts", "wholesale_funders"
  add_foreign_key "wholesale_funder_versions", "users"
  add_foreign_key "wholesale_funder_versions", "wholesale_funders"
  add_foreign_key "workflow_execution_trackers", "email_workflows"
  add_foreign_key "workflow_executions", "email_workflows", column: "workflow_id"
  add_foreign_key "workflow_step_executions", "workflow_executions", column: "execution_id"
  add_foreign_key "workflow_step_executions", "workflow_steps", column: "step_id"
  add_foreign_key "workflow_steps", "email_workflows", column: "workflow_id"
end
