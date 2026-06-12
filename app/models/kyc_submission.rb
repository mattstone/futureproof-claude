class KycSubmission < ApplicationRecord
  belongs_to :application

  # Status enum: pending, submitted, verified, rejected
  enum :status, {
    pending: 0,
    submitted: 1,
    verified: 2,
    rejected: 3
  }

  # Validations
  validates :application_id, presence: true
  validates :status, presence: true
  validates :verification_type, presence: true, inclusion: {
    in: ['government_id', 'passport', 'license', 'utility_bill', 'bank_statement'],
    message: "must be a valid verification type"
  }
  validates :document_url, presence: true, if: :submitted?
  validates :verified_at, presence: true, if: :verified?
  validates :verified_by, presence: true, if: :verified?

  # Scopes
  scope :pending_verification, -> { where(status: :submitted).where('submitted_at > ?', 7.days.ago) }
  scope :verified, -> { where(status: :verified) }
  scope :rejected, -> { where(status: :rejected) }

  # Mark as submitted
  def submit!(document_url, verification_type = nil)
    update!(
      status: :submitted,
      document_url: document_url,
      verification_type: verification_type || 'government_id',
      submitted_at: Time.current
    )
  end

  # Mark as verified
  def verify!(verified_by = 'system')
    update!(
      status: :verified,
      verified_at: Time.current,
      verified_by: verified_by
    )
  end

  # Mark as rejected
  def reject!(reason, verified_by = 'system')
    # NOTE: the table has no failure_reason column (the original code wrote
    # one and raised UnknownAttributeError — rejection never worked); the
    # reason is recorded in notes and in the audit log.
    update!(
      status: :rejected,
      notes: reason,
      verified_by: verified_by,
      verified_at: Time.current
    )
  end

  # Human-readable status display
  def status_display
    case status
    when 'pending'
      'Waiting for submission'
    when 'submitted'
      'Under review'
    when 'verified'
      'Verified ✓'
    when 'rejected'
      'Rejected'
    else
      status.humanize
    end
  end
end
