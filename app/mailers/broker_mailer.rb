class BrokerMailer < ApplicationMailer
  # Send password setup link to newly created broker
  #
  # Called when admin creates a broker. Broker can click link to set their own password.
  def setup_password(broker, temp_token)
    @broker = broker
    @setup_url = new_broker_password_url(token: temp_token)
    mail(to: broker.email, subject: "Set up your FutureProof Broker Account")
  end

  # Send password reset link
  def reset_password(broker)
    @broker = broker
    @reset_url = edit_broker_password_reset_url(token: broker.reset_password_token)
    mail(to: broker.email, subject: "Reset Your FutureProof Broker Password")
  end
end
