import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["slider", "value", "incomeAmount", "applyButton"]
  
  connect() {
    this.updateValue()
    this.updateMonthlyIncome()
  }
  
  async updateValue() {
    const value = parseInt(this.sliderTarget.value)
    this.valueTarget.textContent = this.formatCurrency(value)
    
    // Update the monthly income with random mortgage calculation
    await this.updateMonthlyIncome()
  }
  
  async updateMonthlyIncome() {
    try {
      const homeValue = this.sliderTarget.value
      const response = await fetch(`/api/mortgage_estimate?home_value=${homeValue}`)
      const data = await response.json()
      
      if (this.hasIncomeAmountTarget) {
        this.incomeAmountTarget.textContent = data.formatted_range
      }
    } catch (error) {
      console.error('Error fetching mortgage estimate:', error)
    }
  }
  
  applyNow(event) {
    // Store the current home value in sessionStorage so it can be retrieved on the apply page
    const homeValue = this.sliderTarget.value
    sessionStorage.setItem('calculator_home_value', homeValue)
    // Let the link proceed normally
  }
  
  formatCurrency(value) {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD',
      minimumFractionDigits: 0,
      maximumFractionDigits: 0
    }).format(value)
  }
}