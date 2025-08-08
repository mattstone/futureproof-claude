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
