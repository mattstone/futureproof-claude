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
      
      # Set instance variables for layout
      @email_content = rendered[:content].html_safe
      @email_title = rendered[:subject]
      
      mail(
        to: user.email,
        subject: rendered[:subject]
      ) do |format|
        format.html { render inline: @email_content, layout: 'mailer' }
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
        sign_in_time: Time.current,
        event_type: 'New Browser Sign-in',
        device_type: extract_device_type(browser_info),
        os_info: extract_os_info(browser_info),
        risk_level: 'Low'
      })
      
      # Set instance variables for layout
      @email_content = rendered[:content].html_safe
      @email_title = rendered[:subject]
      
      mail(
        to: user.email,
        subject: rendered[:subject]
      ) do |format|
        format.html { render inline: @email_content, layout: 'mailer' }
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
      
      # Set instance variables for layout
      @email_content = rendered[:content].html_safe
      @email_title = rendered[:subject]
      
      mail(
        to: @user.email,
        subject: rendered[:subject]
      ) do |format|
        format.html { render inline: @email_content, layout: 'mailer' }
      end
    else
      # Fallback to original template
      mail(
        to: @user.email,
        subject: 'Your Equity Preservation Mortgage® Application Has Been Submitted'
      )
    end
  end

  private

  def extract_device_type(browser_info)
    return 'Unknown' if browser_info.blank?
    
    browser_string = browser_info.to_s.downcase
    
    if browser_string.include?('mobile') || browser_string.include?('android') || browser_string.include?('iphone')
      'Mobile Device'
    elsif browser_string.include?('tablet') || browser_string.include?('ipad')
      'Tablet'
    else
      'Desktop Computer'
    end
  end

  def extract_os_info(browser_info)
    return 'Unknown' if browser_info.blank?
    
    browser_string = browser_info.to_s.downcase
    
    if browser_string.include?('windows')
      'Windows'
    elsif browser_string.include?('mac') || browser_string.include?('macintosh')
      'macOS'
    elsif browser_string.include?('linux')
      'Linux'
    elsif browser_string.include?('android')
      'Android'
    elsif browser_string.include?('iphone') || browser_string.include?('ipad') || browser_string.include?('ios')
      'iOS'
    else
      'Unknown'
    end
  end
end
