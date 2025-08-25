class FunderPool < ApplicationRecord
  include ChangeTracking
  
  # Change tracking configuration
  version_association :funder_pool_versions
  track_changes :name, :amount, :allocated, :benchmark_rate, :margin_rate
  
  belongs_to :wholesale_funder
  has_many :contracts, dependent: :nullify
  
  # Lender relationships
  has_many :lender_funder_pools, dependent: :destroy
  has_many :lenders, through: :lender_funder_pools
  has_many :active_lenders, -> { where(lender_funder_pools: { active: true }) },
           through: :lender_funder_pools, source: :lender
  
  # Validations
  validates :name, presence: true, length: { maximum: 255 }
  validates :name, uniqueness: { scope: :wholesale_funder_id, message: "already exists for this wholesale funder" }
  validates :amount, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :allocated, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :benchmark_rate, presence: true, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validates :margin_rate, presence: true, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  
  # Custom validations
  validate :allocated_cannot_exceed_amount
  
  # Callbacks
  before_validation :set_default_benchmark_rate, on: :create
  
  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :by_name, ->(name) { where("name ILIKE ?", "%#{name}%") }
  scope :with_available_capital, ->(amount) { where("amount - allocated >= ?", amount) }
  
  # Methods
  def available_amount
    amount - allocated
  end
  
  def allocation_percentage
    return 0 if amount == 0
    (allocated / amount * 100).round(2)
  end
  
  def formatted_amount
    ActionController::Base.helpers.number_to_currency(amount, precision: 0)
  end
  
  def formatted_allocated
    ActionController::Base.helpers.number_to_currency(allocated, precision: 0)
  end
  
  def formatted_available
    ActionController::Base.helpers.number_to_currency(available_amount, precision: 0)
  end
  
  def display_name
    "#{name} (#{wholesale_funder.name})"
  end
  
  # Rate-related methods
  def currency
    wholesale_funder.currency
  end
  
  def benchmark_rate_name
    case currency
    when 'AUD' then 'BBSW'
    when 'USD' then 'SOFR'
    when 'GBP' then 'SONIA'
    else 'Benchmark'
    end
  end
  
  def total_rate
    (benchmark_rate || 0) + (margin_rate || 0)
  end
  
  def formatted_benchmark_rate
    "#{benchmark_rate}%"
  end
  
  def formatted_margin_rate
    "#{margin_rate}%"
  end
  
  def formatted_total_rate
    "#{total_rate}%"
  end
  
  # Class method to find first available pool for a given amount
  def self.find_available_for_allocation(amount)
    with_available_capital(amount).order(:created_at).first
  end
  
  # Allocate capital to this pool
  def allocate_capital!(amount)
    raise StandardError, "Insufficient capital available" if available_amount < amount
    
    update!(allocated: allocated + amount)
  end
  
  # Deallocate capital from this pool (when contracts are deleted)
  def deallocate_capital!(amount)
    new_allocated = [allocated - amount, 0].max  # Ensure it doesn't go below 0
    update!(allocated: new_allocated)
  end
  
  # Recalculate allocated amount based on actual contracts
  def recalculate_allocation!
    actual_allocated = contracts.sum(:allocated_amount)
    update!(allocated: actual_allocated)
  end
  
  private
  
  def allocated_cannot_exceed_amount
    if allocated && amount && allocated > amount
      errors.add(:allocated, "cannot exceed the total amount")
    end
  end
  
  def set_default_benchmark_rate
    return unless wholesale_funder.present?
    
    # Set benchmark rate to 4% for all currencies by default
    # The benchmark_rate_name method will show the appropriate benchmark name
    self.benchmark_rate = 4.00 if benchmark_rate.blank?
    self.margin_rate = 0.00 if margin_rate.blank?
  end
end
