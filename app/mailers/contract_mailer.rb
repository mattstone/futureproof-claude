class ContractMailer < ApplicationMailer
  def message_notification(contract_message)
    @message = contract_message
    @contract = contract_message.contract
    @application = @contract.application
    @user = @application.user
    @sender = contract_message.sender
    
    # Generate the secure link for customer to access their contract messages
    # Include the message ID to highlight the specific message
    @contract_link = messages_contract_url(@contract, token: generate_secure_token, message_id: @message.id)
    
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
      contract_id: @contract.id,
      user_id: @user.id,
      expires_at: 24.hours.from_now.to_i
    }
    
    # Use secure token encryptor
    SecureTokenEncryptor.encrypt_and_sign(payload)
  end
end
