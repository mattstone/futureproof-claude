# Consolidates the three legacy single-table legal models (TermsOfUse,
# PrivacyPolicy, TermsAndCondition) into LegalDocument rows per jurisdiction.
#
# - ADDITIVE ONLY: no legacy tables or rows are touched (they drop in a
#   separately-approved Phase 4c migration).
# - IDEMPOTENT: re-running skips combinations that already have rows, and
#   never overwrites curated LegalDocuments.
# - The latest active legacy row becomes the ACTIVE universal document for
#   each of the four jurisdictions; older rows become archived versions.
class ConsolidateLegalDocuments < ActiveRecord::Migration[8.1]
  JURISDICTIONS = %w[AU US NZ UK].freeze

  # Lightweight AR classes: no app-model validations/callbacks, and they use
  # the standard connection pool (visible inside test transactions).
  class MigrationLegalDocument < ActiveRecord::Base
    self.table_name = "legal_documents"
  end

  class MigrationTermsOfUse < ActiveRecord::Base
    self.table_name = "terms_of_uses"
  end

  class MigrationPrivacyPolicy < ActiveRecord::Base
    self.table_name = "privacy_policies"
  end

  class MigrationTermsAndCondition < ActiveRecord::Base
    self.table_name = "terms_and_conditions"
  end

  SOURCES = {
    MigrationTermsOfUse => "terms_of_use",
    MigrationPrivacyPolicy => "privacy_policy",
    MigrationTermsAndCondition => "terms_conditions"
  }.freeze

  def up
    SOURCES.each do |source_class, document_type|
      next unless table_exists?(source_class.table_name)

      legacy_rows = source_class.order(:version).to_a
      next if legacy_rows.empty?

      current_row = legacy_rows.select(&:is_active).max_by(&:version) || legacy_rows.max_by(&:version)

      JURISDICTIONS.each do |jurisdiction|
        # Respect any curated active document already in place for this combo.
        has_active = MigrationLegalDocument.where(
          document_type: document_type, jurisdiction: jurisdiction,
          party_type: "universal", is_active: true
        ).exists?

        legacy_rows.each do |row|
          exists = MigrationLegalDocument.where(
            document_type: document_type, jurisdiction: jurisdiction,
            party_type: "universal", version: row.version
          ).exists?
          next if exists

          is_current = !has_active && row.id == current_row.id

          MigrationLegalDocument.create!(
            document_type: document_type,
            jurisdiction: jurisdiction,
            party_type: "universal",
            title: row.title,
            content: row.content,
            version: row.version,
            # status enum: active=3, archived=4
            status: is_current ? 3 : 4,
            is_active: is_current,
            is_draft: false,
            effective_from: (row.respond_to?(:last_updated) && row.last_updated) || row.created_at || Time.current,
            created_at: row.created_at || Time.current,
            updated_at: Time.current
          )
        end
      end
    end
  end

  # Removes only rows this migration could have created: universal documents
  # of the three consolidated types whose (version, title) match a legacy row.
  def down
    SOURCES.each do |source_class, document_type|
      next unless table_exists?(source_class.table_name)

      source_class.pluck(:title, :version).each do |title, version|
        MigrationLegalDocument.where(
          document_type: document_type,
          party_type: "universal",
          jurisdiction: JURISDICTIONS,
          version: version,
          title: title
        ).delete_all
      end
    end
  end
end
