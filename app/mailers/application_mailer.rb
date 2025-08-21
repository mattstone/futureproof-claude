class ApplicationMailer < ActionMailer::Base
  default from: "info@futureprooffinancial.co"
  layout "mailer"
  
  # Add callback to inline CSS for email client compatibility
  after_action :inline_css_for_email

  def message_notification(application_message)
    @message = application_message
    @application = application_message.application
    @user = @application.user
    @sender = application_message.sender
    
    # Generate the secure link for customer to access their application messages
    # Include the message ID to highlight the specific message
    @application_link = messages_application_url(@application, token: generate_secure_token, message_id: @message.id)
    
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
  
  # Inline CSS for email client compatibility while maintaining CSP compliance in templates
  def inline_css_for_email
    if mail.html_part
      # Get the HTML content
      html_content = mail.html_part.body.to_s
      
      # Inline CSS classes to styles for email compatibility
      inlined_html = EmailCssInlinerService.inline_css(html_content)
      
      # Update the mail body with inlined styles
      mail.html_part.body = inlined_html
    elsif mail.body && mail.content_type.include?('text/html')
      # Handle single-part HTML emails
      html_content = mail.body.to_s
      inlined_html = EmailCssInlinerService.inline_css(html_content)
      mail.body = inlined_html
    end
  end
  
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
