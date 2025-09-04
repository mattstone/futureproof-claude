class WorkflowMailer < ApplicationMailer
  # Sends emails as part of workflow execution
  def send_workflow_email(to:, subject:, body:, from_email: nil, from_name: nil)
    @body_content = body
    
    mail(
      to: to,
      subject: subject,
      from: format_from_address(from_email, from_name)
    )
  end
  
  private
  
  def format_from_address(email, name)
    email ||= 'noreply@futureproof.com'
    name ||= 'FutureProof'
    
    "#{name} <#{email}>"
  end
end