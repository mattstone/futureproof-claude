# AiAgentRouter - Routes chat messages to appropriate agents with regional awareness
# 
# Agents: Onboarding, Loan Specialist, Legal, Technical Support, Operations
# Provides mock responses for each agent type based on region
#
class AiAgentRouter
  AGENT_TYPES = {
    onboarding: "Onboarding Specialist",
    loan_specialist: "Loan Specialist",
    legal: "Legal Advisor",
    technical: "Technical Support",
    operations: "Operations Manager"
  }.freeze

  AGENT_SKILLS = {
    onboarding: ["application", "eligibility", "process", "timeline"],
    loan_specialist: ["rates", "terms", "income", "calculation", "approval"],
    legal: ["contract", "terms", "obligations", "rights", "dispute"],
    technical: ["platform", "dashboard", "login", "password", "error"],
    operations: ["settlement", "completion", "drawdown", "insurance"]
  }.freeze

  attr_reader :message, :region, :user

  def initialize(message:, region: "us", user: nil)
    @message = message.downcase
    @region = region.to_s.downcase
    @user = user
  end

  def route_and_respond
    agent_type = determine_agent(message)
    {
      agent_type: agent_type,
      agent_name: AGENT_TYPES[agent_type],
      response: generate_mock_response(agent_type),
      region: region
    }
  end

  private

  def determine_agent(msg)
    case msg
    when /appli|eligib|process|timeline/
      :onboarding
    when /rate|term|income|calcul|approv|epm/
      :loan_specialist
    when /contract|clause|obligation|right|legal|dispute/
      :legal
    when /platform|dashboard|login|password|error|technical/
      :technical
    when /settlement|completion|drawdown|insurance|closing/
      :operations
    else
      :onboarding  # Default agent
    end
  end

  def generate_mock_response(agent_type)
    case agent_type
    when :onboarding
      onboarding_response
    when :loan_specialist
      loan_specialist_response
    when :legal
      legal_response
    when :technical
      technical_response
    when :operations
      operations_response
    end
  end

  def onboarding_response
    case region
    when "au"
      "G'day! I'm your onboarding specialist. To qualify for FutureProof EPM in Australia, you need: age 55+, property value A$500k+, and Australian residency. Our process typically takes 2-4 weeks. What would you like to know?"
    when "us"
      "Hello! I'm your onboarding specialist. To qualify in the US, you need: age 55+, property value $500k+, US citizenship or permanent residency, and a clean credit report. Our process takes 3-5 weeks. How can I help?"
    when "nz"
      "Kia ora! I'm your onboarding specialist. For New Zealand, you need: age 55+, property value NZ$400k+, and NZ residency. We'll also need relationship property consent if applicable. What can I help with?"
    when "uk"
      "Hello! I'm your onboarding specialist. For the UK, you need: age 55+, property value £250k+, UK residency, and FCA compliance. Our process takes 4-6 weeks. What questions do you have?"
    else
      "Hi! I'm your onboarding specialist. Let me help you get started with FutureProof EPM. What would you like to know about our products and process?"
    end
  end

  def loan_specialist_response
    case region
    when "au"
      "G'day! As your loan specialist, I can help with your EPM quote. For a A$2M property at age 65, you might receive around A$2,500/month in income. This depends on your property value and term. We use a portfolio approach with 30% annuity and 70% equity investing. Would you like a personalised quote?"
    when "us"
      "Hello! As your loan specialist, I can provide a quote. For a $2M property, you might receive approximately $2,500/month in tax-free income. Our EPM uses 30% annuity for guaranteed returns and 70% equity indexing. NNEG insurance protects your estate. Want a detailed quote?"
    when "nz"
      "Hi! As your loan specialist, I can help you understand EPM returns. For a NZ$2M property, monthly income might be around NZ$2,500. We use diversified index funds with NNEG protection. Centrelink doesn't apply in NZ, but you should check with IRD on tax treatment. Questions?"
    when "uk"
      "Hello! As your loan specialist, I can assist with quotes and terms. For a £2M property, you might receive approximately £1,800/month in income. We use a diversified investment approach with FCA-compliant insurance. NNEG protection ensures you never owe more than your property is worth. Interested in a quote?"
    else
      "Hello! As your loan specialist, I'm here to discuss rates, terms, income calculations, and EPM features. What specific information would you like?"
    end
  end

  def legal_response
    case region
    when "au"
      "G'day! I'm your legal advisor. Key points about your EPM: NNEG protection means you can never owe more than your property value. You can sell anytime without penalty. Upon sale, proceeds go: Lender first, then Centrelink debt (if any), remainder to you. Any legal concerns about your contract?"
    when "us"
      "Hello! As your legal advisor, here's what you should know: NNEG (No Negative Equity Guarantee) protects your estate from owing more than the property is worth. You have full right to sell at any time. Upon death or sale, proceeds pay the Lender first, then your beneficiaries receive the balance. Any questions about your rights?"
    when "nz"
      "Hi! As your legal advisor, I want to make sure you understand: If your property is relationship property, your spouse's consent is needed. NNEG protects you from negative equity. You can sell anytime. Upon sale or death, the Lender is paid first. Do you have relationship property concerns?"
    when "uk"
      "Hello! As your legal advisor: NNEG protection is built into your mortgage—you cannot owe more than your property value. You have the right to sell at any time. For your estate, consider the IHT implications (40% on amounts above £325k). I recommend planning your will with a solicitor. Legal questions?"
    else
      "Hello! I'm your legal advisor. I can help explain contract terms, your rights and obligations, NNEG protection, and dispute resolution procedures. What legal aspect of your EPM can I clarify?"
    end
  end

  def technical_response
    "Hello! I'm your technical support. I can help with: logging into your dashboard, resetting your password, understanding your account statements, reporting errors, or navigating the platform. What technical issue can I assist with?"
  end

  def operations_response
    case region
    when "au"
      "G'day! As your operations manager, I help with settlement and completion. Once approved, we'll schedule your loan drawdown and investment setup. This typically takes 1-2 weeks. You'll receive quarterly statements showing portfolio balance, income, and NNEG status. Ready to move forward?"
    when "us"
      "Hello! As your operations manager, I oversee settlement and closing. After approval, we'll coordinate closing disclosure, final walkthrough, and fund disbursement. Your investment portfolio setup takes 1-2 weeks. You'll get quarterly statements and year-end tax documents. Any settlement questions?"
    when "nz"
      "Hi! As your operations manager, I manage settlement through a licensed settlement agent. After approval, we'll arrange your loan drawdown and investment setup. Settlement typically takes 2-3 weeks. You'll receive regular statements on your portfolio and income. Questions about settlement?"
    when "uk"
      "Hello! As your operations manager, I coordinate your completion and funding. After approval, we'll handle all regulatory requirements, FCA compliance, and fund disbursement. Completion takes 3-4 weeks. You'll receive statements quarterly showing your portfolio performance and NNEG status. Ready to proceed?"
    else
      "Hello! I'm your operations manager. I oversee loan settlement, completion, funding, and ongoing administration. What questions do you have about moving your loan to completion?"
    end
  end
end
