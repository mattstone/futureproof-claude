import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "addButton",
    "selectionInterface",
    "closeButton",
    "availablePoolsContainer",
    "existingPools"
  ]
  
  static values = {
    lenderId: Number,
    availablePoolsPath: String
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
    
    // Hide existing pools while selecting
    this.existingPoolsTarget.style.display = 'none'
    
    // Update button text
    this.addButtonTarget.textContent = 'Cancel'
    
    this.loadAvailablePools()
  }
  
  hideSelection() {
    // Hide the selection interface
    this.selectionInterfaceTarget.style.display = 'none'
    this.availablePoolsContainerTarget.innerHTML = ''
    
    // Show existing pools again
    this.existingPoolsTarget.style.display = 'block'
    
    // Reset button text
    this.addButtonTarget.textContent = 'Add Funder Pool'
  }
  
  async loadAvailablePools() {
    try {
      // Show loading state
      this.availablePoolsContainerTarget.innerHTML = '<div class="loading-state">Loading available funder pools...</div>'
      
      const response = await fetch(this.availablePoolsPathValue)
      
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`)
      }
      
      const data = await response.json()
      this.renderFunderPools(data.funder_pools)
      
    } catch (error) {
      console.error('Error loading funder pools:', error)
      this.availablePoolsContainerTarget.innerHTML = 
        '<div class="error-state">Failed to load funder pools. Please try again.</div>'
    }
  }
  
  renderFunderPools(pools) {
    if (pools.length === 0) {
      this.availablePoolsContainerTarget.innerHTML = 
        '<div class="empty-state"><p>No funder pools available for selection.</p><p>All available pools from your wholesale funders are already selected.</p></div>'
      return
    }
    
    const poolsHTML = pools.map(pool => `
      <div class="funder-pool-option" data-pool-id="${pool.id}">
        <div class="pool-info">
          <h5>${pool.name}</h5>
          <div class="pool-details">
            <div class="detail-row">
              <span class="detail-label">Total Amount:</span>
              <span class="detail-value">${pool.formatted_amount}</span>
            </div>
            <div class="detail-row">
              <span class="detail-label">Available:</span>
              <span class="detail-value">${pool.formatted_available}</span>
            </div>
          </div>
        </div>
        <div class="pool-actions">
          <form action="/admin/lenders/${this.lenderIdValue}/funder_pools/add_pool" method="post" data-turbo="true">
            <input type="hidden" name="authenticity_token" value="${document.querySelector('meta[name="csrf-token"]').getAttribute('content')}">
            <input type="hidden" name="funder_pool_id" value="${pool.id}">
            <button type="submit" class="admin-btn admin-btn-primary admin-btn-sm">
              Add Pool
            </button>
          </form>
        </div>
      </div>
    `).join('')
    
    this.availablePoolsContainerTarget.innerHTML = poolsHTML
  }
}