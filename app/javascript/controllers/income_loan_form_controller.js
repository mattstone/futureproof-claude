import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["loanTermSlider", "loanTermDisplay", "incomePayoutSlider", "incomePayoutDisplay", "mortgageCard", "mortgageHidden", "interestOnlyIncome", "principalInterestIncome", "interestOnlyRepayment", "growthRateBtn", "customRateInput", "customRateSlider", "customRateDisplay", "estimatedPropertyValue", "appreciationAmount", "growthRateHidden"]

  connect() {
    this.updateLoanTerm()
    this.updateIncomePayout()
    this.setInitialMortgageSelection()
    this.calculateMonthlyIncome()
    this.calculatePropertyValue()
    // Store initial growth rate (defaults to 2% - Low option)
    const initialRate = this.getCurrentGrowthRate()
    this.storeGrowthRate(initialRate)
    this.updateGrowthRateHidden(initialRate)
  }

  updateLoanTerm() {
    if (this.hasLoanTermSliderTarget && this.hasLoanTermDisplayTarget) {
      const loanTermValue = parseInt(this.loanTermSliderTarget.value)
      this.loanTermDisplayTarget.textContent = `${loanTermValue} years`
      
      // Ensure income payout term doesn't exceed loan term
      if (this.hasIncomePayoutSliderTarget) {
        const incomePayoutValue = parseInt(this.incomePayoutSliderTarget.value)
        if (incomePayoutValue > loanTermValue) {
          this.incomePayoutSliderTarget.value = loanTermValue
          if (this.hasIncomePayoutDisplayTarget) {
            this.incomePayoutDisplayTarget.textContent = `${loanTermValue} years`
          }
        }
      }
      
      this.calculateMonthlyIncome()
      this.calculatePropertyValue()
    }
  }

  updateIncomePayout() {
    if (this.hasIncomePayoutSliderTarget && this.hasIncomePayoutDisplayTarget) {
      const incomePayoutValue = parseInt(this.incomePayoutSliderTarget.value)
      const loanTermValue = this.hasLoanTermSliderTarget ? parseInt(this.loanTermSliderTarget.value) : 30
      
      // Constrain income payout term to not exceed loan term
      const constrainedValue = Math.min(incomePayoutValue, loanTermValue)
      
      if (constrainedValue !== incomePayoutValue) {
        this.incomePayoutSliderTarget.value = constrainedValue
      }
      
      this.incomePayoutDisplayTarget.textContent = `${constrainedValue} years`
      this.calculateMonthlyIncome()
      this.calculatePropertyValue()
    }
  }

  selectMortgage(event) {
    const selectedCard = event.currentTarget
    const mortgageId = selectedCard.dataset.mortgageId

    // Remove selected class from all cards
    this.mortgageCardTargets.forEach(card => {
      card.classList.remove('selected')
    })

    // Add selected class to clicked card
    selectedCard.classList.add('selected')

    // Update hidden field
    if (this.hasMortgageHiddenTarget) {
      this.mortgageHiddenTarget.value = mortgageId
    }

    // No need to recalculate - both incomes are already displayed
  }

  setInitialMortgageSelection() {
    // Find the recommended card (Principal & Interest) - it should have the "recommended" badge
    const recommendedCard = this.mortgageCardTargets.find(card => 
      card.querySelector('.mortgage-badge.recommended')
    )
    
    if (recommendedCard) {
      // Select only the recommended option
      recommendedCard.classList.add('selected')
      if (this.hasMortgageHiddenTarget) {
        this.mortgageHiddenTarget.value = recommendedCard.dataset.mortgageId
      }
    } else if (this.hasMortgageHiddenTarget && this.mortgageHiddenTarget.value) {
      // Fallback: if there's an existing selection, respect it
      const mortgageId = this.mortgageHiddenTarget.value
      const selectedCard = this.mortgageCardTargets.find(card => 
        card.dataset.mortgageId === mortgageId
      )
      if (selectedCard) {
        selectedCard.classList.add('selected')
      }
    }
  }

  async calculateMonthlyIncome() {
    // Show loading state for both income displays
    if (this.hasInterestOnlyIncomeTarget) {
      this.interestOnlyIncomeTarget.textContent = "Calculating..."
    }
    if (this.hasPrincipalInterestIncomeTarget) {
      this.principalInterestIncomeTarget.textContent = "Calculating..."
    }
    if (this.hasInterestOnlyRepaymentTarget) {
      this.interestOnlyRepaymentTarget.textContent = "Calculating repayment..."
    }

    try {
      // Get current values
      const loanTerm = this.hasLoanTermSliderTarget ? parseInt(this.loanTermSliderTarget.value) : 30
      const incomePayoutTerm = this.hasIncomePayoutSliderTarget ? parseInt(this.incomePayoutSliderTarget.value) : 30
      
      // Get principal from application data
      const principal = this.data.get("principalValue") || 1500000

      // Build API URL with parameters
      const params = new URLSearchParams({
        principal: principal,
        loan_term: loanTerm,
        income_payout_term: incomePayoutTerm
      })

      const response = await fetch(`/api/monthly_income?${params}`)
      const data = await response.json()

      // Update both income displays with formatted amounts
      if (this.hasInterestOnlyIncomeTarget) {
        this.interestOnlyIncomeTarget.textContent = data.interest_only_income === 0 ? "Not Available" : data.formatted_interest_only_income
      }
      if (this.hasPrincipalInterestIncomeTarget) {
        this.principalInterestIncomeTarget.textContent = data.principal_interest_income === 0 ? "Not Available" : data.formatted_principal_interest_income
      }
      if (this.hasInterestOnlyRepaymentTarget) {
        this.interestOnlyRepaymentTarget.textContent = data.interest_only_repayment === 0 ? "Not Available" : data.formatted_interest_only_repayment
      }

    } catch (error) {
      console.error('Error calculating monthly income:', error)
      if (this.hasInterestOnlyIncomeTarget) {
        this.interestOnlyIncomeTarget.textContent = "Error calculating"
      }
      if (this.hasPrincipalInterestIncomeTarget) {
        this.principalInterestIncomeTarget.textContent = "Error calculating"
      }
      if (this.hasInterestOnlyRepaymentTarget) {
        this.interestOnlyRepaymentTarget.textContent = "Error calculating repayment"
      }
    }
  }

  selectGrowthRate(event) {
    const selectedBtn = event.currentTarget
    const rate = selectedBtn.dataset.rate

    // Remove active class from all buttons
    this.growthRateBtnTargets.forEach(btn => {
      btn.classList.remove('active')
    })

    // Add active class to selected button
    selectedBtn.classList.add('active')

    // Show/hide custom input
    if (rate === 'custom') {
      if (this.hasCustomRateInputTarget) {
        this.customRateInputTarget.style.display = 'block'
      }
    } else {
      if (this.hasCustomRateInputTarget) {
        this.customRateInputTarget.style.display = 'none'
      }
    }

    // Store growth rate in session storage for summary page and update hidden field
    const currentRate = this.getCurrentGrowthRate()
    this.storeGrowthRate(currentRate)
    this.updateGrowthRateHidden(currentRate)
    this.calculatePropertyValue()
  }

  updateCustomRate() {
    if (this.hasCustomRateSliderTarget && this.hasCustomRateDisplayTarget) {
      const value = parseFloat(this.customRateSliderTarget.value)
      this.customRateDisplayTarget.textContent = `${value}%`
      this.storeGrowthRate(value)
      this.updateGrowthRateHidden(value)
      this.calculatePropertyValue()
    }
  }

  getCurrentGrowthRate() {
    const activeBtn = this.growthRateBtnTargets.find(btn => btn.classList.contains('active'))
    if (activeBtn && activeBtn.dataset.rate === 'custom') {
      return this.hasCustomRateSliderTarget ? parseFloat(this.customRateSliderTarget.value) : 2
    }
    return activeBtn ? parseFloat(activeBtn.dataset.rate) : 2
  }

  calculatePropertyValue() {
    if (!this.hasEstimatedPropertyValueTarget) return

    try {
      // Get current values
      const currentValue = parseFloat(this.data.get("principalValue")) || 1500000
      const loanTerm = this.hasLoanTermSliderTarget ? parseInt(this.loanTermSliderTarget.value) : 30
      const growthRate = this.getCurrentGrowthRate()

      // Simple interest calculation: Future Value = Present Value * (1 + rate * time)
      const futureValue = currentValue * (1 + (growthRate / 100) * loanTerm)
      const appreciation = futureValue - currentValue

      // Update displays
      this.estimatedPropertyValueTarget.textContent = this.formatCurrency(futureValue)
      
      if (this.hasAppreciationAmountTarget) {
        this.appreciationAmountTarget.textContent = `+${this.formatCurrency(appreciation)} appreciation`
      }

    } catch (error) {
      console.error('Error calculating property value:', error)
      this.estimatedPropertyValueTarget.textContent = "Error calculating"
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

  storeGrowthRate(rate) {
    try {
      sessionStorage.setItem('selectedGrowthRate', rate.toString())
    } catch (error) {
      console.warn('Could not store growth rate in session storage:', error)
    }
  }

  updateGrowthRateHidden(rate) {
    if (this.hasGrowthRateHiddenTarget) {
      this.growthRateHiddenTarget.value = rate
    }
  }
}