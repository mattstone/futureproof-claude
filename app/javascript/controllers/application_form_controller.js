import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["mortgageCheckbox", "mortgageAmountGroup", "mortgageLenderGroup", "homeValueSlider", "homeValueDisplay", "mortgageSlider", "mortgageAmountDisplay", "ownershipSelect", "individualFields", "jointFields", "superFields", "borrowerNamesHidden", "borrowerAgeSlider", "borrowerAgeDisplay"]

  connect() {
    this.toggleMortgageAmount()
    this.updateHomeValue()
    this.updateMortgageAmount()
    this.updateBorrowerAge()
    this.toggleOwnershipFields()
    this.setupJointBorrowers()
    this.setupJointAgeSliders()
  }

  toggleMortgageAmount() {
    if (this.mortgageCheckboxTarget.checked) {
      this.mortgageAmountGroupTarget.classList.remove("js-hidden")
      if (this.hasMortgageLenderGroupTarget) {
        this.mortgageLenderGroupTarget.classList.remove("js-hidden")
      }
    } else {
      this.mortgageAmountGroupTarget.classList.add("js-hidden")
      if (this.hasMortgageLenderGroupTarget) {
        this.mortgageLenderGroupTarget.classList.add("js-hidden")
      }
      // Reset the mortgage slider when hiding
      if (this.hasMortgageSliderTarget) {
        this.mortgageSliderTarget.value = 500000
        this.updateMortgageAmount()
      }
    }
  }

  updateHomeValue() {
    if (this.hasHomeValueSliderTarget && this.hasHomeValueDisplayTarget) {
      const value = parseInt(this.homeValueSliderTarget.value)
      this.homeValueDisplayTarget.textContent = this.formatCurrency(value)
    }
  }

  updateMortgageAmount() {
    if (this.hasMortgageSliderTarget && this.hasMortgageAmountDisplayTarget) {
      const value = parseInt(this.mortgageSliderTarget.value)
      this.mortgageAmountDisplayTarget.textContent = this.formatCurrency(value)
    }
  }

  updateBorrowerAge() {
    if (this.hasBorrowerAgeSliderTarget && this.hasBorrowerAgeDisplayTarget) {
      const value = parseInt(this.borrowerAgeSliderTarget.value)
      this.borrowerAgeDisplayTarget.textContent = `${value} years`
    }
  }

  formatCurrency(value) {
    return new Intl.NumberFormat('en-AU', {
      style: 'currency',
      currency: 'AUD',
      minimumFractionDigits: 0,
      maximumFractionDigits: 0
    }).format(value)
  }

  toggleOwnershipFields() {
    if (!this.hasOwnershipSelectTarget) return

    const ownershipType = this.ownershipSelectTarget.value

    // Hide all ownership-specific fields
    if (this.hasIndividualFieldsTarget) {
      this.individualFieldsTarget.classList.add("js-hidden")
    }
    if (this.hasJointFieldsTarget) {
      this.jointFieldsTarget.classList.add("js-hidden")
    }
    if (this.hasSuperFieldsTarget) {
      this.superFieldsTarget.classList.add("js-hidden")
    }

    // Show the appropriate fields based on ownership type
    switch(ownershipType) {
      case 'individual':
        if (this.hasIndividualFieldsTarget) {
          this.individualFieldsTarget.classList.remove("js-hidden")
        }
        break
      case 'joint':
        if (this.hasJointFieldsTarget) {
          this.jointFieldsTarget.classList.remove("js-hidden")
        }
        this.updateBorrowerNamesField()
        break
      case 'super':
        if (this.hasSuperFieldsTarget) {
          this.superFieldsTarget.classList.remove("js-hidden")
        }
        break
    }
  }

  setupJointBorrowers() {
    // Set up event listeners for joint borrower management
    const addBorrowerBtn = document.getElementById('add-borrower')
    if (addBorrowerBtn) {
      addBorrowerBtn.addEventListener('click', () => {
        this.addJointBorrower()
      })
    }

    // Load existing borrower data if present
    this.loadExistingBorrowers()

    // Set up initial event listeners for existing borrower inputs
    this.updateBorrowerInputListeners()
  }

  loadExistingBorrowers() {
    if (!this.hasBorrowerNamesHiddenTarget) return

    const existingData = this.borrowerNamesHiddenTarget.value
    if (!existingData || existingData.trim() === '') return

    try {
      const borrowers = JSON.parse(existingData)
      if (Array.isArray(borrowers) && borrowers.length > 0) {
        // Clear existing borrower inputs
        const borrowersContainer = document.getElementById('joint-borrowers')
        if (borrowersContainer) {
          borrowersContainer.innerHTML = ''
        }

        // Add borrowers from existing data
        borrowers.forEach((borrower, index) => {
          this.addBorrowerWithData(borrower.name, borrower.age, index + 1)
        })
      }
    } catch (e) {
      console.log('Could not parse existing borrower data:', e)
    }
  }

  addBorrowerWithData(name, age, index) {
    const borrowersContainer = document.getElementById('joint-borrowers')
    if (!borrowersContainer) return

    const ageValue = age || 60
    const newBorrowerHTML = `
      <div class="joint-borrower-item">
        <div class="joint-borrower-row">
          <div class="joint-borrower-name">
            <input type="text" name="borrower_name_${index}" placeholder="Borrower ${index} name" class="form-input" value="${name || ''}">
          </div>
          <div class="joint-borrower-age">
            <div class="joint-age-slider-container">
              <input type="range" name="borrower_age_${index}" min="18" max="85" step="1" value="${ageValue}" class="joint-age-slider" data-borrower-index="${index}">
              <div class="joint-age-display" data-age-display="${index}">${ageValue} years</div>
            </div>
          </div>
          ${index > 2 ? '<div class="joint-borrower-remove"><button type="button" class="btn btn-secondary btn-sm remove-borrower">Remove</button></div>' : ''}
        </div>
      </div>
    `
    
    borrowersContainer.insertAdjacentHTML('beforeend', newBorrowerHTML)
  }

  addJointBorrower() {
    const borrowersContainer = document.getElementById('joint-borrowers')
    if (!borrowersContainer) return

    const borrowerCount = borrowersContainer.children.length + 1
    const newBorrowerHTML = `
      <div class="joint-borrower-item">
        <div class="joint-borrower-row">
          <div class="joint-borrower-name">
            <input type="text" name="borrower_name_${borrowerCount}" placeholder="Borrower ${borrowerCount} name" class="form-input">
          </div>
          <div class="joint-borrower-age">
            <div class="joint-age-slider-container">
              <input type="range" name="borrower_age_${borrowerCount}" min="18" max="85" step="1" value="60" class="joint-age-slider" data-borrower-index="${borrowerCount}">
              <div class="joint-age-display" data-age-display="${borrowerCount}">60 years</div>
            </div>
          </div>
          <div class="joint-borrower-remove">
            <button type="button" class="btn btn-secondary btn-sm remove-borrower">Remove</button>
          </div>
        </div>
      </div>
    `
    
    borrowersContainer.insertAdjacentHTML('beforeend', newBorrowerHTML)
    this.updateBorrowerInputListeners()
    this.updateJointAgeSliderListeners()
    this.updateBorrowerNamesField()
  }

  updateBorrowerInputListeners() {
    // Add event listeners to all borrower name and age inputs
    const borrowerInputs = document.querySelectorAll('#joint-borrowers input[name^="borrower_"]')
    borrowerInputs.forEach(input => {
      input.removeEventListener('input', this.updateBorrowerNamesField.bind(this))
      input.addEventListener('input', this.updateBorrowerNamesField.bind(this))
    })

    // Add event listeners to remove buttons
    const removeButtons = document.querySelectorAll('.remove-borrower')
    removeButtons.forEach(button => {
      button.removeEventListener('click', this.removeBorrower.bind(this))
      button.addEventListener('click', this.removeBorrower.bind(this))
    })
  }

  removeBorrower(event) {
    const borrowerItem = event.target.closest('.joint-borrower-item')
    if (borrowerItem) {
      borrowerItem.remove()
      this.updateBorrowerNamesField()
    }
  }

  updateBorrowerNamesField() {
    if (!this.hasBorrowerNamesHiddenTarget) return

    const borrowers = []
    const borrowerItems = document.querySelectorAll('#joint-borrowers .joint-borrower-item')
    
    borrowerItems.forEach((item, index) => {
      const nameInput = item.querySelector(`input[name="borrower_name_${index + 1}"]`)
      const ageSlider = item.querySelector(`input[name="borrower_age_${index + 1}"]`)
      
      if (nameInput && ageSlider && nameInput.value.trim() && ageSlider.value) {
        borrowers.push({
          name: nameInput.value.trim(),
          age: parseInt(ageSlider.value)
        })
      }
    })

    this.borrowerNamesHiddenTarget.value = JSON.stringify(borrowers)
  }

  setupJointAgeSliders() {
    // Set up event listeners for joint borrower age sliders
    this.updateJointAgeSliderListeners()
  }

  updateJointAgeSliderListeners() {
    const ageSliders = document.querySelectorAll('.joint-age-slider')
    ageSliders.forEach(slider => {
      slider.removeEventListener('input', this.handleJointAgeSliderChange.bind(this))
      slider.addEventListener('input', this.handleJointAgeSliderChange.bind(this))
    })
  }

  handleJointAgeSliderChange(event) {
    const slider = event.target
    const borrowerIndex = slider.getAttribute('data-borrower-index')
    const ageDisplay = document.querySelector(`[data-age-display="${borrowerIndex}"]`)

    if (ageDisplay) {
      ageDisplay.textContent = `${slider.value} years`
    }

    // Update the borrower names field with new age data
    this.updateBorrowerNamesField()
  }

  async autoSave() {
    try {
      const form = this.element
      const formData = new FormData(form)
      const action = form.action

      const csrfToken = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content')

      const response = await fetch(`${action}.json`, {
        method: 'PATCH',
        body: formData,
        headers: {
          'Accept': 'application/json',
          'X-Requested-With': 'XMLHttpRequest',
          'X-CSRF-Token': csrfToken
        }
      })

      if (response.ok) {
        console.log('Auto-save successful')
      }
    } catch (error) {
      console.log('Auto-save failed:', error)
    }
  }
}