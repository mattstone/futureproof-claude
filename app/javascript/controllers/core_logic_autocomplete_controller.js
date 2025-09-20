import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "suggestions", "selectedId"]
  static values = {
    url: String,
    minChars: { type: Number, default: 3 }
  }

  connect() {
    this.debounceTimer = null
    this.isOpen = false
    this.selectedIndex = -1
    this.lastQuery = ""
    this.isSearching = false

    // Bind event handlers
    this.handleClickOutside = this.handleClickOutside.bind(this)
    document.addEventListener("click", this.handleClickOutside)
  }

  disconnect() {
    document.removeEventListener("click", this.handleClickOutside)
    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer)
    }
  }

  // Input event handler with debouncing
  input() {
    const query = this.inputTarget.value.trim()

    // Clear previous timer
    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer)
    }

    // Hide suggestions if query is too short
    if (query.length < this.minCharsValue) {
      this.hideSuggestions()
      this.lastQuery = ""
      return
    }

    // Show loading state immediately
    this.showLoading()

    // Debounce the search - this will create a new search for every keystroke
    this.debounceTimer = setTimeout(() => {
      this.search(query)
    }, 150)
  }

  // Perform the search
  async search(query) {
    this.isSearching = true
    this.lastQuery = query

    try {
      console.log(`🔍 Searching for: "${query}"`)

      const response = await fetch(`${this.urlValue}?query=${encodeURIComponent(query)}`, {
        headers: {
          'Accept': 'application/json',
          'X-Requested-With': 'XMLHttpRequest'
        }
      })

      if (response.ok) {
        const suggestions = await response.json()
        console.log(`✅ Found ${suggestions.length} suggestions for "${query}"`)

        // Only display results if this query is still the current one
        if (query === this.inputTarget.value.trim()) {
          this.displaySuggestions(suggestions, query)
        }
      } else {
        console.error('Failed to fetch suggestions')
        this.hideSuggestions()
      }
    } catch (error) {
      console.error('Error fetching suggestions:', error)
      this.hideSuggestions()
    } finally {
      this.isSearching = false
    }
  }

  // Display suggestions
  displaySuggestions(suggestions, query) {
    if (suggestions.length === 0) {
      this.showNoResults(query)
      return
    }

    let html = suggestions.map((suggestion, index) => {
      const activeClass = suggestion.is_active ? 'active' : 'inactive'
      const typeIcon = suggestion.is_unit ? '🏢' : '🏠'

      return `
        <div class="autocomplete-item" data-index="${index}" data-id="${suggestion.id}">
          <div class="autocomplete-main">
            <span class="autocomplete-icon">${typeIcon}</span>
            <span class="autocomplete-text">${this.escapeHtml(suggestion.text)}</span>
          </div>
          <div class="autocomplete-meta">
            <span class="autocomplete-type">${suggestion.property_type || 'Property'}</span>
            <span class="autocomplete-status status-${activeClass}">${suggestion.is_active ? 'Active' : 'Inactive'}</span>
          </div>
        </div>
      `
    }).join('')

    this.suggestionsTarget.innerHTML = html
    this.showSuggestions()
    this.selectedIndex = -1
  }

  // Show suggestions dropdown
  showSuggestions() {
    this.suggestionsTarget.classList.add('show')
    this.isOpen = true
  }

  // Hide suggestions dropdown
  hideSuggestions() {
    this.suggestionsTarget.classList.remove('show')
    this.isOpen = false
    this.selectedIndex = -1
  }

  // Show loading state
  showLoading() {
    this.suggestionsTarget.innerHTML = `
      <div class="autocomplete-loading">
        🔍 Searching properties...
      </div>
    `
    this.showSuggestions()
  }

  // Show no results state
  showNoResults(query) {
    this.suggestionsTarget.innerHTML = `
      <div class="autocomplete-no-results">
        No properties found for "${this.escapeHtml(query)}"
      </div>
    `
    this.showSuggestions()
  }

  // Handle keyboard navigation
  keydown(event) {
    if (!this.isOpen) return

    const items = this.suggestionsTarget.querySelectorAll('.autocomplete-item')

    switch (event.key) {
      case 'ArrowDown':
        event.preventDefault()
        this.selectedIndex = Math.min(this.selectedIndex + 1, items.length - 1)
        this.updateSelection(items)
        break

      case 'ArrowUp':
        event.preventDefault()
        this.selectedIndex = Math.max(this.selectedIndex - 1, -1)
        this.updateSelection(items)
        break

      case 'Enter':
        event.preventDefault()
        if (this.selectedIndex >= 0 && items[this.selectedIndex]) {
          this.selectItem(items[this.selectedIndex])
        }
        break

      case 'Escape':
        this.hideSuggestions()
        break
    }
  }

  // Update visual selection
  updateSelection(items) {
    items.forEach((item, index) => {
      item.classList.toggle('selected', index === this.selectedIndex)
    })
  }

  // Handle click on suggestion item
  clickItem(event) {
    const item = event.target.closest('.autocomplete-item')
    if (item) {
      this.selectItem(item)
    }
  }

  // Select an item
  selectItem(item) {
    const text = item.querySelector('.autocomplete-text').textContent
    const id = item.dataset.id

    this.inputTarget.value = text

    // Store the selected property ID for form submission
    if (this.hasSelectedIdTarget) {
      this.selectedIdTarget.value = id
    }

    this.hideSuggestions()

    // Trigger a custom event
    this.element.dispatchEvent(new CustomEvent('autocomplete:selected', {
      detail: { id, text },
      bubbles: true
    }))
  }

  // Handle clicks outside to close dropdown
  handleClickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.hideSuggestions()
    }
  }

  // Utility function to escape HTML
  escapeHtml(text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }

  // Method to programmatically view property details
  viewDetails(event) {
    event.preventDefault()
    const propertyId = this.selectedIdTarget?.value

    if (propertyId) {
      // Navigate to property details page
      const detailsUrl = this.data.get('detailsUrl') || `/admin/core_logic_test/property_details?property_id=${propertyId}`
      window.location.href = detailsUrl
    } else {
      alert('Please select a property first')
    }
  }
}