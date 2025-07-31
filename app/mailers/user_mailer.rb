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
end
