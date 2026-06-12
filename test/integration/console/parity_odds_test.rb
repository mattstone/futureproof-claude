require "test_helper"

class Console::ParityOddsTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:admin_user)
  end

  # --- Service desk -----------------------------------------------------------

  test "service desk renders health, aging chart and queues" do
    get console_service_desk_path
    assert_response :success
    assert_select "[data-controller='pipeline-aging']"
    assert_select ".console-card-title", text: /Unanswered customer messages/
    assert_select ".console-card-title", text: /Stalled applications/
  end

  # --- Mortgage-lender management ----------------------------------------------

  test "mortgage lender assign, toggle, remove" do
    mortgage = mortgages(:interest_only)
    lender = Lender.status_active.where.not(id: mortgage.mortgage_lenders.select(:lender_id)).first
    assert lender, "needs an unassigned lender"

    assert_difference -> { mortgage.mortgage_lenders.count }, 1 do
      post console_mortgage_mortgage_lenders_path(mortgage), params: { lender_id: lender.id }
    end

    relationship = mortgage.mortgage_lenders.find_by(lender: lender)
    patch toggle_active_console_mortgage_mortgage_lender_path(mortgage, relationship)
    assert_not relationship.reload.active?

    assert_difference -> { mortgage.mortgage_lenders.count }, -1 do
      delete console_mortgage_mortgage_lender_path(mortgage, relationship)
    end
  end

  # --- User creation ---------------------------------------------------------------

  test "admin user creation sends set-password email and audits" do
    assert_difference -> { AuditLog.where(action: "user_created_by_admin").count }, 1 do
      assert_emails 1 do
        post console_users_path, params: {
          user: { first_name: "Manual", last_name: "User", email: "manual@example.com", country_of_residence: "Australia" }
        }
      end
    end

    user = User.find_by(email: "manual@example.com")
    assert user.confirmed_at.present?
    assert_redirected_to console_user_path(user)
  end

  # --- FAQ ordering + destroy ----------------------------------------------------------

  test "faq move down swaps positions and destroy removes" do
    faqs = Faq.where(jurisdiction: "AU").ordered.to_a
    if faqs.size < 2
      Faq.create!(jurisdiction: "AU", question: "Q-extra", answer: "A", published: true, position: (faqs.last&.position || 0) + 1)
      faqs = Faq.where(jurisdiction: "AU").ordered.to_a
    end

    first, second = faqs[0], faqs[1]
    patch move_down_console_faq_path(first)
    assert_equal second.reload.position, Faq.where(jurisdiction: "AU").ordered.first.position
    assert_equal first.id, Faq.where(jurisdiction: "AU").ordered.second.id

    assert_difference "Faq.count", -1 do
      delete console_faq_path(first)
    end
  end

  # --- Guarded destroys ------------------------------------------------------------------

  test "mortgage with applications cannot be deleted" do
    mortgage = mortgages(:interest_only)
    applications(:submitted_application).update_columns(mortgage_id: mortgage.id)

    assert_no_difference "Mortgage.count" do
      delete console_mortgage_path(mortgage)
    end
    assert_match(/can't be deleted/, flash[:alert])
  end

  test "contract destroy requires reason, audits and deallocates" do
    contract = contracts(:funding_contract)

    assert_no_difference "Contract.count" do
      delete console_contract_path(contract)
    end

    assert_difference -> { AuditLog.where(action: "contract_deleted").count }, 1 do
      assert_difference "Contract.count", -1 do
        delete console_contract_path(contract), params: { reason: "Created in error" }
      end
    end
  end

  test "allocated pools cannot be deleted" do
    pool = FunderPool.where("allocated > 0").first
    assert pool, "needs an allocated pool fixture"

    assert_no_difference "FunderPool.count" do
      delete console_wholesale_funder_funder_pool_path(pool.wholesale_funder, pool)
    end
    assert_match(/can't be deleted/, flash[:alert])
  end

  test "published mortgage contracts cannot be deleted, drafts can" do
    published = mortgage_contracts(:io_active_contract)
    assert_no_difference "MortgageContract.count" do
      delete console_mortgage_mortgage_contract_path(published.mortgage, published)
    end

    draft = mortgage_contracts(:io_draft_contract)
    assert_difference "MortgageContract.count", -1 do
      delete console_mortgage_mortgage_contract_path(draft.mortgage, draft)
    end
  end

  # --- Legal bootstrap + diagnostics probe ----------------------------------------------------

  test "legal templates page renders and bootstrap validates jurisdiction" do
    get templates_console_legal_documents_path
    assert_response :success

    post setup_jurisdiction_console_legal_documents_path, params: { jurisdiction: "XX" }
    assert_redirected_to compliance_dashboard_console_legal_documents_path
  end

  test "diagnostics property details requires an id" do
    post console_diagnostics_property_details_path
    assert_redirected_to console_diagnostics_path
    assert_match(/property ID/i, flash[:alert])
  end
end
