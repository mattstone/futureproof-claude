import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["mortgageCheckbox", "mortgageAmountGroup"]

  connect() {
    this.toggleMortgageAmount()
  }

  toggleMortgageAmount() {
    if (this.mortgageCheckboxTarget.checked) {
      this.mortgageAmountGroupTarget.style.display = "block"
    } else {
      this.mortgageAmountGroupTarget.style.display = "none"
      // Clear the amount field when hiding
      const amountInput = this.mortgageAmountGroupTarget.querySelector('input[type="number"]')
      if (amountInput) {
        amountInput.value = ""
      }
    }
  }
}