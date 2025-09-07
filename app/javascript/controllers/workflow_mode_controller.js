import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modeBtn", "visualMode", "formMode"]
  
  connect() {
    // Set initial state
    this.switchMode('visual')
  }
  
  switchToMode(event) {
    const mode = event.currentTarget.dataset.mode
    this.switchMode(mode)
  }
  
  switchMode(mode) {
    // Update button states
    this.modeBtnTargets.forEach(btn => {
      btn.classList.remove('active')
      if (btn.dataset.mode === mode) {
        btn.classList.add('active')
      }
    })
    
    // Switch content using CSS classes instead of inline styles
    if (this.hasVisualModeTarget && this.hasFormModeTarget) {
      if (mode === 'visual') {
        this.visualModeTarget.classList.remove('hidden')
        this.formModeTarget.classList.add('hidden')
      } else {
        this.visualModeTarget.classList.add('hidden')
        this.formModeTarget.classList.remove('hidden')
      }
    }
  }
}