class EmailTemplate < ApplicationRecord
  has_many :email_template_versions, dependent: :destroy
  
  validates :name, presence: true, uniqueness: true
  validates :subject, presence: true
  validates :content, presence: true
  validates :template_type, presence: true, inclusion: { in: %w[verification application_submitted security_notification] }
  validates :email_category, presence: true, inclusion: { in: %w[operational marketing] }
  validates :content_body, presence: true
  validate :ensure_security_template_has_proper_padding
  
  # Virtual attribute for markup editor
  attr_accessor :markup_content
  
  scope :active, -> { where(is_active: true) }
  scope :by_type, ->(type) { where(template_type: type) }
  scope :by_category, ->(category) { where(email_category: category) }
  
  # Track changes with audit functionality
  attr_accessor :current_user
  
  after_create :log_creation
  after_update :log_update
  
  # Get the active template for a specific type
  def self.for_type(template_type)
    active.by_type(template_type).first || create_default_for_type(template_type)
  end
  
  # Available field placeholders for different template types
  def self.available_fields
    {
      'verification' => {
        'user' => %w[first_name last_name full_name email mobile_number country_of_residence],
        'verification' => %w[verification_code expires_at formatted_expires_at]
      },
      'application_submitted' => {
        'user' => %w[first_name last_name full_name email mobile_number],
        'application' => %w[id reference_number address home_value formatted_home_value existing_mortgage_amount formatted_existing_mortgage_amount loan_value formatted_loan_value borrower_age loan_term growth_rate formatted_growth_rate future_property_value formatted_future_property_value home_equity_preserved formatted_home_equity_preserved status status_display created_at updated_at submitted_at formatted_created_at formatted_updated_at formatted_submitted_at formatted_monthly_income_amount total_income_amount formatted_total_income_amount monthly_income_amount annuity_duration_years],
        'mortgage' => %w[name lvr formatted_lvr interest_rate mortgage_type_display]
      },
      'security_notification' => {
        'user' => %w[first_name last_name full_name email],
        'security' => %w[browser_info ip_address location sign_in_time event_type device_type os_info risk_level]
      }
    }
  end
  
  # Convert markup to HTML for email templates
  def markup_to_html(text)
    return "" if text.blank?
    
    html = text.dup
    
    # Convert line breaks to HTML paragraphs
    html = html.gsub(/\r\n|\r|\n/, "\n")
    paragraphs = html.split(/\n\s*\n/).reject(&:empty?)
    
    html_parts = []
    
    paragraphs.each do |paragraph|
      lines = paragraph.split("\n").map(&:strip).reject(&:empty?)
      next if lines.empty?
      
      lines.each do |line|
        # Handle headers
        if line.match(/^## (.+)$/)
          title = $1.strip
          html_parts << "<h2 style=\"color: #0891b2; font-size: 20px; margin: 24px 0 16px 0; font-weight: 600;\">#{sanitize_text(title)}</h2>"
        elsif line.match(/^### (.+)$/)
          subtitle = $1.strip
          html_parts << "<h3 style=\"color: #374151; font-size: 16px; margin: 20px 0 12px 0; font-weight: 600;\">#{sanitize_text(subtitle)}</h3>"
        # Handle bullet points
        elsif line.match(/^- (.+)$/)
          item = $1.strip
          html_parts << "<li style=\"margin-bottom: 4px;\">#{format_inline_markup(item)}</li>"
        # Handle regular paragraphs
        else
          html_parts << "<p style=\"margin: 16px 0; line-height: 1.6;\">#{format_inline_markup(line)}</p>"
        end
      end
    end
    
    # Wrap consecutive <li> elements in <ul>
    html_result = html_parts.join("\n")
    html_result = html_result.gsub(/(<li[^>]*>.*?<\/li>\s*)+/m) do |match|
      "<ul style=\"margin: 16px 0; padding-left: 24px;\">\n#{match}\n</ul>"
    end
    
    html_result
  end
  
  # Render template with data substitution and header/footer
  def render_content(data = {}, include_header_footer: true)
    data ||= {}

    # Use content_body if available (new system), otherwise fall back to content (backward compatibility)
    body_content = content_body.present? ? content_body.dup : content.dup
    rendered_subject = subject.dup

    # Apply data substitutions to body content and subject
    body_content = apply_data_substitutions(body_content, data)
    rendered_subject = apply_data_substitutions(rendered_subject, data)

    # Generate complete email with header and footer only if requested
    # (Skip when using Rails mailer layouts to avoid duplicate headers)
    if include_header_footer
      rendered_content = EmailHeaderFooterService.render_complete_email(email_category, body_content)
    else
      rendered_content = body_content
    end

    {
      subject: rendered_subject,
      content: rendered_content
    }
  end
  
  # Create default templates for each type
  def self.create_default_for_type(template_type)
    case template_type
    when 'verification'
      create!(
        name: 'Email Verification',
        template_type: 'verification',
        email_category: 'operational',
        subject: 'Verify Your Futureproof Account',
        description: 'Email sent to new users to verify their email address',
        content: verification_default_content,
        content_body: verification_default_body
      )
    when 'application_submitted'
      create!(
        name: 'Application Submitted',
        template_type: 'application_submitted',
        email_category: 'operational',
        subject: 'Your Equity Preservation Mortgage® Application Has Been Submitted',
        description: 'Email sent when user submits their mortgage application',
        content: application_submitted_default_content,
        content_body: application_submitted_default_body
      )
    when 'security_notification'
      create!(
        name: 'Security Notification',
        template_type: 'security_notification',
        email_category: 'operational',
        subject: 'Security Alert: Sign-in from New Browser',
        description: 'Email sent when user signs in from a new browser',
        content: security_notification_default_content,
        content_body: security_notification_default_body
      )
    else
      raise ArgumentError, "Unknown template type: #{template_type}"
    end
  end
  
  private
  
  # Apply data substitutions to text content
  def apply_data_substitutions(text, data = {})
    return text if text.blank?
    
    processed_text = text.dup
    
    # User fields
    if data[:user]
      user = data[:user]
      processed_text.gsub!(/{{user\.first_name}}/i, safe_field_value(user, :first_name))
      processed_text.gsub!(/{{user\.last_name}}/i, safe_field_value(user, :last_name))
      processed_text.gsub!(/{{user\.full_name}}/i, safe_field_value(user, :full_name))
      processed_text.gsub!(/{{user\.email}}/i, safe_field_value(user, :email))
      processed_text.gsub!(/{{user\.mobile_number}}/i, safe_field_value(user, :full_mobile_number))
      processed_text.gsub!(/{{user\.country_of_residence}}/i, safe_field_value(user, :country_of_residence))
    end
    
    # Application fields
    if data[:application]
      app = data[:application]
      processed_text.gsub!(/{{application\.id}}/i, safe_field_value(app, :id))
      processed_text.gsub!(/{{application\.reference_number}}/i, safe_field_value(app, :id).rjust(6, '0'))
      processed_text.gsub!(/{{application\.address}}/i, safe_field_value(app, :address))
      processed_text.gsub!(/{{application\.home_value}}/i, safe_field_value(app, :home_value))
      processed_text.gsub!(/{{application\.formatted_home_value}}/i, safe_field_value(app, :formatted_home_value))
      processed_text.gsub!(/{{application\.existing_mortgage_amount}}/i, safe_field_value(app, :existing_mortgage_amount))
      processed_text.gsub!(/{{application\.formatted_existing_mortgage_amount}}/i, safe_field_value(app, :formatted_existing_mortgage_amount))
      processed_text.gsub!(/{{application\.loan_value}}/i, safe_field_value(app, :loan_value))
      processed_text.gsub!(/{{application\.formatted_loan_value}}/i, safe_field_value(app, :formatted_loan_value))
      processed_text.gsub!(/{{application\.monthly_income_amount}}/i, safe_field_value(app, :monthly_income_amount))
      processed_text.gsub!(/{{application\.formatted_monthly_income_amount}}/i, safe_field_value(app, :formatted_monthly_income_amount))
      processed_text.gsub!(/{{application\.total_income_amount}}/i, safe_field_value(app, :total_income_amount))
      processed_text.gsub!(/{{application\.formatted_total_income_amount}}/i, safe_field_value(app, :formatted_total_income_amount))
      processed_text.gsub!(/{{application\.annuity_duration_years}}/i, safe_field_value(app, :annuity_duration_years))
      processed_text.gsub!(/{{application\.borrower_age}}/i, safe_field_value(app, :borrower_age))
      processed_text.gsub!(/{{application\.loan_term}}/i, safe_field_value(app, :loan_term))
      processed_text.gsub!(/{{application\.growth_rate}}/i, safe_field_value(app, :growth_rate))
      processed_text.gsub!(/{{application\.formatted_growth_rate}}/i, safe_field_value(app, :formatted_growth_rate))
      processed_text.gsub!(/{{application\.future_property_value}}/i, safe_field_value(app, :formatted_future_property_value))
      processed_text.gsub!(/{{application\.formatted_future_property_value}}/i, safe_field_value(app, :formatted_future_property_value))
      processed_text.gsub!(/{{application\.home_equity_preserved}}/i, safe_field_value(app, :formatted_home_equity_preserved))
      processed_text.gsub!(/{{application\.formatted_home_equity_preserved}}/i, safe_field_value(app, :formatted_home_equity_preserved))
      processed_text.gsub!(/{{application\.status}}/i, safe_field_value(app, :status))
      processed_text.gsub!(/{{application\.status_display}}/i, safe_field_value(app, :status_display))
      processed_text.gsub!(/{{application\.created_at}}/i, safe_field_value(app, :created_at))
      processed_text.gsub!(/{{application\.updated_at}}/i, safe_field_value(app, :updated_at))
      processed_text.gsub!(/{{application\.submitted_at}}/i, safe_field_value(app, :submitted_at))
      processed_text.gsub!(/{{application\.formatted_created_at}}/i, safe_field_value(app, :formatted_created_at))
      processed_text.gsub!(/{{application\.formatted_updated_at}}/i, safe_field_value(app, :formatted_updated_at))
      processed_text.gsub!(/{{application\.formatted_submitted_at}}/i, safe_field_value(app, :formatted_submitted_at))
    end
    
    # Mortgage fields
    if data[:mortgage]
      mortgage = data[:mortgage]
      processed_text.gsub!(/{{mortgage\.name}}/i, safe_field_value(mortgage, :name))
      processed_text.gsub!(/{{mortgage\.lvr}}/i, safe_field_value(mortgage, :lvr))
      processed_text.gsub!(/{{mortgage\.formatted_lvr}}/i, safe_field_value(mortgage, :formatted_lvr))
      processed_text.gsub!(/{{mortgage\.interest_rate}}/i, '7.45') # Static for now
      processed_text.gsub!(/{{mortgage\.mortgage_type_display}}/i, safe_field_value(mortgage, :mortgage_type_display))
    end
    
    # Verification fields
    if data[:verification_code]
      processed_text.gsub!(/{{verification\.verification_code}}/i, data[:verification_code].to_s)
    end
    if data[:expires_at]
      processed_text.gsub!(/{{verification\.expires_at}}/i, data[:expires_at].to_s)
      processed_text.gsub!(/{{verification\.formatted_expires_at}}/i, (data[:expires_at].strftime("%I:%M %p") rescue data[:expires_at].to_s))
    end
    
    # Security fields - always replace these fields with appropriate fallbacks
    browser_info = data[:browser_info].present? ? data[:browser_info].to_s : 'Unknown Browser'
    processed_text.gsub!(/{{security\.browser_info}}/i, browser_info)
    
    ip_address = data[:ip_address].present? ? data[:ip_address].to_s : 'Unknown IP'
    processed_text.gsub!(/{{security\.ip_address}}/i, ip_address)
    
    location_value = data[:location].present? ? data[:location].to_s : 'Unknown Location'
    processed_text.gsub!(/{{security\.location}}/i, location_value)
    
    sign_in_time = data[:sign_in_time].present? ? 
                   (data[:sign_in_time].strftime("%B %d, %Y at %I:%M %p") rescue data[:sign_in_time].to_s) : 
                   Time.current.strftime("%B %d, %Y at %I:%M %p")
    processed_text.gsub!(/{{security\.sign_in_time}}/i, sign_in_time)
    
    event_type = data[:event_type].present? ? data[:event_type].to_s : 'Sign-in Activity'
    processed_text.gsub!(/{{security\.event_type}}/i, event_type)
    
    device_type = data[:device_type].present? ? data[:device_type].to_s : 'Unknown Device'
    processed_text.gsub!(/{{security\.device_type}}/i, device_type)
    
    os_info = data[:os_info].present? ? data[:os_info].to_s : 'Unknown OS'
    processed_text.gsub!(/{{security\.os_info}}/i, os_info)
    
    risk_level = data[:risk_level].present? ? data[:risk_level].to_s : 'Unknown'
    processed_text.gsub!(/{{security\.risk_level}}/i, risk_level)
    
    processed_text
  end
  
  def safe_field_value(object, method_name)
    return '' unless object
    
    if object.respond_to?(method_name)
      value = object.send(method_name)
      value.to_s
    else
      ''
    end
  rescue => e
    Rails.logger.warn "EmailTemplate: Error accessing #{method_name} on #{object.class}: #{e.message}"
    ''
  end
  
  # Format inline markup like **bold** and *italic*
  def format_inline_markup(text)
    return "" if text.blank?
    
    formatted = sanitize_text(text)
    # Convert **bold** to <strong>
    formatted = formatted.gsub(/\*\*(.+?)\*\*/, '<strong>\1</strong>')
    # Convert *italic* to <em>
    formatted = formatted.gsub(/\*(.+?)\*/, '<em>\1</em>')
    
    formatted
  end
  
  # Sanitize text for HTML output
  def sanitize_text(text)
    return "" if text.blank?
    # Escape HTML but preserve special characters and placeholders
    text.to_s.gsub(/[<>"]/, {
      '<' => '&lt;',
      '>' => '&gt;',
      '"' => '&quot;'
    }).strip
  end
  
  def log_creation
    return unless current_user
    
    email_template_versions.create!(
      user: current_user,
      action: 'created',
      change_details: "Created new email template '#{name}' of type '#{template_type}'",
      new_content: content,
      new_subject: subject
    )
  end
  
  def log_update
    return unless current_user
    
    if saved_change_to_is_active?
      # Log activation/deactivation
      action = is_active? ? 'activated' : 'deactivated'
      email_template_versions.create!(
        user: current_user,
        action: action,
        change_details: "#{action.humanize} email template '#{name}'"
      )
    elsif saved_change_to_content? || saved_change_to_subject? || saved_change_to_content_body?
      # Log content/subject update
      email_template_versions.create!(
        user: current_user,
        action: 'updated',
        change_details: build_change_summary,
        previous_content: saved_change_to_content ? saved_change_to_content[0] : nil,
        new_content: saved_change_to_content ? saved_change_to_content[1] : nil,
        previous_subject: saved_change_to_subject ? saved_change_to_subject[0] : nil,
        new_subject: saved_change_to_subject ? saved_change_to_subject[1] : nil
      )
    end
  end
  
  def build_change_summary
    changes_list = []
    
    if saved_change_to_subject?
      changes_list << "Subject changed from '#{saved_change_to_subject[0]}' to '#{saved_change_to_subject[1]}'"
    end
    
    if saved_change_to_content? || saved_change_to_content_body?
      changes_list << "Content updated"
    end
    
    if saved_change_to_name?
      changes_list << "Name changed from '#{saved_change_to_name[0]}' to '#{saved_change_to_name[1]}'"
    end
    
    if saved_change_to_email_category?
      changes_list << "Email category changed from '#{saved_change_to_email_category[0]}' to '#{saved_change_to_email_category[1]}'"
    end
    
    changes_list.join("; ")
  end

  # Custom validation to ensure security notification templates maintain proper padding
  def ensure_security_template_has_proper_padding
    return unless template_type == 'security_notification' 
    
    content_to_check = content_body.present? ? content_body : content
    return unless content_to_check.present?
    
    # Check for the specific pattern that was causing issues
    # The sign-in details table cell should have proper padding
    if content_to_check.include?('Sign-in Details') || content_to_check.include?('sign-in details')
      # Look for table cells with zero padding that contain security details
      if content_to_check.match?(/td\s+style="[^"]*padding:\s*0[^"]*"[^>]*>.*?(Sign-in Details|sign-in details|Time:|Browser:|IP Address:|Location:)/mi)
        errors.add(:content_body, "Security notification template must have proper padding in sign-in details section. " \
                            "Use 'padding: 20px 24px;' or similar instead of 'padding: 0;' for better email formatting.")
      end
      
      # Also warn if no padding is found at all in cells containing security details
      unless content_to_check.match?(/td\s+style="[^"]*padding:\s*(?!0)[^"]*"[^>]*>.*?(Sign-in Details|Time:|Browser:|IP Address:|Location:)/mi)
        # Only add warning if Sign-in Details section exists but has no padding
        if content_to_check.match?(/(Sign-in Details|Time:|Browser:|IP Address:|Location:)/mi)
          errors.add(:content_body, "Security notification template should include proper cell padding (e.g., 'padding: 20px 24px;') " \
                              "in the sign-in details section for professional email appearance.")
        end
      end
    end
  end

  # Default content methods for cleaner code
  def self.verification_default_body
    <<~HTML
      <div style="text-align: center; margin-bottom: 32px;">
        <h1 style="margin: 0; color: #374151; font-size: 24px; font-weight: 600;">Welcome to Futureproof!</h1>
      </div>

      <div style="text-align: center; margin-bottom: 24px;">
        <p style="margin: 24px 0 0 0; color: #374151; font-size: 16px;">Dear {{user.first_name}},</p>
        
        <hr style="border: none; border-top: 1px solid #e5e7eb; margin: 20px auto; width: 60%;">
        
        <p style="margin: 16px 0 0 0; color: #6b7280; font-size: 14px;">
          Thank you for creating your Futureproof account. To complete your registration, please verify your email address using the code below.
        </p>
      </div>

      <table role="presentation" style="width: 100%; border-collapse: collapse; border: 0; border-spacing: 0; margin: 32px 0;">
        <tr>
          <td align="center" style="padding: 0;">
            <table role="presentation" style="background-color: #f0f9ff; border: 2px solid #0891b2; border-radius: 8px; padding: 24px; margin: 0 auto;">
              <tr>
                <td align="center" style="padding: 0;">
                  <div style="font-size: 32px; font-weight: 700; color: #0891b2; letter-spacing: 6px; font-family: 'Courier New', monospace;">
                    {{verification.verification_code}}
                  </div>
                </td>
              </tr>
            </table>
          </td>
        </tr>
      </table>

      <div style="text-align: center; margin: 32px 0;">
        <p style="margin: 0; color: #6b7280; font-size: 14px;">
          This code expires at {{verification.formatted_expires_at}}
        </p>
      </div>

      <div style="text-align: center; margin: 32px 0;">
        <div style="background-color: #fef3c7; border-radius: 8px; padding: 20px; max-width: 400px; margin: 0 auto;">
          <h3 style="color: #d97706; margin: 0 0 12px 0; font-size: 16px;">Security Notice</h3>
          <p style="margin: 0; color: #92400e; font-size: 14px;">
            If you didn't create this account, please ignore this email.
          </p>
        </div>
      </div>
    HTML
  end
  
  def self.verification_default_content
    # Backward compatibility - return full content with basic header/footer
    EmailHeaderFooterService.render_complete_email('operational', verification_default_body)
  end
  
  # Additional default content methods would go here for other templates...
  def self.application_submitted_default_body
    # This would contain the body content for application submitted emails
    # For now, return existing content from migration
    ""
  end
  
  def self.application_submitted_default_content
    EmailHeaderFooterService.render_complete_email('operational', application_submitted_default_body)
  end
  
  def self.security_notification_default_body
    <<~HTML
      <div style="text-align: center; margin-bottom: 32px;">
        <h1 style="margin: 0; color: #374151; font-size: 24px; font-weight: 600;">🔐 Security Alert</h1>
      </div>

      <div style="text-align: center; margin-bottom: 24px;">
        <p style="margin: 24px 0 0 0; color: #374151; font-size: 16px;">Dear {{user.first_name}},</p>
        
        <hr style="border: none; border-top: 1px solid #e5e7eb; margin: 20px auto; width: 60%;">
        
        <p style="margin: 16px 0 0 0; color: #6b7280; font-size: 14px;">
          We detected a sign-in to your Futureproof account from a new browser or device.
        </p>
      </div>

      <table role="presentation" style="width: 100%; border-collapse: collapse; border: 0; border-spacing: 0; margin: 32px 0;">
        <tr>
          <td align="center" style="padding: 0;">
            <table role="presentation" style="background-color: #fef3c7; border: 2px solid #f59e0b; border-radius: 8px; padding: 24px; margin: 0 auto; max-width: 400px;">
              <tr>
                <td style="padding: 20px 24px;">
                  <h3 style="color: #d97706; margin: 0 0 16px 0; font-size: 18px;">Sign-in Details</h3>
                  <div style="margin-bottom: 12px;">
                    <strong style="color: #92400e;">Time:</strong> {{security.sign_in_time}}<br>
                    <strong style="color: #92400e;">IP Address:</strong> {{security.ip_address}}<br>
                    <strong style="color: #92400e;">Location:</strong> {{security.location}}<br>
                    <strong style="color: #92400e;">Browser:</strong> {{security.browser_info}}
                  </div>
                </td>
              </tr>
            </table>
          </td>
        </tr>
      </table>

      <div style="text-align: center; margin: 32px 0;">
        <div style="background-color: #f0f9ff; border-radius: 8px; padding: 20px; max-width: 400px; margin: 0 auto;">
          <h3 style="color: #0891b2; margin: 0 0 12px 0; font-size: 16px;">Was this you?</h3>
          <p style="margin: 0 0 16px 0; color: #374151; font-size: 14px;">
            If this was you, no action is needed. Your account is secure.
          </p>
          <p style="margin: 0; color: #374151; font-size: 14px;">
            If this wasn't you, please contact us immediately and change your password.
          </p>
        </div>
      </div>
    HTML
  end
  
  def self.security_notification_default_content
    EmailHeaderFooterService.render_complete_email('operational', security_notification_default_body)
  end
end