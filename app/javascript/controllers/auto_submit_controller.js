import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="auto-submit"
export default class extends Controller {
  static targets = ["form"]
  static values = { delay: { type: Number, default: 300 } }

  connect() {
    this.timeout = null
  }

  disconnect() {
    if (this.timeout) {
      clearTimeout(this.timeout)
    }
  }

  // Called when search input changes
  searchChanged(event) {
    this.submitWithDelay()
  }

  // Called when filter dropdown changes
  filterChanged(event) {
    this.submitForm()
  }

  // Submit form immediately (for dropdowns)
  submitForm() {
    if (this.timeout) {
      clearTimeout(this.timeout)
    }
    
    if (this.hasFormTarget) {
      this.formTarget.requestSubmit()
    } else if (this.element.tagName === 'FORM') {
      this.element.requestSubmit()
    }
  }

  // Submit form with delay (for text inputs)
  submitWithDelay() {
    if (this.timeout) {
      clearTimeout(this.timeout)
    }

    this.timeout = setTimeout(() => {
      this.submitForm()
    }, this.delayValue)
  }
}