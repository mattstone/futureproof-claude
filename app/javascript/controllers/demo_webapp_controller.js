import { Controller } from "@hotwired/stimulus"

// Demo Webapp Controller
// Handles interactions for the demo application flow replicating the React Webapp
export default class extends Controller {
  static targets = [
    "addressInput",
    "homeValueDisplay",
    "currentValue",
    "growthRateDisplay",
    "projectedValue",
    "maxAnnuityIncome",
    "incomeTerm",
    "incomeTermDisplay",
    "monthlyIncome",
    "incomeYears",
    "loanTerm",
    "interestOnlyAmount",
    "principalInterestAmount",
    "loanRepayment",
    "propertyValue",
    "valuationModal",
    "valuationInput",
    "originalValue"
  ]

  static values = {
    homeValue: { type: Number, default: 2500000 },
    market: { type: String, default: 'us' }
  }

  // Lookup tables matching the QuoteService (Tom's model)
  // Monthly income amounts for a $1.5M property based on income term
  // We scale these values based on the actual property value

  // Interest-only: Higher monthly income, loan balance remains
  interestOnlyLookup = {
    10: { monthly: 1536, loanBalance: 553088 },
    15: { monthly: 1367, loanBalance: 553088 },
    20: { monthly: 1107, loanBalance: 553088 },
    25: { monthly: 996, loanBalance: 553088 },
    30: { monthly: 922, loanBalance: 553088 }
  }

  // Principal + Interest: Lower monthly income, no loan balance at end
  principalInterestLookup = {
    10: { monthly: 1183, loanBalance: 0 },
    15: { monthly: 1052, loanBalance: 0 },
    20: { monthly: 853, loanBalance: 0 },
    25: { monthly: 767, loanBalance: 0 },
    30: { monthly: 710, loanBalance: 0 }
  }

  basePropertyValue = 1500000  // Used for scaling calculations

  connect() {
    // Load any saved values from sessionStorage
    this.loadSavedData()
    this.updateCalculations()
  }

  loadSavedData() {
    // Check if market has changed - if so, reset values for the new market
    const savedMarket = sessionStorage.getItem('demo_market')
    const currentMarket = this.marketValue

    if (savedMarket !== currentMarket) {
      // Market has changed - clear old values and use new defaults
      sessionStorage.setItem('demo_market', currentMarket)
      sessionStorage.setItem('demo_home_value', this.homeValueValue)
      // Clear other values so they reset to defaults
      sessionStorage.removeItem('demo_growth_rate')
      sessionStorage.removeItem('demo_income_term')
      sessionStorage.removeItem('demo_loan_term')
      sessionStorage.removeItem('demo_mortgage_type')
    }

    const savedHomeValue = sessionStorage.getItem('demo_home_value')
    if (savedHomeValue) {
      this.homeValueValue = parseInt(savedHomeValue)
    } else {
      // Save the default home value to sessionStorage
      sessionStorage.setItem('demo_home_value', this.homeValueValue)
    }

    // Update property value display if target exists
    if (this.hasPropertyValueTarget) {
      this.propertyValueTarget.textContent = this.formatCurrency(this.homeValueValue)
    }

    const savedGrowthRate = sessionStorage.getItem('demo_growth_rate')
    if (savedGrowthRate) {
      this.growthRate = parseFloat(savedGrowthRate)
    } else {
      this.growthRate = 4  // Default matches UI (Medium growth - 4%)
      sessionStorage.setItem('demo_growth_rate', this.growthRate)
    }

    // Update growth rate display if target exists
    if (this.hasGrowthRateDisplayTarget) {
      this.growthRateDisplayTarget.textContent = this.growthRate
    }

    const savedIncomeTerm = sessionStorage.getItem('demo_income_term')
    if (savedIncomeTerm && this.hasIncomeTermTarget) {
      this.incomeTermTarget.value = savedIncomeTerm
    }

    // Sync mortgage type selection with sessionStorage
    // This ensures visual state matches stored state
    const savedMortgageType = sessionStorage.getItem('demo_mortgage_type')
    const mortgageCards = this.element.querySelectorAll('.demo-mortgage-option-card')

    if (mortgageCards.length > 0) {
      if (savedMortgageType) {
        // Sync visual state to match sessionStorage
        mortgageCards.forEach(card => {
          if (card.dataset.mortgageType === savedMortgageType) {
            card.classList.add('selected')
          } else {
            card.classList.remove('selected')
          }
        })
      } else {
        // No saved value - save the currently selected card's value
        const selectedCard = this.element.querySelector('.demo-mortgage-option-card.selected')
        if (selectedCard) {
          sessionStorage.setItem('demo_mortgage_type', selectedCard.dataset.mortgageType)
        } else {
          // Default to interest_only if nothing selected
          sessionStorage.setItem('demo_mortgage_type', 'interest_only')
        }
      }
    } else if (!savedMortgageType) {
      // No cards on this page, set default
      sessionStorage.setItem('demo_mortgage_type', 'interest_only')
    }

    // Update projected value with current values
    this.updateProjectedValue()
  }

