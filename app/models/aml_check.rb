class AmlCheck < ApplicationRecord
  belongs_to :application

  # Status enum: pending, checking, passed, failed
  enum :status, {
    pending: 0,
    checking: 1,
    passed: 2,
    failed: 3
  }

  # Validations
  validates :application_id, presence: true
  validates :status, presence: true
  validates :risk_level, inclusion: {
    in: [ "low", "medium", "high" ],
    message: "must be low, medium, or high"
  }, allow_nil: true
  validates :failure_reason, presence: true, if: :failed?
  validates :passed_at, presence: true, if: :passed?

  # Scopes
  scope :high_risk, -> { where(risk_level: "high") }
  scope :pending, -> { where(status: [ :pending, :checking ]) }
  scope :passed, -> { where(status: :passed) }
  scope :failed, -> { where(status: :failed) }
  scope :recent, -> { order(checked_at: :desc) }

  # Check for AML issues (placeholder for external API call)
  def self.check_application(application)
    # In production, this would call an external AML service
    # For now, return a basic risk assessment
    check = application.aml_check || create!(application: application)

    risk_level = assess_risk(application)

    check.update!(
      status: :checking,
      risk_level: risk_level,
      checked_at: Time.current
    )

    # Simulate checking - in production, wait for external service
    if risk_level == "low"
      check.pass!
    elsif risk_level == "high"
      check.fail!("High risk indicators detected")
    else
      # Medium risk - manual review required
      check.update!(status: :pending)
    end

    check
  end

  # Mark as passed
  def pass!
    update!(
      status: :passed,
      passed_at: Time.current,
      risk_level: "low"
    )
  end

  # Mark as failed
  def fail!(reason = "AML check failed")
    update!(
      status: :failed,
      failure_reason: reason,
      risk_level: "high"
    )
  end

  # Status display
  def status_display
    case status
    when "pending"
      "Pending review"
    when "checking"
      "Checking..."
    when "passed"
      "Passed ✓"
    when "failed"
      "Failed"
    else
      status.humanize
    end
  end

  private

  def self.assess_risk(application)
    # Placeholder risk assessment logic
    # In production, integrate with real AML service (Lexis Nexis, etc.)

    risk_score = 0

    # Check for common risk factors
    risk_score += 10 if application.borrower_age && application.borrower_age < 18
    risk_score += 5 if application.existing_mortgage_amount.to_i > 5_000_000
    risk_score += 15 if application.ownership_status == "lender" # Corporate accounts need more scrutiny

    if risk_score >= 15
      "high"
    elsif risk_score >= 5
      "medium"
    else
      "low"
    end
  end
end
