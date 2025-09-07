# Email templates for workflow testing

puts 'Creating workflow email templates...'

# Template for stuck application workflow
stuck_app_template = EmailTemplate.find_or_create_by(name: 'Application Stuck Reminder') do |template|
  template.template_type = 'application_submitted'
  template.email_category = 'operational'
  template.subject = 'Your Application Needs Attention - {{application.reference_number}}'
  template.description = 'Email sent when application is stuck at a status'
  template.content_body = <<~HTML
    <div style="text-align: center; margin-bottom: 32px;">
      <h1 style="margin: 0; color: #dc2626; font-size: 24px; font-weight: 600;">⏰ Application Update Required</h1>
    </div>

    <div style="margin-bottom: 24px;">
      <p style="margin: 24px 0 0 0; color: #374151; font-size: 16px;">Dear {{user.first_name}},</p>
      
      <p style="margin: 16px 0; color: #6b7280; font-size: 14px;">
        Your application (Reference: <strong>{{application.reference_number}}</strong>) has been at <strong>{{application.status_display}}</strong> status for some time.
      </p>
      
      <p style="margin: 16px 0; color: #6b7280; font-size: 14px;">
        We wanted to reach out to see if you need any assistance to move forward with your application.
      </p>
    </div>

    <table role="presentation" style="width: 100%; border-collapse: collapse; border: 0; border-spacing: 0; margin: 32px 0;">
      <tr>
        <td align="center" style="padding: 0;">
          <table role="presentation" style="background-color: #fef3c7; border: 2px solid #f59e0b; border-radius: 8px; padding: 24px; margin: 0 auto; max-width: 500px;">
            <tr>
              <td style="padding: 20px 24px;">
                <h3 style="color: #d97706; margin: 0 0 16px 0; font-size: 18px;">Application Details</h3>
                <div style="margin-bottom: 12px;">
                  <strong style="color: #92400e;">Reference:</strong> {{application.reference_number}}<br>
                  <strong style="color: #92400e;">Property:</strong> {{application.address}}<br>
                  <strong style="color: #92400e;">Home Value:</strong> {{application.formatted_home_value}}<br>
                  <strong style="color: #92400e;">Current Status:</strong> {{application.status_display}}
                </div>
              </td>
            </tr>
          </table>
        </td>
      </tr>
    </table>

    <div style="text-align: center; margin: 32px 0;">
      <p style="margin: 0; color: #6b7280; font-size: 14px;">
        If you have any questions, please don't hesitate to contact us.
      </p>
    </div>
  HTML
  template.content = template.content_body # For backward compatibility
  template.is_active = true
end
puts "✓ Created: #{stuck_app_template.name}"

# Template for contract stuck workflow  
stuck_contract_template = EmailTemplate.find_or_create_by(name: 'Contract Stuck Reminder') do |template|
  template.template_type = 'application_submitted'
  template.email_category = 'operational'
  template.subject = 'Contract Update - Action Required'
  template.description = 'Email sent when contract is stuck at a status'
  template.content_body = <<~HTML
    <div style="text-align: center; margin-bottom: 32px;">
      <h1 style="margin: 0; color: #dc2626; font-size: 24px; font-weight: 600;">📋 Contract Action Required</h1>
    </div>

    <div style="margin-bottom: 24px;">
      <p style="margin: 24px 0 0 0; color: #374151; font-size: 16px;">Dear {{user.first_name}},</p>
      
      <p style="margin: 16px 0; color: #6b7280; font-size: 14px;">
        Your contract has been pending action for some time. We wanted to check if you need any assistance.
      </p>
    </div>

    <div style="text-align: center; margin: 32px 0;">
      <div style="background-color: #f0f9ff; border-radius: 8px; padding: 20px; max-width: 400px; margin: 0 auto;">
        <h3 style="color: #0891b2; margin: 0 0 12px 0; font-size: 16px;">Need Help?</h3>
        <p style="margin: 0; color: #374151; font-size: 14px;">
          Our team is here to assist you with any questions about your contract.
        </p>
      </div>
    </div>
  HTML
  template.content = template.content_body # For backward compatibility
  template.is_active = true
end
puts "✓ Created: #{stuck_contract_template.name}"

# Template for application status change
status_change_template = EmailTemplate.find_or_create_by(name: 'Application Status Changed') do |template|
  template.template_type = 'application_submitted'
  template.email_category = 'operational'
  template.subject = 'Application Update - Now {{application.status_display}}'
  template.description = 'Email sent when application status changes'
  template.content_body = <<~HTML
    <div style="text-align: center; margin-bottom: 32px;">
      <h1 style="margin: 0; color: #059669; font-size: 24px; font-weight: 600;">📈 Application Update</h1>
    </div>

    <div style="margin-bottom: 24px;">
      <p style="margin: 24px 0 0 0; color: #374151; font-size: 16px;">Dear {{user.first_name}},</p>
      
      <p style="margin: 16px 0; color: #6b7280; font-size: 14px;">
        Good news! Your application status has been updated to <strong>{{application.status_display}}</strong>.
      </p>
    </div>

    <table role="presentation" style="width: 100%; border-collapse: collapse; border: 0; border-spacing: 0; margin: 32px 0;">
      <tr>
        <td align="center" style="padding: 0;">
          <table role="presentation" style="background-color: #f0fdf4; border: 2px solid #059669; border-radius: 8px; padding: 24px; margin: 0 auto; max-width: 500px;">
            <tr>
              <td style="padding: 20px 24px;">
                <h3 style="color: #047857; margin: 0 0 16px 0; font-size: 18px;">Application Progress</h3>
                <div style="margin-bottom: 12px;">
                  <strong style="color: #065f46;">Reference:</strong> {{application.reference_number}}<br>
                  <strong style="color: #065f46;">New Status:</strong> {{application.status_display}}<br>
                  <strong style="color: #065f46;">Property:</strong> {{application.address}}<br>
                  <strong style="color: #065f46;">Value:</strong> {{application.formatted_home_value}}
                </div>
              </td>
            </tr>
          </table>
        </td>
      </tr>
    </table>
  HTML
  template.content = template.content_body # For backward compatibility
  template.is_active = true
end
puts "✓ Created: #{status_change_template.name}"

puts ""
puts "All workflow email templates created successfully!"