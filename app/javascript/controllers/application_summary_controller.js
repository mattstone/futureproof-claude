import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["monthlyIncome", "repaymentAmount"]
  static values = {
    principal: Number,
    loanTerm: Number,
    incomePayout: Number,
    mortgageId: Number
  }

  connect() {
    this.calculateIncome()
  }

  async calculateIncome() {
    if (!this.hasMonthlyIncomeTarget) return

    // Show loading state
    this.monthlyIncomeTarget.textContent = "Calculating..."
    if (this.hasRepaymentAmountTarget) {
      this.repaymentAmountTarget.textContent = "Calculating..."
    }

    try {
      // Build API URL with parameters
      const params = new URLSearchParams({
        principal: this.principalValue,
        loan_term: this.loanTermValue,
        income_payout_term: this.incomePayoutValue
      })

      const response = await fetch(`/api/monthly_income?${params}`)
      const data = await response.json()

      // For summary, we'll show the income based on the selected mortgage type
      // The view will determine which repayment info to show based on mortgage type
      let monthlyIncome
      let repayment

      // Check if we have a mortgage ID to determine type
      // For now, we'll use a simple approach - if repayment target exists, it's interest only
      if (this.hasRepaymentAmountTarget) {
        // Interest only mortgage
        monthlyIncome = data.interest_only_income === 0 ? "Not Available" : data.formatted_interest_only_income
        repayment = data.interest_only_repayment === 0 ? "Not Available" : data.formatted_interest_only_repayment
      } else {
        // Principal and interest mortgage
        monthlyIncome = data.principal_interest_income === 0 ? "Not Available" : data.formatted_principal_interest_income
      }

      // Update displays
      this.monthlyIncomeTarget.textContent = monthlyIncome
      
      if (this.hasRepaymentAmountTarget && repayment) {
        this.repaymentAmountTarget.textContent = repayment
      }

    } catch (error) {
      console.error('Error calculating income:', error)
      this.monthlyIncomeTarget.textContent = "Error calculating"
      if (this.hasRepaymentAmountTarget) {
        this.repaymentAmountTarget.textContent = "Error calculating"
      }
    }
  }
}