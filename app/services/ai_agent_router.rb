# AiAgentRouter - Routes chat queries to the appropriate AI agent
#
# Determines the best agent based on:
# - User's current page/context
# - Message content keywords
# - User's application status
# - Region
#
class AiAgentRouter
  KEYWORD_PATTERNS = {
    "onboarding" => %w[quote calculator apply application sign\ up register get\ started how\ does eligible eligibility],
    "loan_specialist" => %w[investment portfolio returns income payment monthly interest rate loan mortgage balance performance],
    "legal" => %w[contract terms conditions privacy policy compliance regulation legal rights dispute cooling-off],
    "support" => %w[help login password account error problem bug issue page loading broken]
  }.freeze

  # Pre-built responses for common questions (mock implementation)
  MOCK_RESPONSES = {
    "onboarding" => {
      default: "Welcome to FutureProof! I can help you understand how our Equity Preservation Mortgage works and guide you through the application process. What would you like to know?",
      patterns: {
        /how does.*work/i => "An EPM allows you to convert your home equity into tax-free retirement income while preserving 100% of your property value. Here's how:\n\n1. We take a mortgage over your property (up to 80% LTV)\n2. The loan amount is invested in diversified index funds\n3. Investment returns pay your monthly income AND the mortgage interest\n4. Your equity is preserved — your home value stays intact for your family\n\nWould you like to get a personalised quote?",
        /eligib/i => "To be eligible for an EPM, you need:\n• Be at least 18 years old\n• Own a property valued at $500,000 or more\n• The property must be in a supported region (AU, NZ, UK, or US)\n\nUnlike traditional reverse mortgages, there are no upper age restrictions. Would you like to check your eligibility?",
        /quote|calculat/i => "I can help you get a quick estimate! To calculate your potential monthly income, I'll need:\n• Your property value\n• Your preferred loan term (10, 15, 20, 25, or 30 years)\n\nYou can also use our interactive calculator on the homepage. Shall I walk you through it?",
        /apply|application/i => "Great! The application process has 5 simple steps:\n1. Personal details\n2. Property information\n3. Property valuation\n4. Loan preferences\n5. Document upload & review\n\nYou can save and continue at any time. The whole process typically takes 15-20 minutes. Ready to start?"
      }
    },
    "loan_specialist" => {
      default: "I'm your loan specialist. I can help with questions about your EPM investment performance, monthly income, or loan details. What would you like to know?",
      patterns: {
        /income|payment|monthly/i => "Your monthly income is calculated from the returns on your investment portfolio. The expected rate is approximately 1.5% of your property value per annum, paid monthly. Your actual income may vary based on market performance, but our insurance mechanism protects against shortfalls.",
        /invest|portfolio|return/i => "Your EPM investment portfolio is structured as:\n• ~70% Reinvestment Portion (S&P 500 index ETFs)\n• ~30% Annuity Portion (government bonds & fixed income)\n\nHistorical average returns have been approximately 10% p.a. for equities. The portfolio is actively managed and rebalanced quarterly.",
        /interest|rate/i => "The interest on your EPM loan is paid entirely from your investment returns — you don't pay it out of pocket. The rate is disclosed as the applicable comparison rate for your region. All interest payments are transparent and shown in your quarterly statement."
      }
    },
    "legal" => {
      default: "I can help with questions about contracts, terms, privacy, and regulatory compliance. What would you like to know?",
      patterns: {
        /cool.*off/i => "You have a cooling-off period after signing your EPM contract. The duration depends on your region:\n• Australia: 10 business days\n• New Zealand: 5 working days\n• United Kingdom: 14 calendar days\n• United States: 3 business days\n\nDuring this period, you can cancel without penalty.",
        /privacy|data/i => "Your personal data is protected under the applicable privacy legislation for your region. We use AES-256 encryption at rest, TLS 1.3 in transit, and strict role-based access controls. You can view our full Privacy Policy in the Legal Documents section.",
        /contract|terms/i => "Your EPM contract covers all the key terms including loan amount, term, income payments, equity preservation guarantee, insurance coverage, and early repayment options. You can review region-specific contracts and terms in our Legal Documents section."
      }
    },
    "support" => {
      default: "I'm here to help with any technical issues. What's going wrong?",
      patterns: {
        /password|login/i => "If you're having trouble logging in:\n1. Click 'Forgot Password' on the login page\n2. Enter your email address\n3. Check your inbox for a reset link\n4. Create a new password\n\nIf you're still having issues, please contact support@futureprooffinancial.co.",
        /error|problem|broken/i => "I'm sorry you're experiencing issues. Could you tell me:\n1. What page were you on?\n2. What action were you trying to take?\n3. What error message did you see?\n\nThis will help me diagnose the problem quickly."
      }
    }
  }.freeze

  class << self
    def route(message:, user: nil, page_context: nil, region: "us")
      agent_type = determine_agent_type(message, page_context, user)
      agent = find_agent(agent_type, region)
      response = generate_response(agent_type, message)

      {
        agent: agent,
        agent_type: agent_type,
        response: response,
        confidence: calculate_confidence(message, agent_type)
      }
    end

    private

    def determine_agent_type(message, page_context, user)
      # First check page context
      return "onboarding" if page_context&.include?("calculator") || page_context&.include?("get-started")
      return "loan_specialist" if page_context&.include?("dashboard") && user&.persisted?

      # Then check message keywords
      best_match = nil
      best_score = 0

      KEYWORD_PATTERNS.each do |type, keywords|
        score = keywords.count { |kw| message.downcase.include?(kw) }
        if score > best_score
          best_score = score
          best_match = type
        end
      end

      best_match || "onboarding"
    end

    def find_agent(agent_type, region)
      ChatAgent.active.by_type(agent_type).for_region(region).first ||
        ChatAgent.active.by_type(agent_type).first ||
        ChatAgent.active.first
    end

    def generate_response(agent_type, message)
      responses = MOCK_RESPONSES[agent_type] || MOCK_RESPONSES["onboarding"]

      # Check pattern matches
      responses[:patterns]&.each do |pattern, response|
        return response if message.match?(pattern)
      end

      # Return default response
      responses[:default]
    end

    def calculate_confidence(message, agent_type)
      keywords = KEYWORD_PATTERNS[agent_type] || []
      matches = keywords.count { |kw| message.downcase.include?(kw) }
      [(matches * 0.3 + 0.4).round(2), 1.0].min
    end
  end
end
