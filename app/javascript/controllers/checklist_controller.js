import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "checkbox"]
  
  connect() {
    this.updateProgressBars()
  }
  
  // Handle checkbox change events
  change(event) {
    const checkbox = event.target
    const form = checkbox.closest("form")
    
    if (form) {
      // Auto-submit the form when checkbox changes
      form.requestSubmit()
    }
  }
  
  // Handle form submission (can be used for additional processing if needed)
  submit(event) {
    // Let the form submit normally - Rails will handle the update
    
    // Listen for turbo:frame-load to update progress bars after form submission
    document.addEventListener('turbo:frame-load', () => {
      this.updateProgressBars()
    }, { once: true })
  }
  
  // Update progress bar widths using CSS classes (CSP compliant)
  updateProgressBars() {
    const progressFills = this.element.querySelectorAll('.progress-fill')
    
    progressFills.forEach(fill => {
      const progress = parseInt(fill.dataset.progress) || 0
      
      // Remove any existing progress classes
      fill.classList.remove('progress-0', 'progress-25', 'progress-50', 'progress-75', 'progress-100')
      
      // Apply appropriate progress class based on percentage
      if (progress >= 100) {
        fill.classList.add('progress-100')
      } else if (progress >= 75) {
        fill.classList.add('progress-75')
      } else if (progress >= 50) {
        fill.classList.add('progress-50')
      } else if (progress >= 25) {
        fill.classList.add('progress-25')
      } else {
        fill.classList.add('progress-0')
      }
    })
  }
}