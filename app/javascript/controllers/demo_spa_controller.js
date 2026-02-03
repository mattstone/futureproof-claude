import { Controller } from "@hotwired/stimulus"

// Demo SPA Controller
// Single Page Application flow with animated transitions
export default class extends Controller {
  static targets = [
    "step",
    "progressBar",
    "progressStep",
    "progressLine",
    // Step 1: Property Details
    "propertyValue",
    "ownership",
    "projectedValue",
    "growthRateDisplay",
    // Step 2: Mortgage Details
    "propertyValueStep2",
    "loanTerm",
    "incomeTerm",
    "incomeTermDisplay",
    "incomeYears",
    "interestOnlyAmount",
    "principalInterestAmount",
    "loanRepayment",
    // Step 3: Funding Summary
    "summaryMortgageType",
    "summaryLoanTerm",
    "summaryLoanAmount",
    "summaryHomeValue",
    "summaryGrowthRate",
    "summaryFutureValue",
    "summaryEquityPreserved",
    "summaryInterestPaid",
    "summaryRepaymentAmount",
    "summaryTotalIncome",
    "summaryMonthlyIncome",
    "summaryAnnuityDuration"
  ]

  static values = {
    homeValue: { type: Number, default: 2500000 },
    market: { type: String, default: 'us' },
    propertyAddress: { type: String, default: '' },
    otherMarket: { type: String, default: 'au' }
  }

  // =============================================================================
  // CALCULATION MODELS
  // Switch between models using URL parameter: ?model=tom or ?model=pavel
  // Default is 'tom' (matches React Webapp)
  // =============================================================================

  // Tom's model (from ReferenceTableV2.csv) - DEFAULT
  tomInterestOnlyLookup = {
    10: { monthly: 2500, loanBalance: 553088 },
    15: { monthly: 2280, loanBalance: 553088 },
    20: { monthly: 1847, loanBalance: 553088 },
    25: { monthly: 1662, loanBalance: 553088 },
    30: { monthly: 1536, loanBalance: 553088 }
  }

  tomPrincipalInterestLookup = {
    10: { monthly: 1925, loanBalance: 0 },
    15: { monthly: 1756, loanBalance: 0 },
    20: { monthly: 1422, loanBalance: 0 },
    25: { monthly: 1280, loanBalance: 0 },
    30: { monthly: 1183, loanBalance: 0 }
  }

  // Pavel's model (annuity rate based)
  pavelInterestOnlyLookup = {
    10: { monthly: 1875, loanBalance: 553088 },
    15: { monthly: 1713, loanBalance: 553088 },
    20: { monthly: 1563, loanBalance: 553088 },
    25: { monthly: 1438, loanBalance: 553088 },
    30: { monthly: 1313, loanBalance: 553088 }
  }

  pavelPrincipalInterestLookup = {
    10: { monthly: 1444, loanBalance: 0 },
    15: { monthly: 1319, loanBalance: 0 },
    20: { monthly: 1204, loanBalance: 0 },
    25: { monthly: 1107, loanBalance: 0 },
    30: { monthly: 1011, loanBalance: 0 }
  }

  basePropertyValue = 1500000
  interestRate = 0.0745
  lvr = 0.80

  // Get the active lookup tables based on selected model
  get interestOnlyLookup() {
    return this.currentModel === 'pavel' ? this.pavelInterestOnlyLookup : this.tomInterestOnlyLookup
  }

  get principalInterestLookup() {
    return this.currentModel === 'pavel' ? this.pavelPrincipalInterestLookup : this.tomPrincipalInterestLookup
  }

  connect() {
    this.currentStep = 0
    this.growthRate = 4
    this.mortgageType = 'interest_only'

    // Load calculation model from URL parameter
    this.loadModel()

    // Load any saved values from sessionStorage
    this.loadSavedData()

    // Check URL for step parameter
    this.loadStepFromUrl()

    // Update progress bar visibility
    this.updateProgressBar()

    // Initial calculations
    this.updateCalculations()

    // Listen for browser back/forward
    window.addEventListener('popstate', this.handlePopState.bind(this))
  }

  disconnect() {
    window.removeEventListener('popstate', this.handlePopState.bind(this))
  }

  // =============================================================================
  // NAVIGATION
  // =============================================================================

  goToStep(event) {
    const newStep = parseInt(event.currentTarget.dataset.step)
    this.navigateToStep(newStep, { updateHistory: true })
  }

