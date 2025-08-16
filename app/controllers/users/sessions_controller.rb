class Users::SessionsController < Devise::SessionsController
  include BrowserFingerprintHelper

  # Override create to track sign-ins from unknown browsers and handle lender scoping
  def create
    super do |resource|
      if resource.persisted?
        track_browser_sign_in(resource)
      end
    end
  end

  protected

  # Override the authentication method to include lender_id
  def auth_options
    options = super
    
    # Add lender_id to authentication conditions if provided
    if params[:lender_id].present?
      options[:lender_id] = params[:lender_id]
    elsif params[:user] && params[:user][:lender_id].present?
      options[:lender_id] = params[:user][:lender_id]
    end
    
    options
  end

  private

  def track_browser_sign_in(user)
    # Generate browser signature and extract browser info
    browser_signature = generate_browser_signature(request)
    browser_info = extract_browser_info(request)
    ip_address = request.remote_ip
    
    return if browser_signature.blank?

    # Check if this is a new browser signature and send notification if so
    was_unknown_browser = user.update_browser_tracking(browser_signature, browser_info)
    
    if was_unknown_browser
      # Send security notification in background to avoid delaying the response
      SecurityNotificationJob.perform_later(user.id, browser_signature, browser_info, ip_address)
    end
  end
end