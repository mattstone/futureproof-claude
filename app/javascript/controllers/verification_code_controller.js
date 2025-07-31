import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input"]

  formatInput(event) {
    const input = event.target
    let value = input.value.replace(/\D/g, '') // Remove non-digits
    
    if (value.length > 6) {
      value = value.slice(0, 6)
    }
    
    input.value = value
    
    // Auto-submit when 6 digits are entered
    if (value.length === 6) {
      // Add visual feedback that code is complete
      input.classList.add('verification-complete')
      
      // Small delay for better UX, then submit
      setTimeout(() => {
        input.form.submit()
      }, 300)
    } else {
      // Remove complete state if user modifies the code
      input.classList.remove('verification-complete')
    }
  }
}