require "test_helper"

# THE verification contract for the legal consolidation: the public pages
# have no legacy fallback anymore, so an active LegalDocument must exist for
# every public document type in every jurisdiction, and signup must record
# acceptance against it.
class LegalConsolidationTest < ActionDispatch::IntegrationTest
  PUBLIC_TYPES = %w[terms_of_use privacy_policy terms_conditions].freeze

  test "an active universal document exists for every public type and jurisdiction" do
    PUBLIC_TYPES.each do |document_type|
      LegalDocument::JURISDICTIONS.each do |jurisdiction|
        document = LegalDocument.current_for(document_type, jurisdiction)
        assert document, "missing active #{document_type} for #{jurisdiction}"
        assert document.content.present? || document.rich_content&.body.present?,
               "#{document_type}/#{jurisdiction} has no content"
      end
    end
  end

  test "public legal pages render from LegalDocument per region" do
    { "privacy-policy" => "Privacy Policy", "terms-of-use" => "Terms of Use" }.each do |path, title|
      get "/#{path}", params: { region: "au" }
      assert_response :success
      assert_match "#{title} (AU)", response.body

      get "/#{path}", params: { region: "uk" }
      assert_match "#{title} (UK)", response.body
    end
  end

  test "signup records a LegalDocumentAcceptance instead of terms_version" do
    assert_difference "LegalDocumentAcceptance.count", 1 do
      post user_registration_path, params: {
        user: {
          email: "legal-test@example.com", password: "Secur3!Password", password_confirmation: "Secur3!Password",
          first_name: "Legal", last_name: "Tester", country_of_residence: "Australia",
          terms_accepted: "1", mobile_country_code: "+61", mobile_number: "400000001"
        },
        region: "au"
      }
    end

    user = User.find_by(email: "legal-test@example.com")
    assert user, "signup should have created the user"
    assert_nil user.terms_version, "terms_version is frozen legacy history and must not be written"

    acceptance = user.legal_document_acceptances.last
    assert_equal "terms_of_use", acceptance.legal_document.document_type
    assert_equal "AU", acceptance.legal_document.jurisdiction
    assert_equal "explicit", acceptance.acceptance_type
  end

  test "agreed_to_current_terms? reflects acceptances in the user's jurisdiction" do
    user = users(:regular_user) # Australia
    assert_not user.agreed_to_current_terms?

    user.legal_document_acceptances.create!(
      legal_document: legal_documents(:terms_of_use_au),
      accepted_at: Time.current,
      acceptance_type: "explicit"
    )
    assert user.agreed_to_current_terms?
  end

  test "consolidation migration is idempotent and reversible" do
    require Rails.root.join("db/migrate/20260612120000_consolidate_legal_documents.rb")

    migration = ConsolidateLegalDocuments.new
    # TermsOfUse validates version uniqueness pre-create, then a before_create
    # callback overwrites it with max+1 — pass a unique sentinel and read back.
    legacy = TermsOfUse.create!(title: "Legacy Terms", content: "<p>Old wording</p>",
                                version: 999_999, is_active: true, last_updated: 1.year.ago)
    version = legacy.version

    # Fixtures already provide ACTIVE terms_of_use docs per jurisdiction, so
    # the migration must add the legacy rows as ARCHIVED versions only.
    assert_difference -> { LegalDocument.where(document_type: "terms_of_use", version: version).count }, 4 do
      ActiveRecord::Migration.suppress_messages { migration.up }
    end
    assert_equal 0, LegalDocument.where(document_type: "terms_of_use", version: version, is_active: true).count

    # Idempotent: nothing new the second time.
    assert_no_difference -> { LegalDocument.count } do
      ActiveRecord::Migration.suppress_messages { migration.up }
    end

    # Reversible: down removes what up created and never touches legacy rows
    # or the curated fixture documents.
    assert_no_difference -> { LegalDocument.where(is_active: true).count } do
      ActiveRecord::Migration.suppress_messages { migration.down }
    end
    assert_equal 0, LegalDocument.where(document_type: "terms_of_use", version: version).count
    assert legacy.reload.persisted?, "legacy rows are never touched"
  end
end
