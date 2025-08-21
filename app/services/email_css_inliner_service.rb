# Service to inline CSS for email templates while maintaining CSP compliance
# This allows us to use CSS classes in templates for CSP compliance,
# then inline them for email client compatibility
class EmailCssInlinerService
  def self.inline_css(html_content)
    # For now, we'll use a simple approach that works without additional gems
    # In production, you might want to add the 'premailer-rails' gem for advanced CSS inlining
    
    # CSS mapping for common email classes
    css_mappings = {
      'email-table' => 'width: 100%; border-collapse: collapse; border: 0; border-spacing: 0;',
      'email-table-mb-32' => 'width: 100%; border-collapse: collapse; border: 0; border-spacing: 0; margin-bottom: 32px;',
      'email-table-mb-24' => 'width: 100%; border-collapse: collapse; border: 0; border-spacing: 0; margin-bottom: 24px;',
      'email-header-cell' => 'text-align: center;',
      'email-title' => 'margin: 0 0 16px 0; color: #1f2937; font-size: 32px; font-weight: 700; line-height: 1.2;',
      'email-subtitle' => 'margin: 0; color: #6b7280; font-size: 18px; line-height: 1.6;',
      'email-greeting' => 'margin: 0 0 24px 0; color: #374151; font-size: 16px; line-height: 1.6;',
      'email-content-text' => 'margin: 0 0 24px 0; color: #374151; font-size: 16px; line-height: 1.6;',
      'email-content-text-final' => 'margin: 0 0 32px 0; color: #374151; font-size: 16px; line-height: 1.6;',
      'email-strong' => 'color: #1f2937;',
      'email-button-table' => 'border-collapse: collapse; border: 0; border-spacing: 0;',
      'email-button-cell' => 'background: linear-gradient(135deg, #3b82f6 0%, #1d4ed8 100%); border-radius: 8px;',
      'email-button-link' => 'display: inline-block; padding: 16px 32px; color: #ffffff; text-decoration: none; font-size: 16px; font-weight: 600; text-align: center; min-width: 200px;',
      'email-alt-link-cell' => 'padding: 24px; background-color: #f9fafb; border-radius: 8px; border: 1px solid #e5e7eb;',
      'email-alt-link-title' => 'margin: 0 0 16px 0; color: #374151; font-size: 14px; line-height: 1.6; text-align: center;',
      'email-alt-link-text' => 'margin: 0; color: #6b7280; font-size: 14px; line-height: 1.6; text-align: center; word-break: break-all;',
      'email-alt-link' => 'color: #3b82f6; text-decoration: underline;',
      'email-notice-warning' => 'padding: 20px; background-color: #fef3c7; border-radius: 8px; border-left: 4px solid #f59e0b;',
      'email-notice-info' => 'padding: 20px; background-color: #eff6ff; border-radius: 8px; border-left: 4px solid #3b82f6;',
      'email-notice-title-warning' => 'margin: 0 0 12px 0; color: #92400e; font-size: 14px; font-weight: 600;',
      'email-notice-title-info' => 'margin: 0 0 12px 0; color: #1e40af; font-size: 14px; font-weight: 600;',
      'email-notice-text-warning' => 'margin: 0; color: #92400e; font-size: 14px; line-height: 1.6;',
      'email-notice-text-info' => 'margin: 0; color: #1e40af; font-size: 14px; line-height: 1.6;',
      'email-notice-link' => 'color: #1e40af; text-decoration: underline;',
      'email-message-header' => 'background: linear-gradient(135deg, #3b82f6 0%, #1d4ed8 100%); padding: 24px; text-align: center;',
      'email-message-title' => 'margin: 0; color: #ffffff; font-size: 24px; font-weight: 700;',
      'email-message-content-wrapper' => 'padding: 32px;',
      'email-message-greeting' => 'margin: 0 0 24px 0; color: #374151; font-size: 16px; line-height: 1.6;',
      'email-message-subject' => 'margin: 0 0 16px 0; color: #1f2937; font-size: 20px; font-weight: 600; padding-bottom: 8px; border-bottom: 2px solid #e5e7eb;',
      'email-message-body' => 'margin: 0 0 32px 0; color: #374151; font-size: 16px; line-height: 1.7; padding: 16px 0;',
      'email-message-footer' => 'background-color: #f8fafc; padding: 24px; border-top: 1px solid #e5e7eb;',
      'email-message-footer-text' => 'margin: 0; color: #6b7280; font-size: 14px; line-height: 1.6; text-align: center;',
      'email-app-status-cell' => 'padding: 16px; background-color: #dcfce7; border-radius: 8px; border-left: 4px solid #22c55e; text-align: center;',
      'email-app-status-title' => 'margin: 0 0 8px 0; color: #166534; font-size: 18px; font-weight: 600;',
      'email-app-status-text' => 'margin: 0; color: #166534; font-size: 14px; line-height: 1.6;',
      'email-security-cell' => 'padding: 20px; background-color: #fef2f2; border-radius: 8px; border-left: 4px solid #ef4444;',
      'email-security-title' => 'margin: 0 0 12px 0; color: #dc2626; font-size: 16px; font-weight: 600;',
      'email-security-text' => 'margin: 0; color: #dc2626; font-size: 14px; line-height: 1.6;',
      'email-verification-code' => 'margin: 16px 0; padding: 12px 20px; background-color: #f3f4f6; border-radius: 6px; border: 2px solid #d1d5db; text-align: center;',
      'email-verification-code-text' => 'margin: 0; color: #1f2937; font-size: 24px; font-weight: 700; font-family: monospace; letter-spacing: 4px;'
    }
    
    # Replace class attributes with inline styles
    processed_html = html_content.dup
    
    css_mappings.each do |css_class, inline_style|
      # Replace class="email-class" with style="inline-style"
      processed_html.gsub!(/class="#{css_class}"/, %Q{style="#{inline_style}"})
      
      # Handle multiple classes - remove the class if it's part of a multi-class string
      processed_html.gsub!(/class="([^"]*\s)?#{css_class}(\s[^"]*)?"/m) do |match|
        other_classes = match.gsub(/class="/, '').gsub(/"/, '').gsub(/#{css_class}/, '').strip
        if other_classes.empty?
          %Q{style="#{inline_style}"}
        else
          %Q{class="#{other_classes}" style="#{inline_style}"}
        end
      end
    end
    
    processed_html
  end
end