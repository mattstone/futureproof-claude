class Contract < ApplicationRecord
  belongs_to :application
  belongs_to :wholesale_funder_pool, optional: true
  has_many :contract_messages, dependent: :destroy
  has_many :contract_versions, dependent: :destroy
  
  enum :status, {
    awaiting_funding: 0,
    awaiting_investment: 1,
    ok: 2,
    in_holiday: 3,
    in_arrears: 4,
    complete: 5
  }, prefix: true, default: :awaiting_funding
  
  validates :start_date, presence: true
  validates :end_date, presence: true
  validates :status, presence: true
  
  validate :end_date_after_start_date
  
  # Track changes with audit functionality
  attr_accessor :current_admin_user
  
  # Callbacks for change tracking
  after_create :log_creation
  after_update :log_update
  
  # Display methods
  def status_display
    status.humanize
  end
  
  def formatted_allocated_amount
    return "$0" unless allocated_amount.present?
    ActionController::Base.helpers.number_to_currency(allocated_amount, precision: (allocated_amount % 1 == 0 ? 0 : 2))
  end
  
  def display_name
    "#{application.user.display_name} - #{application.address[0..50]}"
  end

  # Messaging methods
  def has_unread_customer_messages?
    contract_messages.customer_messages.unread.exists?
  end

  def unread_customer_messages_count
    contract_messages.customer_messages.unread.count
  end

  def latest_customer_message
    contract_messages.customer_messages.sent.order(:created_at).last
  end

  def message_threads
    contract_messages.thread_messages.includes(:replies, :sender).order(created_at: :desc)
  end
  
  # Log when admin views contract
  def log_view_by(admin_user)
    return unless admin_user&.admin?
    
    contract_versions.create!(
      admin_user: admin_user,
      action: 'viewed',
      change_details: "Admin #{admin_user.display_name} viewed contract"
    )
  end
  
  private
  
  def log_creation
    return unless current_admin_user&.admin?
    
    contract_versions.create!(
      admin_user: current_admin_user,
      action: 'created',
      change_details: "Created contract for #{application.user.display_name}",
      new_status: status,
      new_start_date: start_date,
      new_end_date: end_date,
      new_application_id: application_id
    )
  end
  
  def log_update
    return unless current_admin_user&.admin?
    return unless saved_changes.any?
    
    # Special handling for status changes
    if saved_change_to_status?
      action = 'status_changed'
      change_details = "Changed status from '#{saved_change_to_status[0].humanize}' to '#{saved_change_to_status[1].humanize}'"
    else
      action = 'updated'
      change_details = build_change_summary
    end
    
    contract_versions.create!(
      admin_user: current_admin_user,
      action: action,
      change_details: change_details,
      previous_status: saved_change_to_status ? saved_change_to_status[0] : nil,
      new_status: saved_change_to_status ? saved_change_to_status[1] : nil,
      previous_start_date: saved_change_to_start_date ? saved_change_to_start_date[0] : nil,
      new_start_date: saved_change_to_start_date ? saved_change_to_start_date[1] : nil,
      previous_end_date: saved_change_to_end_date ? saved_change_to_end_date[0] : nil,
      new_end_date: saved_change_to_end_date ? saved_change_to_end_date[1] : nil,
      previous_application_id: saved_change_to_application_id ? saved_change_to_application_id[0] : nil,
      new_application_id: saved_change_to_application_id ? saved_change_to_application_id[1] : nil
    )
  end
  
  def build_change_summary
    changes_list = []
    
    if saved_change_to_status?
      changes_list << "Status changed from '#{saved_change_to_status[0].humanize}' to '#{saved_change_to_status[1].humanize}'"
    end
    
    if saved_change_to_start_date?
      old_date = saved_change_to_start_date[0]&.strftime("%B %d, %Y")
      new_date = saved_change_to_start_date[1]&.strftime("%B %d, %Y")
      changes_list << "Start date changed from '#{old_date}' to '#{new_date}'"
    end
    
    if saved_change_to_end_date?
      old_date = saved_change_to_end_date[0]&.strftime("%B %d, %Y")
      new_date = saved_change_to_end_date[1]&.strftime("%B %d, %Y")
      changes_list << "End date changed from '#{old_date}' to '#{new_date}'"
    end
    
    if saved_change_to_application_id?
      changes_list << "Application changed from ##{saved_change_to_application_id[0]} to ##{saved_change_to_application_id[1]}"
    end
    
    changes_list.join("; ")
  end
  
  def end_date_after_start_date
    return unless start_date && end_date
    
    if end_date < start_date
      errors.add(:end_date, "must be after start date")
    end
  end
end
