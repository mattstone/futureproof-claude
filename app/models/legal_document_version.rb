class LegalDocumentVersion < ApplicationRecord
  belongs_to :legal_document
  belongs_to :admin_user, class_name: "User", optional: true

  validates :action, presence: true, inclusion: { in: %w[created updated activated deactivated archived published approved retired] }

  scope :for_document, ->(document_id) { where(legal_document_id: document_id) }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_admin, ->(admin_id) { where(admin_user_id: admin_id) }

  def action_display
    action.humanize
  end

  def created_by
    admin_user&.display_name || "System"
  end

  def summary
    "#{created_by} #{action} — #{change_details}"
  end

  # Show diff between versions
  def show_diff
    return nil unless previous_content && new_content

    {
      action: action,
      timestamp: created_at,
      changed_by: created_by,
      previous: previous_content,
      current: new_content,
      character_delta: new_content.length - previous_content.length
    }
  end
end
