class AdminMailer < ApplicationMailer
  def test_email(to:, subject:, content:)
    @content = content.html_safe
    @subject = subject
    
    mail(
      to: to,
      subject: "[TEST] #{@subject}",
      from: "admin@futureprooffinancial.co"
    )
  end
end