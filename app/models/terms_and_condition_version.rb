class TermsAndConditionVersion < ApplicationRecord
  belongs_to :terms_and_condition
  belongs_to :user
  
  validates :action, presence: true
  validates :action, inclusion: { in: %w[created updated activated] }
  
  scope :recent_first, -> { order(created_at: :desc) }
  scope :for_terms, ->(terms_id) { where(terms_and_condition_id: terms_id) }
  
  def formatted_created_at
    created_at.strftime("%B %d, %Y at %I:%M %p")
  end
  
  def action_description
    case action
    when 'created'
      'Created new terms'
    when 'updated'
      'Updated terms content'
    when 'activated'
      'Activated this version'
    else
      action.humanize
    end
  end
  
  def has_content_changes?
    previous_content.present? && new_content.present?
  end
  
  def summarize_changes
    return change_details if change_details.present?
    return "Content updated" if has_content_changes?
    action_description
  end
  
  def content_diff
    return [] unless has_content_changes?
    
    old_lines = previous_content.to_s.split("\n")
    new_lines = new_content.to_s.split("\n")
    
    diff_lines = []
    i, j = 0, 0
    
    while i < old_lines.length || j < new_lines.length
      if i >= old_lines.length
        # Only new lines remaining
        while j < new_lines.length
          diff_lines << { type: :added, content: new_lines[j] }
          j += 1
        end
      elsif j >= new_lines.length
        # Only old lines remaining
        while i < old_lines.length
          diff_lines << { type: :removed, content: old_lines[i] }
          i += 1
        end
      elsif old_lines[i] == new_lines[j]
        # Lines are the same
        diff_lines << { type: :unchanged, content: old_lines[i] }
        i += 1
        j += 1
      else
        # Lines are different - look ahead to find if this is a change or insertion/deletion
        old_line_in_new = new_lines[j..-1]&.index(old_lines[i])
        new_line_in_old = old_lines[i..-1]&.index(new_lines[j])
        
        if old_line_in_new && new_line_in_old
          # Both lines appear later - this is a change
          if old_line_in_new <= new_line_in_old
            # Treat as removal then addition
            diff_lines << { type: :removed, content: old_lines[i] }
            i += 1
          else
            # Treat as addition
            diff_lines << { type: :added, content: new_lines[j] }
            j += 1
          end
        elsif old_line_in_new
          # Old line appears later in new - this new line is an insertion
          diff_lines << { type: :added, content: new_lines[j] }
          j += 1
        elsif new_line_in_old
          # New line appears later in old - this old line is a deletion
          diff_lines << { type: :removed, content: old_lines[i] }
          i += 1
        else
          # Neither line appears later - this is a change
          diff_lines << { type: :removed, content: old_lines[i] }
          diff_lines << { type: :added, content: new_lines[j] }
          i += 1
          j += 1
        end
      end
    end
    
    # Group consecutive unchanged lines for better display
    grouped_diff = []
    unchanged_count = 0
    
    diff_lines.each do |line|
      if line[:type] == :unchanged
        unchanged_count += 1
      else
        if unchanged_count > 0
          if unchanged_count <= 3
            # Show all unchanged lines if there are only a few
            (unchanged_count).times do |idx|
              back_idx = grouped_diff.length - unchanged_count + idx
              grouped_diff << diff_lines[diff_lines.index(line) - unchanged_count + idx] if back_idx >= 0
            end
          else
            # Show context lines for large unchanged blocks
            grouped_diff << { type: :context, content: "... #{unchanged_count} unchanged lines ..." }
          end
          unchanged_count = 0
        end
        grouped_diff << line
      end
    end
    
    # Handle trailing unchanged lines
    if unchanged_count > 0 && unchanged_count <= 3
      # Add the last few unchanged lines
      last_unchanged = diff_lines.last(unchanged_count)
      grouped_diff.concat(last_unchanged)
    elsif unchanged_count > 0
      grouped_diff << { type: :context, content: "... #{unchanged_count} more unchanged lines ..." }
    end
    
    grouped_diff
  end
end