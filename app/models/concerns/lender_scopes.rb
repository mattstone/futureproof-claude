module LenderScopes
  extend ActiveSupport::Concern

  included do
    scope :for_lender, ->(lender_id) { where(lender_id: lender_id) }
    scope :with_lender_data, ->(lender_id) {
      for_lender(lender_id).includes(:user, :distributions).order(created_at: :desc)
    }
  end
end
