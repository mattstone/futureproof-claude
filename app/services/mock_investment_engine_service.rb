class MockInvestmentEngineService
  @current_scenario = :normal

  def self.set_scenario(scenario)
    @current_scenario = scenario
  end

  def self.current_scenario
    @current_scenario || :normal
  end

  def self.check_funding_availability(funder_pool_id:, amount:)
    seed = deterministic_seed("funding-#{funder_pool_id}")
    rng = Random.new(seed)
    pool_balance = (rng.rand(10_000_000..100_000_000) / 100_000) * 100_000

    result = case current_scenario
    when :no_funding
      { available: false, pool_balance: 0, amount_requested: amount, approval_likelihood: "none", conditions: [ "Pool exhausted" ], expected_return_rate: 0 }
    when :tight_capital
      { available: amount < 500_000, pool_balance: pool_balance / 10, amount_requested: amount, approval_likelihood: "low", conditions: [ "Reduced allocation limits", "Priority queue active" ], expected_return_rate: (8.0 + rng.rand * 2.0).round(1) }
    when :conditional
      { available: true, pool_balance: pool_balance, amount_requested: amount, approval_likelihood: "medium", conditions: [ "Requires additional property assessment", "LVR must be below 70%" ], expected_return_rate: (6.0 + rng.rand * 3.0).round(1) }
    else
      { available: true, pool_balance: pool_balance, amount_requested: amount, approval_likelihood: "high", conditions: [], expected_return_rate: (5.5 + rng.rand * 3.0).round(1) }
    end

    Rails.logger.info("[MockInvestmentEngineService] check_funding_availability pool=#{funder_pool_id} amount=#{amount} available=#{result[:available]}")
    result
  end

  def self.request_capital_allocation(funder_pool_id:, contract_id:, amount:)
    seed = deterministic_seed("alloc-#{funder_pool_id}-#{contract_id}")
    rng = Random.new(seed)
    alloc_id = "ALLOC-#{rng.rand(100000..999999)}"

    result = case current_scenario
    when :no_funding
      { allocation_id: alloc_id, status: "rejected", amount: amount, reason: "No funding available" }
    when :conditional
      { allocation_id: alloc_id, status: "pending_review", amount: amount, interest_rate: (6.0 + rng.rand * 2.0).round(1), terms: "30 years fixed", conditions: [ "Awaiting property assessment" ] }
    else
      { allocation_id: alloc_id, status: "approved", amount: amount, interest_rate: (5.5 + rng.rand * 2.5).round(1), terms: "30 years fixed", approval_date: Date.current }
    end

    Rails.logger.info("[MockInvestmentEngineService] request_capital_allocation alloc=#{alloc_id} status=#{result[:status]}")
    result
  end

  def self.calculate_returns(allocation_id:, period_months: 12)
    seed = deterministic_seed("returns-#{allocation_id}")
    rng = Random.new(seed)
    principal = (rng.rand(300_000..2_000_000) / 1000) * 1000
    rate = (5.5 + rng.rand * 2.5).round(2)
    projected = (principal * rate / 100 * period_months / 12).round(2)
    actual = (projected * (0.9 + rng.rand * 0.2)).round(2)

    { allocation_id: allocation_id, period_months: period_months, principal: principal, interest_rate: rate, projected_return: projected, actual_return: actual, performance_ratio: (actual / projected).round(3) }.tap do |r|
      Rails.logger.info("[MockInvestmentEngineService] calculate_returns alloc=#{allocation_id} actual=#{r[:actual_return]}")
    end
  end

  def self.get_portfolio_summary(funder_pool_id)
    seed = deterministic_seed("portfolio-#{funder_pool_id}")
    rng = Random.new(seed)
    total = (rng.rand(20_000_000..200_000_000) / 100_000) * 100_000
    deployed = (total * (0.6 + rng.rand * 0.3)).round(0)
    {
      funder_pool_id: funder_pool_id, total_capital: total, deployed_capital: deployed,
      available_capital: total - deployed, active_contracts: rng.rand(50..500),
      average_return_rate: (5.5 + rng.rand * 3.0).round(1),
      default_rate: (rng.rand * 2.0).round(2),
      portfolio_health: %w[excellent good fair][rng.rand(3)]
    }.tap { |r| Rails.logger.info("[MockInvestmentEngineService] get_portfolio_summary pool=#{funder_pool_id} health=#{r[:portfolio_health]}") }
  end

  private

  def self.deterministic_seed(input)
    Digest::MD5.hexdigest(input.to_s)[0..7].to_i(16)
  end
end
