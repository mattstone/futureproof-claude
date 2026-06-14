# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Load all seed files
Dir[Rails.root.join('db', 'seeds', '*.rb')].each do |seed_file|
  puts "🌱 Loading #{File.basename(seed_file)}..."
  require seed_file
end

# Create a test user for development
if Rails.env.development?
  user = User.find_or_create_by(email: 'test@example.com') do |u|
    u.password = 'password123'
    u.password_confirmation = 'password123'
  end

  if user.persisted?
    puts "✅ Test user created successfully: #{user.email}"
    puts "🔐 User confirmation status: #{user.confirmed? ? 'Confirmed' : 'Pending confirmation'}"
    puts "📧 Confirmation token: #{user.confirmation_token}" if user.confirmation_token
  else
    puts "❌ Failed to create test user"
    puts user.errors.full_messages
  end
end

# AI agent roster (idempotent). Five agents: four product agents co-located in
# their functional areas + Motoko, the master engineering/ops agent.
[
  { name: "Akane",  agent_type: "applications",     avatar: "Akane.png",  role: "Application Processing Specialist" },
  { name: "Rie",    agent_type: "backoffice",       avatar: "Rie.png",    role: "Back Office Operations Assistant" },
  { name: "Yumi",   agent_type: "investment",       avatar: "Yumi.png",   role: "Investment Advisory Specialist" },
  { name: "Misato", agent_type: "customer_service", avatar: "Yumi.png",   role: "Customer Service Specialist" },
  { name: "Motoko", agent_type: "engineering",      avatar: "Motoko.png", role: "Master Engineering & Operations Agent" }
].each do |spec|
  agent = AiAgent.find_or_initialize_by(name: spec[:name])
  agent.update!(agent_type: spec[:agent_type], avatar_filename: spec[:avatar],
                role_title: spec[:role], greeting_style: agent.greeting_style.presence || "professional",
                is_active: true)
end
