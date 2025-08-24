namespace :admin do
  desc "Reset admin user password"
  task reset_password: :environment do
    # Look for admin user with either email
    admin_user = User.where(admin: true)
                    .where("email = ? OR email = ?", "admin@futureproof.com", "admin@futureprooffinancial.co")
                    .first

    if admin_user.nil?
      puts "No admin user found with either email"
      exit 1
    end

    # Update the email to the requested one and reset password
    admin_user.update!(
      email: "admin@futureprooffinancial.co",
      password: "pathword",
      password_confirmation: "pathword"
    )

    puts "✓ Admin user updated:"
    puts "  Email: #{admin_user.email}"
    puts "  Password: pathword"
    puts "  Admin: #{admin_user.admin?}"
  end
end