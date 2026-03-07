class CustomerSupportService
  # 24/7 Claude-powered customer support
  # Handles general inquiries, borrower help, lender questions, and pre-application support

  MAX_TOKENS = 2000
  MODEL = "claude-sonnet-4-20250514"

  KNOWLEDGE_BASE = {
    product: {
      what_is_epm: "An Equity Preservation Mortgage (EPM) is a new type of home loan where the borrower receives a fixed, tax-free monthly annuity income from their home equity. Unlike reverse mortgages: (1) Simple interest, not compound — home equity is preserved. (2) All property appreciation stays with the borrower/heirs. (3) The borrower never pays interest — it's paid by the lender from the mortgage offset account. (4) Age-independent. (5) NNEG guarantee — never owe more than property value.",
      how_it_works: "1. Apply online with your property details. 2. We assess your property value and eligibility. 3. If approved, a lender is matched to your application. 4. Your loan is activated and capital is placed in an offset account. 5. You receive fixed monthly annuity payments (tax-free). 6. At end of term, the loan principal is repaid from property sale or refinancing.",
      annuity_cap: "Monthly annuity payments are capped at 2% of property value per year. For a $500,000 home: max $10,000/year = ~$833/month.",
      nneg: "The No Negative Equity Guarantee (NNEG) ensures you never owe more than your home is worth. If property value falls below the loan balance, the lender absorbs the loss.",
      vs_reverse_mortgage: "EPM differs from reverse mortgages: (1) Simple interest vs compound — your equity is preserved. (2) Fixed annuity income vs lump sum. (3) Age-independent vs age-restricted (usually 62+). (4) Property appreciation stays with you vs shared. (5) More transparent fee structure.",
      interest: "EPM uses simple interest, not compound. The lender pays interest from the mortgage offset (reinvestment) account. You never make interest payments.",
      tax: "EPM annuity payments are generally tax-free as they represent a loan advance, not income. However, tax implications may vary. We recommend consulting a tax professional."
    },
    eligibility: {
      requirements: "To apply for an EPM you need: (1) Own a residential property in AU, US, NZ, or UK. (2) Property value sufficient for viable annuity. (3) LTV ratio within limits (typically max 80%). (4) Complete KYC/identity verification. (5) No age restrictions.",
      property_types: "Eligible properties: residential houses, townhouses, units/apartments (subject to valuation). Generally excludes: commercial property, vacant land, farms (residential portion may qualify).",
      regions: "FutureProof currently operates in Australia (AU), United States (US), New Zealand (NZ), and United Kingdom (UK). Each region has specific regulatory requirements."
    },
    process: {
      timeline: "Typical timeline: Application (15 min) → KYC verification (1-3 days) → Property valuation (3-5 days) → Lender matching (1-2 days) → Contract review (14-day cooling-off) → Activation → First payment next month. Total: approximately 4-6 weeks.",
      documents_needed: "You'll need: (1) Government-issued photo ID (passport or driver's licence). (2) Proof of property ownership (title deed or rates notice). (3) Recent property valuation or purchase price. (4) Proof of address. (5) Bank account details for annuity payments.",
      cooling_off: "After signing the loan contract, you have a cooling-off period (14 days in AU, varies by region) during which you can cancel without penalty.",
      hardship: "If you experience financial difficulty, contact us immediately. We have a hardship policy and can discuss options including loan modification or early repayment arrangements."
    },
    lender: {
      become_lender: "Lenders can join the FutureProof platform to fund EPM loans. Benefits: stable returns from interest income, property-secured lending, portfolio diversification. Contact our lender partnerships team for details.",
      lender_dashboard: "The lender dashboard provides: portfolio overview, active loan details, payment history, distribution tracking, reports and analytics, and account management.",
      returns: "Lender returns come from interest on the loan principal (paid via the offset account structure). Returns are stable and property-secured. Exact rates vary by region and risk profile."
    },
    support: {
      contact: "Email: support@futureproof.com.au | Phone: 1300 FUTURE (1300 388 873) | Hours: 24/7 AI support, human support Mon-Fri 9am-5pm AEST.",
      complaints: "To lodge a complaint: (1) Contact us first via email or phone. (2) We'll acknowledge within 5 business days. (3) Full response within 30 days. (4) If unsatisfied, contact AFCA (AU), CFPB (US), or FOS (UK/NZ).",
      escalation: "If you need to speak to a human, click 'Escalate to Support' in the chat. Our team will respond within 1 business day."
    }
  }.freeze

  SYSTEM_PROMPT = <<~PROMPT
    You are the FutureProof customer support assistant. You provide helpful, accurate, and friendly support for the Equity Preservation Mortgage (EPM) platform.

    CORE RULES:
    1. Be warm, professional, and empathetic
    2. Answer questions accurately using the knowledge base below
    3. NEVER provide specific legal, tax, or financial advice — always recommend professional consultation
    4. If you don't know something, say so honestly and offer to escalate to a human
    5. For account-specific questions (loan status, payment details), direct users to log in or contact support
    6. Protect user privacy — never ask for sensitive information (SSN, bank details) in chat

    KNOWLEDGE BASE:
    #{KNOWLEDGE_BASE.map { |category, items| items.map { |k, v| "#{category}/#{k}: #{v}" }.join("\n") }.join("\n\n")}

    ESCALATION TRIGGERS (recommend human support):
    - Legal disputes or complaints
    - Account security concerns
    - Payment discrepancies
    - Requests for specific financial advice
    - Emotional distress or vulnerability
    - Complex regulatory questions

    RESPONSE STYLE:
    - Keep responses concise (2-3 paragraphs max)
    - Use bullet points for lists
    - Bold key terms
    - End with a helpful follow-up question or next step
    - Include relevant links where applicable
  PROMPT

  def initialize(session_id:, region: "au")
    @session_id = session_id
    @region = region
    @messages = []
  end

  def self.create_session(user: nil, region: "au")
    session_id = SecureRandom.uuid
    new(session_id: session_id, region: region)
  end

  def respond(user_message:, conversation_history: [])
    messages = conversation_history.map do |msg|
      { role: msg[:role], content: msg[:content] }
    end
    messages << { role: "user", content: user_message }

    # Check for quick answers first
    quick = quick_answer(user_message)
    return { success: true, response: quick, source: :knowledge_base } if quick

    # Route to Claude
    begin
      client = Anthropic::Client.new(api_key: ENV["ANTHROPIC_API_KEY"])

      response = client.messages(
        model: MODEL,
        max_tokens: MAX_TOKENS,
        system: region_system_prompt,
        messages: messages
      )

      content = response.dig("content", 0, "text")
      input_tokens = response.dig("usage", "input_tokens") || 0
      output_tokens = response.dig("usage", "output_tokens") || 0

      escalate = should_escalate?(user_message, content)

      {
        success: true,
        response: content,
        source: :claude,
        model: MODEL,
        tokens: { input: input_tokens, output: output_tokens },
        escalate: escalate
      }
    rescue => e
      Rails.logger.error("CustomerSupportService error: #{e.message}")
      {
        success: false,
        response: "I'm sorry, I'm having trouble right now. Please try again in a moment, or contact us directly at support@futureproof.com.au or 1300 388 873.",
        source: :fallback,
        error: e.message
      }
    end
  end

  private

  def region_system_prompt
    region_context = case @region
    when "au"
      "The user is in Australia. Reference Privacy Act 1988, AFCA for complaints, Centrelink implications. Currency: AUD."
    when "us"
      "The user is in the United States. Reference CFPB for complaints, TILA/RESPA. Emphasize EPM is NOT a HECM. Currency: USD."
    when "nz"
      "The user is in New Zealand. Reference Privacy Act 2020, CCCFA, 5-day cooling-off. Currency: NZD."
    when "uk"
      "The user is in the United Kingdom. Reference UK GDPR, FCA, FOS for complaints. Emphasize EPM is NOT equity release. Currency: GBP."
    else
      ""
    end

    "#{SYSTEM_PROMPT}\n\nREGION: #{region_context}"
  end

  def quick_answer(message)
    msg = message.downcase.strip

    return KNOWLEDGE_BASE[:product][:what_is_epm] if msg.match?(/what is.*(epm|equity preservation)/i)
    return KNOWLEDGE_BASE[:product][:how_it_works] if msg.match?(/how does.*(epm|it|this) work/i)
    return KNOWLEDGE_BASE[:product][:nneg] if msg.match?(/nneg|negative equity/i)
    return KNOWLEDGE_BASE[:product][:vs_reverse_mortgage] if msg.match?(/reverse mortgage|differ/i)
    return KNOWLEDGE_BASE[:eligibility][:requirements] if msg.match?(/eligib|qualify|requirements/i)
    return KNOWLEDGE_BASE[:process][:timeline] if msg.match?(/how long|timeline|how fast/i)
    return KNOWLEDGE_BASE[:process][:documents_needed] if msg.match?(/what documents|what do i need/i)
    return KNOWLEDGE_BASE[:support][:contact] if msg.match?(/contact|phone|email|call/i)
    return KNOWLEDGE_BASE[:support][:complaints] if msg.match?(/complain|dispute/i)

    nil # No quick answer — route to Claude
  end

  def should_escalate?(user_message, response)
    triggers = [
      /complain/i, /legal action/i, /lawyer/i, /sue/i,
      /payment.*(wrong|missing|error)/i, /fraud/i, /hack/i,
      /suicid/i, /harm/i, /die/i, /kill/i,
      /account.*(lock|hack|steal)/i
    ]

    triggers.any? { |t| user_message.match?(t) || response.match?(t) }
  end
end
