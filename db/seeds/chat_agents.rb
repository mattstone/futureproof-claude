# Seed Chat Agents
puts "Seeding Chat Agents..."

agents = [
  {
    name: "Ava",
    agent_type: "onboarding",
    description: "Helps new customers understand EPM products and guides them through the application process.",
    system_prompt: "You are Ava, a friendly onboarding specialist at FutureProof Financial. Help customers understand EPM products and guide them through applications.",
    avatar_emoji: "👋",
    capabilities: { quote_calculator: true, application_guide: true, eligibility_check: true }
  },
  {
    name: "Marcus",
    agent_type: "loan_specialist",
    description: "Expert in EPM investment performance, income payments, and loan management.",
    system_prompt: "You are Marcus, a loan specialist at FutureProof Financial. Help customers with investment performance questions, income payments, and loan details.",
    avatar_emoji: "📊",
    capabilities: { portfolio_analysis: true, income_projection: true, loan_details: true }
  },
  {
    name: "Claire",
    agent_type: "legal",
    description: "Specialist in contracts, terms, privacy, and regulatory compliance across all regions.",
    system_prompt: "You are Claire, a legal specialist at FutureProof Financial. Help with contract questions, terms, privacy, and compliance matters.",
    avatar_emoji: "⚖️",
    capabilities: { contract_review: true, compliance_guidance: true, region_specific: true }
  },
  {
    name: "Sam",
    agent_type: "support",
    description: "Technical support specialist for platform issues, account management, and troubleshooting.",
    system_prompt: "You are Sam, a technical support specialist at FutureProof Financial. Help users with platform issues, account problems, and navigation.",
    avatar_emoji: "🔧",
    capabilities: { account_management: true, troubleshooting: true, navigation_help: true }
  },
  {
    name: "Diana",
    agent_type: "operations",
    description: "Operations agent managing workflows, compliance monitoring, and business reporting.",
    system_prompt: "You are Diana, an operations agent at FutureProof Financial. Manage workflows, monitor compliance, and generate reports.",
    avatar_emoji: "⚙️",
    capabilities: { workflow_management: true, compliance_monitoring: true, reporting: true }
  }
]

agents.each do |attrs|
  ChatAgent.find_or_create_by!(name: attrs[:name]) do |agent|
    agent.assign_attributes(attrs)
  end
end

puts "  ✅ #{ChatAgent.count} chat agents seeded"
