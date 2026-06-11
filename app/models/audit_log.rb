class AuditLog < ApplicationRecord
  # The 'changes' column conflicts with ActiveRecord::Dirty#changes
  # Override to suppress DangerousAttributeError
  class << self
    def dangerous_attribute_method?(method_name)
      return false if method_name == "changes"
      super
    end
  end

  belongs_to :user
  belongs_to :application, optional: true
  # belongs_to :kyc_verification, optional: true  # KYC table not yet in master

  validates :action, :user_id, presence: true

  scope :recent, -> { order(created_at: :desc) }
  scope :by_user, ->(user) { where(user: user) }
  scope :by_action, ->(action) { where(action: action) }
  scope :by_resource, ->(type) { where(resource_type: type) }

  # Use change_data to avoid conflict with ActiveRecord::Dirty#changes
  def change_data
    self[:changes]
  end

  def change_data=(val)
    self[:changes] = val
  end

  def self.log_action(user:, action:, resource:, reason: nil, notes: nil, changes: {})
    record = new(
      user: user,
      action: action,
      resource_type: resource.class.name,
      resource_id: resource.id,
      application: resource.is_a?(Application) ? resource : nil,
      # kyc_verification: resource.is_a?(KycVerification) ? resource : nil,
      reason: reason,
      notes: notes
    )
    record[:changes] = changes.to_json
    record.save!
    record
  end

  def parse_changes
    raw = self[:changes]
    return {} if raw.blank?
    JSON.parse(raw)
  rescue
    {}
  end
end
