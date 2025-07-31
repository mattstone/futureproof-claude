import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["slider", "value"]
  
  connect() {
    this.updateValue()
  }
  
  updateValue() {
    const value = parseInt(this.sliderTarget.value)
    this.valueTarget.textContent = this.formatCurrency(value)
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