  navigateToStep(newStep, { updateHistory = true } = {}) {
    const oldStep = this.currentStep

    // Don't navigate to same step
    if (newStep === oldStep) return

    // Hide current step
    const currentStepEl = this.stepTargets.find(el => parseInt(el.dataset.step) === oldStep)
    if (currentStepEl) {
      currentStepEl.classList.remove('active')
    }

    // Update step counter
    this.currentStep = newStep

    // Show new step
    const newStepEl = this.stepTargets.find(el => parseInt(el.dataset.step) === newStep)
    if (newStepEl) {
      newStepEl.classList.add('active')
    }

    // Update progress bar
    this.updateProgressBar()

    // Update URL
    if (updateHistory) {
      const url = new URL(window.location)
      if (newStep === 0) {
        url.searchParams.delete('step')
      } else {
        url.searchParams.set('step', newStep)
      }
      history.pushState({ step: newStep }, '', url)
    }

    // Update summary values when entering step 3
    if (newStep === 3) {
      this.updateSummary()
    }

    // Scroll to top if not already there
    if (window.scrollY > 100) {
      window.scrollTo({ top: 0, behavior: 'smooth' })
    }
  }

  handlePopState(event) {
    if (event.state?.step !== undefined) {
      this.navigateToStep(event.state.step, { updateHistory: false })
    } else {
      // No state, go to step 0
      this.navigateToStep(0, { updateHistory: false })
    }
  }

  loadStepFromUrl() {
    const urlParams = new URLSearchParams(window.location.search)
    const stepParam = urlParams.get('step')
    if (stepParam) {
      const step = parseInt(stepParam)
      if (step >= 0 && step <= 4) {
        this.currentStep = step

        // Activate the correct step without animation
        this.stepTargets.forEach(el => {
          if (parseInt(el.dataset.step) === step) {
            el.classList.add('active')
          } else {
            el.classList.remove('active')
          }
        })

        // Update summary if starting on step 3
        if (step === 3) {
          this.updateSummary()
        }
      }
    }
  }

  updateProgressBar() {
    const showProgress = this.currentStep >= 1 && this.currentStep <= 3

    // Show/hide progress bar
    if (this.hasProgressBarTarget) {
      this.progressBarTarget.style.display = showProgress ? 'flex' : 'none'
    }

    // Update step indicators
    this.progressStepTargets.forEach((stepEl, index) => {
      const stepNum = index + 1
      stepEl.classList.remove('active', 'completed')

      if (stepNum < this.currentStep) {
        stepEl.classList.add('completed')
        stepEl.innerHTML = '<svg viewBox="0 0 24 24" fill="currentColor" width="16" height="16"><path d="M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41z"/></svg>'
      } else if (stepNum === this.currentStep) {
        stepEl.classList.add('active')
        stepEl.textContent = stepNum
      } else {
        stepEl.textContent = stepNum
      }
    })

    // Update progress lines
    this.progressLineTargets.forEach((lineEl, index) => {
      if (index + 1 < this.currentStep) {
        lineEl.classList.add('completed')
      } else {
        lineEl.classList.remove('completed')
      }
    })
  }

  // =============================================================================
  // MARKET SWITCHING
  // =============================================================================

  switchMarket() {
    const url = new URL(window.location)
    url.searchParams.set('market', this.otherMarketValue)
    url.searchParams.delete('step') // Reset to step 0
    window.location.href = url.toString()
  }

  // =============================================================================
  // DATA PERSISTENCE
  // =============================================================================

  loadModel() {
    const urlParams = new URLSearchParams(window.location.search)
    const urlModel = urlParams.get('model')

    if (urlModel && (urlModel === 'tom' || urlModel === 'pavel')) {
      this.currentModel = urlModel
      sessionStorage.setItem('demo_model', urlModel)
    } else {
      this.currentModel = sessionStorage.getItem('demo_model') || 'tom'
    }
  }

