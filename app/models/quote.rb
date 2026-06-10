# Quote — immutable snapshot of the income quote shown to a borrower.
#
# Records the exact product version, inputs, and outputs so any application
# can be reproduced against the model that priced it (PLATFORM_BUILD_BRIEF §6:
# quotes are immutable, versioned, reproducible). A new snapshot is appended
# every time the borrower's income & mortgage selection changes; the latest
# one is the quote of record.
class Quote < ApplicationRecord
  belongs_to :application

  validates :product_version, :home_value, :term_years, :monthly_income, :issued_at, presence: true

  scope :latest_first, -> { order(issued_at: :desc, id: :desc) }

  # Quotes are immutable once persisted — append a new snapshot instead.
  def readonly?
    persisted?
  end

  # Builds (does not save) a snapshot of the application's current selection.
  def self.snapshot_for(application)
    monthly = application.monthly_income_amount.to_f
    new(
      application: application,
      product_version: EpmModelConfig.model_version,
      pricing_model: "Pavel's Model v14d Optimised",
      mortgage_type: application.mortgage&.mortgage_type,
      region: application.region,
      home_value: application.home_value,
      term_years: application.loan_term,
      income_payout_term: application.income_payout_term,
      annuity_rate: application.home_value.to_i.positive? ? (monthly * 12 / application.home_value).round(6) : nil,
      lvr: application.mortgage&.lvr.to_f.positive? ? (application.mortgage.lvr / 100.0).round(4) : nil,
      max_loan: EpmModelConfig.max_loan(home_value: application.home_value.to_i),
      monthly_income: monthly.round(0),
      annual_income: (monthly * 12).round(0),
      total_income: (monthly * 12 * application.income_payout_term.to_i).round(0),
      issued_at: Time.current
    )
  end
end
