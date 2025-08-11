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
    
    # Determine the from address and name based on the sender
    from_address = "info@futureprooffinancial.co"
    from_name = "Futureproof Financial Group"
    
    if @message.from_ai_agent? && @message.ai_agent
      from_name = @message.ai_agent.display_name
      # Keep the same email but change the display name
      from_email = "#{from_name} <#{from_address}>"
    else
      from_email = "#{from_name} <#{from_address}>"
    end
    
    mail(
      to: @user.email,
      from: from_email,
      subject: @message.processed_subject
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
    
    # Use secure token encryptor
    SecureTokenEncryptor.encrypt_and_sign(payload)
  end
end
