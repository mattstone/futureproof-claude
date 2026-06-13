class CustomerSupportService
  # Knowledge-base customer support for EPM general inquiries
  # Answers public EPM questions only — no proprietary model details

  KNOWLEDGE_BASE = {
    product: {
      what_is_epm: "An Equity Preservation Mortgage (EPM) is a new type of mortgage where the borrower receives a fixed, tax-free monthly annuity income from their home equity. Unlike reverse mortgages: (1) Simple interest, not compound — home equity is preserved. (2) All property appreciation stays with the borrower/heirs. (3) The borrower never pays interest — it's paid by the lender from the mortgage offset account. (4) Age-independent. (5) NNEG guarantee — never owe more than property value.",
      how_it_works: "1. Apply online with your property details. 2. We assess your property value and eligibility. 3. If approved, a lender is matched to your application. 4. Your mortgage is activated and capital is placed in an offset account. 5. You receive fixed monthly annuity payments (tax-free). 6. At end of term, the mortgage principal is repaid from property sale or refinancing.",
      annuity_income: "You receive a fixed monthly annuity payment from your home equity. The amount depends on your property value, chosen term, and region. Use our online calculator to get a personalised quote.",
      nneg: "The No Negative Equity Guarantee (NNEG) ensures you never owe more than your home is worth. If property value falls below the mortgage balance, the lender absorbs the loss. Your equity is protected.",
      vs_reverse_mortgage: "EPM differs from reverse mortgages: (1) Simple interest vs compound — your equity is preserved. (2) Fixed annuity income vs lump sum. (3) Age-independent vs age-restricted (usually 62+). (4) Property appreciation stays with you vs shared. (5) More transparent fee structure.",
      interest: "EPM uses simple interest, not compound. The lender pays interest from the mortgage offset (reinvestment) account. You never make interest payments.",
      tax: "EPM annuity payments are generally tax-free as they represent a mortgage advance, not income. However, tax implications may vary by jurisdiction. We recommend consulting a tax professional for your personal situation.",
      term_end: "At the end of the mortgage term, the principal is repaid — typically from the sale of the property or by refinancing. All property appreciation during the term belongs to you or your heirs.",
      legitimacy: "FutureProof is a regulated financial services platform operating in Australia, the US, New Zealand, and the UK. The EPM is a fully documented mortgage product with legal contracts, cooling-off periods, and regulatory oversight in each jurisdiction. If you'd like to learn more, we're happy to walk you through the details."
    },
    eligibility: {
      requirements: "To apply for an EPM you need: (1) Own a residential property in AU, US, NZ, or UK. (2) Property value sufficient for viable annuity. (3) LTV ratio within limits (typically max 80%). (4) Complete KYC/identity verification. (5) No age restrictions.",
      age: "There are no age restrictions for an EPM. Whether you're 25 or 95, you can apply. Unlike reverse mortgages which typically require you to be 62 or older, the Equity Preservation Mortgage is age-independent. Eligibility is based on property ownership and value, not your age.",
      property_types: "Eligible properties: residential houses, townhouses, units/apartments (subject to valuation). Generally excludes: commercial property, vacant land, farms (residential portion may qualify).",
      property_value: "Your property needs to have sufficient value to generate a viable annuity. The exact minimum depends on your region and chosen term. Use our online calculator to check, or contact us for a personalised assessment.",
      regions: "FutureProof currently operates in Australia (AU), United States (US), New Zealand (NZ), and United Kingdom (UK). Each region has specific regulatory requirements. Scotland is included as part of the UK.",
      credit_score: "EPM eligibility is primarily based on property ownership and value, not your credit score. Standard KYC (Know Your Customer) and identity checks are required, but this is not a traditional credit-based product.",
      joint_application: "Yes, joint applications are possible. If you and your spouse or partner co-own the property, you can apply together. Contact us to discuss your specific situation.",
      selling: "If you wish to sell your property during the EPM term, the mortgage principal would need to be repaid from the sale proceeds. Any remaining equity and all property appreciation belongs to you.",
      investment_property: "EPM is designed for residential properties. Investment properties may be considered on a case-by-case basis depending on the property type and jurisdiction. Contact us to discuss your situation."
    },
    process: {
      timeline: "Typical timeline: Application (15 min) → KYC verification (1-3 days) → Property valuation (3-5 days) → Lender matching (1-2 days) → Contract review (14-day cooling-off) → Activation → First payment next month. Total: approximately 4-6 weeks.",
      documents_needed: "You'll need: (1) Government-issued photo ID (passport or driver's licence). (2) Proof of property ownership (title deed or rates notice). (3) Recent property valuation or purchase price. (4) Proof of address. (5) Bank account details for annuity payments.",
      cooling_off: "After signing the mortgage contract, you have a cooling-off period (14 days in AU, varies by region) during which you can cancel without penalty.",
      hardship: "If you're experiencing financial difficulty, contact us immediately. We have a hardship policy and can discuss options including mortgage modification or early repayment arrangements. EPM can also be a way to unlock income from your home equity if you're struggling."
    },
    lender: {
      become_lender: "Lenders can join the FutureProof platform to fund EPM mortgages. Benefits: stable returns from interest income, property-secured lending, portfolio diversification. Contact our lender partnerships team for details.",
      lender_dashboard: "The lender dashboard provides: portfolio overview, active mortgage details, payment history, distribution tracking, reports and analytics, and account management.",
      returns: "Lender returns come from interest on the mortgage principal (paid via the offset account structure). Returns are stable and property-secured. Exact rates vary by region and risk profile."
    },
    support: {
      contact: "Email: support@futureproof.com.au | Phone: 1300 FUTURE (1300 388 873) | Hours: 24/7 AI support, human support Mon-Fri 9am-5pm AEST.",
      complaints: "To lodge a complaint: (1) Contact us first via email or phone. (2) We'll acknowledge within 5 business days. (3) Full response within 30 days. (4) If unsatisfied, contact AFCA (AU), CFPB (US), or FOS (UK/NZ).",
      escalation: "If you need to speak to a human, click 'Escalate to Support' in the chat. Our team will respond within 1 business day."
    }
  }.freeze

  # Topics that are off-limits — proprietary model details
  PROPRIETARY_PATTERNS = [
    /monte carlo/i, /simulation/i, /optimization|optimisation/i,
    /waterfall/i, /surplus split/i, /run.?off/i,
    /probability.*(default|claim)/i, /po[dc]\b/i,
    /s&p.*500|etf|investment.*(strategy|allocation|portfolio)/i,
    /offset account.*(structure|model|formula)/i,
    /funder.*(pool|model|structure)/i, /credit risk model/i,
    /pricing model/i, /spread|margin.*model/i,
    /actuarial/i, /stochastic/i, /scenario analysis/i,
    /internal rate|irr\b/i, /yield curve/i
  ].freeze

  PROPRIETARY_RESPONSE = "That's outside the scope of what I can respond to. " \
    "I can help with how EPM works, eligibility, the application process, and what to expect as a borrower or lender. " \
    "For more detailed questions, contact our team at support@futureproof.com.au."

  # Pattern-matched responses for common questions
  # Order matters — more specific patterns MUST come before general ones
  PATTERNS = [
    # Scam / trust / legitimacy — check early before "what is" catches it
    { match: /scam|legit|trust|fraud|dodgy|too good to be true|real company/i, key: [ :product, :legitimacy ] },

    # Product questions
    { match: /what is.*(epm|equity preservation|futureproof)/i, key: [ :product, :what_is_epm ] },
    { match: /how does.*(epm|it|this|mortgage) work/i, key: [ :product, :how_it_works ] },
    { match: /nneg|negative equity|guarantee/i, key: [ :product, :nneg ] },
    { match: /reverse mortgage/i, key: [ :product, :vs_reverse_mortgage ] },
    { match: /simple interest|compound interest|interest rate|what interest/i, key: [ :product, :interest ] },
    { match: /\btax\b(?!i).*\b(epm|annuity|payment|free|exempt|implications?)\b|\btax.?free\b/i, key: [ :product, :tax ] },
    { match: /annuity|income.*receive|how much.*(get|receive|paid|earn)/i, key: [ :product, :annuity_income ] },
    { match: /term (end|finish|expire|over|up)|end of (the )?(term|mortgage|loan)|when.*(term|mortgage).*(end|finish|expire|over)/i, key: [ :product, :term_end ] },

    # House price / value drop — must come before property_types
    { match: /price.*(drop|fall|crash|decline|down)|value.*(drop|fall|crash|decline|down)|what if.*(house|property|home).*(drop|fall|worth less)/i, key: [ :product, :nneg ] },

    # Selling during term
    { match: /sell.*(house|home|property)|want to (move|sell)/i, key: [ :eligibility, :selling ] },

    # Age / eligibility — specific patterns before general eligibility
    { match: /\b\d+\b.*\b(can i|still|apply|eligible|old enough|too old)\b|\bage\b|too old|too young|elderly|senior|retired|pension|older/i, key: [ :eligibility, :age ] },
    { match: /credit score|credit (check|rating|history)/i, key: [ :eligibility, :credit_score ] },
    { match: /joint(ly)?|spouse|partner|co.?own|couple|together/i, key: [ :eligibility, :joint_application ] },
    { match: /minimum.*(value|property|amount|price)|property.*(minimum|value.*need)/i, key: [ :eligibility, :property_value ] },
    { match: /investment property/i, key: [ :eligibility, :investment_property ] },
    { match: /eligib|qualify|requirements|can i (apply|get)\b/i, key: [ :eligibility, :requirements ] },
    { match: /property type|what propert|house|apartment|unit/i, key: [ :eligibility, :property_types ] },
    { match: /region|countr|where.*available|scotland|australia|us\b|uk\b|new zealand|which (countr|state)/i, key: [ :eligibility, :regions ] },

    # Process
    { match: /how long|timeline|how fast|when.*start/i, key: [ :process, :timeline ] },
    { match: /what documents|what do i need|id|passport/i, key: [ :process, :documents_needed ] },
    { match: /cooling.?off|cancel|change.*mind/i, key: [ :process, :cooling_off ] },
    { match: /hardship|difficult|can't pay|struggling|struggle|ends? meet/i, key: [ :process, :hardship ] },

    # Lender — allow either word order
    { match: /become.*lender|lend.*money|fund.*mortgage/i, key: [ :lender, :become_lender ] },
    { match: /lender.*dashboard|lender.*portal/i, key: [ :lender, :lender_dashboard ] },
    { match: /lender.*return|lender.*earn|lender.*profit|return.*lender|earn.*lender/i, key: [ :lender, :returns ] },

    # Support
    { match: /contact|phone|email|call|reach/i, key: [ :support, :contact ] },
    { match: /complain|dispute|unhappy|unsatisfied/i, key: [ :support, :complaints ] },
    { match: /human|escalat|real person|speak.*someone/i, key: [ :support, :escalation ] },

    # Generic apply — LAST so it doesn't swallow specific questions
    { match: /how (do i|to) apply|get started|sign up|start.*application/i, key: [ :process, :timeline ] }
  ].freeze

  GREETING_PATTERNS = /\A\s*(hi|hello|hey|g'day|good\s*(morning|afternoon|evening)|thanks|thank you|cheers)\s*[!.]?\s*\z/i

  GREETING_RESPONSE = "Welcome. I'm the FutureProof assistant, your EPM specialist. " \
    "I can answer questions about how the Equity Preservation Mortgage works, eligibility, " \
    "the application process, and how it compares to other products. What would you like to know?"

  # Abusive or inappropriate language
  ABUSE_PATTERNS = [
    /\b(fuck|shit|ass\b|bitch|bastard|damn|crap|dick|cock|cunt|wanker|piss|bullshit)\b/i,
    /\b(idiot|stupid|moron|dumb|suck|loser|trash|garbage|useless)\b/i,
    /\b(kill\s+you|threat|bomb|attack)\b/i
  ].freeze

  ABUSE_RESPONSE = "I'm here to help with EPM questions. If you're frustrated, I understand — " \
    "and I'd recommend speaking with our team directly at support@futureproof.com.au or 1300 388 873. " \
    "Otherwise, ask me anything about the Equity Preservation Mortgage."

  # Off-topic questions (not EPM-related)
  OFF_TOPIC_RESPONSE = "That's outside my area. I specialise in the Equity Preservation Mortgage. " \
    "Here's what I can help with:\n\n" \
    "• **What is an EPM** — how it works and why it's different\n" \
    "• **Eligibility** — requirements and property types\n" \
    "• **Application process** — timeline, documents, and next steps\n" \
    "• **Lender information** — funding EPM mortgages\n" \
    "• **Contact support** — reach our team directly\n\n" \
    "What would you like to know?"

  def initialize(session_id:, region: "au", claude_service: :default, user: nil)
    @session_id = session_id
    @region = region
    @user = user
    @claude_service = if claude_service == :default
                        ClaudeChatService.available? ? ClaudeChatService.new : nil
    else
                        claude_service
    end
  end

  def self.create_session(user: nil, region: "au")
    session_id = SecureRandom.uuid
    new(session_id: session_id, region: region, user: user)
  end

  def respond(user_message:, conversation_history: [])
    escalate = should_escalate?(user_message)

    # Check for proprietary questions first
    if proprietary_question?(user_message)
      return {
        success: true,
        response: PROPRIETARY_RESPONSE,
        source: :knowledge_base,
        escalate: escalate
      }
    end

    # Check for abusive language
    if abusive_message?(user_message)
      return {
        success: true,
        response: ABUSE_RESPONSE,
        source: :knowledge_base,
        escalate: should_escalate?(user_message)
      }
    end

    # Check for greetings
    if user_message.strip.match?(GREETING_PATTERNS)
      return {
        success: true,
        response: GREETING_RESPONSE,
        source: :knowledge_base,
        escalate: false
      }
    end

    # Live Claude when configured; falls back silently to the regex KB on error
    if @claude_service
      claude_result = ask_claude(user_message: user_message, conversation_history: conversation_history, escalate: escalate)
      if claude_result
        persist!(user_message: user_message, result: claude_result)
        return claude_result
      end
    end

    fallback = fallback_to_knowledge_base(user_message: user_message, escalate: escalate)
    persist!(user_message: user_message, result: fallback)
    fallback
  end

  private

  def persist!(user_message:, result:)
    return unless @user
    conversation = ChatConversation.find_or_create_by!(user: @user, status: "active") do |c|
      c.chat_agent = support_agent
      c.region = @region
    end

    ChatMessage.create!(
      chat_conversation: conversation,
      role: "user",
      content: user_message
    )
    ChatMessage.create!(
      chat_conversation: conversation,
      role: "agent",
      content: result[:response],
      metadata: {
        source: result[:source].to_s,
        escalate: result[:escalate],
        usage: result[:usage],
        tool_calls: result[:tool_calls],
        # Which prompt content served this call (slot => content sha, or "fallback")
        prompt_slots: result[:prompt_slots]
      }.compact
    )
  rescue StandardError => e
    Rails.logger.error("Failed to persist support chat: #{e.class}: #{e.message}")
  end

  def support_agent
    ChatAgent.find_by(name: "Akane") || ChatAgent.find_by(agent_type: "support") || ChatAgent.first
  end

  def ask_claude(user_message:, conversation_history:, escalate:)
    history = build_claude_history(conversation_history, user_message)
    prompt = CustomerSupportPrompt.build_with_refs(region: @region)
    Rails.logger.info("[PROMPT] support_chat region=#{@region} slots=#{prompt[:slots]}")
    chat_args = {
      system: prompt[:text],
      messages: history
    }
    if @user
      chat_args[:tools] = CustomerSupportTools.tool_definitions
      chat_args[:tool_dispatcher] = CustomerSupportTools.for(@user)
    end
    result = @claude_service.chat(**chat_args)
    return nil if result.text.blank?

    {
      success: true,
      response: result.text,
      source: :claude,
      escalate: escalate,
      usage: result.usage,
      tool_calls: result.tool_calls,
      prompt_slots: prompt[:slots]
    }
  rescue StandardError => e
    Rails.logger.error("Claude chat failed, falling back to KB: #{e.class}: #{e.message}")
    nil
  end

  def build_claude_history(history, user_message)
    history.map { |m| { role: m[:role] || m["role"], content: m[:content] || m["content"] } } +
      [ { role: "user", content: user_message } ]
  end

  def fallback_to_knowledge_base(user_message:, escalate:)
    response = match_knowledge_base(user_message)

    if response
      region_note = region_addendum(user_message)
      full_response = region_note ? "#{response}\n\n#{region_note}" : response

      {
        success: true,
        response: full_response,
        source: :knowledge_base,
        escalate: escalate
      }
    else
      {
        success: true,
        response: OFF_TOPIC_RESPONSE,
        source: :knowledge_base,
        escalate: escalate
      }
    end
  end

  def abusive_message?(message)
    ABUSE_PATTERNS.any? { |p| message.match?(p) }
  end

  def proprietary_question?(message)
    PROPRIETARY_PATTERNS.any? { |p| message.match?(p) }
  end

  def match_knowledge_base(message)
    matched = PATTERNS.find { |p| message.match?(p[:match]) }
    return nil unless matched

    category, key = matched[:key]
    KNOWLEDGE_BASE.dig(category, key)
  end

  def region_addendum(message)
    case @region
    when "au"
      "Note: As an Australian customer, complaints can be directed to AFCA if unresolved." if message.match?(/complain|dispute/i)
    when "us"
      "Note: EPM is not a HECM (Home Equity Conversion Mortgage). It is a distinct product." if message.match?(/reverse|hecm/i)
    when "nz"
      "Note: In New Zealand, you have a 5-day cooling-off period under the CCCFA." if message.match?(/cooling|cancel/i)
    when "uk"
      "Note: EPM is not an equity release product. It is regulated separately under FCA guidelines." if message.match?(/equity release|reverse/i)
    end
  end

  def should_escalate?(user_message)
    triggers = [
      /complain/i, /legal action/i, /lawyer/i, /sue/i,
      /payment.*(wrong|missing|error)/i, /fraud/i, /hack/i,
      /suicid/i, /harm/i, /die/i, /kill/i,
      /account.*(lock|hack|steal)/i
    ]

    triggers.any? { |t| user_message.match?(t) }
  end
end
