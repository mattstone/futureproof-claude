class LegalDocument < ApplicationRecord
  # Rich text content (ActionText + Lexxy editor)
  has_rich_text :rich_content

  # Relationships
  has_many :legal_document_versions, dependent: :destroy
  has_many :legal_document_acceptances, dependent: :destroy
  has_many :users, through: :legal_document_acceptances
  has_many :lenders, through: :legal_document_acceptances
  has_many :applications, through: :legal_document_acceptances

  # Enums
  enum :status, {
    draft: 0,
    in_review: 1,
    approved: 2,
    active: 3,
    archived: 4,
    retired: 5
  }, prefix: true, default: :draft

  # Document types
  DOCUMENT_TYPES = {
    privacy_policy: "Privacy Policy",
    terms_of_use: "Terms of Use",
    terms_conditions: "Terms & Conditions",
    customer_contract: "Customer Mortgage Contract",
    lender_contract: "Lender Agreement",
    wholesale_funder_contract: "Wholesale Funder Agreement",
    broker_contract: "Broker Agreement",
    investment_provider_contract: "Investment Provider Agreement",
    key_facts_sheet: "Key Facts Sheet",
    disclosure_statement: "Disclosure Statement",
    risk_warning: "Risk Warning Document"
  }.freeze

  PARTY_TYPES = %w[universal customer lender broker wholesale_funder investment_provider].freeze
  JURISDICTIONS = %w[AU US NZ UK].freeze

  # Validations
  validates :document_type, presence: true, inclusion: { in: DOCUMENT_TYPES.keys.map(&:to_s) }
  validates :jurisdiction, presence: true, inclusion: { in: JURISDICTIONS }
  validates :party_type, presence: true, inclusion: { in: PARTY_TYPES }
  validates :title, presence: true
  validate :content_or_rich_content_present
  validates :version, presence: true
  validates :effective_from, presence: true
  validates :status, presence: true

  # Uniqueness constraint: only one active version per document type/jurisdiction/party
  validates :version, uniqueness: { scope: [ :document_type, :jurisdiction, :party_type ],
                                    message: "already exists for this document type, jurisdiction, and party type" }

  # Scopes
  scope :active, -> { where(is_active: true) }
  scope :draft, -> { where(is_draft: true) }
  scope :for_jurisdiction, ->(jurisdiction) { where(jurisdiction: jurisdiction) }
  scope :for_party, ->(party_type) { where(party_type: party_type) }
  scope :of_type, ->(document_type) { where(document_type: document_type) }
  scope :effective, -> {
    where("effective_from <= ?", Time.current)
      .where("effective_to IS NULL OR effective_to > ?", Time.current)
  }
  scope :by_jurisdiction, ->(jurisdiction) { for_jurisdiction(jurisdiction).order(:document_type, :party_type) }
  scope :recent, -> { order(created_at: :desc) }

  # Callbacks
  attr_accessor :current_admin_user

  before_create :set_next_version, if: :new_record?
  before_save :validate_jurisdiction_specific
  after_create :log_creation
  after_update :log_update, if: :saved_changes?
  after_save :ensure_single_active, if: :saved_change_to_is_active?

  # Class methods
  def self.current_for(document_type, jurisdiction, party_type = "universal")
    where(
      document_type: document_type,
      jurisdiction: jurisdiction,
      is_active: true
    ).where(party_type: [ party_type, "universal" ])
     .effective
     .order(party_type: :desc) # Prefer specific party_type over universal
     .first
  end

  def self.for_application(application)
    jurisdiction = application.jurisdiction

    {
      customer_contracts: current_for("customer_contract", jurisdiction),
      terms_conditions: current_for("terms_conditions", jurisdiction),
      privacy_policy: current_for("privacy_policy", jurisdiction),
      key_facts: current_for("key_facts_sheet", jurisdiction),
      disclosure: current_for("disclosure_statement", jurisdiction)
    }
  end

  def self.for_lender(lender)
    jurisdiction = lender.jurisdiction || "AU"

    {
      lender_agreement: current_for("lender_contract", jurisdiction, "lender"),
      terms_conditions: current_for("terms_conditions", jurisdiction),
      privacy_policy: current_for("privacy_policy", jurisdiction)
    }
  end

  def self.create_from_template(template, customizations = {})
    doc = new(
      document_type: template.document_type,
      jurisdiction: template.jurisdiction,
      party_type: template.party_type,
      title: customizations[:title] || template.template_name,
      content: apply_customizations(template.template_content, customizations),
      is_draft: true
    )

    doc.save!
    doc
  end

  def self.apply_customizations(template_content, customizations = {})
    content = template_content

    # Simple variable substitution: {{variable_name}} → value
    customizations.each do |key, value|
      content = content.gsub("{{#{key}}}", value.to_s)
    end

    content
  end

  # Instance methods
  def activate!
    transaction do
      # Deactivate all other versions of this document
      LegalDocument.where(
        document_type: document_type,
        jurisdiction: jurisdiction,
        party_type: party_type
      ).where.not(id: id).update_all(is_active: false)

      # Mark this as active
      update!(is_active: true, is_draft: false, status: :active, effective_from: Time.current)
    end
  end

  def archive!
    update!(is_active: false, status: :archived)
  end

  def retire!
    update!(is_active: false, status: :retired, effective_to: Time.current)
  end

  def publish!
    transaction do
      update!(is_draft: false, status: :in_review)
      log_version_action("published", "Document published for review")
    end
  end

  def approve!
    transaction do
      update!(status: :approved)
      log_version_action("approved", "Document approved for activation")
    end
  end

  # Check if document is currently effective
  def effective?
    effective_from <= Time.current && (effective_to.nil? || effective_to > Time.current)
  end

  # Get acceptance status for a specific user
  def accepted_by?(user)
    legal_document_acceptances.exists?(user: user)
  end

  def acceptance_by(user)
    legal_document_acceptances.find_by(user: user)
  end

  # Format for display
  def display_name
    "#{DOCUMENT_TYPES[document_type.to_sym] || document_type} (#{jurisdiction}) — v#{version}"
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

  def party_type_display
    party_type.titleize
  end

  def document_type_display
    DOCUMENT_TYPES[document_type.to_sym] || document_type.humanize
  end

  # Returns rendered HTML content (rich_content preferred, falls back to plain text)
  def rendered_content
    if rich_content.body.present?
      rich_content.body.to_s
    elsif content.present?
      content
    else
      ""
    end
  end

  # Version comparison
  def changes_from_previous
    previous = LegalDocument.where(
      document_type: document_type,
      jurisdiction: jurisdiction,
      party_type: party_type
    ).where("version < ?", version).order(version: :desc).first

    return nil unless previous

    {
      previous_version: previous.version,
      previous_updated: previous.updated_at,
      changes: legal_document_versions.where("created_at > ?", previous.created_at)
    }
  end

  # Bulk accept documents (for onboarding workflows)
  def self.require_acceptance_for(user, jurisdiction, party_type = "universal")
    required_types = %w[terms_conditions privacy_policy]

    docs = where(
      jurisdiction: jurisdiction,
      is_active: true
    ).where(document_type: required_types)
     .where(party_type: [ party_type, "universal" ])
     .effective

    docs.each do |doc|
      unless user.accepted?(doc)
        LegalDocumentAcceptance.create!(
          legal_document: doc,
          user: user,
          accepted_at: Time.current,
          acceptance_type: "required_for_application"
        )
      end
    end
  end

  private

  def content_or_rich_content_present
    if content.blank? && !rich_content.body.present?
      errors.add(:base, "Content is required (use the rich text editor or provide plain text)")
    end
  end

  def validate_jurisdiction_specific
    # Could add jurisdiction-specific validation here
    # E.g., required clauses for specific jurisdictions
  end

  def set_next_version
    existing_versions = LegalDocument.where(
      document_type: document_type,
      jurisdiction: jurisdiction,
      party_type: party_type
    ).pluck(:version).map { |v| Gem::Version.new(v) }

    if existing_versions.empty?
      self.version = "1.0"
    else
      latest = existing_versions.max
      major, minor = latest.release.segments[0..1]
      self.version = "#{major}.#{(minor || 0) + 1}"
    end
  end

  def log_creation
    return unless current_admin_user

    legal_document_versions.create!(
      admin_user: current_admin_user,
      action: "created",
      change_details: "Created #{document_type_display} v#{version} for #{jurisdiction}",
      new_content: content
    )
  end

  def log_update
    return unless current_admin_user || saved_changes.any?

    changes = []
    changes << "Title changed" if saved_change_to_title?
    changes << "Content updated" if saved_change_to_content?
    changes << "Status changed to #{status}" if saved_change_to_status?
    changes << "Activated" if saved_change_to_is_active? && is_active?
    changes << "Deactivated" if saved_change_to_is_active? && !is_active?

    legal_document_versions.create!(
      admin_user: current_admin_user,
      action: changes.first&.downcase&.sub(" ", "_") || "updated",
      change_details: changes.join("; "),
      previous_content: saved_changes["content"]&.first,
      new_content: saved_changes["content"]&.last
    )
  end

  def ensure_single_active
    return unless is_active?

    LegalDocument.where(
      document_type: document_type,
      jurisdiction: jurisdiction,
      party_type: party_type
    ).where.not(id: id).update_all(is_active: false)
  end

  def log_version_action(action, details)
    legal_document_versions.create!(
      admin_user: current_admin_user,
      action: action,
      change_details: details
    )
  end
end
