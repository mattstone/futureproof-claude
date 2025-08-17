import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["existingLenders", "selectionInterface", "loadingState", "lenderOptions"]
  static values = { mortgageId: Number }

  connect() {
    console.log("Mortgage lender selector controller connected")
  }

  showSelection() {
    // Show the selection interface
    this.selectionInterfaceTarget.style.display = "block"
    
    // Show loading state
    this.loadingStateTarget.style.display = "block"
    this.lenderOptionsTarget.innerHTML = ""
    
    // Load available lenders
    this.loadAvailableLenders()
  }

  hideSelection() {
    this.selectionInterfaceTarget.style.display = "none"
    // Clear any loaded content
    this.lenderOptionsTarget.innerHTML = ""
  }

  async loadAvailableLenders() {
    try {
      const response = await fetch(`/admin/mortgages/${this.mortgageIdValue}/lenders/available_lenders`, {
        headers: {
          'Accept': 'application/json',
          'X-Requested-With': 'XMLHttpRequest'
        }
      })
      
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`)
      }
      
      const data = await response.json()
      this.renderLenderOptions(data.lenders)
      
    } catch (error) {
      console.error('Error loading available lenders:', error)
      this.showError('Failed to load available lenders. Please try again.')
    }
  }

  renderLenderOptions(lenders) {
    // Hide loading state
    this.loadingStateTarget.style.display = "none"
    
    if (lenders.length === 0) {
      this.lenderOptionsTarget.innerHTML = `
        <div class="no-lenders-available">
          <p>No lenders available to add to this mortgage.</p>
          <p>All existing lenders are already associated with this mortgage.</p>
        </div>
      `
      return
    }

    // Create lender option elements
    const lenderOptionsHTML = lenders.map(lender => `
      <div class="lender-option" data-lender-id="${lender.id}">
        <div class="lender-option-info">
          <h6>${this.escapeHtml(lender.name)}</h6>
          <p>${this.escapeHtml(lender.lender_type)} • ${this.escapeHtml(lender.contact_email)}</p>
        </div>
        <form action="/admin/mortgages/${this.mortgageIdValue}/lenders/add_lender" method="post" data-turbo="true">
          <input type="hidden" name="authenticity_token" value="${this.getCSRFToken()}">
          <input type="hidden" name="lender_id" value="${lender.id}">
          <button type="submit" class="admin-btn admin-btn-sm admin-btn-primary">
            Add Lender
          </button>
        </form>
      </div>
    `).join('')

    this.lenderOptionsTarget.innerHTML = lenderOptionsHTML
  }

  showError(message) {
    this.loadingStateTarget.style.display = "none"
    this.lenderOptionsTarget.innerHTML = `
      <div class="error-message">
        <p style="color: #dc2626; font-weight: 500;">${this.escapeHtml(message)}</p>
        <button class="admin-btn admin-btn-sm admin-btn-secondary" data-action="click->mortgage-lender-selector#loadAvailableLenders">
          Try Again
        </button>
      </div>
    `
  }

  // Utility methods
  escapeHtml(text) {
    const map = {
      '&': '&amp;',
      '<': '&lt;',
      '>': '&gt;',
      '"': '&quot;',
      "'": '&#039;'
    }
    return text.replace(/[&<>"']/g, function(m) { return map[m] })
  }

  getCSRFToken() {
    const token = document.querySelector('meta[name="csrf-token"]')
    return token ? token.getAttribute('content') : ''
  }
}