import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["slider", "display", "originalValue", "explanation", "monthlyIncomeDisplay"]
  static values = {
    applicationId: Number,
    originalValuation: Number,
    loanTerm: Number,
    incomeTerm: Number,
    mortgageType: String
  }

  connect() {
    this.updateDisplay()
  }

  updateDisplay() {
    const value = parseInt(this.sliderTarget.value)
    this.displayTarget.textContent = this.formatCurrency(value)

    // Update monthly income if mortgage data is available
    if (this.hasMonthlyIncomeDisplayTarget && this.hasMortgageTypeValue) {
      this.updateMonthlyIncomeDisplay(value)
    }
  }

  updateMonthlyIncomeDisplay(propertyValue) {
    // Calculate monthly income based on property value
    const monthlyIncome = this.calculateMonthlyIncome(propertyValue)
    this.monthlyIncomeDisplayTarget.textContent = this.formatCurrency(monthlyIncome)
  }

  calculateMonthlyIncome(propertyValue) {
    // Simple approximation of the monthly income calculation
    // This is a simplified version - in a real implementation you'd want to use the same
    // calculation logic as the server-side FPCalculator

    const loanTerm = this.loanTermValue || 30
    const incomeTerm = this.incomeTermValue || 30
    const mortgageType = this.mortgageTypeValue

    // Basic calculation based on typical rates
    // This should ideally match the server-side calculation more precisely
    const yearlyRate = 0.06 // 6% approximate rate
    const monthlyRate = yearlyRate / 12
    const totalMonths = loanTerm * 12

    // Simplified calculation - adjust this to match your actual formula
    let monthlyIncome = 0

    if (mortgageType === "interest_only") {
      // For interest only, typically a percentage of property value
      monthlyIncome = propertyValue * 0.002 // ~0.2% monthly
    } else if (mortgageType === "principal_and_interest") {
      // For P&I, typically lower monthly income
      monthlyIncome = propertyValue * 0.0015 // ~0.15% monthly
    }

    return Math.round(monthlyIncome)
  }

  async confirmAndSave() {
    const newValue = parseInt(this.sliderTarget.value)
    const originalValue = this.originalValuationValue
    const explanation = this.explanationTarget.value.trim()

    if (newValue === originalValue) {
      this.showMessage("No change to save - valuation is the same as current value.", "info")
      return
    }

    if (!explanation) {
      this.showMessage("Please provide a reason for the valuation change.", "error")
      this.explanationTarget.focus()
      return
    }

    const confirmed = confirm(
      `Are you sure you want to change the property valuation from ${this.formatCurrency(originalValue)} to ${this.formatCurrency(newValue)}?\n\nReason: ${explanation}\n\nThis change will be recorded in the application history.`
    )

    if (!confirmed) {
      return
    }

    // Save the new valuation
    try {
      const response = await this.saveValuation(newValue, explanation)

      if (response.ok) {
        // Update the original value display
        this.originalValueTarget.textContent = this.formatCurrency(newValue)
        this.originalValuationValue = newValue

        // Clear the explanation field
        this.explanationTarget.value = ""

        // Show success message
        this.showMessage("Property valuation updated successfully", "success")
      } else {
        throw new Error("Failed to save valuation")
      }
    } catch (error) {
      console.error("Error saving valuation:", error)
      this.showMessage("Error updating valuation. Please try again.", "error")
    }
  }

  resetToOriginal() {
    // Reset slider to original value
    this.sliderTarget.value = this.originalValuationValue
    this.updateDisplay()

    // Clear explanation
    this.explanationTarget.value = ""

    this.showMessage("Valuation reset to original value", "info")
  }

  async saveValuation(newValue, explanation) {
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content')

    return await fetch(`/admin/applications/${this.applicationIdValue}`, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'X-CSRF-Token': csrfToken,
        'X-Requested-With': 'XMLHttpRequest'
      },
      body: JSON.stringify({
        application: {
          property_valuation_middle: newValue
        },
        valuation_change: true,
        valuation_explanation: explanation
      })
    })
  }

  showMessage(text, type) {
    // Create or update flash message
    let flashContainer = document.getElementById('flash-messages')
    if (!flashContainer) {
      flashContainer = document.createElement('div')
      flashContainer.id = 'flash-messages'
      this.element.closest('.admin-form').prepend(flashContainer)
    }

    const messageClass = type === 'success' ? 'alert-success' : (type === 'error' ? 'alert-danger' : 'alert-info')
    flashContainer.innerHTML = `
      <div class="alert ${messageClass}">
        ${text}
      </div>
    `

    // Auto-hide after 3 seconds
    setTimeout(() => {
      flashContainer.innerHTML = ''
    }, 3000)
  }

  formatCurrency(value) {
    return new Intl.NumberFormat('en-AU', {
      style: 'currency',
      currency: 'AUD',
      minimumFractionDigits: 0,
      maximumFractionDigits: 0
    }).format(value)
  }
}