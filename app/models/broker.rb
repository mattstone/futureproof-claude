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

  # Partner lifecycle (spec: pending → active → suspended). The legacy
  # `active` boolean stays in sync because the old admin and the lender
  # portal still read it.
  enum :status, { pending: 0, active: 1, suspended: 2 }, prefix: true
  before_save :sync_status_and_active

  validates :jurisdiction, presence: true, inclusion: { in: VALID_JURISDICTIONS }

  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }
  scope :by_jurisdiction, ->(jurisdiction) { where(jurisdiction: jurisdiction) }

  private

  # Console drives the enum; the old admin still flips the boolean. Whichever
  # side changed wins, the other follows.
  def sync_status_and_active
    if will_save_change_to_active? && !will_save_change_to_status?
      self.status = active? ? :active : :suspended
    else
      self.active = status_active?
    end
  end
end
