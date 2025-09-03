# Service to manage email headers and footers for different email categories
class EmailHeaderFooterService
  
  # Get header for specified email category
  def self.header_for_category(category)
    case category
    when 'marketing'
      marketing_header
    when 'operational'
      operational_header
    else
      operational_header # default
    end
  end
  
  # Get footer for specified email category
  def self.footer_for_category(category)
    case category
    when 'marketing'
      marketing_footer
    when 'operational'
      operational_footer
    else
      operational_footer # default
    end
  end
  
  # Render complete email with header, content, and footer
  def self.render_complete_email(category, content_body)
    header = header_for_category(category)
    footer = footer_for_category(category)
    
    <<~HTML
      #{header}
      
      #{content_body}
      
      #{footer}
    HTML
  end
  
  private
  
  def self.operational_header
    <<~HTML
      <table role="presentation" style="width: 100%; border-collapse: collapse; border: 0; border-spacing: 0; background-color: #ffffff;">
        <tr>
          <td align="center" style="padding: 0;">
            <table role="presentation" style="width: 100%; max-width: 600px; margin: 0 auto; border-collapse: collapse; border: 0; border-spacing: 0;">
              <tr>
                <td style="padding: 32px 20px 24px 20px; background-color: #0891b2;">
                  <table role="presentation" style="width: 100%; border-collapse: collapse; border: 0; border-spacing: 0;">
                    <tr>
                      <td align="center">
                        <div style="font-size: 32px; font-weight: 700; color: #ffffff; text-decoration: none; font-family: Arial, sans-serif; letter-spacing: -1px;">
                          Futureproof
                        </div>
                        <div style="font-size: 14px; color: #bae6fd; margin-top: 4px; font-family: Arial, sans-serif;">
                          Your Financial Future, Secured
                        </div>
                      </td>
                    </tr>
                  </table>
                </td>
              </tr>
            </table>
          </td>
        </tr>
      </table>
      
      <table role="presentation" style="width: 100%; border-collapse: collapse; border: 0; border-spacing: 0; background-color: #ffffff;">
        <tr>
          <td align="center" style="padding: 0;">
            <table role="presentation" style="width: 100%; max-width: 600px; margin: 0 auto; border-collapse: collapse; border: 0; border-spacing: 0;">
              <tr>
                <td style="padding: 32px 40px;">
    HTML
  end
  
  def self.operational_footer
    <<~HTML
                </td>
              </tr>
            </table>
          </td>
        </tr>
      </table>
      
      <!-- Footer -->
      <table role="presentation" style="width: 100%; border-collapse: collapse; border: 0; border-spacing: 0; background-color: #f8fafc;">
        <tr>
          <td align="center" style="padding: 0;">
            <table role="presentation" style="width: 100%; max-width: 600px; margin: 0 auto; border-collapse: collapse; border: 0; border-spacing: 0;">
              <tr>
                <td style="padding: 32px 40px; text-align: center;">
                  <div style="border-top: 1px solid #e5e7eb; padding-top: 32px;">
                    <div style="margin-bottom: 16px;">
                      <strong style="color: #0891b2; font-size: 16px; font-family: Arial, sans-serif;">Futureproof Financial Group</strong>
                    </div>
                    
                    <div style="margin-bottom: 24px;">
                      <div style="color: #6b7280; font-size: 14px; line-height: 1.6; font-family: Arial, sans-serif;">
                        This is an important account notification. Please do not reply to this email as it is sent from an unmonitored address.
                      </div>
                    </div>
                    
                    <div style="margin-bottom: 16px;">
                      <div style="color: #6b7280; font-size: 13px; font-family: Arial, sans-serif;">
                        <strong>Contact Us:</strong><br>
                        Email: <a href="mailto:info@futureprooffinancial.app" style="color: #0891b2; text-decoration: none;">info@futureprooffinancial.app</a><br>
                        Phone: 1300 123 456
                      </div>
                    </div>
                    
                    <div style="color: #9ca3af; font-size: 12px; font-family: Arial, sans-serif; margin-top: 24px;">
                      © #{Date.current.year} Futureproof Financial Group Pty Ltd. All rights reserved.<br>
                      Australian Credit Licence: [LICENCE_NUMBER]<br>
                      <br>
                      <div style="margin-top: 8px;">
                        <a href="https://futureprooffinancial.app/privacy-policy" style="color: #9ca3af; font-size: 11px; text-decoration: underline;">Privacy Policy</a> | 
                        <a href="https://futureprooffinancial.app/terms-of-use" style="color: #9ca3af; font-size: 11px; text-decoration: underline;">Terms of Use</a>
                      </div>
                    </div>
                  </div>
                </td>
              </tr>
            </table>
          </td>
        </tr>
      </table>
    HTML
  end
  
  def self.marketing_header
    <<~HTML
      <table role="presentation" style="width: 100%; border-collapse: collapse; border: 0; border-spacing: 0; background-color: #ffffff;">
        <tr>
          <td align="center" style="padding: 0;">
            <table role="presentation" style="width: 100%; max-width: 600px; margin: 0 auto; border-collapse: collapse; border: 0; border-spacing: 0;">
              <tr>
                <td style="padding: 32px 20px 24px 20px; background: linear-gradient(135deg, #0891b2 0%, #0c4a6e 100%);">
                  <table role="presentation" style="width: 100%; border-collapse: collapse; border: 0; border-spacing: 0;">
                    <tr>
                      <td align="center">
                        <div style="font-size: 36px; font-weight: 700; color: #ffffff; text-decoration: none; font-family: Arial, sans-serif; letter-spacing: -1px;">
                          Futureproof
                        </div>
                        <div style="font-size: 16px; color: #bae6fd; margin-top: 4px; font-family: Arial, sans-serif; font-weight: 500;">
                          Secure Your Financial Future
                        </div>
                      </td>
                    </tr>
                  </table>
                </td>
              </tr>
            </table>
          </td>
        </tr>
      </table>
      
      <table role="presentation" style="width: 100%; border-collapse: collapse; border: 0; border-spacing: 0; background-color: #ffffff;">
        <tr>
          <td align="center" style="padding: 0;">
            <table role="presentation" style="width: 100%; max-width: 600px; margin: 0 auto; border-collapse: collapse; border: 0; border-spacing: 0;">
              <tr>
                <td style="padding: 32px 40px;">
    HTML
  end
  
  def self.marketing_footer
    <<~HTML
                </td>
              </tr>
            </table>
          </td>
        </tr>
      </table>
      
      <!-- Marketing Footer with Social Links -->
      <table role="presentation" style="width: 100%; border-collapse: collapse; border: 0; border-spacing: 0; background: linear-gradient(135deg, #f8fafc 0%, #e2e8f0 100%);">
        <tr>
          <td align="center" style="padding: 0;">
            <table role="presentation" style="width: 100%; max-width: 600px; margin: 0 auto; border-collapse: collapse; border: 0; border-spacing: 0;">
              <tr>
                <td style="padding: 40px 40px 32px 40px; text-align: center;">
                  <div style="border-top: 2px solid #0891b2; padding-top: 32px;">
                    <div style="margin-bottom: 24px;">
                      <strong style="color: #0891b2; font-size: 18px; font-family: Arial, sans-serif;">Futureproof Financial Group</strong>
                    </div>
                    
                    <div style="margin-bottom: 32px;">
                      <div style="color: #475569; font-size: 15px; line-height: 1.7; font-family: Arial, sans-serif;">
                        Helping Australians secure their financial future with innovative mortgage solutions.
                      </div>
                    </div>
                    
                    <!-- Social Media Links Placeholder -->
                    <div style="margin-bottom: 32px;">
                      <div style="color: #6b7280; font-size: 14px; font-family: Arial, sans-serif;">
                        Follow us: 
                        <a href="#" style="color: #0891b2; text-decoration: none; margin: 0 8px;">LinkedIn</a> | 
                        <a href="#" style="color: #0891b2; text-decoration: none; margin: 0 8px;">Facebook</a> | 
                        <a href="#" style="color: #0891b2; text-decoration: none; margin: 0 8px;">Twitter</a>
                      </div>
                    </div>
                    
                    <div style="margin-bottom: 24px;">
                      <div style="color: #475569; font-size: 14px; font-family: Arial, sans-serif;">
                        <strong>Get in Touch:</strong><br>
                        Email: <a href="mailto:info@futureprooffinancial.app" style="color: #0891b2; text-decoration: none;">info@futureprooffinancial.app</a><br>
                        Phone: 1300 123 456<br>
                        Web: <a href="https://futureprooffinancial.app" style="color: #0891b2; text-decoration: none;">www.futureprooffinancial.app</a>
                      </div>
                    </div>
                    
                    <div style="color: #9ca3af; font-size: 12px; font-family: Arial, sans-serif; margin-top: 32px;">
                      © #{Date.current.year} Futureproof Financial Group Pty Ltd. All rights reserved.<br>
                      Australian Credit Licence: [LICENCE_NUMBER] | ABN: [ABN_NUMBER]<br>
                      <br>
                      <div style="margin-top: 16px;">
                        <a href="{{unsubscribe_url}}" style="color: #9ca3af; font-size: 11px; text-decoration: underline;">Unsubscribe</a> | 
                        <a href="https://futureprooffinancial.app/privacy-policy" style="color: #9ca3af; font-size: 11px; text-decoration: underline;">Privacy Policy</a> | 
                        <a href="https://futureprooffinancial.app/terms-of-use" style="color: #9ca3af; font-size: 11px; text-decoration: underline;">Terms of Use</a>
                      </div>
                      <div style="margin-top: 12px; font-size: 10px; color: #9ca3af; line-height: 1.4;">
                        This email was sent to {{user.email}}. If you no longer wish to receive marketing emails from us, please click the unsubscribe link above.
                      </div>
                    </div>
                  </div>
                </td>
              </tr>
            </table>
          </td>
        </tr>
      </table>
    HTML
  end
end