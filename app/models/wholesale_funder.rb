class WholesaleFunder < ApplicationRecord
  include ChangeTracking
  
  # Change tracking configuration
  version_association :wholesale_funder_versions
  track_changes :name, :country, :currency
  
  # Associations
  has_many :funder_pools, dependent: :destroy
  
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
    "$#{total_capital.to_i.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
  end

  def formatted_total_allocated
    "$#{total_allocated.to_f.round(2).to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
  end

  def formatted_total_available
    "$#{total_available.to_f.round(2).to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
  end

  def capital_allocation_percentage
    return 0 if total_capital == 0
    (total_allocated / total_capital * 100).round(2)
  end

  # Count unique lenders that are using any of this wholesale funder's pools
  def lenders_count
    Lender.joins(lender_funder_pools: :funder_pool)
          .where(funder_pools: { wholesale_funder_id: id })
          .distinct
          .count
  end

  # Count active lenders only
  def active_lenders_count
    Lender.joins(lender_funder_pools: :funder_pool)
          .where(funder_pools: { wholesale_funder_id: id })
          .where(lender_funder_pools: { active: true })
          .distinct
          .count
  end
end