  // Property Search page
  handleKeydown(event) {
    if (event.key === 'Enter') {
      this.searchProperty()
    }
  }

  searchProperty() {
    // For demo, just navigate to property details
    const address = this.hasAddressInputTarget ? this.addressInputTarget.value : ''
    if (address) {
      sessionStorage.setItem('demo_address', address)
    }
    window.location.href = '/applications/demo_property_details'
  }

  // Property Details page - Growth Rate Selection
  selectGrowthRate(event) {
    // Select only radio items with data-growth-rate attribute (growth rate options)
    const radioItems = this.element.querySelectorAll('[data-growth-rate]')
    radioItems.forEach(item => item.classList.remove('selected'))
    event.currentTarget.classList.add('selected')

    this.growthRate = parseInt(event.currentTarget.dataset.growthRate)
    sessionStorage.setItem('demo_growth_rate', this.growthRate)

    if (this.hasGrowthRateDisplayTarget) {
      this.growthRateDisplayTarget.textContent = this.growthRate
    }

    this.updateProjectedValue()
  }

  updateProjectedValue() {
    if (this.hasProjectedValueTarget) {
      const growthRate = this.growthRate || 5
      const projectedValue = this.homeValueValue * Math.pow(1 + (growthRate / 100), 30)
      this.projectedValueTarget.textContent = this.formatCurrency(Math.round(projectedValue))
    }
  }

  // Property Details page - Mortgage Status
  selectMortgageStatus(event) {
    const options = this.element.querySelectorAll('[data-has-mortgage]')
    options.forEach(opt => opt.classList.remove('selected'))
    event.currentTarget.classList.add('selected')

    const hasMortgage = event.currentTarget.dataset.hasMortgage === 'true'
    sessionStorage.setItem('demo_has_mortgage', hasMortgage)
  }

  // Property Details page - Ownership Selection
  selectOwnership(event) {
    const cards = this.element.querySelectorAll('[data-ownership]')
    cards.forEach(card => card.classList.remove('selected'))
    event.currentTarget.classList.add('selected')

    const ownership = event.currentTarget.dataset.ownership
    sessionStorage.setItem('demo_ownership', ownership)
  }

  // Property Details page - Occupancy Selection
  selectOccupancy(event) {
    const cards = this.element.querySelectorAll('[data-occupancy]')
    cards.forEach(card => card.classList.remove('selected'))
    event.currentTarget.classList.add('selected')

    const occupancy = event.currentTarget.dataset.occupancy
    sessionStorage.setItem('demo_occupancy', occupancy)
  }

  // Mortgage Details page - Loan Term Selection
  selectLoanTerm(event) {
    const loanTerm = event.currentTarget.value
    sessionStorage.setItem('demo_loan_term', loanTerm)
    this.updateCalculations()
  }

  // Property Details page - Valuation Modal
  openValuationModal() {
    if (this.hasValuationModalTarget) {
      this.valuationModalTarget.style.display = 'flex'
      if (this.hasValuationInputTarget) {
        this.valuationInputTarget.value = ''
        this.valuationInputTarget.focus()
      }
      if (this.hasOriginalValueTarget) {
        this.originalValueTarget.textContent = this.formatNumber(this.homeValueValue)
      }
    }
  }

  closeValuationModal() {
    if (this.hasValuationModalTarget) {
      this.valuationModalTarget.style.display = 'none'
    }
  }

  applyOriginalValue() {
    if (this.hasValuationInputTarget) {
      this.valuationInputTarget.value = this.formatNumber(this.homeValueValue)
    }
  }

