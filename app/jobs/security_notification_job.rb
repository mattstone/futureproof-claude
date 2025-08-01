class SecurityNotificationJob < ApplicationJob
  include IpGeolocationHelper
  
  queue_as :default

  def perform(user_id, browser_signature, browser_info, ip_address = nil)
    user = User.find(user_id)
    
    # Get location for IP address if provided
    location = ip_address ? get_location_for_ip(ip_address) : nil
    
    # Send the security notification email with browser and location information
    UserMailer.security_notification(user, browser_signature, browser_info, ip_address, location).deliver_now
  end
end
