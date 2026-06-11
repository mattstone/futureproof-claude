class Agreement < ApplicationRecord
  has_rich_text :rich_content

  belongs_to :legal_document
  belongs_to :agreeable, polymorphic: true
  belongs_to :created_by, class_name: "User"
  has_many :agreement_signatures, dependent: :destroy

  enum :status, {
    draft: 0,
    sent: 1,
    counterparty_signed: 2,
    fully_executed: 3,
    expired: 4,
    cancelled: 5
  }, prefix: true

  validates :title, presence: true
  validates :jurisdiction, presence: true, inclusion: { in: LegalDocument::JURISDICTIONS }
  validates :agreeable_type, inclusion: { in: %w[Lender WholesaleFunder Broker] }
  validate :content_or_rich_content_present

  scope :for_party, ->(party) { where(agreeable: party) }
  scope :active, -> { where.not(status: [:cancelled, :expired]) }
  scope :pending_signature, -> { where(status: [:sent, :counterparty_signed]) }
  scope :recent, -> { order(created_at: :desc) }

  # Generate a new agreement from a LegalDocument template
  def self.generate_from_template(legal_document:, agreeable:, created_by:, customizations: {})
    content = legal_document.rendered_content

    # Apply variable substitutions
    customizations.each do |key, value|
      content = content.gsub("{{#{key}}}", value.to_s)
      content = content.gsub("[#{key}]", value.to_s)
    end

    agreement = new(
      legal_document: legal_document,
      agreeable: agreeable,
      created_by: created_by,
      title: "#{legal_document.document_type_display} — #{agreeable.name}",
      content: content,
      jurisdiction: legal_document.jurisdiction,
      version: legal_document.version,
      status: :draft
    )
    agreement.rich_content = content
    agreement
  end

  # Status transitions
  def send_for_signing!
    raise "Can only send draft agreements" unless status_draft?
    update!(status: :sent, sent_at: Time.current)
  end

  def cancel!
    raise "Cannot cancel executed agreements" if status_fully_executed?
    update!(status: :cancelled)
  end

  def record_signature!(role:, signer_name:, signer_email:, signer_title: nil, typed_signature:, ip_address: nil, user_agent: nil)
    raise "Agreement must be sent before signing" if status_draft? || status_cancelled?

    sig = agreement_signatures.create!(
      signer_role: role,
      signer_name: signer_name,
      signer_email: signer_email,
      signer_title: signer_title,
      signature_method: "typed",
      typed_signature: typed_signature,
      ip_address: ip_address,
      user_agent: user_agent,
      signed_at: Time.current
    )

    # Check if both parties have signed
    if agreement_signatures.count >= 2
      update!(status: :fully_executed, executed_at: Time.current)
    elsif role == "counterparty"
      update!(status: :counterparty_signed)
    end

    sig
  end

  def counterparty_signature
    agreement_signatures.find_by(signer_role: "counterparty")
  end

  def futureproof_signature
    agreement_signatures.find_by(signer_role: "futureproof")
  end

  def signed_by?(role)
    agreement_signatures.exists?(signer_role: role)
  end

  def signature_count
    agreement_signatures.count
  end

  def editable?
    status_draft?
  end

  def signable?
    status_sent? || status_counterparty_signed?
  end

  def party_type_label
    case agreeable_type
    when "Lender" then "Lender"
    when "WholesaleFunder" then "Wholesale Funder"
    when "Broker" then "Broker"
    else agreeable_type.titleize
    end
  end

  def rendered_content
    if rich_content.body.present?
      rich_content.body.to_s
    elsif content.present?
      content
    else
      ""
    end
  end

  private

  def content_or_rich_content_present
    if content.blank? && !rich_content.body.present?
      errors.add(:base, "Agreement content is required")
    end
  end
end
