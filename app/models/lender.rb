class Lender < ApplicationRecord
  include ChangeTracking
  
  # Change tracking configuration
  version_association :lender_versions
  track_changes :name, :lender_type, :contact_email, :country
  
  enum :lender_type, { futureproof: 0, lender: 1 }, prefix: true
  
  # Associations
  has_many :users, dependent: :restrict_with_exception
  has_many :mortgages, dependent: :restrict_with_exception
  
  # Wholesale Funder relationships
  has_many :lender_wholesale_funders, dependent: :destroy
  has_many :wholesale_funders, through: :lender_wholesale_funders
  has_many :active_wholesale_funders, -> { where(lender_wholesale_funders: { active: true }) }, 
           through: :lender_wholesale_funders, source: :wholesale_funder
  
  # Funder Pool relationships
  has_many :lender_funder_pools, dependent: :destroy
  has_many :funder_pools, through: :lender_funder_pools
  has_many :active_funder_pools, -> { where(lender_funder_pools: { active: true }) },
           through: :lender_funder_pools, source: :funder_pool
  
  validates :name, presence: true
  validates :lender_type, presence: true
  validates :contact_email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :country, presence: true
  
  # Ensure only one futureproof lender can exist
  validate :only_one_futureproof_lender, if: :lender_type_futureproof?
  
  private
  
  def only_one_futureproof_lender
    existing_futureproof = Lender.lender_type_futureproof.where.not(id: id).first
    if existing_futureproof.present?
      errors.add(:lender_type, "Only one Futureproof lender is allowed. #{existing_futureproof.name} is already the Futureproof lender.")
    end
  end
end
