# User browser tracking concern
# Handles browser signature tracking for security purposes
module User::BrowserTracking
  extend ActiveSupport::Concern

  # Track a new browser signature for this user
  def track_browser(signature, ip_address = nil, user_agent = nil)
    return if signature.blank?

    # Add signature to array if not already present
    current_signatures = browser_signatures || []
    unless current_signatures.include?(signature)
      current_signatures << signature
      update_column(:browser_signatures, current_signatures)

      # Log for security monitoring
      Rails.logger.info "New browser signature tracked for user #{id}: #{signature}"
    end
  end

  # Check if browser signature is known
  def known_browser?(signature)
    return false if signature.blank?
    return false if browser_signatures.blank?

    browser_signatures.include?(signature)
  end

  # Remove a browser signature (e.g., user logs out from specific device)
  def remove_browser_signature(signature)
    return unless browser_signatures.present?

    current_signatures = browser_signatures.dup
    current_signatures.delete(signature)
    update_column(:browser_signatures, current_signatures)
  end

  # Clear all browser signatures (e.g., security reset)
  def clear_all_browsers
    update_column(:browser_signatures, [])
  end

  # Count of tracked browsers
  def tracked_browsers_count
    (browser_signatures || []).count
  end
end