  loadSavedData() {
    // Check if market has changed
    const savedMarket = sessionStorage.getItem('demo_market')
    const currentMarket = this.marketValue

    if (savedMarket !== currentMarket) {
      sessionStorage.setItem('demo_market', currentMarket)
      sessionStorage.setItem('demo_home_value', this.homeValueValue)
      sessionStorage.removeItem('demo_growth_rate')
      sessionStorage.removeItem('demo_income_term')
      sessionStorage.removeItem('demo_loan_term')
      sessionStorage.removeItem('demo_mortgage_type')
    }

    const savedHomeValue = sessionStorage.getItem('demo_home_value')
    if (savedHomeValue) {
      this.homeValueValue = parseInt(savedHomeValue)
    } else {
      sessionStorage.setItem('demo_home_value', this.homeValueValue)
    }

    const savedGrowthRate = sessionStorage.getItem('demo_growth_rate')
    if (savedGrowthRate) {
      this.growthRate = parseFloat(savedGrowthRate)
    } else {
      sessionStorage.setItem('demo_growth_rate', this.growthRate)
    }

    const savedMortgageType = sessionStorage.getItem('demo_mortgage_type')
    if (savedMortgageType) {
      this.mortgageType = savedMortgageType
    } else {
      sessionStorage.setItem('demo_mortgage_type', this.mortgageType)
    }

    // Update display
    this.updatePropertyValueDisplays()
    this.updateProjectedValue()
    this.syncSelections()
  }

  syncSelections() {
    // Sync growth rate radio buttons
    const growthRateItems = this.element.querySelectorAll('[data-growth-rate]')
    growthRateItems.forEach(item => {
      const rate = parseInt(item.dataset.growthRate)
      item.classList.toggle('selected', rate === this.growthRate)
    })

    // Sync mortgage type cards
    const mortgageCards = this.element.querySelectorAll('.demo-mortgage-option-card')
    mortgageCards.forEach(card => {
      card.classList.toggle('selected', card.dataset.mortgageType === this.mortgageType)
    })

    // Update growth rate display
    if (this.hasGrowthRateDisplayTarget) {
      this.growthRateDisplayTarget.textContent = this.growthRate
    }
  }

  // =============================================================================
  // FORM INTERACTIONS
  // =============================================================================

  selectOwnership(event) {
    const value = event.currentTarget.value
    sessionStorage.setItem('demo_ownership', value)
  }

  selectMortgageStatus(event) {
    const options = this.element.querySelectorAll('[data-has-mortgage]')
    options.forEach(opt => opt.classList.remove('selected'))
    event.currentTarget.classList.add('selected')

    const hasMortgage = event.currentTarget.dataset.hasMortgage === 'true'
    sessionStorage.setItem('demo_has_mortgage', hasMortgage)
  }

  selectOccupancy(event) {
    const options = this.element.querySelectorAll('[data-occupancy]')
    options.forEach(opt => opt.classList.remove('selected'))
    event.currentTarget.classList.add('selected')

    sessionStorage.setItem('demo_occupancy', event.currentTarget.dataset.occupancy)
  }

  selectGrowthRate(event) {
    const options = this.element.querySelectorAll('[data-growth-rate]')
    options.forEach(opt => opt.classList.remove('selected'))
    event.currentTarget.classList.add('selected')

    this.growthRate = parseInt(event.currentTarget.dataset.growthRate)
    sessionStorage.setItem('demo_growth_rate', this.growthRate)

    if (this.hasGrowthRateDisplayTarget) {
      this.growthRateDisplayTarget.textContent = this.growthRate
    }

    this.updateProjectedValue()
  }

  selectMortgageType(event) {
    const cards = this.element.querySelectorAll('.demo-mortgage-option-card')
    cards.forEach(card => {
      card.classList.remove('selected')
    })
    event.currentTarget.classList.add('selected')

    this.mortgageType = event.currentTarget.dataset.mortgageType
    sessionStorage.setItem('demo_mortgage_type', this.mortgageType)

    this.updateCalculations()
  }

  toggleCheckbox(event) {
    event.currentTarget.classList.toggle('checked')
  }

  // =============================================================================
  // CALCULATIONS
  // =============================================================================

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

    // Update displays with animation
    if (this.hasInterestOnlyAmountTarget) {
      this.animateValue(this.interestOnlyAmountTarget, interestOnlyMonthly, true)
    }

    if (this.hasLoanRepaymentTarget) {
      this.animateValue(this.loanRepaymentTarget, interestOnlyLoanBalance, true)
    }

    if (this.hasPrincipalInterestAmountTarget) {
      this.animateValue(this.principalInterestAmountTarget, principalInterestMonthly, true)
    }

