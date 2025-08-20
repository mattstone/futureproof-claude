import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="structured-form"
export default class extends Controller {
  static targets = ["sectionsContainer", "addSectionButton"]
  static values = { sectionIndex: Number }

  connect() {
    this.setupEventListeners()
    this.updateSectionEvents()
  }

  setupEventListeners() {
    if (this.hasAddSectionButtonTarget) {
      this.addSectionButtonTarget.addEventListener('click', this.addSection.bind(this))
    }
  }

  addSection(event) {
    event.preventDefault()
    
    const template = document.getElementById('section-template')
    if (!template || !this.hasSectionsContainerTarget) {
      console.error('Section template or container not found')
      return
    }

    let html = template.innerHTML.replace(/__INDEX__/g, this.sectionIndexValue)
    
    const div = document.createElement('div')
    div.innerHTML = html
    this.sectionsContainerTarget.appendChild(div.firstElementChild)
    
    this.sectionIndexValue++
    this.updateSectionEvents()
  }

  updateSectionEvents() {
    this.updateRemoveSectionEvents()
    this.updateSectionTypeEvents()
    this.updateItemEvents()
  }

  updateRemoveSectionEvents() {
    // Remove old event listeners by cloning nodes
    document.querySelectorAll('.remove-section-btn').forEach(btn => {
      const newBtn = btn.cloneNode(true)
      btn.parentNode.replaceChild(newBtn, btn)
      
      newBtn.addEventListener('click', (event) => {
        event.preventDefault()
        event.target.closest('.section-form').remove()
      })
    })
  }

  updateSectionTypeEvents() {
    document.querySelectorAll('.section-type-selector').forEach(select => {
      const newSelect = select.cloneNode(true)
      select.parentNode.replaceChild(newSelect, select)
      
      newSelect.addEventListener('change', (event) => {
        const section = event.target.closest('.section-form')
        const type = event.target.value
        
        // Update section styling
        section.className = `section-form section-${type}`
        
        // Show/hide relevant fields
        const standardFields = section.querySelector('.standard-fields')
        const contactFields = section.querySelector('.contact-fields')
        
        if (standardFields && contactFields) {
          if (type === 'contact') {
            standardFields.style.display = 'none'
            contactFields.style.display = 'block'
          } else {
            standardFields.style.display = 'block'
            contactFields.style.display = 'none'
          }
        }
      })
    })
  }

  updateItemEvents() {
    this.updateAddItemEvents()
    this.updateRemoveItemEvents()
  }

  updateAddItemEvents() {
    document.querySelectorAll('.add-item-btn').forEach(btn => {
      const newBtn = btn.cloneNode(true)
      btn.parentNode.replaceChild(newBtn, btn)
      
      newBtn.addEventListener('click', (event) => {
        event.preventDefault()
        const container = event.target.previousElementSibling
        const newItem = document.createElement('div')
        newItem.className = 'item-input'
        
        // Get the field name pattern from existing items or construct it
        const existingItem = container.querySelector('input[name*="[items]"]')
        let fieldPattern = 'terms_and_condition[sections][][items][]'
        if (existingItem) {
          fieldPattern = existingItem.name
        }
        
        newItem.innerHTML = `
          <input type="text" name="${fieldPattern}" placeholder="Enter item text">
          <button type="button" class="remove-item-btn">Remove</button>
        `
        container.appendChild(newItem)
        this.updateRemoveItemEvents()
      })
    })
  }

  updateRemoveItemEvents() {
    document.querySelectorAll('.remove-item-btn').forEach(btn => {
      const newBtn = btn.cloneNode(true)
      btn.parentNode.replaceChild(newBtn, btn)
      
      newBtn.addEventListener('click', (event) => {
        event.preventDefault()
        event.target.parentElement.remove()
      })
    })
  }
}