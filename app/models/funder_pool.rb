class FunderPool < ApplicationRecord
  belongs_to :funder
  has_many :mortgage_funder_pools, dependent: :destroy
  has_many :mortgages, through: :mortgage_funder_pools
  
  # Validations
  validates :name, presence: true, length: { maximum: 255 }
  validates :name, uniqueness: { scope: :funder_id, message: "already exists for this funder" }
  validates :amount, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :allocated, presence: true, numericality: { greater_than_or_equal_to: 0 }
  
  # Custom validation
  validate :allocated_cannot_exceed_amount
  
  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :by_name, ->(name) { where("name ILIKE ?", "%#{name}%") }
  
  # Methods
  def available_amount
    amount - allocated
  end
  
  def allocation_percentage
    return 0 if amount == 0
    (allocated / amount * 100).round(2)
  end
  
  def formatted_amount
    "$#{amount.to_f.round(2).to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
  end
  
  def formatted_allocated
    "$#{allocated.to_f.round(2).to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
  end
  
  def formatted_available
    "$#{available_amount.to_f.round(2).to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
  end
  
  def display_name
    "#{name} (#{funder.name})"
  end
  
  private
  
  def allocated_cannot_exceed_amount
    if allocated && amount && allocated > amount
      errors.add(:allocated, "cannot exceed the total amount")
    end
  end
end
