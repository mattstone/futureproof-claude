import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modeBtn", "visualMode", "formMode"]
  
  connect() {
    console.log("Workflow mode controller connected")
    this.initializeMode()
  }
  
  initializeMode() {
    // Set initial active state
    const activeBtn = this.modeBtnTargets.find(btn => btn.classList.contains('active'))
    if (activeBtn) {
      const mode = activeBtn.dataset.mode
      this.showMode(mode)
    }
  }
  
  switchToMode(event) {
    const clickedBtn = event.currentTarget
    const mode = clickedBtn.dataset.mode
    
    // Update button states
    this.modeBtnTargets.forEach(btn => btn.classList.remove('active'))
    clickedBtn.classList.add('active')
    
    // Show the selected mode
    this.showMode(mode)
  }
  
  showMode(mode) {
    if (mode === 'visual') {
      if (this.hasVisualModeTarget) {
        this.visualModeTarget.classList.remove('hidden')
      }
      if (this.hasFormModeTarget) {
        this.formModeTarget.classList.add('hidden')
      }
    } else if (mode === 'form') {
      if (this.hasVisualModeTarget) {
        this.visualModeTarget.classList.add('hidden')
      }
      if (this.hasFormModeTarget) {
        this.formModeTarget.classList.remove('hidden')
      }
    }
  }
}