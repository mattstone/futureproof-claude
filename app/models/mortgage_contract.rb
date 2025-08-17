class MortgageContract < ApplicationRecord
  has_many :mortgage_contract_versions, dependent: :destroy
  belongs_to :created_by, class_name: 'User', optional: true
  
  validates :title, presence: true
  validates :content, presence: true
  validates :last_updated, presence: true
  validates :version, presence: true, uniqueness: true
  
  scope :active, -> { where(is_active: true) }
  scope :published, -> { where(is_draft: false) }
  scope :drafts, -> { where(is_draft: true) }
  scope :by_version, -> { order(:version) }
  
  # Track changes with PaperTrail-like functionality
  attr_accessor :current_user
  
  before_validation :set_last_updated, on: [:create, :update]
  before_validation :set_next_version, on: :create
  after_save :ensure_single_active
  after_create :log_creation
  after_update :log_update
  
  def self.current
    active.published.order(:last_updated).last || create_default
  end
  
  def self.latest
    order(:version).last
  end
  
  def self.create_default
    default_content = <<~MARKUP
      ## 1. Loan Agreement Details
      
      This Equity Preservation Mortgage Agreement ("Agreement") is entered into between:
      
      **Lender:** Futureproof Financial Group Limited
      **Borrower:** [Borrower Name]
      **Property:** [Property Address]
      **Loan Amount:** [Loan Amount]
      **Loan-to-Value Ratio:** [LVR]%
      
      ## 2. Equity Preservation Features
      
      ### 2.1 Equity Protection
      
      This mortgage includes equity preservation features designed to protect your home's value:
      
      - **Market Value Protection:** Your loan amount will not exceed the original LVR even if property values decline
      - **Equity Sharing:** You maintain full ownership and benefit from any property value increases
      - **No Negative Equity:** You will never owe more than your property is worth
      
      ### 2.2 Interest Rate Structure
      
      - **Initial Rate:** [Interest Rate]% per annum
      - **Rate Type:** [Fixed/Variable]
      - **Rate Review:** [Review Terms]
      
      ## 3. Repayment Terms
      
      ### 3.1 Monthly Payments
      
      - **Payment Amount:** $[Monthly Payment]
      - **Payment Date:** [Day] of each month
      - **Payment Method:** Direct debit from nominated account
      
      ### 3.2 Early Repayment
      
      You may repay this loan early without penalty, subject to:
      - 30 days written notice
      - Settlement of outstanding balance
      - Discharge of security
      
      ## 4. Security and Insurance
      
      ### 4.1 Property Security
      
      This loan is secured by a first mortgage over the property described above.
      
      ### 4.2 Insurance Requirements
      
      You must maintain:
      - Building insurance for full replacement value
      - Public liability insurance
      - Mortgage protection insurance (optional but recommended)
      
      ## 5. Default and Enforcement
      
      ### 5.1 Events of Default
      
      Default occurs if you:
      - Fail to make required payments
      - Breach any covenant in this agreement
      - Become insolvent or bankrupt
      
      ### 5.2 Remedies
      
      Upon default, we may:
      - Demand immediate repayment
      - Exercise powers of sale
      - Appoint a receiver
      
      ## 6. Fees and Charges
      
      ### 6.1 Establishment Fees
      
      - **Application Fee:** $[Amount]
      - **Valuation Fee:** $[Amount]
      - **Legal Fees:** $[Amount]
      
      ### 6.2 Ongoing Fees
      
      - **Monthly Service Fee:** $[Amount]
      - **Annual Review Fee:** $[Amount]
      
      ## 7. Regulatory Information
      
      ### 7.1 Credit Provider
      
      **Credit Provider:** Futureproof Financial Group Limited
      **Australian Credit Licence:** [ACL Number]
      **Contact:** legal@futureprooffinancial.app
      
      ### 7.2 Dispute Resolution
      
      If you have a complaint:
      1. Contact us directly at complaints@futureprooffinancial.app
      2. If unresolved, contact the Australian Financial Complaints Authority (AFCA)
      
      ## 8. Agreement Terms
      
      ### 8.1 Governing Law
      
      This agreement is governed by the laws of Australia and the jurisdiction where the property is located.
      
      ### 8.2 Variation
      
      This agreement may only be varied in writing and signed by both parties.
      
      ### 8.3 Entire Agreement
      
      This agreement constitutes the entire agreement between the parties and supersedes all prior negotiations, representations, and agreements.
      
      **Contact Information:**
      Lender: Futureproof Financial Group Limited
      Email: legal@futureprooffinancial.app
      Phone: 1300 XXX XXX
      Address: [Lender Address]
    MARKUP
    
    create!(
      title: "Equity Preservation Mortgage Contract",
      content: default_content,
      last_updated: Time.current,
      is_active: false,
      is_draft: true,
      version: 1
    )
  end
  
  def published?
    !is_draft?
  end
  
  def draft?
    is_draft?
  end
  
  def status
    return 'Active' if is_active? && published?
    return 'Published' if published?
    return 'Draft' if draft?
    'Unknown'
  end
  
  def status_color
    return 'success' if is_active? && published?
    return 'info' if published?
    return 'warning' if draft?
    'secondary'
  end
  
  def formatted_last_updated
    last_updated.strftime("%B %d, %Y")
  end
  
  # Convert markup to HTML for display
  def rendered_content
    return "" if content.blank?
    markup_to_html(content)
  end
  
  # Create a new version when updating published contracts
  def create_new_version_if_published
    if persisted? && published? && content_changed?
      # Create a new version instead of updating existing
      new_version = self.class.new(
        title: title,
        content: content,
        is_draft: true,
        is_active: false,
        current_user: current_user
      )
      new_version.save!
      
      # Restore original content to prevent saving changes
      restore_attributes(['content'])
      return new_version
    end
    nil
  end
  
  def publish!
    update!(is_draft: false)
  end
  
  def activate!
    update!(is_active: true, is_draft: false)
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
      in_details = false
      
      content_lines.each do |line|
        line = line.strip
        next if line.empty?
        
        # Handle subsections
        if line.match(/^### (.+)$/)
          # Close any open structures
          if in_list
            html_parts << "  </ul>"
            in_list = false
          end
          if in_details
            html_parts << "  </div>"
            in_details = false
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
          
        # Handle loan details pattern
        elsif line.match(/^\*\*(.+):\*\* (.+)$/)
          unless in_details
            html_parts << "  <div class=\"loan-details\">"
            in_details = true
          end
          field = $1.strip
          value = $2.strip
          html_parts << "    <div class=\"detail-row\">"
          html_parts << "      <strong>#{sanitize_text(field)}:</strong>"
          html_parts << "      <span>#{sanitize_text(value)}</span>"
          html_parts << "    </div>"
          
        # Handle contact info pattern  
        elsif line.match(/^(Lender|Email|Phone|Address): (.+)$/)
          unless in_contact
            if in_details
              html_parts << "  </div>"
              in_details = false
            end
            html_parts << "  <div class=\"contact-info\">"
            in_contact = true
          end
          field = $1
          value = $2.strip
          if field == "Lender"
            html_parts << "    <p><strong>#{sanitize_text(value)}</strong></p>"
          else
            html_parts << "    <p>#{sanitize_text(field)}: #{sanitize_text(value)}</p>"
          end
          
        # Handle regular paragraphs
        else
          # Close any open structures
          if in_list
            html_parts << "  </ul>"
            in_list = false
          end
          if in_details
            html_parts << "  </div>"
            in_details = false
          end
          if in_contact
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
      if in_details
        html_parts << "  </div>"
      end
      if in_contact
        html_parts << "  </div>"
      end
      
      html_parts << "</section>"
    end
    
    html_parts.join("\n")
  end
  
  def sanitize_text(text)
    return "" if text.blank?
    # Allow only safe characters, preserve special symbols
    text.to_s.gsub(/[<>"]/, '').strip
  end
  
  def set_last_updated
    self.last_updated = Time.current if content_changed? || last_updated.blank?
  end
  
  def set_next_version
    self.version = (MortgageContract.maximum(:version) || 0) + 1
  end
  
  def ensure_single_active
    if is_active? && saved_change_to_is_active?
      MortgageContract.where.not(id: id).update_all(is_active: false)
    end
  end
  
  def log_creation
    return unless current_user
    
    mortgage_contract_versions.create!(
      user: current_user,
      action: 'created',
      change_details: "Created new Mortgage Contract version #{version} (#{status.downcase})",
      new_content: content
    )
  end
  
  def log_update
    return unless current_user
    
    if saved_change_to_is_active? && is_active?
      # Log activation
      mortgage_contract_versions.create!(
        user: current_user,
        action: 'activated',
        change_details: "Activated Mortgage Contract version #{version}"
      )
    elsif saved_change_to_is_draft? && !is_draft?
      # Log publishing
      mortgage_contract_versions.create!(
        user: current_user,
        action: 'published',
        change_details: "Published Mortgage Contract version #{version}"
      )
    elsif saved_change_to_content?
      # Log content update
      mortgage_contract_versions.create!(
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
      changes_list << "Content updated"
    end
    
    if saved_change_to_is_draft?
      changes_list << "Status changed to #{is_draft? ? 'draft' : 'published'}"
    end
    
    changes_list.join("; ")
  end
end