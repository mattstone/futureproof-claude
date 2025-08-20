class ClausePosition < ApplicationRecord
  # Associations
  has_many :contract_clause_usages, dependent: :destroy
  has_many :lender_clauses, through: :contract_clause_usages
  has_many :mortgage_contracts, through: :contract_clause_usages

  # Validations
  validates :name, presence: true
  validates :section_identifier, presence: true, uniqueness: true
  validates :display_order, presence: true, numericality: { greater_than_or_equal_to: 0 }
  
  # Scopes
  scope :active, -> { where(is_active: true) }
  scope :ordered, -> { order(:display_order, :name) }

  # Instance methods
  def to_s
    name
  end
  
  def active_contract_clause_usages
    contract_clause_usages.where(is_active: true)
  end
  
  def contracts_using_position
    mortgage_contracts.joins(:contract_clause_usages)
                     .where(contract_clause_usages: { clause_position_id: id, is_active: true })
                     .distinct
  end
end