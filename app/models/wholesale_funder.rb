class WholesaleFunder < ApplicationRecord
  # Partner lifecycle — see Lender#status.
  enum :status, { active: 0, suspended: 1 }, prefix: true
  # Constituent spec: wholesale facilities vs warehouse lines.
  enum :funding_type, { wholesale: 0, warehouse: 1 }, prefix: true
  scope :real, -> { where(demo: false) }
  include ChangeTracking
  
  # Change tracking configuration
  version_association :wholesale_funder_versions
  track_changes :name, :country, :currency
  
  # Associations
  has_many :agreements, as: :agreeable, dependent: :restrict_with_exception
  has_many :funder_pools, dependent: :destroy
  has_many :wholesale_funder_contracts, dependent: :destroy
  
  # Lender relationships
  has_many :lender_wholesale_funders, dependent: :destroy
  has_many :lenders, through: :lender_wholesale_funders
  has_many :active_lenders, -> { where(lender_wholesale_funders: { active: true }) },
           through: :lender_wholesale_funders, source: :lender
  
  # Validations
  validates :name, presence: true, length: { maximum: 255 }, uniqueness: true
  validates :country, presence: true, length: { maximum: 100 }
  validates :currency, presence: true, inclusion: { in: %w[AUD USD GBP] }

  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :by_country, ->(country) { where(country: country) }
  scope :by_currency, ->(currency) { where(currency: currency) }

  # Methods
  def display_name
    "#{name} (#{country})"
  end

  def currency_display
    case currency
    when 'AUD' then 'Australian Dollar'
    when 'USD' then 'US Dollar'
    when 'GBP' then 'British Pound'
    else currency
    end
  end

  def currency_symbol
    case currency
    when 'AUD' then 'A$'
    when 'USD' then '$'
    when 'GBP' then '£'
    else currency
    end
  end

  # Enum-like methods for compatibility
  def self.currencies
    { "aud" => "AUD", "usd" => "USD", "gbp" => "GBP" }
  end

  def currency_aud?
    currency == 'AUD'
  end

  def currency_usd?
    currency == 'USD'
  end

  def currency_gbp?
    currency == 'GBP'
  end

  # WholesaleFunderPool summary methods
  def pools_count
    funder_pools.count
  end

  def total_capital
    funder_pools.sum(:amount)
  end

  def total_allocated
    funder_pools.sum(:allocated)
  end

  def total_available
    total_capital - total_allocated
  end

  def formatted_total_capital
    ActionController::Base.helpers.number_to_currency(total_capital, precision: 0)
  end

  def formatted_total_allocated
    ActionController::Base.helpers.number_to_currency(total_allocated, precision: 0)
  end

  def formatted_total_available
    ActionController::Base.helpers.number_to_currency(total_available, precision: 0)
  end

  def capital_allocation_percentage
    return 0 if total_capital == 0
    (total_allocated / total_capital * 100).round(2)
  end

  # Count unique lenders that are using any of this wholesale funder's pools
  def lenders_count
    Rails.cache.fetch("wholesale_funder_#{id}_lenders_count", expires_in: 1.hour) do
      Lender.joins(lender_funder_pools: :funder_pool)
            .where(funder_pools: { wholesale_funder_id: id })
            .distinct
            .count
    end
  end

  # Count active lenders only
  def active_lenders_count
    Rails.cache.fetch("wholesale_funder_#{id}_active_lenders_count", expires_in: 1.hour) do
      Lender.joins(lender_funder_pools: :funder_pool)
            .where(funder_pools: { wholesale_funder_id: id })
            .where(lender_funder_pools: { active: true })
            .distinct
            .count
    end
  end

  # Calculate committed amount from active applications
  def committed_amount
    active_lenders.joins(:applications)
                  .where(applications: { status: :accepted })
                  .sum('applications.equity_investment_amount')
  end

  # Available amount = total allocated - committed
  def available_amount
    total_allocated_amount - committed_amount
  end

  # Utilization percentage
  def utilization_percentage
    return 0 if total_allocated_amount == 0
    ((committed_amount.to_f / total_allocated_amount) * 100).round(2)
  end

  # Average monthly deployment over specified months
  def average_monthly_deployment(months = 12)
    start_date = months.months.ago
    # Get distributions for applications where lender uses this wholesale funder
    distributions = Distribution.where(
      application_id: Application.where(lender_id: self.lenders.pluck(:id))
    ).where('distributions.created_at >= ?', start_date)
     .sum(:amount)
    
    months_count = [months, 1].max
    (distributions / months_count).round(2)
  end

  # Runway calculation: available / monthly avg
  def runway_months
    monthly_avg = average_monthly_deployment(12)
    return 999 if monthly_avg == 0 || monthly_avg < 0.01
    (available_amount / monthly_avg).round(1)
  end
end
