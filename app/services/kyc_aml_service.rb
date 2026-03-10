# Service for managing KYC/AML compliance status and tracking
class KycAmlService
  def initialize(application)
    @application = application
  end

  # Get complete compliance status
  def compliance_status
    kyc = @application.kyc_submission || initialize_kyc
    aml = @application.aml_check || initialize_aml
    
    {
      kyc: kyc_status(kyc),
      aml: aml_status(aml),
      overall: overall_status(kyc, aml),
      can_proceed: can_proceed?(kyc, aml)
    }
  end

  # Trigger KYC process
  def start_kyc_verification(verification_type = 'government_id')
    kyc = @application.kyc_submission || KycSubmission.create!(application: @application)
    kyc.update!(status: :pending, verification_type: verification_type)
    kyc
  end

  # Trigger AML check
  def check_aml
    AmlCheck.check_application(@application)
  end

  # Complete compliance verification
  def verify_compliance!
    kyc = start_kyc_verification
    aml = check_aml
    
    if kyc.pending? && aml.pending?
      {
        status: 'pending',
        message: 'KYC and AML checks initiated. Manual review required.',
        kyc: kyc,
        aml: aml
      }
    elsif kyc.verified? && aml.passed?
      {
        status: 'approved',
        message: 'All compliance checks passed',
        kyc: kyc,
        aml: aml
      }
    else
      {
        status: 'pending_review',
        message: 'Compliance review in progress',
        kyc: kyc,
        aml: aml
      }
    end
  end

  # Get compliance dashboard data
  def compliance_dashboard
    kyc = @application.kyc_submission
    aml = @application.aml_check
    
    {
      application_id: @application.id,
      applicant_name: @application.user&.full_name,
      loan_amount: @application.loan_value,
      kyc: {
        status: kyc&.status,
        status_display: kyc&.status_display,
        verification_type: kyc&.verification_type,
        submitted_at: kyc&.submitted_at,
        verified_at: kyc&.verified_at,
        verified_by: kyc&.verified_by,
        document_url: kyc&.document_url
      },
      aml: {
        status: aml&.status,
        status_display: aml&.status_display,
        risk_level: aml&.risk_level,
        checked_at: aml&.checked_at,
        passed_at: aml&.passed_at,
        failure_reason: aml&.failure_reason
      },
      compliance_complete: kyc&.verified? && aml&.passed?
    }
  end

  private

  def initialize_kyc
    KycSubmission.create!(
      application: @application,
      status: :pending,
      verification_type: 'government_id'
    )
  end

  def initialize_aml
    AmlCheck.create!(
      application: @application,
      status: :pending,
      risk_level: 'medium'
    )
  end

  def kyc_status(kyc)
    {
      status: kyc.status,
      display: kyc.status_display,
      verified: kyc.verified?,
      rejected: kyc.rejected?,
      verified_at: kyc.verified_at
    }
  end

  def aml_status(aml)
    {
      status: aml.status,
      display: aml.status_display,
      risk_level: aml.risk_level,
      passed: aml.passed?,
      failed: aml.failed?,
      passed_at: aml.passed_at
    }
  end

  def overall_status(kyc, aml)
    return 'approved' if kyc.verified? && aml.passed?
    return 'rejected' if kyc.rejected? || aml.failed?
    return 'pending_review' if kyc.submitted? || aml.checking?
    'pending'
  end

  def can_proceed?(kyc, aml)
    kyc.verified? && aml.passed?
  end
end
