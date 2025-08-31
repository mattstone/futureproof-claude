import { Controller } from "@hotwired/stimulus"

// Admin Dashboard Controller - handles metric card font scaling
export default class extends Controller {
  connect() {
    this.scaleMetricFonts()
  }

  scaleMetricFonts() {
    const metricNumbers = this.element.querySelectorAll('.metric-content h3')
    
    metricNumbers.forEach((element) => {
      const text = element.textContent.trim()
      const length = text.length
      element.setAttribute('data-length', length)
    })
  }
}