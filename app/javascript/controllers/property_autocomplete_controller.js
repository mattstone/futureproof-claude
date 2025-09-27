import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "suggestions", "propertyId", "homeValue", "propertyPreview", "primaryImage"]
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

    // Check if there's existing property data to display
    this.checkExistingData()
  }

  // Check if there's existing property data and display it
  checkExistingData() {
    const corelogicDataField = this.element.querySelector('[data-field="corelogic_data"]')
    if (corelogicDataField && corelogicDataField.value) {
      try {
        const existingData = JSON.parse(corelogicDataField.value)
        console.log('📋 Found existing property data, displaying preview')
        this.showPropertyPreview(existingData)
      } catch (e) {
        console.log('📋 No valid existing property data found')
      }
    }
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

    // Debounce the search
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
        <div class="autocomplete-item" data-index="${index}" data-id="${suggestion.id}" data-text="${this.escapeHtml(suggestion.text)}">
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

  // Select an item and fetch property details
  async selectItem(item) {
    const text = item.dataset.text
    const id = item.dataset.id

    this.inputTarget.value = text

    // Store the selected property ID
    if (this.hasPropertyIdTarget) {
      this.propertyIdTarget.value = id
    }

    this.hideSuggestions()

    // Fetch full property details and update form
    await this.fetchAndSetPropertyDetails(id)

    // Save the property data to the application
    this.savePropertyData()

    // Trigger a custom event
    this.element.dispatchEvent(new CustomEvent('property:selected', {
      detail: { id, text },
      bubbles: true
    }))
  }

  // Fetch property details and update form fields
  async fetchAndSetPropertyDetails(propertyId) {
    try {
      console.log(`🏠 Fetching property details for: ${propertyId}`)

      const response = await fetch(`/applications/get_property_details?property_id=${encodeURIComponent(propertyId)}`, {
        headers: {
          'Accept': 'application/json',
          'X-Requested-With': 'XMLHttpRequest'
        }
      })

      if (response.ok) {
        const propertyData = await response.json()
        console.log(`✅ Property details received:`, propertyData)

        // Extract valuation data and set middle value as home_value
        if (propertyData.valuation && (propertyData.valuation.avm || propertyData.valuation.estimate)) {
          // Handle both real API format (avm) and mock data format (direct estimates)
          const lowValue = propertyData.valuation.avm?.low_range_value || propertyData.valuation.low_estimate
          const highValue = propertyData.valuation.avm?.high_range_value || propertyData.valuation.high_estimate
          const middleValue = propertyData.valuation.avm?.estimate || propertyData.valuation.estimate || Math.round((lowValue + highValue) / 2)

          // Update the home value field if available
          if (this.hasHomeValueTarget) {
            this.homeValueTarget.value = middleValue

            // Trigger input event to update slider display
            const event = new Event('input', { bubbles: true })
            this.homeValueTarget.dispatchEvent(event)
          }

          // Store property data in hidden fields (if they exist)
          const propertyDataField = this.element.querySelector('[data-field="corelogic_data"]')
          if (propertyDataField) {
            // Map API response to expected format for the view template
            const mappedData = {
              bedrooms: propertyData.attributes?.beds || propertyData.attributes?.bedrooms,
              bathrooms: propertyData.attributes?.baths || propertyData.attributes?.bathrooms,
              car_spaces: propertyData.attributes?.car_spaces,
              land_area: propertyData.attributes?.land_area,
              building_area: propertyData.attributes?.building_area,
              year_built: propertyData.attributes?.year_built,
              property_type: propertyData.attributes?.property_type,
              ...propertyData  // Include all original data as well
            }
            propertyDataField.value = JSON.stringify(mappedData)
          }

          const valuationLowField = this.element.querySelector('[data-field="property_valuation_low"]')
          if (valuationLowField) {
            valuationLowField.value = lowValue
          }

          const valuationMiddleField = this.element.querySelector('[data-field="property_valuation_middle"]')
          if (valuationMiddleField) {
            valuationMiddleField.value = middleValue
          }

          const valuationHighField = this.element.querySelector('[data-field="property_valuation_high"]')
          if (valuationHighField) {
            valuationHighField.value = highValue
          }

          const propertyImagesField = this.element.querySelector('[data-field="property_images"]')
          if (propertyImagesField && propertyData.images) {
            // Extract image URLs from the API response
            const imageUrls = propertyData.images.map(img =>
              img.large_photo_url || img.medium_photo_url || img.base_photo_url || img
            )
            propertyImagesField.value = JSON.stringify(imageUrls)
          }

          const propertyTypeField = this.element.querySelector('[data-field="property_type"]')
          if (propertyTypeField && propertyData.attributes) {
            propertyTypeField.value = propertyData.attributes.property_type || 'Property'
          }

          console.log(`🎯 Set property value to: $${middleValue.toLocaleString()} (range: $${lowValue.toLocaleString()} - $${highValue.toLocaleString()})`)
        }

        // Show property preview after setting all data
        this.showPropertyPreview(propertyData)
      } else {
        console.error('Failed to fetch property details')
      }
    } catch (error) {
      console.error('Error fetching property details:', error)
    }
  }

  // Show the property preview section with updated data
  showPropertyPreview(propertyData) {
    if (this.hasPropertyPreviewTarget) {
      console.log('🎬 Showing property preview with data:', propertyData)

      // Ensure the property preview section has the proper structure
      this.ensurePropertyPreviewStructure()

      // Show the preview section (start collapsed)
      this.propertyPreviewTarget.classList.remove('hidden')
      this.propertyPreviewTarget.classList.add('visible')
      console.log('👁️ Property preview classes after adding visible:', this.propertyPreviewTarget.classList.toString())

      // Update property images if available
      if (propertyData.images && propertyData.images.length > 0) {
        console.log('📸 Updating property images:', propertyData.images.length)
        // Extract image URLs from the API response
        const imageUrls = propertyData.images.map(img =>
          img.large_photo_url || img.medium_photo_url || img.base_photo_url || img
        )
        this.updatePropertyImages(imageUrls)
      }

      // Update property details in the DOM
      console.log('📋 Updating property details')
      this.updatePropertyDetails(propertyData)

      // Update summary in header
      this.updatePropertySummary(propertyData)

      // Scroll to the property preview
      setTimeout(() => {
        this.propertyPreviewTarget.scrollIntoView({
          behavior: 'smooth',
          block: 'nearest'
        })
      }, 300)
    } else {
      console.error('❌ Property preview target not found')
    }
  }

  // Ensure the property preview has the basic structure needed
  ensurePropertyPreviewStructure() {
    // Check if we need to add missing elements, but don't replace existing structure

    // Ensure header has toggle functionality
    let header = this.propertyPreviewTarget.querySelector('.property-preview-header')
    if (header && !header.hasAttribute('data-action')) {
      header.setAttribute('data-action', 'click->property-autocomplete#togglePreview')
    }

    // Ensure we have a summary element
    let summaryElement = this.propertyPreviewTarget.querySelector('.property-preview-summary')
    if (!summaryElement && header) {
      summaryElement = document.createElement('div')
      summaryElement.className = 'property-preview-summary'
      header.appendChild(summaryElement)
    }

    // Ensure we have a toggle button
    let toggleButton = this.propertyPreviewTarget.querySelector('.property-preview-toggle')
    if (!toggleButton && header) {
      toggleButton = document.createElement('button')
      toggleButton.type = 'button'
      toggleButton.className = 'property-preview-toggle'
      toggleButton.textContent = '▼'
      header.appendChild(toggleButton)
    }

    // Ensure content section exists
    let content = this.propertyPreviewTarget.querySelector('.property-preview-content')
    if (!content) {
      content = document.createElement('div')
      content.className = 'property-preview-content'
      this.propertyPreviewTarget.appendChild(content)
    }

    // Ensure details grid exists
    let detailsSection = content.querySelector('.property-details-section')
    if (!detailsSection) {
      detailsSection = document.createElement('div')
      detailsSection.className = 'property-details-section'
      content.appendChild(detailsSection)
    }

    let detailsGrid = detailsSection.querySelector('.property-details-grid')
    if (!detailsGrid) {
      detailsGrid = document.createElement('div')
      detailsGrid.className = 'property-details-grid'
      detailsSection.appendChild(detailsGrid)
    }
  }

  // Toggle property preview expansion
  togglePreview(event) {
    event.preventDefault()
    event.stopPropagation()
    this.propertyPreviewTarget.classList.toggle('expanded')
  }

  // Update property details in the DOM directly
  updatePropertyDetails(propertyData) {
    // Update valuation display
    if (propertyData.valuation && (propertyData.valuation.estimate || propertyData.valuation.avm)) {
      const estimate = propertyData.valuation.avm?.estimate || propertyData.valuation.estimate
      const lowValue = propertyData.valuation.avm?.low_range_value || propertyData.valuation.low_estimate
      const highValue = propertyData.valuation.avm?.high_range_value || propertyData.valuation.high_estimate

      if (estimate) {
        this.updateDetailItem('Valuation', this.formatCurrency(estimate), `Range: ${this.formatCurrency(lowValue)} - ${this.formatCurrency(highValue)}`)
      }
    }

    // Update property attributes
    if (propertyData.attributes) {
      const attrs = propertyData.attributes

      if (attrs.land_area) {
        this.updateDetailItem('Land Area', `${attrs.land_area} m²`)
      }

      if (attrs.building_area) {
        this.updateDetailItem('Building Area', `${attrs.building_area} m²`)
      }

      if (attrs.year_built) {
        this.updateDetailItem('Year Built', attrs.year_built)
      }

      if (attrs.property_type) {
        this.updateDetailItem('Property Type', attrs.property_type)
      }
    }
  }

  // Helper to update or create property detail items
  updateDetailItem(label, value, subtitle = null) {
    const detailsGrid = this.propertyPreviewTarget.querySelector('.property-details-grid')
    if (!detailsGrid) return

    // Look for existing item or create new one
    let item = Array.from(detailsGrid.children).find(child =>
      child.querySelector('.property-detail-label')?.textContent.trim() === label
    )

    if (!item) {
      item = document.createElement('div')
      item.className = 'property-detail-item'
      detailsGrid.appendChild(item)
    }

    const rangeHtml = subtitle ? `<div class="property-detail-range">${subtitle}</div>` : ''
    const primaryClass = label === 'Valuation' ? ' primary-value' : ''

    item.innerHTML = `
      <div class="property-detail-label">${label}</div>
      <div class="property-detail-value${primaryClass}">${value}</div>
      ${rangeHtml}
    `
  }

  // Update property summary in the header
  updatePropertySummary(propertyData) {
    const summaryElement = this.propertyPreviewTarget.querySelector('.property-preview-summary')
    if (!summaryElement) return

    // Update the subtitle to show property type instead of "Searching property values"
    const subtitleElement = this.propertyPreviewTarget.querySelector('.property-preview-subtitle')
    if (subtitleElement && propertyData.attributes && propertyData.attributes.property_type) {
      subtitleElement.textContent = propertyData.attributes.property_type
    }

    const summaryParts = []

    // Add valuation
    if (propertyData.valuation && (propertyData.valuation.estimate || propertyData.valuation.avm)) {
      const estimate = propertyData.valuation.avm?.estimate || propertyData.valuation.estimate
      if (estimate) {
        summaryParts.push(`💰 ${this.formatCurrency(estimate)}`)
      }
    }

    // Add property details
    if (propertyData.attributes) {
      const attrs = propertyData.attributes
      const details = []

      if (attrs.beds || attrs.bedrooms) {
        details.push(`${attrs.beds || attrs.bedrooms} bed`)
      }
      if (attrs.baths || attrs.bathrooms) {
        details.push(`${attrs.baths || attrs.bathrooms} bath`)
      }
      if (attrs.car_spaces) {
        details.push(`${attrs.car_spaces} car`)
      }

      if (details.length > 0) {
        summaryParts.push(`🏠 ${details.join(', ')}`)
      }
    }

    summaryElement.innerHTML = summaryParts.map(part => `<span>${part}</span>`).join('')
  }

  // Helper to format currency
  formatCurrency(amount) {
    if (!amount) return 'Not available'
    return new Intl.NumberFormat('en-AU', {
      style: 'currency',
      currency: 'AUD',
      minimumFractionDigits: 0,
      maximumFractionDigits: 0
    }).format(amount)
  }

  // Update property images in the gallery
  updatePropertyImages(images) {
    if (!images || images.length === 0) return

    // Find or create the images section
    let imagesSection = this.propertyPreviewTarget.querySelector('.property-images-section')
    if (!imagesSection) {
      imagesSection = document.createElement('div')
      imagesSection.className = 'property-images-section'

      // Insert at the beginning of property-preview-content
      const content = this.propertyPreviewTarget.querySelector('.property-preview-content')
      if (content) {
        content.insertBefore(imagesSection, content.firstChild)
      }
    }

    // Create the complete image gallery structure
    const galleryHTML = `
      <div class="property-images-gallery">
        <div class="property-image-main">
          <img src="${images[0]}"
               alt="Property main image"
               class="property-image-primary"
               data-property-autocomplete-target="primaryImage">
        </div>
        ${images.length > 1 ? `
          <div class="property-image-thumbnails">
            ${images.map((imageUrl, index) => `
              <div class="property-image-thumb ${index === 0 ? 'active' : ''}"
                   data-action="click->property-autocomplete#selectImage"
                   data-index="${index}"
                   data-image-url="${imageUrl}">
                <img src="${imageUrl}" alt="Property image ${index + 1}">
              </div>
            `).join('')}
          </div>
        ` : ''}
      </div>
    `

    imagesSection.innerHTML = galleryHTML
  }

  // Handle image thumbnail selection
  selectImage(event) {
    const thumb = event.currentTarget
    const imageUrl = thumb.dataset.imageUrl

    // Update primary image
    if (this.hasPrimaryImageTarget) {
      this.primaryImageTarget.src = imageUrl
    }

    // Update active thumbnail
    const allThumbs = this.element.querySelectorAll('.property-image-thumb')
    allThumbs.forEach(t => t.classList.remove('active'))
    thumb.classList.add('active')
  }

  // Handle clicks outside to close dropdown
  handleClickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.hideSuggestions()
    }
  }

  // Save property data to the application automatically
  async savePropertyData() {
    try {
      console.log('💾 Auto-saving property data to application...')

      // Get the form element
      const form = this.element.closest('form')
      if (!form) {
        console.warn('No form found for auto-save')
        return
      }

      // Get essential form data to save property info only
      const propertyData = {
        address: this.inputTarget.value,
        property_id: this.hasPropertyIdTarget ? this.propertyIdTarget.value : null,
        home_value: this.hasHomeValueTarget ? this.homeValueTarget.value : null,
        property_type: this.element.querySelector('[data-field="property_type"]')?.value,
        property_images: this.element.querySelector('[data-field="property_images"]')?.value,
        property_valuation_low: this.element.querySelector('[data-field="property_valuation_low"]')?.value,
        property_valuation_middle: this.element.querySelector('[data-field="property_valuation_middle"]')?.value,
        property_valuation_high: this.element.querySelector('[data-field="property_valuation_high"]')?.value,
        corelogic_data: this.element.querySelector('[data-field="corelogic_data"]')?.value
      }
      console.log('📋 Property data to save:', propertyData)

      // Send PATCH request to update the application
      // Extract application ID more reliably
      let applicationId = null

      // Try to get ID from the form's action URL
      const actionUrl = form.action
      console.log('🔍 Form action URL:', actionUrl)
      const actionMatch = actionUrl.match(/\/applications\/(\d+)/)
      if (actionMatch) {
        applicationId = actionMatch[1]
        console.log('✅ Extracted application ID from form action:', applicationId)
      }

      // Fallback: try URL pathname
      if (!applicationId) {
        const pathMatch = window.location.pathname.match(/\/applications\/(\d+)/)
        if (pathMatch) {
          applicationId = pathMatch[1]
          console.log('✅ Extracted application ID from pathname:', applicationId)
        }
      }

      if (!applicationId) {
        console.warn('Could not determine application ID for auto-save')
        return
      }

      const saveUrl = `/applications/${applicationId}`
      console.log('💾 Auto-save URL:', saveUrl)

      // Get CSRF token
      const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content ||
                       form.querySelector('input[name="authenticity_token"]')?.value
      console.log('🔐 CSRF Token found:', !!csrfToken)

      // Create URLSearchParams for the application data
      const params = new URLSearchParams()
      Object.entries(propertyData).forEach(([key, value]) => {
        if (value !== null && value !== undefined) {
          params.append(`application[${key}]`, value)
        }
      })

      console.log('📤 Making PATCH request to:', saveUrl)
      const response = await fetch(`${saveUrl}.json`, {
        method: 'PATCH',
        body: params,
        headers: {
          'X-Requested-With': 'XMLHttpRequest',
          'X-CSRF-Token': csrfToken,
          'Content-Type': 'application/x-www-form-urlencoded',
          'Accept': 'application/json'
        }
      })
      console.log('📨 Response status:', response.status, 'URL:', response.url)

      if (response.ok) {
        console.log('✅ Property data auto-saved successfully')

        // Show a subtle success indicator
        this.showSaveSuccess()
      } else {
        console.warn('⚠️ Auto-save failed, data will be saved on form submission')
      }
    } catch (error) {
      console.warn('⚠️ Auto-save error:', error.message)
    }
  }

  // Show a subtle save success indicator
  showSaveSuccess() {
    const header = this.propertyPreviewTarget.querySelector('.property-preview-subtitle')
    if (header) {
      const originalText = header.textContent
      header.textContent = 'Searching property values • Saved ✓'
      header.classList.add('save-success')

      setTimeout(() => {
        header.textContent = originalText
        header.classList.remove('save-success')
      }, 2000)
    }
  }

  // Utility function to escape HTML
  escapeHtml(text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }
}