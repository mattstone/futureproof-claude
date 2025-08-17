import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "toggleButton",
    "closeButton", 
    "selectionInterface",
    "availableFundersContainer",
    "existingRelationships"
  ]
  
  static values = {
    lenderId: Number,
    availableWholesaleFundersPath: String
  }
  
  connect() {
    // Initialize the interface state
    this.hideSelection()
  }
  
  toggleSelection() {
    if (this.selectionInterfaceTarget.style.display === 'none' || 
        this.selectionInterfaceTarget.style.display === '') {
      this.showSelection()
    } else {
      this.hideSelection()
    }
  }
  
  closeSelection() {
    this.hideSelection()
  }
  
  showSelection() {
    // Show the selection interface
    this.selectionInterfaceTarget.style.display = 'block'
    
    // Hide existing relationships while selecting
    this.existingRelationshipsTarget.style.display = 'none'
    
    // Update button text
    this.toggleButtonTarget.textContent = 'Cancel'
    
    this.loadAvailableWholesaleFunders()
  }
  
  hideSelection() {
    // Hide the selection interface
    this.selectionInterfaceTarget.style.display = 'none'
    this.availableFundersContainerTarget.innerHTML = ''
    
    // Show existing relationships again
    this.existingRelationshipsTarget.style.display = 'block'
    
    // Reset button text
    this.toggleButtonTarget.textContent = 'Add Wholesale Funder'
  }
  
  async loadAvailableWholesaleFunders() {
    try {
      // Show loading state
      this.availableFundersContainerTarget.innerHTML = '<div class="loading-state">Loading available wholesale funders...</div>'
      
      const response = await fetch(this.availableWholesaleFundersPathValue)
      
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`)
      }
      
      const data = await response.json()
      this.renderWholesaleFunders(data.wholesale_funders)
      
    } catch (error) {
      console.error('Error loading wholesale funders:', error)
      this.availableFundersContainerTarget.innerHTML = 
        '<div class="error-state">Failed to load wholesale funders. Please try again.</div>'
    }
  }
  
  renderWholesaleFunders(funders) {
    if (funders.length === 0) {
      this.availableFundersContainerTarget.innerHTML = 
        '<div class="empty-state"><p>No wholesale funders available for selection.</p></div>'
      return
    }
    
    const fundersHTML = funders.map(funder => `
      <div class="wholesale-funder-option clickable-card" 
           data-funder-id="${funder.id}" 
           data-funder-name="${funder.name}"
           data-action="click->wholesale-funder-selector#selectFunder"
           role="button"
           tabindex="0">
        <div class="funder-info">
          <h5>${funder.name}</h5>
          <div class="funder-details">
            <div class="detail-row">
              <span class="detail-label">Country:</span>
              <span class="detail-value">${funder.country}</span>
            </div>
            <div class="detail-row">
              <span class="detail-label">Currency:</span>
              <span class="detail-value">${funder.currency_symbol} ${funder.currency}</span>
            </div>
            <div class="detail-row">
              <span class="detail-label">Available Pools:</span>
              <span class="detail-value">${funder.pools_count}</span>
            </div>
            <div class="detail-row">
              <span class="detail-label">Total Capital:</span>
              <span class="detail-value">${funder.formatted_total_capital}</span>
            </div>
          </div>
        </div>
        <div class="click-indicator">
          <span class="click-text">Click to add</span>
        </div>
        <!-- Hidden form for submission -->
        <form style="display: none;" 
              data-target="hiddenForm"
              action="/admin/lenders/${this.lenderIdValue}/wholesale_funders/add_wholesale_funder" 
              method="post" 
              data-turbo="true">
          <input type="hidden" name="authenticity_token" value="${document.querySelector('meta[name="csrf-token"]').getAttribute('content')}">
          <input type="hidden" name="wholesale_funder_id" value="${funder.id}">
        </form>
      </div>
    `).join('')
    
    this.availableFundersContainerTarget.innerHTML = fundersHTML
  }

  selectFunder(event) {
    const card = event.currentTarget
    const funderName = card.dataset.funderName
    const funderId = card.dataset.funderId
    
    // Prevent multiple clicks while processing
    if (card.classList.contains('processing')) {
      return
    }
    
    // Show confirmation dialog
    const confirmed = confirm(`Are you sure you want to add "${funderName}" as a wholesale funder for this lender?`)
    
    if (confirmed) {
      // Add processing state
      card.classList.add('processing')
      card.style.opacity = '0.6'
      card.style.pointerEvents = 'none'
      
      // Find and submit the hidden form
      const form = card.querySelector('form[data-target="hiddenForm"]')
      if (form) {
        form.submit()
      } else {
        console.error('Hidden form not found for funder:', funderId)
        // Reset processing state if error
        card.classList.remove('processing')
        card.style.opacity = ''
        card.style.pointerEvents = ''
      }
    }
  }
  
}