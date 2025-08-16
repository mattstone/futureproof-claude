class TermsOfUse < ApplicationRecord
  has_many :terms_of_use_versions, dependent: :destroy
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

      By accessing and using this website and our services, you accept and agree to be bound by the terms and provision of this agreement. If you do not agree to abide by the above, please do not use this service.

      ## 2. About Our Services

      Futureproof Financial Group Limited provides financial services including the Equity Preservation Mortgage® product. Our services are designed to help eligible homeowners access their home equity while preserving it for wealth transfer.

      ### Important Disclaimers:

      - Calculations provided on this website are estimates only and not loan approvals
      - All applications are subject to final property valuations, satisfactory security, and borrower eligibility requirements
      - Full terms and conditions will be set out in the Equity Preservation Mortgage® offer
      - All Equity Preservation Mortgages® are secured by registered first mortgage over residential property

      ## 3. Eligibility and Application Process

      To be eligible for our services, you must:

      - Be at least 18 years of age
      - Own residential property in Australia
      - Meet our lending criteria and creditworthiness requirements
      - Provide accurate and complete information in your application

      We reserve the right to decline any application at our sole discretion.

      ## 4. Website Use

      ### Permitted Use

      You may use our website for lawful purposes only. You agree not to:

      - Use the site in any way that violates applicable laws or regulations
      - Transmit or procure sending of any advertising or promotional material without our consent
      - Impersonate or attempt to impersonate our lender, employees, or other users
      - Engage in any activity that interferes with or disrupts the site

      ### Account Security

      If you create an account on our website, you are responsible for maintaining the confidentiality of your login credentials and for all activities that occur under your account.

      ## 12. Contact Information

      If you have any questions about these Terms of Use, please contact us at:

      **Contact Info:**
      Lender: Futureproof Financial Group Limited
      Email: legal@futureprooffinancial.app
      Address: [Lender Address]
    MARKUP
    
    create!(
      title: "Terms of Use",
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
        elsif in_contact && line.match(/^(Lender|Email|Address): (.+)$/)
          field = $1
          value = $2.strip
          if field == "Lender"
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
    self.version = (TermsOfUse.maximum(:version) || 0) + 1
  end
  
  def ensure_single_active
    if is_active? && saved_change_to_is_active?
      TermsOfUse.where.not(id: id).update_all(is_active: false)
    end
  end
  
  def log_creation
    return unless current_user
    
    terms_of_use_versions.create!(
      user: current_user,
      action: 'created',
      change_details: "Created new Terms of Use version #{version}",
      new_content: content
    )
  end
  
  def log_update
    return unless current_user
    
    if saved_change_to_is_active? && is_active?
      # Log activation
      terms_of_use_versions.create!(
        user: current_user,
        action: 'activated',
        change_details: "Activated Terms of Use version #{version}"
      )
    elsif saved_change_to_content?
      # Log content update
      terms_of_use_versions.create!(
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
