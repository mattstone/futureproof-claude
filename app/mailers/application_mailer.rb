class ApplicationMailer < ActionMailer::Base
  default from: "info@futureprooffinancial.co"
  layout "mailer"

  def message_notification(application_message)
    @message = application_message
    @application = application_message.application
    @user = @application.user
    @sender = application_message.sender
    
    # Generate the secure link for customer to access their application messages
    @application_link = messages_application_url(@application, token: generate_secure_token)
    
    mail(
      to: @user.email,
      subject: @message.subject
    )
  end
  
  private
  
  def generate_secure_token
    # Generate a secure token that expires in 24 hours
    payload = {
      application_id: @application.id,
      user_id: @user.id,
      expires_at: 24.hours.from_now.to_i
    }
    
    # Use Rails' message encryptor for secure tokens
    Rails.application.message_encryptor(:secure_tokens).encrypt_and_sign(payload)
  end
end
