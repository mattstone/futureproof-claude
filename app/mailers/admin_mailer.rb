class AdminMailer < ApplicationMailer
  # Daily "what needs attention" digest for admins — same content as the
  # dashboard's recommendations card, delivered instead of waiting to be found.
  def daily_attention_digest(to:, recommendations:, counts:)
    @recommendations = recommendations
    @counts = counts

    mail(
      to: to,
      subject: "FutureProof admin digest — #{counts.values.sum} items need attention",
      from: "admin@futureprooffinancial.co"
    )
  end

  def test_email(to:, subject:, content:)
    @content = content.html_safe
    @subject = subject

    mail(
      to: to,
      subject: "[TEST] #{@subject}",
      from: "admin@futureprooffinancial.co"
    )
  end

  def workflow_email(to:, subject:, content:)
    @content = content.html_safe
    @subject = subject

    mail(
      to: to,
      subject: @subject,
      from: "info@futureprooffinancial.co"
    )
  end
end
