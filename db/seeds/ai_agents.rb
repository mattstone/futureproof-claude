# Create AI Agents for customer service
puts "🤖 Creating AI Agents..."

# Applications Agent - Motoko
motoko = AiAgent.find_or_create_by(name: 'Motoko') do |agent|
  agent.agent_type = 'applications'
  agent.avatar_filename = 'Motoko.png'
  agent.role_title = 'Application Processing Specialist'
  agent.description = 'Specializes in guiding customers through the application process, reviewing documentation, and providing updates on application status.'
  agent.specialties = 'Application reviews, document verification, status updates, eligibility assessments'
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
puts "   - #{motoko.display_name} (#{motoko.role_title})"
puts "   - #{rie.display_name} (#{rie.role_title})"
puts "   - #{yumi.display_name} (#{yumi.role_title})"
puts ""