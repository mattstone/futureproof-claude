class MockPaymentService
  @current_scenario = :normal

  def self.set_scenario(scenario)
    @current_scenario = scenario
  end

  def self.current_scenario
    @current_scenario || :normal
  end

  def self.initiate_settlement(contract_id:, amount:, recipient:)
    seed = deterministic_seed("settlement-#{contract_id}")
    rng = Random.new(seed)
    txn_id = "TXN-#{rng.rand(100000..999999)}"

    result = case current_scenario
    when :failed
      { transaction_id: txn_id, status: "failed", error: "Payment declined", amount: amount, recipient: recipient }
    when :delayed
      { transaction_id: txn_id, status: "pending", estimated_completion: 7.days.from_now, amount: amount, recipient: recipient, fees: { processing: 250, legal: 1500 }, note: "Settlement delayed due to additional verification" }
    when :insufficient_funds
      { transaction_id: txn_id, status: "failed", error: "Insufficient funds in settlement account", amount: amount, recipient: recipient }
    else
      { transaction_id: txn_id, status: "pending", estimated_completion: 3.days.from_now, amount: amount, recipient: recipient, fees: { processing: 250, legal: 1500 } }
    end

    Rails.logger.info("[MockPaymentService] initiate_settlement contract=#{contract_id} amount=#{amount} status=#{result[:status]}")
    result
  end

  def self.process_monthly_disbursement(contract_id:, amount:, recipient:)
    seed = deterministic_seed("disbursement-#{contract_id}-#{Date.current}")
    rng = Random.new(seed)
    acct = "****#{rng.rand(1000..9999)}"

    result = if current_scenario == :failed
      { transaction_id: "DIS-#{rng.rand(100000..999999)}", status: "failed", error: "Disbursement failed", amount: amount, recipient: recipient }
    else
      { transaction_id: "DIS-#{rng.rand(100000..999999)}", status: "completed", amount: amount.to_f, recipient_account: acct, next_disbursement_date: 1.month.from_now.to_date }
    end

    Rails.logger.info("[MockPaymentService] process_monthly_disbursement contract=#{contract_id} status=#{result[:status]}")
    result
  end

  def self.get_transaction_status(transaction_id)
    seed = deterministic_seed(transaction_id.to_s)
    rng = Random.new(seed)
    statuses = %w[pending processing completed failed]
    status = current_scenario == :normal ? "completed" : statuses[rng.rand(statuses.size)]
    { transaction_id: transaction_id, status: status, updated_at: Time.current }.tap do |r|
      Rails.logger.info("[MockPaymentService] get_transaction_status #{transaction_id} status=#{r[:status]}")
    end
  end

  def self.get_payment_history(contract_id)
    seed = deterministic_seed("history-#{contract_id}")
    rng = Random.new(seed)
    count = rng.rand(3..12)
    count.times.map do |i|
      s = Random.new(seed + i)
      { transaction_id: "DIS-#{s.rand(100000..999999)}", date: Date.current - (count - i).months, amount: (2000 + s.rand(0..1000)).to_f, status: "completed", type: "disbursement" }
    end.tap { |r| Rails.logger.info("[MockPaymentService] get_payment_history contract=#{contract_id} count=#{r.size}") }
  end

  private

  def self.deterministic_seed(input)
    Digest::MD5.hexdigest(input.to_s)[0..7].to_i(16)
  end
end
