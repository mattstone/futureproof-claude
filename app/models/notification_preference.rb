class NotificationPreference < ApplicationRecord
  belongs_to :user

  validates :user_id, presence: true, uniqueness: true

  # Default preferences: all enabled
  after_create :set_defaults

  private

  def set_defaults
    self.update_columns(
      payment_email: true,
      payment_sms: true,
      message_email: true
    ) if payment_email.nil?
  end
end
