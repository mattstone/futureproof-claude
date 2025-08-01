class UserMailer < ApplicationMailer
  # Subject can be set in your I18n file at config/locales/en.yml
  # with the following lookup:
  #
  #   en.user_mailer.verification_code.subject
  #
  def verification_code(user)
    @user = user
    @verification_code = user.verification_code
    @expires_at = user.verification_code_expires_at

    mail(
      to: user.email,
      subject: 'Verify Your Futureproof Account'
    )
  end

  def security_notification(user, browser_signature, browser_info, ip_address = nil, location = nil)
    @user = user
    @browser_signature = browser_signature
    @browser_info = browser_info
    @ip_address = ip_address
    @location = location
    @sign_in_time = Time.current

    mail(
      to: user.email,
      subject: 'Security Alert: Sign-in from New Browser'
    )
  end
end
