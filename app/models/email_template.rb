class EmailTemplate < ApplicationRecord
  has_many :email_template_versions, dependent: :destroy
  
  validates :name, presence: true, uniqueness: true
  validates :subject, presence: true
  validates :content, presence: true
  validates :template_type, presence: true, inclusion: { in: %w[verification application_submitted security_notification] }
  
  # Virtual attribute for markup editor
  attr_accessor :markup_content
  
  scope :active, -> { where(is_active: true) }
  scope :by_type, ->(type) { where(template_type: type) }
  
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
        'application' => %w[id reference_number address home_value formatted_home_value existing_mortgage_amount formatted_existing_mortgage_amount loan_value formatted_loan_value borrower_age loan_term growth_rate formatted_growth_rate future_property_value formatted_future_property_value home_equity_preserved formatted_home_equity_preserved status status_display created_at updated_at submitted_at formatted_created_at formatted_updated_at formatted_submitted_at],
        'mortgage' => %w[name lvr interest_rate mortgage_type_display]
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
  
  # Render template with data substitution
  def render_content(data = {})
    data ||= {}
    rendered_content = content.dup
    rendered_subject = subject.dup
    
    # Replace placeholders in both content and subject
    [rendered_content, rendered_subject].each do |text|
      # User fields
      if data[:user]
        user = data[:user]
        text.gsub!(/{{user\.first_name}}/i, safe_field_value(user, :first_name))
        text.gsub!(/{{user\.last_name}}/i, safe_field_value(user, :last_name))
        text.gsub!(/{{user\.full_name}}/i, safe_field_value(user, :full_name))
        text.gsub!(/{{user\.email}}/i, safe_field_value(user, :email))
        text.gsub!(/{{user\.mobile_number}}/i, safe_field_value(user, :full_mobile_number))
        text.gsub!(/{{user\.country_of_residence}}/i, safe_field_value(user, :country_of_residence))
      end
      
      # Application fields
      if data[:application]
        app = data[:application]
        text.gsub!(/{{application\.id}}/i, safe_field_value(app, :id))
        text.gsub!(/{{application\.reference_number}}/i, safe_field_value(app, :id).rjust(6, '0'))
        text.gsub!(/{{application\.address}}/i, safe_field_value(app, :address))
        text.gsub!(/{{application\.home_value}}/i, safe_field_value(app, :home_value))
        text.gsub!(/{{application\.formatted_home_value}}/i, safe_field_value(app, :formatted_home_value))
        text.gsub!(/{{application\.existing_mortgage_amount}}/i, safe_field_value(app, :existing_mortgage_amount))
        text.gsub!(/{{application\.formatted_existing_mortgage_amount}}/i, safe_field_value(app, :formatted_existing_mortgage_amount))
        text.gsub!(/{{application\.loan_value}}/i, safe_field_value(app, :loan_value))
        text.gsub!(/{{application\.formatted_loan_value}}/i, safe_field_value(app, :formatted_loan_value))
        text.gsub!(/{{application\.borrower_age}}/i, safe_field_value(app, :borrower_age))
        text.gsub!(/{{application\.loan_term}}/i, safe_field_value(app, :loan_term))
        text.gsub!(/{{application\.growth_rate}}/i, safe_field_value(app, :growth_rate))
        text.gsub!(/{{application\.formatted_growth_rate}}/i, safe_field_value(app, :formatted_growth_rate))
        text.gsub!(/{{application\.future_property_value}}/i, safe_field_value(app, :formatted_future_property_value))
        text.gsub!(/{{application\.formatted_future_property_value}}/i, safe_field_value(app, :formatted_future_property_value))
        text.gsub!(/{{application\.home_equity_preserved}}/i, safe_field_value(app, :formatted_home_equity_preserved))
        text.gsub!(/{{application\.formatted_home_equity_preserved}}/i, safe_field_value(app, :formatted_home_equity_preserved))
        text.gsub!(/{{application\.status}}/i, safe_field_value(app, :status))
        text.gsub!(/{{application\.status_display}}/i, safe_field_value(app, :status_display))
        text.gsub!(/{{application\.created_at}}/i, safe_field_value(app, :created_at))
        text.gsub!(/{{application\.updated_at}}/i, safe_field_value(app, :updated_at))
        text.gsub!(/{{application\.submitted_at}}/i, safe_field_value(app, :submitted_at))
        text.gsub!(/{{application\.formatted_created_at}}/i, safe_field_value(app, :formatted_created_at))
        text.gsub!(/{{application\.formatted_updated_at}}/i, safe_field_value(app, :formatted_updated_at))
        text.gsub!(/{{application\.formatted_submitted_at}}/i, safe_field_value(app, :formatted_submitted_at))
      end
      
      # Mortgage fields
      if data[:mortgage]
        mortgage = data[:mortgage]
        text.gsub!(/{{mortgage\.name}}/i, safe_field_value(mortgage, :name))
        text.gsub!(/{{mortgage\.lvr}}/i, safe_field_value(mortgage, :lvr))
        text.gsub!(/{{mortgage\.interest_rate}}/i, '7.45') # Static for now
        text.gsub!(/{{mortgage\.mortgage_type_display}}/i, safe_field_value(mortgage, :mortgage_type_display))
      end
      
      # Verification fields
      if data[:verification_code]
        text.gsub!(/{{verification\.verification_code}}/i, data[:verification_code].to_s)
      end
      if data[:expires_at]
        text.gsub!(/{{verification\.expires_at}}/i, data[:expires_at].to_s)
        text.gsub!(/{{verification\.formatted_expires_at}}/i, (data[:expires_at].strftime("%I:%M %p") rescue data[:expires_at].to_s))
      end
      
      # Security fields - always replace these fields with appropriate fallbacks
      browser_info = data[:browser_info].present? ? data[:browser_info].to_s : 'Unknown Browser'
      text.gsub!(/{{security\.browser_info}}/i, browser_info)
      
      ip_address = data[:ip_address].present? ? data[:ip_address].to_s : 'Unknown IP'
      text.gsub!(/{{security\.ip_address}}/i, ip_address)
      
      location_value = data[:location].present? ? data[:location].to_s : 'Unknown Location'
      text.gsub!(/{{security\.location}}/i, location_value)
      
      sign_in_time = data[:sign_in_time].present? ? 
                     (data[:sign_in_time].strftime("%B %d, %Y at %I:%M %p") rescue data[:sign_in_time].to_s) : 
                     Time.current.strftime("%B %d, %Y at %I:%M %p")
      text.gsub!(/{{security\.sign_in_time}}/i, sign_in_time)
      
      event_type = data[:event_type].present? ? data[:event_type].to_s : 'Sign-in Activity'
      text.gsub!(/{{security\.event_type}}/i, event_type)
      
      device_type = data[:device_type].present? ? data[:device_type].to_s : 'Unknown Device'
      text.gsub!(/{{security\.device_type}}/i, device_type)
      
      os_info = data[:os_info].present? ? data[:os_info].to_s : 'Unknown OS'
      text.gsub!(/{{security\.os_info}}/i, os_info)
      
      risk_level = data[:risk_level].present? ? data[:risk_level].to_s : 'Unknown'
      text.gsub!(/{{security\.risk_level}}/i, risk_level)
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
        subject: 'Verify Your Futureproof Account',
        description: 'Email sent to new users to verify their email address',
        content: '<div style="text-align: center; margin-bottom: 32px;">
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
                      <div style="font-size: 32px; font-weight: 700; color: #0891b2; letter-spacing: 6px; font-family: \'Courier New\', monospace;">
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
                If you didn\'t create this account, please ignore this email.
              </p>
            </div>
          </div>'
      )
    when 'application_submitted'
      create!(
        name: 'Application Submitted',
        template_type: 'application_submitted',
        subject: 'Your Equity Preservation Mortgage® Application Has Been Submitted',
        description: 'Email sent when user submits their mortgage application',
        content: <<~HTML
          <div style="text-align: center; margin-bottom: 32px;">
            <h1 style="margin: 0; color: #374151; font-size: 24px; font-weight: 600;">🎉 Application Submitted Successfully!</h1>
          </div>

          <table role="presentation" style="width: 100%; border-collapse: collapse; border: 0; border-spacing: 0; margin: 32px 0;">
            <tr>
              <td align="center" style="padding: 0;">
                <table role="presentation" style="background-color: #fff3cd; border: 2px solid #ffeaa7; border-radius: 8px; padding: 24px; margin: 0 auto;">
                  <tr>
                    <td align="center" style="padding: 0;">
                      <div style="font-size: 18px; font-weight: 600; color: #1f2937;">
                        Application Reference: #{ '{{application.reference_number}}' }
                      </div>
                    </td>
                  </tr>
                </table>
              </td>
            </tr>
          </table>

          <div style="text-align: center; margin-bottom: 24px;">
            <p style="margin: 24px 0 0 0; color: #374151; font-size: 16px;">Dear {{user.first_name}},</p>
            
            <hr style="border: none; border-top: 1px solid #e5e7eb; margin: 20px auto; width: 60%;">
            
            <p style="margin: 16px 0 0 0; color: #6b7280; font-size: 14px;">
              Thank you for choosing our Equity Preservation Mortgage®. We have received your application and will be in touch shortly to guide you through the next steps.
            </p>
          </div>

          <table role="presentation" style="width: 100%; border-collapse: collapse; border: 0; border-spacing: 0; margin: 24px 0;">
            <tr>
              <td align="center" style="padding: 0;">
                <table role="presentation" style="background-color: #f9fafb; border: 2px solid #e5e7eb; border-radius: 8px; padding: 32px; width: 100%; max-width: 500px;">
                  <tr>
                    <td style="padding: 16px;">
                      
                      <h3 style="color: #0891b2; text-align: center; margin: 0 0 16px 0; font-size: 18px;">Personal Information</h3>
                      <div style="margin-bottom: 24px;">
                        <div style="display: flex; justify-content: space-between; padding: 12px 16px; border-bottom: 1px solid #e5e7eb;">
                          <span style="font-weight: 600; color: #555;">Name:</span>
                          <span style="color: #333;">{{user.full_name}}</span>
                        </div>
                        <div style="display: flex; justify-content: space-between; padding: 12px 16px;">
                          <span style="font-weight: 600; color: #555;">Email:</span>
                          <span style="color: #333;">{{user.email}}</span>
                        </div>
                      </div>

                      <h3 style="color: #0891b2; text-align: center; margin: 24px 0 16px 0; font-size: 18px;">Loan Summary</h3>
                      <div style="margin-bottom: 24px;">
                        <div style="display: flex; justify-content: space-between; padding: 12px 16px; border-bottom: 1px solid #e5e7eb;">
                          <span style="font-weight: 600; color: #555;">Mortgage Type:</span>
                          <span style="color: #333;">{{mortgage.name}}</span>
                        </div>
                        <div style="display: flex; justify-content: space-between; padding: 12px 16px; border-bottom: 1px solid #e5e7eb;">
                          <span style="font-weight: 600; color: #555;">LVR:</span>
                          <span style="color: #333;">{{mortgage.lvr}}%</span>
                        </div>
                        <div style="display: flex; justify-content: space-between; padding: 12px 16px; border-bottom: 1px solid #e5e7eb;">
                          <span style="font-weight: 600; color: #555;">Interest Rate:</span>
                          <span style="color: #333;">{{mortgage.interest_rate}}%</span>
                        </div>
                        <div style="display: flex; justify-content: space-between; padding: 12px 16px; border-bottom: 1px solid #e5e7eb;">
                          <span style="font-weight: 600; color: #555;">Loan Term:</span>
                          <span style="color: #333;">{{application.loan_term}} years</span>
                        </div>
                        <div style="display: flex; justify-content: space-between; padding: 12px 16px;">
                          <span style="font-weight: 600; color: #555;">Loan Value:</span>
                          <span style="color: #333;">{{application.formatted_loan_value}}</span>
                        </div>
                        <div style="padding: 8px 16px; margin-top: 8px; background-color: #f8fafc; border-radius: 4px;">
                          <small style="color: #64748b; font-size: 12px;">
                            Calculated as: (Home Value - Existing Mortgage) × {{mortgage.lvr}}% LVR
                            <br>({{application.formatted_home_value}} - {{application.formatted_existing_mortgage_amount}}) × {{mortgage.lvr}}%
                          </small>
                        </div>
                      </div>

                      <h3 style="color: #0891b2; text-align: center; margin: 24px 0 16px 0; font-size: 18px;">Property Summary</h3>
                      <div>
                        <div style="display: flex; justify-content: space-between; padding: 12px 16px; border-bottom: 1px solid #e5e7eb;">
                          <span style="font-weight: 600; color: #555;">Address:</span>
                          <span style="color: #333; text-align: right;">{{application.address}}</span>
                        </div>
                        <div style="display: flex; justify-content: space-between; padding: 12px 16px; border-bottom: 1px solid #e5e7eb;">
                          <span style="font-weight: 600; color: #555;">Current Value:</span>
                          <span style="color: #333;">{{application.formatted_home_value}}</span>
                        </div>
                        <div style="display: flex; justify-content: space-between; padding: 12px 16px; border-bottom: 1px solid #e5e7eb;">
                          <span style="font-weight: 600; color: #555;">Annual Growth:</span>
                          <span style="color: #333;">{{application.formatted_growth_rate}}</span>
                        </div>
                        <div style="display: flex; justify-content: space-between; padding: 12px 16px; border-bottom: 1px solid #e5e7eb;">
                          <span style="font-weight: 600; color: #555;">Future Value:</span>
                          <span style="color: #333;">{{application.formatted_future_property_value}}</span>
                        </div>
                        <div style="display: flex; justify-content: space-between; padding: 12px 16px;">
                          <span style="font-weight: 600; color: #555;">Equity Preserved:</span>
                          <span style="color: #16a34a; font-weight: 600;">{{application.formatted_home_equity_preserved}}</span>
                        </div>
                      </div>

                    </td>
                  </tr>
                </table>
              </td>
            </tr>
          </table>

          <div style="text-align: center; margin: 32px 0;">
            <h3 style="color: #0891b2; margin: 0 0 16px 0; font-size: 18px;">What happens next?</h3>
            <div style="background-color: #f8f9fa; border-radius: 8px; padding: 20px; text-align: left; max-width: 400px; margin: 0 auto;">
              <div style="margin-bottom: 16px;">
                <span style="background-color: #0891b2; color: white; width: 20px; height: 20px; border-radius: 50%; display: inline-flex; align-items: center; justify-content: center; font-size: 12px; font-weight: bold; margin-right: 12px;">1</span>
                <strong>Property Valuation</strong><br>
                <span style="margin-left: 32px; color: #6b7280; font-size: 14px;">Independent valuation to confirm current market value</span>
              </div>
              <div style="margin-bottom: 16px;">
                <span style="background-color: #0891b2; color: white; width: 20px; height: 20px; border-radius: 50%; display: inline-flex; align-items: center; justify-content: center; font-size: 12px; font-weight: bold; margin-right: 12px;">2</span>
                <strong>Document Review</strong><br>
                <span style="margin-left: 32px; color: #6b7280; font-size: 14px;">Our team will review and may request additional documentation</span>
              </div>
              <div>
                <span style="background-color: #0891b2; color: white; width: 20px; height: 20px; border-radius: 50%; display: inline-flex; align-items: center; justify-content: center; font-size: 12px; font-weight: bold; margin-right: 12px;">3</span>
                <strong>Final Approval</strong><br>
                <span style="margin-left: 32px; color: #6b7280; font-size: 14px;">Final loan approval and settlement details</span>
              </div>
            </div>
          </div>

          <div style="text-align: center; margin: 32px 0;">
            <div style="background-color: #e3f2fd; border-radius: 8px; padding: 20px; max-width: 300px; margin: 0 auto;">
              <h3 style="color: #0891b2; margin: 0 0 12px 0; font-size: 16px;">Need Help?</h3>
              <p style="margin: 0 0 8px 0; color: #374151; font-size: 14px;">Questions about your application?</p>
              <p style="margin: 0; color: #374151; font-size: 14px;">
                <strong>Email:</strong> info@futureprooffinancial.co<br>
                <strong>Phone:</strong> 1300 XXX XXX
              </p>
            </div>
          </div>
        HTML
      )
    when 'security_notification'
      create!(
        name: 'Security Notification',
        template_type: 'security_notification',
        subject: 'Security Alert: Sign-in from New Browser',
        description: 'Email sent when user signs in from a new browser',
        content: <<~HTML
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
                    <td style="padding: 0;">
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

          <div style="text-align: center; margin: 32px 0;">
            <div style="background-color: #e3f2fd; border-radius: 8px; padding: 20px; max-width: 300px; margin: 0 auto;">
              <h3 style="color: #0891b2; margin: 0 0 12px 0; font-size: 16px;">Contact Support</h3>
              <p style="margin: 0; color: #374151; font-size: 14px;">
                <strong>Email:</strong> security@futureprooffinancial.co<br>
                <strong>Phone:</strong> 1300 XXX XXX
              </p>
            </div>
          </div>
        HTML
      )
    else
      raise ArgumentError, "Unknown template type: #{template_type}"
    end
  end
  
  private
  
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
    elsif saved_change_to_content? || saved_change_to_subject?
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
    
    if saved_change_to_content?
      changes_list << "Content updated"
    end
    
    if saved_change_to_name?
      changes_list << "Name changed from '#{saved_change_to_name[0]}' to '#{saved_change_to_name[1]}'"
    end
    
    changes_list.join("; ")
  end
end