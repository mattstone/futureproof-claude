namespace :admin do
  desc "Create an admin user for the admin system"
  task setup: :environment do
    email = 'admin@futureprooffinancial.co'
    password = 'admin123'
    
    # Find or create admin user
    admin_user = User.find_by(email: email) || User.new(email: email)
    
    admin_user.assign_attributes(
      first_name: 'Admin',
      last_name: 'User',
      password: password,
      password_confirmation: password,
      country_of_residence: 'Australia',
      admin: true,
      confirmed_at: Time.current
    )
    
    if admin_user.save
      puts "✅ Admin user created successfully!"
      puts ""
      puts "Admin Login Details:"
      puts "===================="
      puts "Email: #{email}"
      puts "Password: #{password}"
      puts ""
      puts "You can access the admin system at: /admin"
      puts "Make sure to change the password after first login!"
    else
      puts "❌ Failed to create admin user:"
      admin_user.errors.full_messages.each do |error|
        puts "  - #{error}"
      end
    end
  end
end