class BorrowerMailer < ApplicationMailer
  def payment_distributed(distribution)
    @distribution = distribution
    @application = distribution.application
    @user = @application.user

    # Check notification preferences
    return if @user.notification_preference && !@user.notification_preference.payment_email

    @amount = number_with_precision(distribution.amount, precision: 2, delimiter: ',')
    @property = @application.property_address
    @total_received = number_with_precision(
      @application.distributions.where(status: 'completed').sum(:amount),
      precision: 2,
      delimiter: ','
    )

    mail(
      to: @user.email,
      subject: "Your EPM Monthly Income Payment - $#{@amount}"
    )
  end

  def lender_message(message)
    @message = message
    @application = message.application
    @user = @application.user
    @lender = message.lender

    # Check notification preferences
    return if @user.notification_preference && !@user.notification_preference.message_email

    @preview = truncate(@message.message, length: 150)

    mail(
      to: @user.email,
      subject: "New Message from Your Lender"
    )
  end

  private

  def number_with_precision(number, precision: 2, delimiter: ',')
    ActionController::Base.helpers.number_with_precision(number, precision: precision, delimiter: delimiter)
  end

  def truncate(text, length: 30)
    ActionController::Base.helpers.truncate(text, length: length)
  end
end
