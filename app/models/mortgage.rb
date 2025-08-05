class Mortgage < ApplicationRecord
  has_many :mortgage_versions, dependent: :destroy
  
  enum :mortgage_type, {
    interest_only: 0,
    principal_and_interest: 1
  }, prefix: true

  validates :name, presence: true
  validates :mortgage_type, presence: true
  validates :lvr, presence: true, numericality: { greater_than: 0, less_than_or_equal_to: 100 }
  
  # Track changes with audit functionality
  attr_accessor :current_user
  
  after_create :log_creation
  after_update :log_update

  def calculate_monthly_income(principal = 1500000, loan_duration = 30, annuity_duration = 30)
    calc = FPCalculator.new

    results = calc.calculate(principal, loan_duration, annuity_duration)

    case mortgage_type
    when "interest_only"          then results[:interest_only_monthly_income]
    when "principal_and_interest" then results[:principal_and_interest_monthly_income]
    end
  end

  def repayment(principal = 1500000, loan_duration = 30, annuity_duration = 30)
    return 0 if mortgage_type_principal_and_interest?

    mortgage_type          = "interest_only"
    monthly_income_payment = calculate_monthly_income(principal, loan_duration, annuity_duration)
    ((monthly_income_payment * 12.to_f) * loan_duration.to_f).round(2)
  end

  def mini_calculator(principal = 1500000, loan_duration = 30, annuity_duration = 30)
    calc              = FPCalculator.new

    @min_results     = calc.calculate(principal, loan_duration, annuity_duration)
    annuity_duration = 10
    @max_results     = calc.calculate(principal, loan_duration, annuity_duration)

    # Return the range values
    {
      min_income: @min_results[:principal_and_interest_monthly_income],
      max_income: @max_results[:interest_only_monthly_income],
      min_results: @min_results,
      max_results: @max_results
    }
  end
  
  # Display name for mortgage type
  def mortgage_type_display
    case mortgage_type
    when 'interest_only'
      'Interest Only'
    when 'principal_and_interest'
      'Principal and Interest'
    else
      mortgage_type.humanize
    end
  end
  
  private
  
  def log_creation
    return unless current_user
    
    mortgage_versions.create!(
      user: current_user,
      action: 'created',
      change_details: "Created new mortgage '#{name}' with type '#{mortgage_type_display}' and LVR #{lvr}%",
      new_name: name,
      new_mortgage_type: mortgage_type_before_type_cast,
      new_lvr: lvr
    )
  end
  
  def log_update
    return unless current_user
    
    if saved_changes.any?
      mortgage_versions.create!(
        user: current_user,
        action: 'updated',
        change_details: build_change_summary,
        previous_name: saved_change_to_name ? saved_change_to_name[0] : nil,
        new_name: saved_change_to_name ? saved_change_to_name[1] : nil,
        previous_mortgage_type: saved_change_to_mortgage_type ? saved_change_to_mortgage_type[0] : nil,
        new_mortgage_type: saved_change_to_mortgage_type ? saved_change_to_mortgage_type[1] : nil,
        previous_lvr: saved_change_to_lvr ? saved_change_to_lvr[0] : nil,
        new_lvr: saved_change_to_lvr ? saved_change_to_lvr[1] : nil
      )
    end
  end
  
  def build_change_summary
    changes_list = []
    
    if saved_change_to_name?
      changes_list << "Name changed from '#{saved_change_to_name[0]}' to '#{saved_change_to_name[1]}'"
    end
    
    if saved_change_to_mortgage_type?
      old_type = case saved_change_to_mortgage_type[0]
                 when 0 then 'Interest Only'
                 when 1 then 'Principal and Interest'
                 else saved_change_to_mortgage_type[0].to_s
                 end
      new_type = case saved_change_to_mortgage_type[1]
                 when 0 then 'Interest Only'
                 when 1 then 'Principal and Interest'
                 else saved_change_to_mortgage_type[1].to_s
                 end
      changes_list << "Mortgage type changed from '#{old_type}' to '#{new_type}'"
    end
    
    if saved_change_to_lvr?
      changes_list << "LVR changed from #{saved_change_to_lvr[0]}% to #{saved_change_to_lvr[1]}%"
    end
    
    changes_list.join("; ")
  end
end
