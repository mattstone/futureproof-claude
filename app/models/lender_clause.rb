class LenderClause < ApplicationRecord
  # Associations
  belongs_to :lender
  belongs_to :created_by, class_name: 'User', optional: true
  has_many :lender_clause_versions, dependent: :destroy
  has_many :contract_clause_usages, dependent: :destroy
  has_many :mortgage_contracts, through: :contract_clause_usages

  # Validations
  validates :title, presence: true
  validates :content, presence: true
  validates :last_updated, presence: true
  validates :version, presence: true, uniqueness: { scope: :lender_id }
  
  # Scopes
  scope :active, -> { where(is_active: true) }
  scope :published, -> { where(is_draft: false) }
  scope :drafts, -> { where(is_draft: true) }
  scope :by_version, -> { order(:version) }
  scope :for_lender, ->(lender) { where(lender: lender) }

  # Track changes with callbacks
  attr_accessor :current_user

  before_validation :set_last_updated, on: [:create, :update]
  before_validation :set_next_version, on: :create
  before_validation :set_created_by, on: :create
  after_save :ensure_single_active_per_lender
  after_create :log_creation
  after_update :log_update

  # Class methods
  def self.current_for_lender(lender)
    active.published.where(lender: lender).order(:last_updated).last
  end

  def self.latest_for_lender(lender)
    where(lender: lender).order(:version).last
  end

  # Instance methods
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
  def rendered_content(substitutions = {})
    return "" if content.blank?
    substituted_content = substitute_placeholders(content, substitutions)
    markup_to_html(substituted_content)
  end

  # Preview with sample data
  def rendered_preview_content
    sample_substitutions = {
      'primary_user_full_name' => 'John Smith',
      'primary_user_address' => '123 Main Street, Melbourne VIC 3000',
      'lender_name' => lender.name,
      'lender_address' => '456 Collins Street, Melbourne VIC 3000'
    }
    rendered_content(sample_substitutions)
  end

  # Substitute placeholders in content
  def substitute_placeholders(text, substitutions = {})
    return text if text.blank?
    
    # Default substitutions
    default_substitutions = {
      'lender_name' => lender.name,
      'lender_contact_email' => lender.contact_email || 'Contact email not provided'
    }
    
    # Contract date substitutions
    start_date = created_at || Time.current
    default_substitutions['contract_start_date'] = start_date.strftime('%B %d, %Y')
    
    # Merge with provided substitutions (provided ones take precedence)
    all_substitutions = default_substitutions.merge(substitutions)
    
    # Replace placeholders in format {{placeholder_name}}
    result = text.dup
    all_substitutions.each do |key, value|
      result.gsub!("{{#{key}}}", value.to_s)
    end
    
    result
  end

  # Create a new version when updating published clauses
  def create_new_version_if_published
    if persisted? && published? && content_changed?
      # Create a new version instead of updating existing
      new_version = self.class.new(
        lender: lender,
        title: title,
        content: content,
        description: description,
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

  # Get contract usages with snapshot data
  def contract_usages
    contract_clause_usages.includes(:mortgage_contract, :clause_position, :added_by, :removed_by)
  end

  def active_contract_usages
    contract_clause_usages.where(is_active: true)
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
        html_parts << "  <h3>#{sanitize_text(title)}</h3>"
      end
      
      # Process content lines
      in_list = false
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
          html_parts << "  <h4>#{sanitize_text(subtitle)}</h4>"
          
        # Handle bullet points
        elsif line.match(/^- (.+)$/)
          unless in_list
            html_parts << "  <ul>"
            in_list = true
          end
          item = $1.strip
          html_parts << "    <li>#{sanitize_text(item)}</li>"
          
        # Handle details pattern
        elsif line.match(/^\*\*(.+):\*\* (.+)$/)
          unless in_details
            html_parts << "  <div class=\"clause-details\">"
            in_details = true
          end
          field = $1.strip
          value = $2.strip
          html_parts << "    <div class=\"detail-row\">"
          html_parts << "      <strong>#{sanitize_text(field)}:</strong>"
          html_parts << "      <span>#{sanitize_text(value)}</span>"
          html_parts << "    </div>"
          
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
    max_version = lender.lender_clauses.maximum(:version) || 0
    self.version = max_version + 1
  end

  def set_created_by
    self.created_by = current_user if current_user.present? && created_by.blank?
  end

  def ensure_single_active_per_lender
    if is_active? && saved_change_to_is_active?
      lender.lender_clauses.where.not(id: id).update_all(is_active: false)
    end
  end

  def log_creation
    return unless current_user
    
    lender_clause_versions.create!(
      user: current_user,
      action: 'created',
      change_details: "Created new Lender Clause version #{version} (#{status.downcase})",
      new_content: content
    )
  end

  def log_update
    return unless current_user
    
    if saved_change_to_is_active? && is_active?
      # Log activation
      lender_clause_versions.create!(
        user: current_user,
        action: 'activated',
        change_details: "Activated Lender Clause version #{version}"
      )
    elsif saved_change_to_is_draft? && !is_draft?
      # Log publishing
      lender_clause_versions.create!(
        user: current_user,
        action: 'published',
        change_details: "Published Lender Clause version #{version}"
      )
    elsif saved_change_to_content?
      # Log content update
      lender_clause_versions.create!(
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
    
    if saved_change_to_description?
      changes_list << "Description updated"
    end
    
    if saved_change_to_is_draft?
      changes_list << "Status changed to #{is_draft? ? 'draft' : 'published'}"
    end
    
    changes_list.join("; ")
  end
end