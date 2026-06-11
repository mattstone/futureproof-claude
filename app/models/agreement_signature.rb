class AgreementSignature < ApplicationRecord
  belongs_to :agreement

  ROLES = %w[futureproof counterparty].freeze

  validates :signer_role, presence: true, inclusion: { in: ROLES }
  validates :signer_name, presence: true
  validates :signer_email, presence: true
  validates :typed_signature, presence: true
  validates :signed_at, presence: true
  validates :signer_role, uniqueness: { scope: :agreement_id, message: "has already signed this agreement" }

  def role_label
    signer_role == "futureproof" ? "FutureProof Financial" : agreement.party_type_label
  end

  def audit_summary
    "#{signer_name} (#{signer_email}) signed as #{role_label} on #{signed_at.strftime('%d %b %Y at %H:%M')} from #{ip_address || 'unknown IP'}"
  end
end
