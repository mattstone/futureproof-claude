class LenderClauseVersion < ApplicationRecord
  # Associations
  belongs_to :lender_clause
  belongs_to :user, optional: true

  # Validations
  validates :action, presence: true, inclusion: { in: %w[created updated activated published] }

  # Scopes
  scope :ordered, -> { order(:created_at) }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_action, ->(action) { where(action: action) }

  # Instance methods
  def action_description
    case action
    when 'created'
      'Created'
    when 'updated' 
      'Updated'
    when 'activated'
      'Activated'
    when 'published'
      'Published'
    else
      action.humanize
    end
  end

  def action_color
    case action
    when 'created'
      'info'
    when 'updated'
      'warning' 
    when 'activated'
      'success'
    when 'published'
      'primary'
    else
      'secondary'
    end
  end

  def formatted_created_at
    created_at.strftime("%B %d, %Y at %I:%M %p")
  end

  def user_name
    user&.full_name || 'System'
  end

  def has_content_changes?
    previous_content.present? && new_content.present?
  end

  def content_diff
    return nil unless has_content_changes?
    
    # Simple line-by-line diff
    old_lines = previous_content.lines
    new_lines = new_content.lines
    
    {
      removed_lines: old_lines - new_lines,
      added_lines: new_lines - old_lines
    }
  end
end