class ContractClauseUsage < ApplicationRecord
  # Associations
  belongs_to :mortgage_contract
  belongs_to :lender_clause
  belongs_to :clause_position
  belongs_to :added_by, class_name: 'User', optional: true
  belongs_to :removed_by, class_name: 'User', optional: true

  # Validations
  validates :contract_version_at_usage, presence: true, numericality: { greater_than: 0 }
  validates :clause_version_at_usage, presence: true, numericality: { greater_than: 0 }
  validates :clause_content_snapshot, presence: true
  validates :added_at, presence: true

  # Ensure we don't have duplicate active usages for the same position in the same contract
  validates :clause_position_id, uniqueness: { 
    scope: [:mortgage_contract_id, :is_active],
    conditions: -> { where(is_active: true) },
    message: "can only have one active clause per position per contract"
  }

  # Scopes
  scope :active, -> { where(is_active: true) }
  scope :inactive, -> { where(is_active: false) }
  scope :ordered_by_position, -> { joins(:clause_position).order('clause_positions.display_order') }
  scope :recent, -> { order(added_at: :desc) }

  # Callbacks
  before_validation :set_added_at, on: :create
  before_validation :capture_clause_snapshot, on: :create
  before_validation :set_version_numbers, on: :create

  # Instance methods
  def active?
    is_active? && removed_at.nil?
  end

  def removed?
    !is_active? && removed_at.present?
  end

  def formatted_added_at
    added_at.strftime("%B %d, %Y at %I:%M %p")
  end

  def formatted_removed_at
    return nil unless removed_at.present?
    removed_at.strftime("%B %d, %Y at %I:%M %p")
  end

  def added_by_name
    added_by&.full_name || 'System'
  end

  def removed_by_name
    removed_by&.full_name || 'System'
  end

  def duration_active
    return nil unless removed_at.present?
    
    duration = removed_at - added_at
    days = (duration / 1.day).round
    
    case days
    when 0
      'Less than a day'
    when 1
      '1 day'
    else
      "#{days} days"
    end
  end

  # Get rendered HTML content using the snapshot
  def rendered_content(substitutions = {})
    return "" if clause_content_snapshot.blank?
    
    # Use substituted content if available, otherwise substitute on the fly
    if substituted_content.present?
      markup_to_html(substituted_content)
    else
      # Substitute placeholders and convert to HTML
      substituted = substitute_placeholders(clause_content_snapshot, substitutions)
      markup_to_html(substituted)
    end
  end

  # Mark as removed
  def remove!(user = nil)
    update!(
      is_active: false,
      removed_at: Time.current,
      removed_by: user
    )
  end

  # Reactivate (if it was previously removed)
  def reactivate!(user = nil)
    # First deactivate any other active clauses at this position
    mortgage_contract.contract_clause_usages
                    .where(clause_position: clause_position, is_active: true)
                    .where.not(id: id)
                    .update_all(is_active: false, removed_at: Time.current)

    update!(
      is_active: true,
      removed_at: nil,
      removed_by: nil
    )
  end

  # Historical context methods
  def contract_at_usage
    mortgage_contract.mortgage_contract_versions
                    .where('created_at <= ?', added_at)
                    .order(:created_at)
                    .last
  end

  def clause_at_usage
    lender_clause.lender_clause_versions
                 .where('created_at <= ?', added_at)
                 .order(:created_at)
                 .last
  end

  # Check if this usage represents the current state
  def represents_current_versions?
    current_contract_version = mortgage_contract.version
    current_clause_version = lender_clause.version
    
    contract_version_at_usage == current_contract_version &&
    clause_version_at_usage == current_clause_version
  end

  private

  def set_added_at
    self.added_at = Time.current if added_at.blank?
  end

  def capture_clause_snapshot
    if lender_clause.present? && clause_content_snapshot.blank?
      self.clause_content_snapshot = lender_clause.content
      
      # Also capture substituted content if we have context
      if mortgage_contract&.primary_user.present?
        substitutions = build_substitutions_for_contract
        self.substituted_content = lender_clause.substitute_placeholders(lender_clause.content, substitutions)
      end
    end
  end

  def set_version_numbers
    if mortgage_contract.present? && contract_version_at_usage.blank?
      self.contract_version_at_usage = mortgage_contract.version
    end
    
    if lender_clause.present? && clause_version_at_usage.blank?
      self.clause_version_at_usage = lender_clause.version
    end
  end

  def build_substitutions_for_contract
    substitutions = {}
    
    # Primary user substitutions
    if mortgage_contract.primary_user.present?
      user = mortgage_contract.primary_user
      substitutions['primary_user_full_name'] = user.full_name
      substitutions['primary_user_address'] = user.address || 'Address not provided'
    end
    
    # Lender substitutions
    substitutions['lender_name'] = lender_clause.lender.name
    substitutions['lender_contact_email'] = lender_clause.lender.contact_email || 'Contact email not provided'
    
    # Mortgage substitutions
    if mortgage_contract.mortgage.present?
      substitutions['mortgage_lvr'] = mortgage_contract.mortgage.lvr&.to_s || 'Not specified'
    end
    
    # Contract date substitutions
    substitutions['contract_start_date'] = added_at.strftime('%B %d, %Y')
    
    substitutions
  end

  def substitute_placeholders(text, substitutions = {})
    return text if text.blank?
    
    # Default substitutions
    default_substitutions = build_substitutions_for_contract
    
    # Merge with provided substitutions (provided ones take precedence)
    all_substitutions = default_substitutions.merge(substitutions)
    
    # Replace placeholders in format {{placeholder_name}}
    result = text.dup
    all_substitutions.each do |key, value|
      result.gsub!("{{#{key}}}", value.to_s)
    end
    
    result
  end

  def markup_to_html(text)
    return "" if text.blank?
    
    # Simple markup to HTML conversion (similar to LenderClause)
    # This could be extracted to a shared concern if needed
    sections = text.split(/^## /).reject(&:empty?)
    html_parts = []
    
    sections.each do |section_text|
      section_lines = section_text.split("\n")
      title = section_lines.first&.strip
      content_lines = section_lines[1..-1] || []
      
      html_parts << "<section class=\"clause-section\">"
      
      # Add section title
      if title && !title.empty?
        html_parts << "  <h4>#{sanitize_text(title)}</h4>"
      end
      
      # Process content lines
      in_list = false
      
      content_lines.each do |line|
        line = line.strip
        next if line.empty?
        
        # Handle bullet points
        if line.match(/^- (.+)$/)
          unless in_list
            html_parts << "  <ul>"
            in_list = true
          end
          item = $1.strip
          html_parts << "    <li>#{sanitize_text(item)}</li>"
          
        # Handle regular paragraphs
        else
          if in_list
            html_parts << "  </ul>"
            in_list = false
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
      
      html_parts << "</section>"
    end
    
    html_parts.join("\n")
  end

  def sanitize_text(text)
    return "" if text.blank?
    # Allow only safe characters, preserve special symbols
    text.to_s.gsub(/[<>"]/, '').strip
  end
end