class LegalDocumentTemplate < ApplicationRecord
  validates :document_type, :jurisdiction, :party_type, :template_name, :template_content, presence: true

  scope :active, -> { where(is_active: true) }
  scope :for_type, ->(doc_type) { where(document_type: doc_type) }
  scope :for_jurisdiction, ->(jurisdiction) { where(jurisdiction: jurisdiction) }
  scope :for_party, ->(party_type) { where(party_type: party_type) }
  scope :ordered, -> { order(:sort_order, :template_name) }

  DOCUMENT_TYPES = LegalDocument::DOCUMENT_TYPES.freeze
  JURISDICTIONS = LegalDocument::JURISDICTIONS.freeze
  PARTY_TYPES = LegalDocument::PARTY_TYPES.freeze

  def self.find_for(document_type, jurisdiction, party_type)
    where(
      document_type: document_type,
      jurisdiction: jurisdiction,
      party_type: party_type,
      is_active: true
    ).ordered.first
  end

  def self.available_for(jurisdiction)
    where(jurisdiction: jurisdiction, is_active: true)
      .group_by(&:document_type)
      .transform_values { |templates| templates.sort_by(&:sort_order) }
  end

  def create_document(customizations = {})
    LegalDocument.create_from_template(self, customizations)
  end

  def document_type_display
    DOCUMENT_TYPES[document_type.to_sym] || document_type.humanize
  end

  def jurisdiction_name
    case jurisdiction
    when "AU" then "Australia"
    when "US" then "United States"
    when "NZ" then "New Zealand"
    when "UK" then "United Kingdom"
    else jurisdiction
    end
  end

  def display_name
    "#{template_name} (#{jurisdiction_name} - #{party_type.titleize})"
  end

  # List variables in template that can be customized
  def available_variables
    template_content.scan(/\{\{(\w+)\}\}/).flatten.uniq
  end
end
