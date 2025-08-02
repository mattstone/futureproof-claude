import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  startApplication(event) {
    // Get the home value from sessionStorage if it exists
    const homeValue = sessionStorage.getItem('calculator_home_value')
    
    if (homeValue) {
      // Modify the URL to include the home value as a parameter
      const url = new URL(event.target.href)
      url.searchParams.set('home_value', homeValue)
      event.target.href = url.toString()
      
      // Clear the stored value after using it
      sessionStorage.removeItem('calculator_home_value')
    }
    
    // Let the link proceed normally
  }
}