  saveValuation() {
    if (this.hasValuationInputTarget) {
      // Parse the input value (remove commas and non-numeric characters)
      const inputValue = this.valuationInputTarget.value.replace(/[^0-9]/g, '')
      const newValue = parseInt(inputValue)

      // Validate the value
      if (isNaN(newValue) || newValue < 1500000 || newValue > 10000000) {
        alert('Please enter a value between $1,500,000 and $10,000,000')
        return
      }

      // Update the home value
      this.homeValueValue = newValue
      sessionStorage.setItem('demo_home_value', newValue)

      // Update the displayed property value
      if (this.hasPropertyValueTarget) {
        this.propertyValueTarget.textContent = this.formatCurrency(newValue)
      }

      // Recalculate projected value
      this.updateProjectedValue()

      // Close the modal
      this.closeValuationModal()
    }
  }

  // Format number with commas (no currency symbol)
  formatNumber(amount) {
    return new Intl.NumberFormat('en-AU').format(amount)
  }

  // Mortgage Details page - Mortgage Type Selection
  selectMortgageType(event) {
    const options = this.element.querySelectorAll('.demo-mortgage-option-card')
    options.forEach(opt => opt.classList.remove('selected'))
    event.currentTarget.classList.add('selected')

    const mortgageType = event.currentTarget.dataset.mortgageType
    sessionStorage.setItem('demo_mortgage_type', mortgageType)

    this.updateCalculations()
  }

  // Mortgage Details page - Calculations
  updateCalculations() {
    const incomeTerm = this.hasIncomeTermTarget ? parseInt(this.incomeTermTarget.value) : 10
    const loanTerm = this.hasLoanTermTarget ? parseInt(this.loanTermTarget.value) : 30

    // Update income term display
    if (this.hasIncomeTermDisplayTarget) {
      this.incomeTermDisplayTarget.textContent = `${incomeTerm} years`
    }

    if (this.hasIncomeYearsTarget) {
      this.incomeYearsTarget.textContent = loanTerm
    }

    // Calculate property value multiplier
    const multiplier = this.homeValueValue / this.basePropertyValue

    // Calculate interest-only values
    const interestOnlyData = this.interestOnlyLookup[incomeTerm] || this.interestOnlyLookup[10]
    const interestOnlyMonthly = interestOnlyData.monthly * multiplier
    const interestOnlyLoanBalance = interestOnlyData.loanBalance * multiplier

    // Calculate principal + interest values
    const principalInterestData = this.principalInterestLookup[incomeTerm] || this.principalInterestLookup[10]
    const principalInterestMonthly = principalInterestData.monthly * multiplier

    // Update interest-only display
    if (this.hasInterestOnlyAmountTarget) {
      this.interestOnlyAmountTarget.textContent = this.formatCurrencyWithCents(interestOnlyMonthly)
    }

    // Update loan repayment display
    if (this.hasLoanRepaymentTarget) {
      this.loanRepaymentTarget.textContent = this.formatCurrencyWithCents(interestOnlyLoanBalance)
    }

    // Update principal + interest display
    if (this.hasPrincipalInterestAmountTarget) {
      this.principalInterestAmountTarget.textContent = this.formatCurrencyWithCents(principalInterestMonthly)
    }

    // Update monthly income display (for older pages)
    if (this.hasMonthlyIncomeTarget) {
      this.monthlyIncomeTarget.textContent = this.formatCurrency(Math.round(interestOnlyMonthly))
    }

    // Update max annuity income (30 year term)
    if (this.hasMaxAnnuityIncomeTarget) {
      const maxData = this.interestOnlyLookup[30]
      const maxIncome = maxData.monthly * multiplier * 12 * 30
      this.maxAnnuityIncomeTarget.textContent = this.formatCurrency(Math.round(maxIncome))
    }

    // Save to sessionStorage
    sessionStorage.setItem('demo_income_term', incomeTerm)
    sessionStorage.setItem('demo_loan_term', loanTerm)
    sessionStorage.setItem('demo_monthly_income', Math.round(interestOnlyMonthly))
  }

  // Funding Details page - Checkbox Toggle
  toggleCheckbox(event) {
    event.currentTarget.classList.toggle('checked')
  }

  // Utility: Format currency (no cents)
  formatCurrency(amount) {
    return new Intl.NumberFormat('en-AU', {
      style: 'currency',
      currency: 'AUD',
      minimumFractionDigits: 0,
      maximumFractionDigits: 0
    }).format(amount)
  }

  // Utility: Format currency with cents
  formatCurrencyWithCents(amount) {
    return new Intl.NumberFormat('en-AU', {
      style: 'currency',
      currency: 'AUD',
      minimumFractionDigits: 2,
      maximumFractionDigits: 2
    }).format(amount)
  }
}
