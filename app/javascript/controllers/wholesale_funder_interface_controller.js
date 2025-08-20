import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["card", "flashMessages"]
  static values = { 
    lenderId: Number,
    addWholesaleFunderUrl: String 
  }

  connect() {
    this.selectedFunders = new Set()
    this.loadingStates = new Map()
    this.hideTemporaryNotices()
  }

  hideTemporaryNotices() {
    const notice = document.getElementById('temp-notice')
    if (notice) {
      setTimeout(() => {
        notice.style.display = 'none'
      }, 3000)
    }
  }

  toggleFunderSelection(event) {
    // Don't trigger on pool button clicks
    if (event.target.closest('.pool-toggle-btn') || event.target.closest('.pool-item')) {
      return
    }
    
    const card = event.currentTarget
    this.handleFunderCardClick(card)
  }

  poolButtonClick(event) {
    // Just prevent button clicks from bubbling to card click handlers
    event.stopPropagation()
  }

  async handleFunderCardClick(card) {
    const funderId = card.dataset.wholesaleFunderId
    const isSelected = card.classList.contains('selected')
    const funderName = card.querySelector('h4').textContent.trim()

    if (this.loadingStates.get(funderId)) return

    // Show confirmation prompt when selecting a new wholesale funder
    if (!isSelected) {
      if (!confirm(`Are you sure you want to add a relationship with ${funderName}? This relationship will persist until any loans are fully paid back.`)) {
        return
      }
    }

    this.loadingStates.set(funderId, true)

    try {
      if (isSelected) {
        // Note: Removal functionality disabled - relationships persist until loans are paid back
        this.showError('Cannot remove wholesale funder relationships once established.')
      } else {
        const response = await this.addWholesaleFunderRelationship(funderId)
        if (response.success) {
          this.selectCard(card)
          this.showPools(card, response.pools)
        }
      }
    } catch (error) {
      this.showError('Failed to update relationship. Please try again.')
    } finally {
      this.loadingStates.set(funderId, false)
    }
  }

  async addWholesaleFunderRelationship(wholesaleFunderId) {
    const response = await fetch(this.addWholesaleFunderUrlValue, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
      },
      body: JSON.stringify({
        wholesale_funder_id: wholesaleFunderId
      })
    })
    
    return await response.json()
  }

  selectCard(card) {
    card.classList.add('selected')
    const statusText = card.querySelector('.card-status .status-text')
    statusText.textContent = 'Selected'
  }

  deselectCard(card) {
    card.classList.remove('selected')
    const statusText = card.querySelector('.card-status .status-text')
    statusText.textContent = 'Click to Select'
  }

  showPools(card, pools) {
    const poolsSection = card.querySelector('.funder-pools-section')
    poolsSection.style.display = 'block'
    
    // Update pool data with server response
    pools.forEach(pool => {
      const poolItem = poolsSection.querySelector(`[data-pool-id="${pool.id}"]`)
      if (poolItem) {
        const button = poolItem.querySelector('.pool-toggle-btn')
        this.updatePoolButton(button, pool.active)
      }
    })
  }

  hidePools(card) {
    const poolsSection = card.querySelector('.funder-pools-section')
    poolsSection.style.display = 'none'
  }

  updatePoolButton(button, isActive) {
    if (isActive) {
      button.classList.remove('inactive')
      button.classList.add('active')
      button.textContent = 'Active'
    } else {
      button.classList.remove('active')
      button.classList.add('inactive')
      button.textContent = 'Inactive'
    }
  }

  showSuccess(message) {
    this.showFlashMessage(message, 'success')
  }

  showError(message) {
    this.showFlashMessage(message, 'error')
  }

  showFlashMessage(message, type) {
    const flashContainer = this.hasFlashMessagesTarget ? 
      this.flashMessagesTarget : 
      document.getElementById('flash-messages')
    
    if (!flashContainer) return

    const alertDiv = document.createElement('div')
    alertDiv.className = `alert alert-${type}`
    alertDiv.textContent = message
    
    // Remove any existing alerts
    const existingAlerts = flashContainer.querySelectorAll('.alert')
    existingAlerts.forEach(alert => alert.remove())
    
    flashContainer.appendChild(alertDiv)
    
    // Auto-hide after 5 seconds
    setTimeout(() => {
      if (alertDiv.parentNode) {
        alertDiv.remove()
      }
    }, 5000)
    
    // Scroll to top to show the message
    window.scrollTo({ top: 0, behavior: 'smooth' })
  }
}