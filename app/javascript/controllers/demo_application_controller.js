import { Controller } from "@hotwired/stimulus"

// Demo Application Controller
// Handles the demo property details form
export default class extends Controller {
  static targets = [
    "address",
    "homeValue",
    "homeValueDisplay",
    "ownership",
    "propertyType",
    "borrowerAge",
    "borrowerAgeDisplay",
    "hasMortgage",
    "mortgageGroup",
    "mortgageAmount",
    "mortgageAmountDisplay"
  ]

  connect() {
    // Load any saved demo data from sessionStorage
    this.loadSavedData()
  }

  loadSavedData() {
    const savedHomeValue = sessionStorage.getItem('demo_home_value')
    if (savedHomeValue && this.hasHomeValueTarget) {
      this.homeValueTarget.value = savedHomeValue
      this.updateHomeValue()
    }
  }

  updateHomeValue() {
    if (this.hasHomeValueTarget && this.hasHomeValueDisplayTarget) {
      const value = parseInt(this.homeValueTarget.value)
      this.homeValueDisplayTarget.textContent = this.formatCurrency(value)
      sessionStorage.setItem('demo_home_value', value)
    }
  }

  updateBorrowerAge() {
    if (this.hasBorrowerAgeTarget && this.hasBorrowerAgeDisplayTarget) {
      const age = this.borrowerAgeTarget.value
      this.borrowerAgeDisplayTarget.textContent = `${age} years`
      sessionStorage.setItem('demo_borrower_age', age)
    }
  }

  toggleMortgage() {
    if (this.hasHasMortgageTarget && this.hasMortgageGroupTarget) {
      if (this.hasMortgageTarget.checked) {
        this.mortgageGroupTarget.classList.remove('js-hidden')
      } else {
        this.mortgageGroupTarget.classList.add('js-hidden')
      }
    }
  }

  updateMortgageAmount() {
    if (this.hasMortgageAmountTarget && this.hasMortgageAmountDisplayTarget) {
      const value = parseInt(this.mortgageAmountTarget.value)
      this.mortgageAmountDisplayTarget.textContent = this.formatCurrency(value)
    }
  }

  saveAndContinue(event) {
    // Save all form data to sessionStorage
    if (this.hasAddressTarget) {
      sessionStorage.setItem('demo_address', this.addressTarget.value)
    }
    if (this.hasHomeValueTarget) {
      sessionStorage.setItem('demo_home_value', this.homeValueTarget.value)
    }
    if (this.hasOwnershipTarget) {
      sessionStorage.setItem('demo_ownership', this.ownershipTarget.value)
    }
    if (this.hasPropertyTypeTarget) {
      sessionStorage.setItem('demo_property_type', this.propertyTypeTarget.value)
    }
    if (this.hasBorrowerAgeTarget) {
      sessionStorage.setItem('demo_borrower_age', this.borrowerAgeTarget.value)
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
}
