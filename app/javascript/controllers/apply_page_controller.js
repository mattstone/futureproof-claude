import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    // Apply page controller connected
  }
  startApplication(event) {
    // Get the home value from sessionStorage if it exists
    const homeValue = sessionStorage.getItem('calculator_home_value')
    console.log('Apply Page: Retrieved home value from sessionStorage:', homeValue)
    
    if (homeValue) {
      // Modify the URL to include the home value as a parameter
      const url = new URL(event.target.href)
      url.searchParams.set('home_value', homeValue)
      console.log('Apply Page: Updated URL with home value:', url.toString())
      event.target.href = url.toString()
      
      // Clear the stored value after using it
      sessionStorage.removeItem('calculator_home_value')
    } else {
      console.log('Apply Page: No home value found in sessionStorage')
    }
    
    // Let the link proceed normally
  }

  startRegistration(event) {
    // Get the home value from sessionStorage if it exists
    const homeValue = sessionStorage.getItem('calculator_home_value')
    console.log('Apply Page: Retrieved home value for registration:', homeValue)
    
    if (homeValue) {
      // Modify the URL to include the home value as a parameter
      const url = new URL(event.target.href)
      url.searchParams.set('home_value', homeValue)
      console.log('Apply Page: Updated registration URL with home value:', url.toString())
      event.target.href = url.toString()
      
      // Don't clear the stored value yet - we'll need it through the registration flow
    } else {
      console.log('Apply Page: No home value found for registration')
    }
    
    // Let the link proceed normally
  }
}