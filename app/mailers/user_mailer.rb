class UserMailer < ApplicationMailer
  # Subject can be set in your I18n file at config/locales/en.yml
  # with the following lookup:
  #
  #   en.user_mailer.verification_code.subject
  #
  def verification_code(user)
    @user = user
    @verification_code = user.verification_code
    @expires_at = user.verification_code_expires_at

    # Use EmailTemplate if available
    template = EmailTemplate.for_type('verification')
    if template
      rendered = template.render_content({
        user: user,
        verification_code: user.verification_code,
        expires_at: user.verification_code_expires_at
      })
      
      mail(
        to: user.email,
        subject: rendered[:subject]
      ) do |format|
        format.html { render html: rendered[:content].html_safe }
      end
    else
      # Fallback to original template
      mail(
        to: user.email,
        subject: 'Verify Your Futureproof Account'
      )
    end
  end

  def security_notification(user, browser_signature, browser_info, ip_address = nil, location = nil)
    @user = user
    @browser_signature = browser_signature
    @browser_info = browser_info
    @ip_address = ip_address
    @location = location
    @sign_in_time = Time.current

    # Use EmailTemplate if available
    template = EmailTemplate.for_type('security_notification')
    if template
      rendered = template.render_content({
        user: user,
        browser_info: browser_info.to_s,
        ip_address: ip_address,
        location: location,
        sign_in_time: Time.current
      })
      
      mail(
        to: user.email,
        subject: rendered[:subject]
      ) do |format|
        format.html { render html: rendered[:content].html_safe }
      end
    else
      # Fallback to original template
      mail(
        to: user.email,
        subject: 'Security Alert: Sign-in from New Browser'
      )
    end
  end

  def application_submitted(application)
    @application = application
    @user = application.user

    # Use EmailTemplate if available
    template = EmailTemplate.for_type('application_submitted')
    if template
      rendered = template.render_content({
        user: @user,
        application: @application,
        mortgage: @application.mortgage
      })
      
      mail(
        to: @user.email,
        subject: rendered[:subject]
      ) do |format|
        format.html { render html: rendered[:content].html_safe }
      end
    else
      # Fallback to original template
      mail(
        to: @user.email,
        subject: 'Your Equity Preservation Mortgage® Application Has Been Submitted'
      )
    end
  end
end
