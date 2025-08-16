class PrivacyPolicy < ApplicationRecord
  has_many :privacy_policy_versions, dependent: :destroy
  has_many :users, foreign_key: 'privacy_version', primary_key: 'version'
  
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
      ## 1. Introduction

      Futureproof Financial Group Limited ("we," "our," or "us") is committed to protecting your privacy. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you visit our website or use our services, including our Equity Preservation Mortgage® products.

      ## 2. Information We Collect

      ### Personal Information

      We may collect the following types of personal information:

      - Contact information (name, email address, phone number, mailing address)
      - Property information (address, estimated value)
      - Financial information (income, assets, liabilities)
      - Identity verification documents
      - Communication records and preferences

      ### Automatically Collected Information

      When you visit our website, we may automatically collect:

      - IP address and device information
      - Browser type and version
      - Pages visited and time spent on our site
      - Referring website information
      - Cookies and similar tracking technologies

      ## 3. How We Use Your Information

      We use your information for the following purposes:

      - Processing and evaluating mortgage applications
      - Providing customer service and support
      - Communicating about our products and services
      - Conducting risk assessments and fraud prevention
      - Complying with legal and regulatory requirements
      - Improving our website and services
      - Marketing and promotional activities (with your consent)

      ## 4. Information Sharing and Disclosure

      We may share your information with:

      - **Service Providers:** Third parties who assist us in providing our services
      - **Financial Partners:** Approved lenders and financial institutions
      - **Legal Authorities:** When required by law or to protect our rights
      - **Business Transfers:** In connection with mergers, acquisitions, or asset sales

      We do not sell, trade, or rent your personal information to third parties for marketing purposes without your explicit consent.

      ## 5. Data Security

      We implement appropriate technical and organizational measures to protect your personal information against unauthorized access, alteration, disclosure, or destruction. However, no method of transmission over the internet or electronic storage is 100% secure.

      ## 6. Your Rights

      You have the right to:

      - Access and review your personal information
      - Request corrections to inaccurate information
      - Request deletion of your information (subject to legal requirements)
      - Opt-out of marketing communications
      - Lodge a complaint with relevant privacy authorities

      ## 7. Cookies and Tracking

      Our website uses cookies and similar technologies to enhance your browsing experience, analyze site traffic, and personalize content. You can control cookie settings through your browser preferences.

      ## 8. Changes to This Policy

      We may update this Privacy Policy periodically. We will notify you of any material changes by posting the updated policy on our website with a new "Last updated" date.

      ## 9. Contact Us

      **Contact Info:**
      Lender: Futureproof Financial Group Limited
      Email: privacy@futureprooffinancial.app
      Address: [Lender Address]
    MARKUP
    
    create!(
      title: "Privacy Policy",
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
    self.version = (PrivacyPolicy.maximum(:version) || 0) + 1
  end
  
  def ensure_single_active
    if is_active? && saved_change_to_is_active?
      PrivacyPolicy.where.not(id: id).update_all(is_active: false)
    end
  end
  
  def log_creation
    return unless current_user
    
    privacy_policy_versions.create!(
      user: current_user,
      action: 'created',
      change_details: "Created new Privacy Policy version #{version}",
      new_content: content
    )
  end
  
  def log_update
    return unless current_user
    
    if saved_change_to_is_active? && is_active?
      # Log activation
      privacy_policy_versions.create!(
        user: current_user,
        action: 'activated',
        change_details: "Activated Privacy Policy version #{version}"
      )
    elsif saved_change_to_content?
      # Log content update
      privacy_policy_versions.create!(
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
