class MortgageContractUser < ApplicationRecord
  belongs_to :mortgage_contract
  belongs_to :user
  
  validates :mortgage_contract_id, uniqueness: { scope: :user_id }
end