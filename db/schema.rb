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

ActiveRecord::Schema[8.0].define(version: 2025_09_08_161700) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "ai_agents", force: :cascade do |t|
    t.string "name", null: false
    t.string "agent_type", null: false
    t.text "description"
    t.string "avatar_filename", null: false
    t.boolean "is_active", default: true
    t.string "role_title"
    t.text "specialties"
    t.string "greeting_style"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["agent_type"], name: "index_ai_agents_on_agent_type"
    t.index ["is_active"], name: "index_ai_agents_on_is_active"
  end

  create_table "application_checklists", force: :cascade do |t|
    t.bigint "application_id", null: false
    t.string "name", null: false
    t.boolean "completed", default: false, null: false
    t.datetime "completed_at"
    t.bigint "completed_by_id"
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["application_id", "position"], name: "index_application_checklists_on_application_id_and_position"
    t.index ["application_id"], name: "index_application_checklists_on_application_id"
    t.index ["completed_by_id"], name: "index_application_checklists_on_completed_by_id"
  end

  create_table "application_messages", force: :cascade do |t|
    t.bigint "application_id", null: false
    t.string "sender_type", null: false
    t.bigint "sender_id", null: false
    t.string "message_type"
    t.string "subject"
    t.text "content"
    t.string "status"
    t.datetime "sent_at"
    t.datetime "read_at"
    t.bigint "parent_message_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "ai_agent_id"
    t.index ["ai_agent_id"], name: "index_application_messages_on_ai_agent_id"
    t.index ["application_id"], name: "index_application_messages_on_application_id"
    t.index ["parent_message_id"], name: "index_application_messages_on_parent_message_id"
    t.index ["sender_type", "sender_id"], name: "index_application_messages_on_sender"
  end

  create_table "application_versions", force: :cascade do |t|
    t.bigint "application_id", null: false
    t.bigint "user_id", null: false
    t.string "action"
    t.text "change_details"
    t.integer "previous_status"
    t.integer "new_status"
    t.text "previous_address"
    t.text "new_address"
    t.bigint "previous_home_value"
    t.bigint "new_home_value"
    t.bigint "previous_existing_mortgage_amount"
    t.bigint "new_existing_mortgage_amount"
    t.integer "previous_borrower_age"
    t.integer "new_borrower_age"
    t.integer "previous_ownership_status"
    t.integer "new_ownership_status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["application_id"], name: "index_application_versions_on_application_id"
    t.index ["user_id"], name: "index_application_versions_on_user_id"
  end

  create_table "applications", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "address"
    t.integer "home_value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "ownership_status", default: 0, null: false
    t.integer "property_state", default: 0, null: false
    t.boolean "has_existing_mortgage", default: false, null: false
    t.decimal "existing_mortgage_amount", precision: 12, scale: 2, default: "0.0"
    t.integer "status", default: 0, null: false
    t.text "rejected_reason"
    t.integer "borrower_age", default: 0
    t.text "borrower_names"
    t.string "company_name"
    t.string "super_fund_name"
    t.integer "loan_term"
    t.integer "income_payout_term"
    t.bigint "mortgage_id"
    t.decimal "growth_rate", precision: 5, scale: 2, default: "2.0"
    t.index ["mortgage_id"], name: "index_applications_on_mortgage_id"
    t.index ["user_id"], name: "index_applications_on_user_id"
  end

  create_table "clause_positions", force: :cascade do |t|
    t.string "name", null: false
    t.string "section_identifier", null: false
    t.text "description"
    t.integer "display_order", default: 0, null: false
    t.boolean "is_active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["display_order"], name: "index_clause_positions_on_display_order"
    t.index ["is_active"], name: "index_clause_positions_on_is_active"
    t.index ["section_identifier"], name: "index_clause_positions_on_section_identifier", unique: true
  end

  create_table "contract_clause_usages", force: :cascade do |t|
    t.bigint "mortgage_contract_id", null: false
    t.bigint "lender_clause_id", null: false
    t.bigint "clause_position_id", null: false
    t.integer "contract_version_at_usage", null: false
    t.integer "clause_version_at_usage", null: false
    t.text "clause_content_snapshot", null: false
    t.text "substituted_content"
    t.boolean "is_active", default: true, null: false
    t.datetime "added_at", null: false
    t.datetime "removed_at"
    t.bigint "added_by_id"
    t.bigint "removed_by_id"
    t.datetime "created_at", null: false
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
    t.bigint "contract_id", null: false
    t.string "sender_type", null: false
    t.bigint "sender_id", null: false
    t.string "message_type"
    t.string "subject"
    t.text "content"
    t.string "status"
    t.datetime "sent_at"
    t.datetime "read_at"
    t.bigint "parent_message_id"
    t.bigint "ai_agent_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ai_agent_id"], name: "index_contract_messages_on_ai_agent_id"
    t.index ["contract_id"], name: "index_contract_messages_on_contract_id"
    t.index ["parent_message_id"], name: "index_contract_messages_on_parent_message_id"
    t.index ["sender_type", "sender_id"], name: "index_contract_messages_on_sender"
  end

  create_table "contract_versions", force: :cascade do |t|
    t.bigint "contract_id", null: false
    t.bigint "admin_user_id", null: false
    t.string "action"
    t.text "change_details"
    t.string "previous_status"
    t.string "new_status"
    t.datetime "previous_start_date"
    t.datetime "new_start_date"
    t.datetime "previous_end_date"
    t.datetime "new_end_date"
    t.integer "previous_application_id"
    t.integer "new_application_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["admin_user_id"], name: "index_contract_versions_on_admin_user_id"
    t.index ["contract_id"], name: "index_contract_versions_on_contract_id"
  end

  create_table "contracts", force: :cascade do |t|
    t.bigint "application_id", null: false
    t.integer "status", default: 0, null: false
    t.date "start_date", null: false
    t.date "end_date", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "funder_pool_id"
    t.decimal "allocated_amount", precision: 15, scale: 2
    t.bigint "lender_id"
    t.bigint "mortgage_contract_id"
    t.index ["application_id"], name: "index_contracts_on_application_id", unique: true
    t.index ["funder_pool_id"], name: "index_contracts_on_funder_pool_id"
    t.index ["lender_id"], name: "index_contracts_on_lender_id"
    t.index ["mortgage_contract_id"], name: "index_contracts_on_mortgage_contract_id"
  end

  create_table "email_template_versions", force: :cascade do |t|
    t.bigint "email_template_id", null: false
    t.bigint "user_id", null: false
    t.string "action"
    t.text "change_details"
    t.text "previous_content"
    t.text "new_content"
    t.string "previous_subject"
    t.string "new_subject"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email_template_id"], name: "index_email_template_versions_on_email_template_id"
    t.index ["user_id"], name: "index_email_template_versions_on_user_id"
  end

  create_table "email_templates", force: :cascade do |t|
    t.string "name", null: false
    t.string "subject", null: false
    t.text "content", null: false
    t.string "template_type", null: false
    t.boolean "is_active", default: true, null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "email_category", default: "operational", null: false
    t.text "content_body"
    t.index ["email_category"], name: "index_email_templates_on_email_category"
    t.index ["is_active"], name: "index_email_templates_on_is_active"
    t.index ["name"], name: "index_email_templates_on_name", unique: true
    t.index ["template_type"], name: "index_email_templates_on_template_type"
  end

  create_table "email_workflows", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.boolean "active", default: true, null: false
    t.string "trigger_type", null: false
    t.json "trigger_conditions", default: {}
    t.bigint "created_by_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.json "workflow_builder_data"
    t.string "condition_type"
    t.index ["created_by_id"], name: "index_email_workflows_on_created_by_id"
    t.index ["trigger_type", "active"], name: "index_email_workflows_on_trigger_type_and_active"
  end

  create_table "funder_pool_versions", force: :cascade do |t|
    t.bigint "funder_pool_id", null: false
    t.bigint "user_id", null: false
    t.string "action", null: false
    t.text "change_details"
    t.string "previous_name"
    t.string "new_name"
    t.decimal "previous_amount", precision: 15, scale: 2
    t.decimal "new_amount", precision: 15, scale: 2
    t.decimal "previous_allocated", precision: 15, scale: 2
    t.decimal "new_allocated", precision: 15, scale: 2
    t.decimal "previous_benchmark_rate", precision: 5, scale: 2
    t.decimal "new_benchmark_rate", precision: 5, scale: 2
    t.decimal "previous_margin_rate", precision: 5, scale: 2
    t.decimal "new_margin_rate", precision: 5, scale: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["action"], name: "index_funder_pool_versions_on_action"
    t.index ["funder_pool_id", "created_at"], name: "index_funder_pool_versions_on_funder_pool_id_and_created_at"
    t.index ["funder_pool_id"], name: "index_funder_pool_versions_on_funder_pool_id"
    t.index ["user_id"], name: "index_funder_pool_versions_on_user_id"
  end

  create_table "funder_pools", force: :cascade do |t|
    t.bigint "wholesale_funder_id", null: false
    t.string "name", null: false
    t.decimal "amount", precision: 15, scale: 2, default: "0.0", null: false
    t.decimal "allocated", precision: 15, scale: 2, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "benchmark_rate", precision: 5, scale: 2, default: "4.0"
    t.decimal "margin_rate", precision: 5, scale: 2, default: "0.0"
    t.index ["name"], name: "index_funder_pools_on_name"
    t.index ["wholesale_funder_id", "name"], name: "index_funder_pools_on_wholesale_funder_id_and_name", unique: true
    t.index ["wholesale_funder_id"], name: "index_funder_pools_on_wholesale_funder_id"
  end

  create_table "lender_clause_versions", force: :cascade do |t|
    t.bigint "lender_clause_id", null: false
    t.bigint "user_id"
    t.string "action", null: false
    t.text "change_details"
    t.text "previous_content"
    t.text "new_content"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["action"], name: "index_lender_clause_versions_on_action"
    t.index ["lender_clause_id", "created_at"], name: "idx_on_lender_clause_id_created_at_bdf14e14bc"
    t.index ["lender_clause_id"], name: "index_lender_clause_versions_on_lender_clause_id"
    t.index ["user_id"], name: "index_lender_clause_versions_on_user_id"
  end

  create_table "lender_clauses", force: :cascade do |t|
    t.bigint "lender_id", null: false
    t.string "title", null: false
    t.text "content", null: false
    t.text "description"
    t.integer "version", default: 1, null: false
    t.boolean "is_active", default: false, null: false
    t.boolean "is_draft", default: true, null: false
    t.datetime "last_updated", null: false
    t.bigint "created_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_lender_clauses_on_created_by_id"
    t.index ["is_active", "is_draft"], name: "index_lender_clauses_on_is_active_and_is_draft"
    t.index ["last_updated"], name: "index_lender_clauses_on_last_updated"
    t.index ["lender_id", "title"], name: "index_lender_clauses_on_lender_and_title"
    t.index ["lender_id", "version"], name: "index_lender_clauses_on_lender_id_and_version", unique: true
    t.index ["lender_id"], name: "index_lender_clauses_on_lender_id"
  end

  create_table "lender_funder_pool_versions", force: :cascade do |t|
    t.bigint "lender_funder_pool_id", null: false
    t.bigint "user_id", null: false
    t.string "action"
    t.text "change_details"
    t.boolean "previous_active"
    t.boolean "new_active"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["lender_funder_pool_id"], name: "index_lender_funder_pool_versions_on_lender_funder_pool_id"
    t.index ["user_id"], name: "index_lender_funder_pool_versions_on_user_id"
  end

  create_table "lender_funder_pools", force: :cascade do |t|
    t.bigint "lender_id", null: false
    t.bigint "funder_pool_id", null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["funder_pool_id"], name: "index_lender_funder_pools_on_funder_pool_id"
    t.index ["lender_id", "funder_pool_id"], name: "index_lender_funder_pools_uniqueness", unique: true
    t.index ["lender_id"], name: "index_lender_funder_pools_on_lender_id"
  end

  create_table "lender_versions", force: :cascade do |t|
    t.bigint "lender_id", null: false
    t.bigint "user_id", null: false
    t.string "action", null: false
    t.text "change_details"
    t.string "previous_name"
    t.string "new_name"
    t.integer "previous_lender_type"
    t.integer "new_lender_type"
    t.string "previous_contact_email"
    t.string "new_contact_email"
    t.string "previous_country"
    t.string "new_country"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["action"], name: "index_lender_versions_on_action"
    t.index ["lender_id", "created_at"], name: "index_lender_versions_on_lender_id_and_created_at"
    t.index ["lender_id"], name: "index_lender_versions_on_lender_id"
    t.index ["user_id"], name: "index_lender_versions_on_user_id"
  end

  create_table "lender_wholesale_funder_versions", force: :cascade do |t|
    t.bigint "lender_wholesale_funder_id", null: false
    t.bigint "user_id", null: false
    t.string "action"
    t.text "change_details"
    t.boolean "previous_active"
    t.boolean "new_active"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["lender_wholesale_funder_id"], name: "idx_on_lender_wholesale_funder_id_1651cbe225"
    t.index ["user_id"], name: "index_lender_wholesale_funder_versions_on_user_id"
  end

  create_table "lender_wholesale_funders", force: :cascade do |t|
    t.bigint "lender_id", null: false
    t.bigint "wholesale_funder_id", null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["lender_id", "wholesale_funder_id"], name: "index_lender_wholesale_funders_uniqueness", unique: true
    t.index ["lender_id"], name: "index_lender_wholesale_funders_on_lender_id"
    t.index ["wholesale_funder_id"], name: "index_lender_wholesale_funders_on_wholesale_funder_id"
  end

  create_table "lenders", force: :cascade do |t|
    t.integer "lender_type", null: false
    t.string "name", null: false
    t.text "address"
    t.string "postcode"
    t.string "country", default: "Australia", null: false
    t.string "contact_email", null: false
    t.string "contact_telephone"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "contact_telephone_country_code", default: "+61"
    t.text "custom_clause_content"
    t.index ["lender_type"], name: "index_lenders_on_lender_type"
    t.index ["name"], name: "index_lenders_on_name"
  end

  create_table "mortgage_contract_users", force: :cascade do |t|
    t.bigint "mortgage_contract_id", null: false
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["mortgage_contract_id", "user_id"], name: "index_mortgage_contract_users_unique", unique: true
    t.index ["mortgage_contract_id"], name: "index_mortgage_contract_users_on_mortgage_contract_id"
    t.index ["user_id"], name: "index_mortgage_contract_users_on_user_id"
  end

  create_table "mortgage_contract_versions", force: :cascade do |t|
    t.bigint "mortgage_contract_id", null: false
    t.bigint "user_id", null: false
    t.string "action"
    t.text "change_details"
    t.text "previous_content"
    t.text "new_content"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["mortgage_contract_id"], name: "index_mortgage_contract_versions_on_mortgage_contract_id"
    t.index ["user_id"], name: "index_mortgage_contract_versions_on_user_id"
  end

  create_table "mortgage_contracts", force: :cascade do |t|
    t.string "title", null: false
    t.text "content", null: false
    t.integer "version", null: false
    t.datetime "last_updated", null: false
    t.boolean "is_active", default: false, null: false
    t.boolean "is_draft", default: true, null: false
    t.bigint "created_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "mortgage_id"
    t.bigint "primary_user_id"
    t.index ["created_by_id"], name: "index_mortgage_contracts_on_created_by_id"
    t.index ["is_active"], name: "index_mortgage_contracts_on_is_active"
    t.index ["is_draft"], name: "index_mortgage_contracts_on_is_draft"
    t.index ["last_updated"], name: "index_mortgage_contracts_on_last_updated"
    t.index ["mortgage_id"], name: "index_mortgage_contracts_on_mortgage_id"
    t.index ["primary_user_id"], name: "index_mortgage_contracts_on_primary_user_id"
    t.index ["version"], name: "index_mortgage_contracts_on_version", unique: true
  end

  create_table "mortgage_lender_versions", force: :cascade do |t|
    t.bigint "mortgage_lender_id", null: false
    t.bigint "user_id", null: false
    t.string "action"
    t.text "change_details"
    t.boolean "previous_active"
    t.boolean "new_active"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["mortgage_lender_id"], name: "index_mortgage_lender_versions_on_mortgage_lender_id"
    t.index ["user_id"], name: "index_mortgage_lender_versions_on_user_id"
  end

  create_table "mortgage_lenders", force: :cascade do |t|
    t.bigint "mortgage_id", null: false
    t.bigint "lender_id", null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_mortgage_lenders_on_active"
    t.index ["lender_id", "mortgage_id"], name: "index_mortgage_lenders_on_lender_id_and_mortgage_id"
    t.index ["lender_id"], name: "index_mortgage_lenders_on_lender_id"
    t.index ["mortgage_id", "lender_id"], name: "index_mortgage_lenders_on_mortgage_id_and_lender_id", unique: true
    t.index ["mortgage_id"], name: "index_mortgage_lenders_on_mortgage_id"
  end

  create_table "mortgage_versions", force: :cascade do |t|
    t.bigint "mortgage_id", null: false
    t.bigint "user_id", null: false
    t.string "action"
    t.text "change_details"
    t.text "previous_name"
    t.text "new_name"
    t.integer "previous_mortgage_type"
    t.integer "new_mortgage_type"
    t.decimal "previous_lvr", precision: 5, scale: 2
    t.decimal "new_lvr", precision: 5, scale: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["mortgage_id"], name: "index_mortgage_versions_on_mortgage_id"
    t.index ["user_id"], name: "index_mortgage_versions_on_user_id"
  end

  create_table "mortgages", force: :cascade do |t|
    t.text "name"
    t.integer "mortgage_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "lvr", precision: 5, scale: 2, default: "80.0"
    t.integer "status", default: 0, null: false
    t.index ["status"], name: "index_mortgages_on_status"
  end

  create_table "privacy_policies", force: :cascade do |t|
    t.string "title"
    t.text "content"
    t.datetime "last_updated"
    t.boolean "is_active"
    t.integer "version"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "privacy_policy_versions", force: :cascade do |t|
    t.bigint "privacy_policy_id", null: false
    t.bigint "user_id", null: false
    t.string "action"
    t.text "change_details"
    t.text "previous_content"
    t.text "new_content"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["privacy_policy_id"], name: "index_privacy_policy_versions_on_privacy_policy_id"
    t.index ["user_id"], name: "index_privacy_policy_versions_on_user_id"
  end

  create_table "scheduled_workflow_jobs", force: :cascade do |t|
    t.bigint "execution_id", null: false
    t.bigint "step_id", null: false
    t.datetime "scheduled_for", null: false
    t.integer "attempts", default: 0, null: false
    t.text "last_error"
    t.string "status", default: "scheduled", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["execution_id", "step_id"], name: "index_scheduled_workflow_jobs_on_execution_id_and_step_id"
    t.index ["execution_id"], name: "index_scheduled_workflow_jobs_on_execution_id"
    t.index ["scheduled_for"], name: "index_scheduled_workflow_jobs_on_scheduled_for"
    t.index ["status", "scheduled_for"], name: "index_scheduled_workflow_jobs_on_status_and_scheduled_for"
    t.index ["step_id"], name: "index_scheduled_workflow_jobs_on_step_id"
  end

  create_table "terms_and_condition_versions", force: :cascade do |t|
    t.bigint "terms_and_condition_id", null: false
    t.bigint "user_id", null: false
    t.string "action"
    t.text "change_details"
    t.text "previous_content"
    t.text "new_content"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["terms_and_condition_id"], name: "index_terms_and_condition_versions_on_terms_and_condition_id"
    t.index ["user_id"], name: "index_terms_and_condition_versions_on_user_id"
  end

  create_table "terms_and_conditions", force: :cascade do |t|
    t.string "title", null: false
    t.text "content", null: false
    t.integer "version", null: false
    t.datetime "last_updated", null: false
    t.boolean "is_active", default: false, null: false
    t.bigint "created_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_terms_and_conditions_on_created_by_id"
    t.index ["is_active"], name: "index_terms_and_conditions_on_is_active"
    t.index ["last_updated"], name: "index_terms_and_conditions_on_last_updated"
    t.index ["version"], name: "index_terms_and_conditions_on_version", unique: true
  end

  create_table "terms_of_use_versions", force: :cascade do |t|
    t.bigint "terms_of_use_id", null: false
    t.bigint "user_id", null: false
    t.string "action", null: false
    t.text "change_details"
    t.text "previous_content"
    t.text "new_content"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["terms_of_use_id", "created_at"], name: "index_terms_of_use_versions_on_terms_of_use_id_and_created_at"
    t.index ["terms_of_use_id"], name: "index_terms_of_use_versions_on_terms_of_use_id"
    t.index ["user_id"], name: "index_terms_of_use_versions_on_user_id"
  end

  create_table "terms_of_uses", force: :cascade do |t|
    t.string "title", null: false
    t.text "content", null: false
    t.datetime "last_updated", null: false
    t.boolean "is_active", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "sections"
    t.integer "version", default: 1, null: false
    t.index ["is_active"], name: "index_terms_of_uses_on_is_active"
    t.index ["last_updated"], name: "index_terms_of_uses_on_last_updated"
    t.index ["version"], name: "index_terms_of_uses_on_version"
  end

  create_table "user_versions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "admin_user_id", null: false
    t.string "action"
    t.text "change_details"
    t.string "previous_first_name"
    t.string "new_first_name"
    t.string "previous_last_name"
    t.string "new_last_name"
    t.string "previous_email"
    t.string "new_email"
    t.boolean "previous_admin"
    t.boolean "new_admin"
    t.string "previous_country_of_residence"
    t.string "new_country_of_residence"
    t.string "previous_mobile_number"
    t.string "new_mobile_number"
    t.string "previous_mobile_country_code"
    t.string "new_mobile_country_code"
    t.integer "previous_terms_version"
    t.integer "new_terms_version"
    t.datetime "previous_confirmed_at"
    t.datetime "new_confirmed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["admin_user_id"], name: "index_user_versions_on_admin_user_id"
    t.index ["user_id"], name: "index_user_versions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "unconfirmed_email"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "first_name"
    t.string "last_name"
    t.string "country_of_residence", default: "Australia"
    t.boolean "admin", default: false, null: false
    t.string "verification_code"
    t.datetime "verification_code_expires_at"
    t.text "known_browser_signatures"
    t.string "last_browser_signature"
    t.text "last_browser_info"
    t.string "mobile_country_code"
    t.string "mobile_number"
    t.boolean "terms_accepted", default: false, null: false
    t.integer "terms_version"
    t.bigint "lender_id", null: false
    t.text "address"
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email", "lender_id"], name: "index_users_on_email_and_lender_id", unique: true
    t.index ["lender_id"], name: "index_users_on_lender_id"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["terms_version"], name: "index_users_on_terms_version"
  end

  create_table "versions", force: :cascade do |t|
    t.string "whodunnit"
    t.datetime "created_at"
    t.bigint "item_id", null: false
    t.string "item_type", null: false
    t.string "event", null: false
    t.text "object"
    t.text "object_changes"
    t.index ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id"
  end

  create_table "wholesale_funder_versions", force: :cascade do |t|
    t.bigint "wholesale_funder_id", null: false
    t.bigint "user_id", null: false
    t.string "action", null: false
    t.text "change_details"
    t.string "previous_name"
    t.string "new_name"
    t.string "previous_country"
    t.string "new_country"
    t.string "previous_currency"
    t.string "new_currency"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["action"], name: "index_wholesale_funder_versions_on_action"
    t.index ["user_id"], name: "index_wholesale_funder_versions_on_user_id"
    t.index ["wholesale_funder_id", "created_at"], name: "idx_on_wholesale_funder_id_created_at_9a95a5b8cc"
    t.index ["wholesale_funder_id"], name: "index_wholesale_funder_versions_on_wholesale_funder_id"
  end

  create_table "wholesale_funders", force: :cascade do |t|
    t.string "name", null: false
    t.string "country", default: "Australia", null: false
    t.string "currency", default: "AUD", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["country"], name: "index_wholesale_funders_on_country"
    t.index ["currency"], name: "index_wholesale_funders_on_currency"
    t.index ["name"], name: "index_wholesale_funders_on_name"
  end

  create_table "workflow_execution_trackers", force: :cascade do |t|
    t.bigint "email_workflow_id", null: false
    t.string "target_type", null: false
    t.bigint "target_id", null: false
    t.string "trigger_type", null: false
    t.string "trigger_key", null: false
    t.datetime "executed_at", null: false
    t.boolean "run_once", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email_workflow_id", "target_type", "target_id", "trigger_key"], name: "index_workflow_execution_uniqueness", unique: true
    t.index ["email_workflow_id"], name: "index_workflow_execution_trackers_on_email_workflow_id"
    t.index ["target_type", "target_id"], name: "index_workflow_execution_trackers_on_target"
    t.index ["target_type", "target_id"], name: "index_workflow_execution_trackers_on_target_type_and_target_id"
    t.index ["trigger_type", "executed_at"], name: "idx_on_trigger_type_executed_at_3e8d80a085"
  end

  create_table "workflow_executions", force: :cascade do |t|
    t.bigint "workflow_id", null: false
    t.string "target_type", null: false
    t.bigint "target_id", null: false
    t.string "status", default: "pending", null: false
    t.datetime "started_at"
    t.datetime "completed_at"
    t.integer "current_step_position", default: 0
    t.json "context", default: {}
    t.text "last_error"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["started_at"], name: "index_workflow_executions_on_started_at"
    t.index ["status"], name: "index_workflow_executions_on_status"
    t.index ["target_type", "target_id"], name: "index_workflow_executions_on_target"
    t.index ["target_type", "target_id"], name: "index_workflow_executions_on_target_type_and_target_id"
    t.index ["workflow_id", "status"], name: "index_workflow_executions_on_workflow_id_and_status"
    t.index ["workflow_id"], name: "index_workflow_executions_on_workflow_id"
  end

  create_table "workflow_step_executions", force: :cascade do |t|
    t.bigint "execution_id", null: false
    t.bigint "step_id", null: false
    t.string "status", default: "pending", null: false
    t.datetime "started_at"
    t.datetime "completed_at"
    t.json "result", default: {}
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["execution_id", "step_id"], name: "index_workflow_step_executions_on_execution_id_and_step_id", unique: true
    t.index ["execution_id"], name: "index_workflow_step_executions_on_execution_id"
    t.index ["started_at"], name: "index_workflow_step_executions_on_started_at"
    t.index ["status"], name: "index_workflow_step_executions_on_status"
    t.index ["step_id"], name: "index_workflow_step_executions_on_step_id"
  end

  create_table "workflow_steps", force: :cascade do |t|
    t.bigint "workflow_id", null: false
    t.string "step_type", null: false
    t.integer "position", null: false
    t.json "configuration", default: {}
    t.string "name"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["step_type"], name: "index_workflow_steps_on_step_type"
    t.index ["workflow_id", "position"], name: "index_workflow_steps_on_workflow_id_and_position", unique: true
    t.index ["workflow_id"], name: "index_workflow_steps_on_workflow_id"
  end

  add_foreign_key "application_checklists", "applications"
  add_foreign_key "application_checklists", "users", column: "completed_by_id"
  add_foreign_key "application_messages", "ai_agents"
  add_foreign_key "application_messages", "application_messages", column: "parent_message_id"
  add_foreign_key "application_messages", "applications"
  add_foreign_key "application_versions", "applications"
  add_foreign_key "application_versions", "users"
  add_foreign_key "applications", "mortgages"
  add_foreign_key "applications", "users"
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
  add_foreign_key "email_template_versions", "email_templates"
  add_foreign_key "email_template_versions", "users"
  add_foreign_key "email_workflows", "users", column: "created_by_id"
  add_foreign_key "funder_pool_versions", "funder_pools"
  add_foreign_key "funder_pool_versions", "users"
  add_foreign_key "funder_pools", "wholesale_funders"
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
  add_foreign_key "wholesale_funder_versions", "users"
  add_foreign_key "wholesale_funder_versions", "wholesale_funders"
  add_foreign_key "workflow_execution_trackers", "email_workflows"
  add_foreign_key "workflow_executions", "email_workflows", column: "workflow_id"
  add_foreign_key "workflow_step_executions", "workflow_executions", column: "execution_id"
  add_foreign_key "workflow_step_executions", "workflow_steps", column: "step_id"
  add_foreign_key "workflow_steps", "email_workflows", column: "workflow_id"
end
