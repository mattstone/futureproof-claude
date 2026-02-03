import { Controller } from "@hotwired/stimulus"

// Demo Income & Loan Controller
// Handles calculations for the demo income and loan page
export default class extends Controller {
  static targets = [
    "homeValueDisplay",
    "mortgageCard",
    "loanTerm",
    "loanTermDisplay",
    "incomeTerm",
    "incomeTermDisplay",
    "monthlyIncome",
    "totalIncome",
    "loanAmount"
  ]

  static values = {
    homeValue: { type: Number, default: 1500000 }
  }

  // Lookup table matching the QuoteService (Tom's model)
  loanLookup = {
    10: 300000,
    15: 410468,
    20: 443306,
    25: 498478,
    30: 553088
  }

  basePropertyValue = 1500000

  connect() {
    // Load saved home value from sessionStorage
    const savedHomeValue = sessionStorage.getItem('demo_home_value')
    if (savedHomeValue) {
      this.homeValueValue = parseInt(savedHomeValue)
      if (this.hasHomeValueDisplayTarget) {
        this.homeValueDisplayTarget.textContent = this.formatCurrency(this.homeValueValue)
      }
    }

    this.updateCalculations()
  }

  selectMortgage(event) {
    // Remove selected class from all cards
    this.mortgageCardTargets.forEach(card => {
      card.classList.remove('selected')
    })

    // Add selected class to clicked card
    event.currentTarget.classList.add('selected')

    // Store the selection
    const mortgageType = event.currentTarget.dataset.mortgageType
    sessionStorage.setItem('demo_mortgage_type', mortgageType)

    this.updateCalculations()
  }

  updateCalculations() {
    const loanTerm = this.hasLoanTermTarget ? parseInt(this.loanTermTarget.value) : 30
    const incomeTerm = this.hasIncomeTermTarget ? parseInt(this.incomeTermTarget.value) : 10

    // Update displays
    if (this.hasLoanTermDisplayTarget) {
      this.loanTermDisplayTarget.textContent = `${loanTerm} years`
    }
    if (this.hasIncomeTermDisplayTarget) {
      this.incomeTermDisplayTarget.textContent = `${incomeTerm} years`
    }

    // Calculate values using the lookup table
    const totalIncomeBase = this.loanLookup[incomeTerm] || this.loanLookup[10]
    const multiplier = this.homeValueValue / this.basePropertyValue
    const totalIncome = Math.round(totalIncomeBase * multiplier)
    const monthlyIncome = Math.round(totalIncome / incomeTerm / 12)
    const loanAmount = Math.round(this.homeValueValue * 0.8) // 80% LVR

    // Update displays
    if (this.hasMonthlyIncomeTarget) {
      this.monthlyIncomeTarget.textContent = this.formatCurrency(monthlyIncome)
    }
    if (this.hasTotalIncomeTarget) {
      this.totalIncomeTarget.textContent = this.formatCurrency(totalIncome)
    }
    if (this.hasLoanAmountTarget) {
      this.loanAmountTarget.textContent = this.formatCurrency(loanAmount)
    }

    // Save to sessionStorage
    sessionStorage.setItem('demo_loan_term', loanTerm)
    sessionStorage.setItem('demo_income_term', incomeTerm)
    sessionStorage.setItem('demo_monthly_income', monthlyIncome)
    sessionStorage.setItem('demo_total_income', totalIncome)
  }

  formatCurrency(amount) {
    return new Intl.NumberFormat('en-AU', {
      style: 'currency',
      currency: 'AUD',
      minimumFractionDigits: 0,
      maximumFractionDigits: 0
    }).format(amount)
  }
}
