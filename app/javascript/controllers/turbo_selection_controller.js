import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="turbo-selection"
export default class extends Controller {
  static targets = [
    "toggleButton",
    "closeButton", 
    "selectionInterface",
    "availableItemsContainer",
    "existingItems"
  ]
  
  static values = {
    itemsPath: String,
    toggleButtonText: String,
    toggleButtonActiveText: String
  }
  
  connect() {
    this.hideSelection()
    this.originalButtonText = this.toggleButtonTextValue || 'Add Item'
    this.activeButtonText = this.toggleButtonActiveTextValue || 'Cancel'
  }
  
  toggleSelection(event) {
    event.preventDefault()
    
    if (this.selectionInterfaceTarget.style.display === 'none' || 
        this.selectionInterfaceTarget.style.display === '') {
      this.showSelection()
    } else {
      this.hideSelection()
    }
  }
  
  closeSelection(event) {
    event.preventDefault()
    this.hideSelection()
  }
  
  showSelection() {
    this.selectionInterfaceTarget.style.display = 'block'
    
    if (this.hasExistingItemsTarget) {
      this.existingItemsTarget.style.display = 'none'
    }
    
    if (this.hasToggleButtonTarget) {
      this.toggleButtonTarget.textContent = this.activeButtonText
    }
    
    this.loadAvailableItems()
  }
  
  hideSelection() {
    this.selectionInterfaceTarget.style.display = 'none'
    this.availableItemsContainerTarget.innerHTML = ''
    
    if (this.hasExistingItemsTarget) {
      this.existingItemsTarget.style.display = 'block'
    }
    
    if (this.hasToggleButtonTarget) {
      this.toggleButtonTarget.textContent = this.originalButtonText
    }
  }
  
  async loadAvailableItems() {
    if (!this.itemsPathValue) {
      console.error('Items path not provided')
      return
    }

    try {
      this.availableItemsContainerTarget.innerHTML = '<div class="loading-state">Loading available items...</div>'
      
      const response = await fetch(this.itemsPathValue)
      
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`)
      }
      
      const data = await response.json()
      this.renderItems(data)
      
    } catch (error) {
      console.error('Error loading items:', error)
      this.availableItemsContainerTarget.innerHTML = 
        '<div class="error-state">Failed to load items. Please try again.</div>'
    }
  }
  
  renderItems(data) {
    // This method should be customized per use case
    // The data structure will vary based on the endpoint
    const items = data.items || data.funder_pools || data.wholesale_funders || []
    
    if (items.length === 0) {
      this.availableItemsContainerTarget.innerHTML = 
        '<div class="empty-state"><p>No items available for selection.</p></div>'
      return
    }
    
    // Basic rendering - can be extended for specific use cases
    const itemsHTML = items.map(item => this.renderItem(item)).join('')
    this.availableItemsContainerTarget.innerHTML = itemsHTML
  }
  
  renderItem(item) {
    // Basic item rendering - override in specific controllers for custom rendering
    return `
      <div class="selectable-item" data-item-id="${item.id}">
        <div class="item-info">
          <h5>${item.name || item.title}</h5>
          <div class="item-details">
            ${Object.entries(item).map(([key, value]) => {
              if (key !== 'id' && key !== 'name' && key !== 'title' && value) {
                return `<div class="detail-row">
                  <span class="detail-label">${key.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase())}:</span>
                  <span class="detail-value">${value}</span>
                </div>`
              }
              return ''
            }).join('')}
          </div>
        </div>
        <div class="item-actions">
          <button type="button" class="admin-btn admin-btn-primary admin-btn-sm" 
                  data-action="click->turbo-selection#selectItem"
                  data-item-id="${item.id}">
            Select
          </button>
        </div>
      </div>
    `
  }
  
  selectItem(event) {
    const itemId = event.target.dataset.itemId
    if (!itemId) return
    
    // This should be implemented by extending controllers
    console.log('Item selected:', itemId)
  }
}