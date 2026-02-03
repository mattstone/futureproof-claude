import { Controller } from "@hotwired/stimulus"

// Demo Funding Controller
// Displays saved values from sessionStorage on the funding details page
export default class extends Controller {
  static targets = [
    "mortgageType",
    "loanTerm",
    "loanAmount",
    "homeValue",
    "growthRate",
    "futureValue",
    "equityPreserved",
    "interestPaid",
    "repaymentAmount",
    "totalIncome",
    "monthlyIncome",
    "annuityDuration"
  ]

  static values = {
    market: { type: String, default: 'us' },
    defaultHomeValue: { type: Number, default: 2450000 }
  }

  // Default values (matching demo_property_details defaults)
  defaults = {
    homeValue: 2450000,  // Will be overridden by market-specific value
    loanTerm: 30,
    incomeTerm: 10,
    growthRate: 4,
    mortgageType: 'interest_only',
    interestRate: 0.0745,
    lvr: 0.80
  }

  // Lookup tables (same as demo_webapp_controller)
  interestOnlyLookup = {
    10: { monthly: 1536, loanBalance: 553088 },
    15: { monthly: 1367, loanBalance: 553088 },
    20: { monthly: 1107, loanBalance: 553088 },
    25: { monthly: 996, loanBalance: 553088 },
    30: { monthly: 922, loanBalance: 553088 }
  }

  principalInterestLookup = {
    10: { monthly: 1183, loanBalance: 0 },
    15: { monthly: 1052, loanBalance: 0 },
    20: { monthly: 853, loanBalance: 0 },
    25: { monthly: 767, loanBalance: 0 },
    30: { monthly: 710, loanBalance: 0 }
  }

  basePropertyValue = 1500000

  connect() {
    this.loadAndDisplayValues()
  }

  loadAndDisplayValues() {
    // Use market-specific default home value
    const defaultHomeValue = this.hasDefaultHomeValueValue ? this.defaultHomeValueValue : this.defaults.homeValue

    // Load saved values from sessionStorage
    const homeValue = parseInt(sessionStorage.getItem('demo_home_value')) || defaultHomeValue
    const loanTerm = parseInt(sessionStorage.getItem('demo_loan_term')) || this.defaults.loanTerm
    const incomeTerm = parseInt(sessionStorage.getItem('demo_income_term')) || this.defaults.incomeTerm
    const growthRate = parseFloat(sessionStorage.getItem('demo_growth_rate')) || this.defaults.growthRate
    const mortgageType = sessionStorage.getItem('demo_mortgage_type') || this.defaults.mortgageType

    // Calculate derived values
    const loanAmount = Math.round(homeValue * this.defaults.lvr)
    const multiplier = homeValue / this.basePropertyValue

    // Get income based on mortgage type
    const lookup = mortgageType === 'principal_and_interest'
      ? this.principalInterestLookup
      : this.interestOnlyLookup
    const incomeData = lookup[incomeTerm] || lookup[10]
    const monthlyIncome = incomeData.monthly * multiplier
    const totalIncome = monthlyIncome * 12 * incomeTerm

    // Calculate future value and equity
    const futureValue = homeValue * Math.pow(1 + (growthRate / 100), loanTerm)
    const repaymentAmount = mortgageType === 'principal_and_interest' ? 0 : loanAmount
    const equityPreserved = futureValue - repaymentAmount

    // Calculate interest paid (simplified: loan amount * rate * years)
    const interestPaid = loanAmount * this.defaults.interestRate * loanTerm

    // Update display
    if (this.hasMortgageTypeTarget) {
      this.mortgageTypeTarget.textContent = mortgageType === 'principal_and_interest'
        ? 'Principal + interest'
        : 'Interest-only'
    }

    if (this.hasLoanTermTarget) {
      this.loanTermTarget.textContent = `${loanTerm} years`
    }

    if (this.hasLoanAmountTarget) {
      this.loanAmountTarget.textContent = this.formatCurrency(loanAmount)
    }

    if (this.hasHomeValueTarget) {
      this.homeValueTarget.textContent = this.formatCurrency(homeValue)
    }

    if (this.hasGrowthRateTarget) {
      this.growthRateTarget.textContent = `${growthRate}%`
    }

    if (this.hasFutureValueTarget) {
      this.futureValueTarget.textContent = this.formatCurrency(Math.round(futureValue))
    }

    if (this.hasEquityPreservedTarget) {
      this.equityPreservedTarget.textContent = this.formatCurrency(Math.round(equityPreserved))
    }

    if (this.hasInterestPaidTarget) {
      this.interestPaidTarget.textContent = this.formatCurrency(Math.round(interestPaid))
    }

    if (this.hasRepaymentAmountTarget) {
      this.repaymentAmountTarget.textContent = this.formatCurrency(repaymentAmount)
    }

    if (this.hasTotalIncomeTarget) {
      this.totalIncomeTarget.textContent = this.formatCurrency(Math.round(totalIncome))
    }

    if (this.hasMonthlyIncomeTarget) {
      this.monthlyIncomeTarget.textContent = this.formatCurrencyWithCents(monthlyIncome)
    }

    if (this.hasAnnuityDurationTarget) {
      this.annuityDurationTarget.textContent = `${incomeTerm} years`
    }
  }

  formatCurrency(amount) {
    return new Intl.NumberFormat('en-AU', {
      style: 'currency',
      currency: 'AUD',
      minimumFractionDigits: 0,
      maximumFractionDigits: 0
    }).format(amount)
  }

  formatCurrencyWithCents(amount) {
    return new Intl.NumberFormat('en-AU', {
      style: 'currency',
      currency: 'AUD',
      minimumFractionDigits: 2,
      maximumFractionDigits: 2
    }).format(amount)
  }

  // Checkbox toggle (for annuity use checkboxes)
  toggleCheckbox(event) {
    event.currentTarget.classList.toggle('checked')
  }
}
