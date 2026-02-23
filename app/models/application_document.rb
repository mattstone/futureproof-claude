class ApplicationDocument < ApplicationRecord
  belongs_to :application
  has_one_attached :file

  DOCUMENT_TYPES = %w[
    identity income_proof property_title bank_statement
    insurance tax_return council_rates mortgage_statement
    property_valuation employment_letter
  ].freeze

  REQUIRED_FOR_SUBMISSION = %w[identity income_proof bank_statement].freeze
  REQUIRED_FOR_PROCESSING = %w[identity income_proof bank_statement property_title].freeze
  REQUIRED_FOR_ACCEPTANCE = %w[identity income_proof bank_statement property_title insurance property_valuation].freeze

  enum :status, { pending: "pending", uploaded: "uploaded", verified: "verified", rejected: "rejected", expired: "expired" }

  validates :document_type, presence: true, inclusion: { in: DOCUMENT_TYPES }
  validates :status, presence: true
  validates :rejection_reason, presence: true, if: :rejected?

  scope :required_for_submission, -> { where(document_type: REQUIRED_FOR_SUBMISSION) }
  scope :required_for_processing, -> { where(document_type: REQUIRED_FOR_PROCESSING) }
  scope :outstanding, -> { where(status: %w[pending rejected]) }
  scope :complete, -> { where(status: %w[uploaded verified]) }

  def verify!(agent_name:, notes: nil)
    update!(
      status: :verified,
      verified_by: agent_name,
      verified_at: Time.current,
      notes: notes
    )
  end

  def reject!(agent_name:, reason:)
    update!(
      status: :rejected,
      rejection_reason: reason,
      verified_by: agent_name,
      notes: "Rejected: #{reason}"
    )
  end

  def display_name
    name || document_type.humanize
  end
end
