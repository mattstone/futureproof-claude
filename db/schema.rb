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

ActiveRecord::Schema[8.0].define(version: 2025_08_03_101203) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "applications", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "address"
    t.integer "home_value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "ownership_status", default: 0, null: false
    t.integer "property_state", default: 0, null: false
    t.boolean "has_existing_mortgage", default: false, null: false
    t.decimal "existing_mortgage_amount", precision: 12, scale: 2
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

  create_table "mortgages", force: :cascade do |t|
    t.text "name"
    t.integer "mortgage_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "lvr", precision: 5, scale: 2, default: "80.0"
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
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["terms_version"], name: "index_users_on_terms_version"
  end

  add_foreign_key "applications", "mortgages"
  add_foreign_key "applications", "users"
  add_foreign_key "privacy_policy_versions", "privacy_policies"
  add_foreign_key "privacy_policy_versions", "users"
  add_foreign_key "terms_of_use_versions", "terms_of_uses"
  add_foreign_key "terms_of_use_versions", "users"
end
