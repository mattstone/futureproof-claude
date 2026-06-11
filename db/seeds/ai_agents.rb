# Create AI Agents for customer service
puts "🤖 Creating AI Agents..."

# Acquisition Agent - Akane
akane = AiAgent.find_or_create_by(name: 'Akane') do |agent|
  agent.agent_type = 'applications'
  agent.avatar_filename = 'Akane.png'
  agent.role_title = 'Customer Acquisition Specialist'
  agent.description = 'Guides prospective customers through EPM questions, eligibility, and structured intake before handoff to a licensed adviser.'
  agent.specialties = 'EPM FAQs, eligibility assessments, structured intake, application guidance'
  agent.greeting_style = 'professional'
  agent.is_active = true
end

# Back Office Agent - Rie
rie = AiAgent.find_or_create_by(name: 'Rie') do |agent|
  agent.agent_type = 'backoffice'
  agent.avatar_filename = 'Rie.png'
  agent.role_title = 'Back Office Operations Assistant'
  agent.description = 'Handles operational queries, settlement processes, account management, and administrative tasks.'
  agent.specialties = 'Account management, settlement coordination, policy administration, operational support'
  agent.greeting_style = 'friendly'
  agent.is_active = true
end

# Investment Agent - Yumi
yumi = AiAgent.find_or_create_by(name: 'Yumi') do |agent|
  agent.agent_type = 'investment'
  agent.avatar_filename = 'Yumi.png'
  agent.role_title = 'Investment Advisory Specialist'
  agent.description = 'Provides guidance on investment strategies, market insights, and long-term financial planning.'
  agent.specialties = 'Investment strategies, market analysis, portfolio management, financial planning'
  agent.greeting_style = 'formal'
  agent.is_active = true
end

puts "✅ Created AI Agents:"
puts "   - #{akane.display_name} (#{akane.role_title})"
puts "   - #{rie.display_name} (#{rie.role_title})"
puts "   - #{yumi.display_name} (#{yumi.role_title})"
puts ""