class MortgageContract < ApplicationRecord
  belongs_to :mortgage, optional: true
  has_many :mortgage_contract_versions, dependent: :destroy
  belongs_to :created_by, class_name: 'User', optional: true
  
  # User relationships for contracts
  belongs_to :primary_user, class_name: 'User', optional: true
  has_many :mortgage_contract_users, dependent: :destroy
  has_many :additional_users, through: :mortgage_contract_users, source: :user
  
  # Contract relationships
  has_many :contracts, dependent: :restrict_with_exception

  # Lender clauses relationships
  has_many :contract_clause_usages, dependent: :destroy
  has_many :active_contract_clause_usages, -> { where(is_active: true) }, 
           class_name: 'ContractClauseUsage'
  has_many :lender_clauses, through: :contract_clause_usages
  has_many :clause_positions, through: :contract_clause_usages
  
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
      ## 1. Agreement Parties
      
      This Equity Preservation Mortgage Agreement ("Agreement") is entered into between:
      
      **The Customer (Borrower):**
      {{primary_user_full_name}}
      {{primary_user_address}}
      
      **The Lender:**
      {{lender_name}}
      {{lender_address}}
      
      ## 2. Loan Agreement Details
      
      This is a paperless mortgage contract agreement between the Customer and the Lender for the following loan:
      
      **Property:** [Property Address]
      **Loan Amount:** [Loan Amount]
      **Loan-to-Value Ratio:** [LVR]%
      
      ## 3. Equity Preservation Features
      
      ### 3.1 Equity Protection
      
      This mortgage includes equity preservation features designed to protect your home's value:
      
      - **Market Value Protection:** Your loan amount will not exceed the original LVR even if property values decline
      - **Equity Sharing:** You maintain full ownership and benefit from any property value increases
      - **No Negative Equity:** You will never owe more than your property is worth
      
      ### 3.2 Interest Rate Structure
      
      - **Initial Rate:** [Interest Rate]% per annum
      - **Rate Type:** [Fixed/Variable]
      - **Rate Review:** [Review Terms]
      
      ## 4. Repayment Terms
      
      ### 4.1 Monthly Payments
      
      - **Payment Amount:** $[Monthly Payment]
      - **Payment Date:** [Day] of each month
      - **Payment Method:** Direct debit from nominated account
      
      ### 4.2 Early Repayment
      
      You may repay this loan early without penalty, subject to:
      - 30 days written notice
      - Settlement of outstanding balance
      - Discharge of security
      
      ## 5. Security and Insurance
      
      ### 5.1 Property Security
      
      This loan is secured by a first mortgage over the property described above.
      
      ### 5.2 Insurance Requirements
      
      You must maintain:
      - Building insurance for full replacement value
      - Public liability insurance
      - Mortgage protection insurance (optional but recommended)
      
      ## 6. Default and Enforcement
      
      ### 6.1 Events of Default
      
      Default occurs if you:
      - Fail to make required payments
      - Breach any covenant in this agreement
      - Become insolvent or bankrupt
      
      ### 6.2 Remedies
      
      Upon default, we may:
      - Demand immediate repayment
      - Exercise powers of sale
      - Appoint a receiver
      
      ## 7. Fees and Charges
      
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
      
      ## 9. Agreement Execution
      
      By entering into this agreement, both parties acknowledge that they have read, understood, and agree to be bound by all terms and conditions contained herein.
      
      **The Customer:**
      Name: {{primary_user_full_name}}
      Address: {{primary_user_address}}
      Signature: _________________________ Date: _____________
      
      **The Lender:**
      Name: {{lender_name}}
      Address: {{lender_address}}
      Signature: _________________________ Date: _____________
      
      **Contact Information:**
      Lender: {{lender_name}}
      Email: legal@futureprooffinancial.app
      Phone: 1300 XXX XXX
      Address: {{lender_address}}
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
  
  # Convert markup to HTML for display with integrated lender clauses
  def rendered_content(substitutions = {})
    return "" if content.blank?
    substituted_content = substitute_placeholders(content, substitutions)
    html_content = markup_to_html(substituted_content)
    
    # Integrate active lender clauses at their specified positions
    integrate_lender_clauses(html_content, substitutions)
  end
  
  # Convert markup to HTML with placeholder substitution for preview
  def rendered_preview_content
    sample_substitutions = {
      'primary_user_full_name' => 'John Smith',
      'primary_user_address' => '123 Main Street, Melbourne VIC 3000',
      'lender_name' => 'Futureproof Financial Group',
      'lender_address' => '456 Collins Street, Melbourne VIC 3000'
    }
    rendered_content(sample_substitutions)
  end
  
  # Substitute placeholders in content
  def substitute_placeholders(text, substitutions = {})
    return text if text.blank?
    
    # Default substitutions from associated records
    default_substitutions = {}
    
    # Primary user substitutions
    if primary_user.present?
      default_substitutions['primary_user_full_name'] = primary_user.full_name
      default_substitutions['primary_user_address'] = primary_user.address || 'Address not provided'
    end
    
    # Lender substitutions from mortgage's lenders
    if mortgage&.active_lenders&.any?
      primary_lender = mortgage.active_lenders.first
      default_substitutions['lender_name'] = primary_lender.name
      default_substitutions['lender_address'] = primary_lender.address || 'Address not provided'
      default_substitutions['lender_contact_email'] = primary_lender.contact_email || 'Contact email not provided'
    end
    
    # Mortgage substitutions
    if mortgage.present?
      default_substitutions['mortgage_lvr'] = mortgage.lvr&.to_s || 'Not specified'
    end
    
    # Application substitutions (from primary user's application if available)
    if primary_user&.applications&.any?
      application = primary_user.applications.order(:created_at).last
      if application.present?
        default_substitutions['application_address'] = application.address || 'Property address not provided'
        default_substitutions['application_home_value'] = application.home_value&.to_s || 'Not specified'
        default_substitutions['application_loan_term'] = application.loan_term&.to_s || 'Not specified'
        default_substitutions['application_income_payout_term'] = application.income_payout_term&.to_s || 'Not specified'
        default_substitutions['application_growth_rate'] = application.growth_rate&.to_s || 'Not specified'
        
        # Calculate monthly income using the application's method
        if application.mortgage.present?
          monthly_income = application.monthly_income_amount
          default_substitutions['application_monthly_income'] = ActionController::Base.helpers.number_with_delimiter(monthly_income.round(0))
        else
          default_substitutions['application_monthly_income'] = 'To be calculated'
        end
      end
    end
    
    # Contract date substitutions
    start_date = created_at || Time.current
    default_substitutions['contract_start_date'] = start_date.strftime('%B %d, %Y')
    
    # Calculate end date from start date + income payout term
    if primary_user&.applications&.any?
      application = primary_user.applications.order(:created_at).last
      if application&.income_payout_term.present?
        end_date = start_date + application.income_payout_term.years
        default_substitutions['contract_end_date'] = end_date.strftime('%B %d, %Y')
      else
        default_substitutions['contract_end_date'] = 'To be determined'
      end
    else
      default_substitutions['contract_end_date'] = 'To be determined'
    end
    
    # Merge with provided substitutions (provided ones take precedence)
    all_substitutions = default_substitutions.merge(substitutions)
    
    # Replace placeholders in format {{placeholder_name}}
    result = text.dup
    all_substitutions.each do |key, value|
      result.gsub!("{{#{key}}}", value.to_s)
    end
    
    result
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

  # Lender clauses integration methods
  def has_active_clauses?
    active_contract_clause_usages.any?
  end

  def active_clauses_count
    active_contract_clause_usages.count
  end

  def clauses_by_position
    active_contract_clause_usages.includes(:lender_clause, :clause_position)
                                 .joins(:clause_position)
                                 .order('clause_positions.display_order')
                                 .group_by(&:clause_position)
  end

  # Add a lender clause to this contract at a specific position
  def add_lender_clause(lender_clause, clause_position, user = nil)
    # Check if there's already an active clause at this position
    existing_usage = active_contract_clause_usages.find_by(clause_position: clause_position)
    
    if existing_usage
      # Remove the existing clause first
      existing_usage.remove!(user)
    end

    # Create new usage
    contract_clause_usages.create!(
      lender_clause: lender_clause,
      clause_position: clause_position,
      added_by: user
    )
  end

  # Remove a lender clause from this contract
  def remove_lender_clause(clause_position, user = nil)
    usage = active_contract_clause_usages.find_by(clause_position: clause_position)
    usage&.remove!(user)
  end

  # Get contract with all clauses as it was at a specific time (historical reconstruction)
  def contract_at_time(timestamp)
    {
      contract_version: mortgage_contract_versions.where('created_at <= ?', timestamp).order(:created_at).last,
      active_clauses: contract_clause_usages.where('added_at <= ? AND (removed_at IS NULL OR removed_at > ?)', timestamp, timestamp)
                                           .includes(:lender_clause, :clause_position)
    }
  end
  
  private

  # Integrate lender clauses into the HTML content at their specified positions
  def integrate_lender_clauses(html_content, substitutions = {})
    return html_content unless has_active_clauses?

    # Parse the HTML to find section insertion points
    sections = html_content.split(/(<\/section>)/i)
    integrated_sections = []
    section_count = 0

    sections.each_with_index do |section_part, index|
      integrated_sections << section_part

      # Check if this is the end of a section
      if section_part.match(/<\/section>/i) 
        section_count += 1
        
        # Insert clauses that should come after this section
        section_identifier = "after_section_#{section_count}"
        clauses_for_position = active_contract_clause_usages
                              .joins(:clause_position)
                              .where(clause_positions: { section_identifier: section_identifier })
                              .includes(:lender_clause)

        clauses_for_position.each do |usage|
          clause_html = usage.rendered_content(substitutions)
          integrated_sections << "\n<div class=\"lender-clause-insertion\">\n#{clause_html}\n</div>\n"
        end
      end
    end

    # Add clauses that should come before signatures (at the very end)
    before_signatures_clauses = active_contract_clause_usages
                               .joins(:clause_position)
                               .where(clause_positions: { section_identifier: 'before_signatures' })
                               .includes(:lender_clause)

    before_signatures_clauses.each do |usage|
      clause_html = usage.rendered_content(substitutions)
      integrated_sections << "\n<div class=\"lender-clause-insertion\">\n#{clause_html}\n</div>\n"
    end

    integrated_sections.join
  end
  
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