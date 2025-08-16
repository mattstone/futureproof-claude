class FunderPoolVersion < ApplicationRecord
  belongs_to :funder_pool
  belongs_to :user
  
  # Alias for consistency with shared change history interface
  alias_method :admin_user, :user
  
  validates :action, presence: true, inclusion: { in: %w[created updated viewed] }
  
  scope :recent, -> { order(created_at: :desc) }
  scope :by_action, ->(action) { where(action: action) }
  scope :changes_only, -> { where.not(action: 'viewed') }
  scope :views_only, -> { where(action: 'viewed') }
  
  # Action descriptions for display
  def action_description
    case action
    when 'created'
      'created funder pool'
    when 'updated'
      'updated funder pool'
    when 'viewed'
      'viewed funder pool'
    else
      action
    end
  end
  
  # Formatted creation time
  def formatted_created_at
    created_at.strftime("%B %d, %Y at %I:%M %p")
  end
  
  # Check if this version has field changes to display
  def has_field_changes?
    has_name_changes? || has_amount_changes? || has_allocated_changes? || 
    has_benchmark_rate_changes? || has_margin_rate_changes?
  end
  
  def has_name_changes?
    previous_name.present? && new_name.present? && previous_name != new_name
  end
  
  def has_amount_changes?
    previous_amount.present? && new_amount.present? && previous_amount != new_amount
  end
  
  def has_allocated_changes?
    previous_allocated.present? && new_allocated.present? && previous_allocated != new_allocated
  end
  
  def has_benchmark_rate_changes?
    previous_benchmark_rate.present? && new_benchmark_rate.present? && previous_benchmark_rate != new_benchmark_rate
  end
  
  def has_margin_rate_changes?
    previous_margin_rate.present? && new_margin_rate.present? && previous_margin_rate != new_margin_rate
  end
  
  # Generate detailed change summary
  def detailed_changes
    changes = []
    
    if has_name_changes?
      changes << {
        field: 'Name',
        from: previous_name,
        to: new_name
      }
    end
    
    if has_amount_changes?
      changes << {
        field: 'Amount',
        from: format_currency(previous_amount),
        to: format_currency(new_amount)
      }
    end
    
    if has_allocated_changes?
      changes << {
        field: 'Allocated',
        from: format_currency(previous_allocated),
        to: format_currency(new_allocated)
      }
    end
    
    if has_benchmark_rate_changes?
      changes << {
        field: 'Benchmark Rate',
        from: "#{previous_benchmark_rate}%",
        to: "#{new_benchmark_rate}%"
      }
    end
    
    if has_margin_rate_changes?
      changes << {
        field: 'Margin Rate',
        from: "#{previous_margin_rate}%",
        to: "#{new_margin_rate}%"
      }
    end
    
    changes
  end
  
  private
  
  def format_currency(amount)
    return "N/A" unless amount.present?
    ActionController::Base.helpers.number_to_currency(amount, precision: 0)
  end
end