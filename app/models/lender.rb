class Lender < ApplicationRecord
  include ChangeTracking
  
  # Change tracking configuration
  version_association :lender_versions
  track_changes :name, :lender_type, :contact_email, :country
  
  enum :lender_type, { futureproof: 0, lender: 1 }, prefix: true
  
  # Associations
  has_many :users, dependent: :restrict_with_exception
  
  # Mortgage relationships (many-to-many)
  has_many :mortgage_lenders, dependent: :destroy
  has_many :mortgages, through: :mortgage_lenders
  has_many :active_mortgages, -> { where(mortgage_lenders: { active: true }) },
           through: :mortgage_lenders, source: :mortgage
  
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
  
  # Contract relationships
  has_many :contracts, dependent: :restrict_with_exception

  # Lender Clauses relationships
  has_many :lender_clauses, dependent: :destroy
  has_many :active_lender_clauses, -> { where(is_active: true) }, 
           class_name: 'LenderClause'
  has_many :published_lender_clauses, -> { where(is_draft: false) }, 
           class_name: 'LenderClause'
  
  validates :name, presence: true
  validates :lender_type, presence: true
  validates :contact_email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :country, presence: true
  
  # Ensure only one futureproof lender can exist
  validate :only_one_futureproof_lender, if: :lender_type_futureproof?
  
  # Summary methods for admin display
  def wholesale_funders_count
    lender_wholesale_funders.count
  end
  
  def total_fund_pool_amount
    funder_pools.sum(:amount)
  end
  
  def formatted_total_fund_pool_amount
    ActionController::Base.helpers.number_to_currency(total_fund_pool_amount, precision: 0)
  end
  
  # Loan/Contract summary methods
  def loans_count
    contracts.count
  end
  
  def total_allocated_amount
    contracts.sum(:allocated_amount)
  end
  
  def formatted_total_allocated_amount
    ActionController::Base.helpers.number_to_currency(total_allocated_amount, precision: 0)
  end

  # Simplified clause methods (singleton approach)
  def clause_content
    # Get the single clause content from the custom_clause_content field or create default
    custom_clause_content || ""
  end

  def clause_content=(content)
    self.custom_clause_content = content
  end

  def has_clause?
    custom_clause_content.present?
  end
  
  # Get the single active funder pool for this lender
  def active_funder_pool
    active_funder_pools.first
  end

  def clause_summary
    return "No clause" unless has_clause?
    truncated = custom_clause_content.strip
    truncated.length > 50 ? "#{truncated[0..47]}..." : truncated
  end
  
  private
  
  def only_one_futureproof_lender
    existing_futureproof = Lender.lender_type_futureproof.where.not(id: id).first
    if existing_futureproof.present?
      errors.add(:lender_type, "Only one Futureproof lender is allowed. #{existing_futureproof.name} is already the Futureproof lender.")
    end
  end
end
