# Preview all emails at http://localhost:3000/rails/mailers/contract_mailer
class ContractMailerPreview < ActionMailer::Preview
  # Preview this email at http://localhost:3000/rails/mailers/contract_mailer/message_notification
  def message_notification
    ContractMailer.message_notification
  end
end