    // Save to sessionStorage
    sessionStorage.setItem('demo_income_term', incomeTerm)
    sessionStorage.setItem('demo_loan_term', loanTerm)
    sessionStorage.setItem('demo_monthly_income', Math.round(interestOnlyMonthly))
  }

  updatePropertyValueDisplays() {
    const formattedValue = this.formatCurrency(this.homeValueValue)

    if (this.hasPropertyValueTarget) {
      this.propertyValueTarget.textContent = formattedValue
    }
    if (this.hasPropertyValueStep2Target) {
      this.propertyValueStep2Target.textContent = formattedValue
    }
  }

  updateProjectedValue() {
    if (this.hasProjectedValueTarget) {
      const projectedValue = this.homeValueValue * Math.pow(1 + (this.growthRate / 100), 30)
      this.animateValue(this.projectedValueTarget, projectedValue, true)
    }
  }

  updateSummary() {
    const incomeTerm = this.hasIncomeTermTarget ? parseInt(this.incomeTermTarget.value) : 10
    const loanTerm = this.hasLoanTermTarget ? parseInt(this.loanTermTarget.value) : 30
    const mortgageType = this.mortgageType

    // Calculate values
    const loanAmount = Math.round(this.homeValueValue * this.lvr)
    const multiplier = this.homeValueValue / this.basePropertyValue

    // Get income based on mortgage type
    const lookup = mortgageType === 'principal_and_interest'
      ? this.principalInterestLookup
      : this.interestOnlyLookup
    const incomeData = lookup[incomeTerm] || lookup[10]
    const monthlyIncome = incomeData.monthly * multiplier
    const totalIncome = monthlyIncome * 12 * incomeTerm

    // Calculate future value and equity
    const futureValue = this.homeValueValue * Math.pow(1 + (this.growthRate / 100), loanTerm)
    const repaymentAmount = mortgageType === 'principal_and_interest' ? 0 : loanAmount
    const equityPreserved = futureValue - repaymentAmount

    // Calculate interest paid
    const interestPaid = loanAmount * this.interestRate * loanTerm

    // Update displays
    if (this.hasSummaryMortgageTypeTarget) {
      this.summaryMortgageTypeTarget.textContent = mortgageType === 'principal_and_interest'
        ? 'Principal + interest'
        : 'Interest-only'
    }

    if (this.hasSummaryLoanTermTarget) {
      this.summaryLoanTermTarget.textContent = `${loanTerm} years`
    }

    if (this.hasSummaryLoanAmountTarget) {
      this.summaryLoanAmountTarget.textContent = this.formatCurrency(loanAmount)
    }

    if (this.hasSummaryHomeValueTarget) {
      this.summaryHomeValueTarget.textContent = this.formatCurrency(this.homeValueValue)
    }

    if (this.hasSummaryGrowthRateTarget) {
      this.summaryGrowthRateTarget.textContent = `${this.growthRate}%`
    }

    if (this.hasSummaryFutureValueTarget) {
      this.summaryFutureValueTarget.textContent = this.formatCurrency(Math.round(futureValue))
    }

    if (this.hasSummaryEquityPreservedTarget) {
      this.summaryEquityPreservedTarget.textContent = this.formatCurrency(Math.round(equityPreserved))
    }

    if (this.hasSummaryInterestPaidTarget) {
      this.summaryInterestPaidTarget.textContent = this.formatCurrency(Math.round(interestPaid))
    }

    if (this.hasSummaryRepaymentAmountTarget) {
      this.summaryRepaymentAmountTarget.textContent = this.formatCurrency(repaymentAmount)
    }

    if (this.hasSummaryTotalIncomeTarget) {
      this.summaryTotalIncomeTarget.textContent = this.formatCurrency(Math.round(totalIncome))
    }

    if (this.hasSummaryMonthlyIncomeTarget) {
      this.summaryMonthlyIncomeTarget.textContent = this.formatCurrencyWithCents(monthlyIncome)
    }

    if (this.hasSummaryAnnuityDurationTarget) {
      this.summaryAnnuityDurationTarget.textContent = `${incomeTerm} years`
    }
  }

  // =============================================================================
  // UTILITIES
  // =============================================================================

  animateValue(element, value, withCents = false) {
    element.classList.add('demo-value-updating')

    setTimeout(() => {
      element.textContent = withCents ? this.formatCurrencyWithCents(value) : this.formatCurrency(value)
      element.classList.remove('demo-value-updating')
    }, 150)
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
}
