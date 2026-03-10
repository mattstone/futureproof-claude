class LegalDocumentSignature < ApplicationRecord
  belongs_to :legal_document_acceptance

  validates :signer_name, :signer_email, :signature_method, presence: true
  validates :signature_method, inclusion: { in: %w[electronic wet_signature witnessed] }
  validates :signature_provider, inclusion: { in: %w[docusign adobe_sign manual] }, allow_blank: true

  scope :signed, -> { where.not(signed_at: nil) }
  scope :pending, -> { where(signed_at: nil) }
  scope :by_method, ->(method) { where(signature_method: method) }
  scope :recent, -> { order(created_at: :desc) }

  def signed?
    signed_at.present?
  end

  def signature_method_display
    signature_method.humanize
  end

  def signature_provider_display
    signature_provider&.humanize || "Manual"
  end

  def signed_by
    "#{signer_name} (#{signer_email})"
  end

  def signature_age
    return "Not yet signed" unless signed_at
    
    duration = Time.current - signed_at
    case duration
    when 0..60 then "Just now"
    when 60...3600 then "#{(duration / 60).to_i} minutes ago"
    when 3600...86400 then "#{(duration / 3600).to_i} hours ago"
    else "#{(duration / 86400).to_i} days ago"
    end
  end

  # For audit trails
  def audit_summary
    {
      signer: signed_by,
      method: signature_method_display,
      provider: signature_provider_display,
      signed_at: signed_at,
      ip_address: ip_address,
      timestamp_format: signed_at&.strftime("%B %d, %Y at %I:%M %p")
    }
  end
end
