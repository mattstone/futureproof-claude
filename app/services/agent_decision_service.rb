# Service for AI agents to evaluate applications and make structured decisions.
# Currently rule-based; structured for future LLM integration.
class AgentDecisionService
  PROPERTY_VALUE_MIN = 800_000
  PROPERTY_VALUE_MAX = 10_000_000
  BORROWER_AGE_MIN = 18
  BORROWER_AGE_MAX = 85
  BORROWER_AGE_FLAG = 75
  MIN_MONTHLY_INCOME = 500
  MAX_LVR = 80.0
  RISK_THRESHOLD_APPROVE = 40
  RISK_THRESHOLD_FLAG = 70

  Result = Struct.new(:decision, :confidence, :reasoning, :flags, :next_action, :agent_notes, :risk_score, :contract_terms, keyword_init: true)

  def initialize(agent, entity)
    @agent = agent
    @entity = entity
  end

  def evaluate
    case @agent.agent_type
    when "applications"
      evaluate_application
    when "backoffice"
      evaluate_for_processing
    when "investment"
      evaluate_for_acceptance
    else
      Result.new(decision: :flag, confidence: 0.0, reasoning: "Unknown agent type: #{@agent.agent_type}", flags: [ "unknown_agent_type" ], next_action: :escalate)
    end
  end

  private

  # Akane: initial application quality check
  def evaluate_application
    flags = []
    reasons = []

    # Property value check
    home_value = @entity.home_value || 0
    if home_value < PROPERTY_VALUE_MIN
      flags << "property_value_too_low"
      reasons << "Property value $#{home_value.to_i} is below minimum $#{PROPERTY_VALUE_MIN.to_i}"
    elsif home_value > PROPERTY_VALUE_MAX
      flags << "property_value_too_high"
      reasons << "Property value $#{home_value.to_i} exceeds maximum $#{PROPERTY_VALUE_MAX.to_i}"
    end

    # Borrower age check
    age = @entity.borrower_age
    if age.present?
      if age < BORROWER_AGE_MIN || age > BORROWER_AGE_MAX
        flags << "borrower_age_out_of_range"
        reasons << "Borrower age #{age} is outside acceptable range (#{BORROWER_AGE_MIN}-#{BORROWER_AGE_MAX})"
      elsif age > BORROWER_AGE_FLAG
        flags << "borrower_age_senior"
        reasons << "Borrower age #{age} is above #{BORROWER_AGE_FLAG} — shorter loan term recommended"
      end
    end

    # Ownership type check
    unless %w[individual joint lender super].include?(@entity.ownership_status)
      flags << "invalid_ownership_type"
      reasons << "Invalid ownership type: #{@entity.ownership_status}"
    end

    # LVR check
    if @entity.mortgage.present?
      lvr = @entity.mortgage.lvr || 0
      if lvr > MAX_LVR
        flags << "high_lvr"
        reasons << "LVR #{lvr}% exceeds maximum #{MAX_LVR}%"
      end
    end

    risk = calculate_risk_score(flags)
    build_result(flags, reasons, risk)
  end

  # Rie: processing readiness check
  def evaluate_for_processing
    flags = []
    reasons = []

    # Required fields check
    %i[address home_value ownership_status property_state].each do |field|
      if @entity.send(field).blank?
        flags << "missing_#{field}"
        reasons << "Required field '#{field}' is missing"
      end
    end

    # Property valuation check
    unless @entity.has_property_valuation?
      flags << "no_property_valuation"
      reasons << "Property valuation has not been obtained"
    end

    # Documents check
    if @entity.respond_to?(:application_documents)
      required = ApplicationDocument::REQUIRED_FOR_PROCESSING
      uploaded_types = @entity.application_documents.complete.pluck(:document_type)
      missing = required - uploaded_types
      if missing.any?
        flags << "missing_documents"
        reasons << "Missing required documents: #{missing.join(', ')}"
      end
    end

    # Checklist progress
    if @entity.application_checklists.exists?
      pct = @entity.checklist_completion_percentage
      if pct < 100
        flags << "checklist_incomplete"
        reasons << "Checklist is #{pct}% complete"
      end
    end

    # Income validation
    monthly = @entity.monthly_income_amount
    if monthly > 0 && monthly < MIN_MONTHLY_INCOME
      flags << "low_income"
      reasons << "Monthly income $#{monthly.round(2)} is below minimum $#{MIN_MONTHLY_INCOME}"
    end

    risk = calculate_risk_score(flags)
    build_result(flags, reasons, risk)
  end

  # Yumi: acceptance evaluation
  def evaluate_for_acceptance
    flags = []
    reasons = []

    # Run processing checks first
    processing_result = evaluate_for_processing
    flags.concat(processing_result.flags || [])
    reasons.concat(extract_reasons(processing_result))

    # Documents for acceptance
    if @entity.respond_to?(:application_documents)
      required = ApplicationDocument::REQUIRED_FOR_ACCEPTANCE
      uploaded_types = @entity.application_documents.where(status: "verified").pluck(:document_type)
      missing = required - uploaded_types
      if missing.any?
        flags << "unverified_documents"
        reasons << "Documents not yet verified: #{missing.join(', ')}"
      end
    end

    # Funding availability
    funding_result = check_funding_availability
    if funding_result[:error]
      flags << "funding_unavailable"
      reasons << funding_result[:error]
    end

    # Contract terms check
    unless MortgageContract.current.present?
      flags << "no_active_contract_terms"
      reasons << "No active mortgage contract terms available"
    end

    risk = calculate_risk_score(flags)
    result = build_result(flags, reasons, risk)

    # Add contract terms recommendation
    if result.decision == :approve && funding_result[:funder_pool]
      result.contract_terms = {
        recommended_lender: funding_result[:lender]&.name,
        funder_pool_id: funding_result[:funder_pool]&.id,
        available_capital: funding_result[:available],
        loan_value: @entity.loan_value,
        loan_term: @entity.loan_term
      }
    end

    result
  end

  def check_funding_availability
    lender = @entity.mortgage&.active_lenders&.first
    return { error: "No active lender found for this mortgage" } unless lender

    pool = lender.active_funder_pool
    return { error: "Lender #{lender.name} has no active funder pool" } unless pool

    available = pool.amount - pool.allocated
    needed = @entity.home_value || 0

    if available < needed
      { error: "Insufficient funding: need $#{needed.to_i}, available $#{available.to_i}", lender: lender, funder_pool: pool, available: available }
    else
      { error: nil, lender: lender, funder_pool: pool, available: available }
    end
  rescue => e
    { error: "Funding check failed: #{e.message}" }
  end

  def calculate_risk_score(flags)
    score = 0
    weights = {
      "property_value_too_low" => 25, "property_value_too_high" => 20,
      "borrower_age_out_of_range" => 30, "borrower_age_senior" => 10,
      "invalid_ownership_type" => 15, "high_lvr" => 20,
      "missing_documents" => 15, "unverified_documents" => 15,
      "no_property_valuation" => 10, "checklist_incomplete" => 10,
      "low_income" => 20, "funding_unavailable" => 30,
      "no_active_contract_terms" => 25
    }
    # Add weight for missing fields
    flags.each { |f| score += weights.fetch(f, f.start_with?("missing_") ? 10 : 5) }
    [ score, 100 ].min
  end

  def build_result(flags, reasons, risk_score)
    if flags.any? { |f| %w[property_value_too_low property_value_too_high borrower_age_out_of_range funding_unavailable no_active_contract_terms].include?(f) }
      decision = :reject
      next_action = :reject
      confidence = [ 0.7 + (risk_score / 200.0), 1.0 ].min
    elsif flags.any?
      decision = :flag
      next_action = risk_score > RISK_THRESHOLD_FLAG ? :escalate : :request_info
      confidence = [ 0.5 + (risk_score / 200.0), 0.95 ].min
    else
      decision = :approve
      next_action = :advance
      confidence = [ 1.0 - (risk_score / 100.0), 1.0 ].min
    end

    reasoning = flags.empty? ? "All checks passed. Application meets all criteria." : reasons.join(". ") + "."
    agent_notes = "#{@agent.name} evaluated #{@entity.class.name}##{@entity.id} — risk score: #{risk_score}/100"

    Result.new(
      decision: decision,
      confidence: confidence.round(3),
      reasoning: reasoning,
      flags: flags,
      next_action: next_action,
      agent_notes: agent_notes,
      risk_score: risk_score
    )
  end

  def extract_reasons(result)
    result.reasoning.present? && result.reasoning != "All checks passed. Application meets all criteria." ? [ result.reasoning ] : []
  end
end
