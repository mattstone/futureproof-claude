class TermsAndCondition < ApplicationRecord
  has_many :terms_and_condition_versions, dependent: :destroy
  has_many :users, foreign_key: 'terms_version', primary_key: 'version'
  
  validates :title, presence: true
  validates :content, presence: true
  validates :last_updated, presence: true
  validates :version, presence: true, uniqueness: true
  
  scope :active, -> { where(is_active: true) }
  scope :by_version, -> { order(:version) }
  
  # Track changes with PaperTrail-like functionality
  attr_accessor :current_user
  
  before_save :set_last_updated
  before_create :set_next_version
  after_save :ensure_single_active
  after_create :log_creation
  after_update :log_update
  
  def self.current
    active.order(:last_updated).last || create_default
  end
  
  def self.latest
    order(:version).last
  end
  
  def self.create_default
    default_content = <<~MARKUP
      ## 1. Acceptance of Terms

      By creating an account and using this website, you accept and agree to be bound by these terms and conditions. If you do not agree to abide by the above, please do not use this service.

      ## 2. Account Creation and Use

      When you create an account with us, you must provide information that is accurate, complete, and current at all times. You are responsible for safeguarding the password and for all activities that occur under your account.

      ### Your Responsibilities:

      - Provide accurate and complete information during registration
      - Maintain the security of your login credentials
      - Notify us immediately of any unauthorized use of your account
      - Use our services only for lawful purposes

      ## 3. Application Process

      By submitting an application through our platform, you acknowledge that:

      - All information provided is true and accurate to the best of your knowledge
      - You understand this is an application, not a loan approval
      - Final approval is subject to satisfactory security, property valuation, and creditworthiness assessment
      - We reserve the right to decline any application at our sole discretion

      ## 4. Privacy and Data Protection

      Your privacy is important to us. By using our service, you consent to the collection and use of your personal information as described in our Privacy Policy.

      ## 5. Service Availability

      We strive to keep our service available at all times, but we cannot guarantee uninterrupted access. We may suspend or restrict access to our service for maintenance or other operational reasons.

      ## 6. Limitation of Liability

      To the fullest extent permitted by law, Futureproof Financial Group Limited shall not be liable for any indirect, incidental, special, consequential, or punitive damages resulting from your use of our services.

      ## 7. Changes to Terms

      We reserve the right to modify these terms at any time. We will notify users of any material changes, and continued use of our service constitutes acceptance of the updated terms.

      ## 8. Contact Information

      If you have any questions about these Terms and Conditions, please contact us at:

      **Contact Info:**
      Company: Futureproof Financial Group Limited
      Email: legal@futureprooffinancial.app
      Address: [Company Address]
    MARKUP
    
    create!(
      title: "Terms and Conditions",
      content: default_content,
      last_updated: Time.current,
      is_active: true,
      version: 1
    )
  end
  
  def formatted_last_updated
    last_updated.strftime("%B %d, %Y")
  end
  
  # Convert markup to HTML for display
  def rendered_content
    return "" if content.blank?
    markup_to_html(content)
  end
  
  private
  
  def markup_to_html(text)
    return "" if text.blank?
    
    # Split into sections first
    sections = text.split(/^## /).reject(&:empty?)
    html_parts = []
    
    sections.each do |section_text|
      section_lines = section_text.split("\n")
      title = section_lines.first&.strip
      content_lines = section_lines[1..-1] || []
      
      html_parts << "<section class=\"legal-section\">"
      
      # Add section title
      if title && !title.empty?
        html_parts << "  <h2>#{sanitize_text(title)}</h2>"
      end
      
      # Process content lines
      in_list = false
      in_contact = false
      
      content_lines.each do |line|
        line = line.strip
        next if line.empty?
        
        # Handle subsections
        if line.match(/^### (.+)$/)
          # Close any open list
          if in_list
            html_parts << "  </ul>"
            in_list = false
          end
          subtitle = $1.strip
          html_parts << "  <h3>#{sanitize_text(subtitle)}</h3>"
          
        # Handle bullet points
        elsif line.match(/^- (.+)$/)
          unless in_list
            html_parts << "  <ul>"
            in_list = true
          end
          item = $1.strip
          html_parts << "    <li>#{sanitize_text(item)}</li>"
          
        # Handle contact info start
        elsif line == "**Contact Info:**"
          if in_list
            html_parts << "  </ul>"
            in_list = false
          end
          html_parts << "  <div class=\"contact-info\">"
          html_parts << "    <p>"
          in_contact = true
          
        # Handle contact info lines
        elsif in_contact && line.match(/^(Company|Email|Address): (.+)$/)
          field = $1
          value = $2.strip
          if field == "Company"
            html_parts << "      <strong>#{sanitize_text(value)}</strong><br>"
          else
            html_parts << "      #{sanitize_text(field)}: #{sanitize_text(value)}<br>"
          end
          
        # Handle regular paragraphs
        else
          # Close any open structures
          if in_list
            html_parts << "  </ul>"
            in_list = false
          end
          if in_contact
            html_parts << "    </p>"
            html_parts << "  </div>"
            in_contact = false
          end
          
          # Process **bold** text
          processed_line = line.gsub(/\*\*(.+?)\*\*/) { "<strong>#{sanitize_text($1)}</strong>" }
          html_parts << "  <p>#{processed_line}</p>"
        end
      end
      
      # Close any open structures
      if in_list
        html_parts << "  </ul>"
      end
      if in_contact
        html_parts << "    </p>"
        html_parts << "  </div>"
      end
      
      html_parts << "</section>"
    end
    
    html_parts.join("\n")
  end
  
  def sanitize_text(text)
    return "" if text.blank?
    # Allow only safe characters, preserve ® and other special symbols
    text.to_s.gsub(/[<>"]/, '').strip
  end
  
  def set_last_updated
    self.last_updated = Time.current if content_changed?
  end
  
  def set_next_version
    self.version = (TermsAndCondition.maximum(:version) || 0) + 1
  end
  
  def ensure_single_active
    if is_active? && saved_change_to_is_active?
      TermsAndCondition.where.not(id: id).update_all(is_active: false)
    end
  end
  
  def log_creation
    return unless current_user
    
    terms_and_condition_versions.create!(
      user: current_user,
      action: 'created',
      change_details: "Created new Terms and Conditions version #{version}",
      new_content: content
    )
  end
  
  def log_update
    return unless current_user
    
    if saved_change_to_is_active? && is_active?
      # Log activation
      terms_and_condition_versions.create!(
        user: current_user,
        action: 'activated',
        change_details: "Activated Terms and Conditions version #{version}"
      )
    elsif saved_change_to_content?
      # Log content update
      terms_and_condition_versions.create!(
        user: current_user,
        action: 'updated',
        change_details: build_change_summary,
        previous_content: saved_change_to_content[0],
        new_content: saved_change_to_content[1]
      )
    end
  end
  
  def build_change_summary
    changes_list = []
    
    if saved_change_to_title?
      changes_list << "Title changed from '#{saved_change_to_title[0]}' to '#{saved_change_to_title[1]}'"
    end
    
    if saved_change_to_content?
      # For content, just note that it was updated
      changes_list << "Content updated"
    end
    
    changes_list.join("; ")
  end
end