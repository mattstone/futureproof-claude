class Broker < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :agreements, as: :agreeable, dependent: :restrict_with_exception
  has_many :broker_lenders, dependent: :destroy
  has_many :lenders, through: :broker_lenders
  has_many :applications, dependent: :nullify
  has_many :commission_rates, class_name: "BrokerCommissionRate", dependent: :destroy
  has_many :broker_commissions, dependent: :destroy

  VALID_JURISDICTIONS = [ "AU", "US", "NZ", "UK" ].freeze

  validates :jurisdiction, presence: true, inclusion: { in: VALID_JURISDICTIONS }

  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }
  scope :by_jurisdiction, ->(jurisdiction) { where(jurisdiction: jurisdiction) }
end
