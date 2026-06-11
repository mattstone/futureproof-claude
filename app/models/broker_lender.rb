class BrokerLender < ApplicationRecord
  belongs_to :broker
  belongs_to :lender
end
