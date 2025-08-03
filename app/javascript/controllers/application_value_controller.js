import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["homeValueSlider", "homeValueDisplay"]

  connect() {
    console.log('Application Value Controller connected')
    this.loadHomeValueFromStorage()
  }

  loadHomeValueFromStorage() {
    const storedValue = sessionStorage.getItem('calculator_home_value')
    console.log('Application Value: Retrieved from sessionStorage:', storedValue)
    
    if (storedValue && this.hasHomeValueSliderTarget) {
      const homeValue = parseInt(storedValue)
      console.log('Application Value: Setting form value to:', homeValue)
      
      // Update the slider value
      this.homeValueSliderTarget.value = homeValue
      
      // Update the display
      if (this.hasHomeValueDisplayTarget) {
        this.homeValueDisplayTarget.textContent = this.formatCurrency(homeValue)
      }
      
      // Trigger any change events that might be needed
      this.homeValueSliderTarget.dispatchEvent(new Event('input'))
      
      // Clear the stored value after using it
      sessionStorage.removeItem('calculator_home_value')
      console.log('Application Value: Cleared sessionStorage and updated form')
    } else {
      console.log('Application Value: No stored value found or no slider target available')
    }
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