class LegalDocumentAcceptance < ApplicationRecord
  belongs_to :legal_document
  belongs_to :user, optional: true
  belongs_to :lender, optional: true
  belongs_to :application, optional: true
  has_many :legal_document_signatures, dependent: :destroy

  validates :legal_document_id, presence: true
  validates :accepted_at, presence: true
  validates :acceptance_type, presence: true, inclusion: { in: %w[explicit implicit required_for_application] }
  
  # Ensure at least one of user/lender/application is present
  validate :at_least_one_party_present

  scope :for_user, ->(user_id) { where(user_id: user_id) }
  scope :for_lender, ->(lender_id) { where(lender_id: lender_id) }
  scope :for_application, ->(application_id) { where(application_id: application_id) }
  scope :recent, -> { order(accepted_at: :desc) }
  scope :explicit, -> { where(acceptance_type: "explicit") }
  scope :for_document_type, ->(doc_type) {
    joins(:legal_document).where("legal_documents.document_type = ?", doc_type)
  }

  # Quick access to acceptance info
  def accepted_by_name
    case
    when user
      user.display_name
    when lender
      lender.name
    when application
      application.user.display_name
    else
      "Unknown"
    end
  end

  def accepted_by_email
    case
    when user
      user.email
    when lender
      lender.primary_contact_email
    when application
      application.user.email
    else
      nil
    end
  end

  def document_version
    legal_document.version
  end

  def document_title
    legal_document.title
  end

  # Check if this acceptance is still valid (document hasn't been superseded)
  def current?
    legal_document.is_active? && legal_document.effective?
  end

  # Mark as signed (after e-signature or manual signing)
  def sign!(signature_method: "electronic", signature_data: nil, ip_address: nil, user_agent: nil)
    transaction do
      legal_document_signatures.create!(
        signer_name: accepted_by_name,
        signer_email: accepted_by_email,
        signature_method: signature_method,
        signature_data: signature_data,
        ip_address: ip_address,
        user_agent: user_agent,
        signed_at: Time.current
      )
    end
  end

  def signed?
    legal_document_signatures.exists?
  end

  def latest_signature
    legal_document_signatures.order(created_at: :desc).first
  end

  private

  def at_least_one_party_present
    unless user.present? || lender.present? || application.present?
      errors.add(:base, "At least one of user, lender, or application must be present")
    end
  end
end
