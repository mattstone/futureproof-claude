import { Controller } from "@hotwired/stimulus"

// Get Started Calculator Controller
// Matches the React webapp calculator functionality exactly
export default class extends Controller {
  static targets = [
    "homeValue",
    "monthlyIncome",
    "termDisplay",
    "termSlider",
    "modal",
    "modalInput",
    "helpModal",
    "emailModal",
    "emailInput",
    "termsCheckbox",
    "termsLabel",
    "continueButton",
    "mobileMenu",
    "mobileOverlay",
    "hamburgerBtn"
  ]

  // Loan lookup table (matches React app exactly)
  // Based on $1.5M base property value, 30-year loan term
  loanLookup = {
    10: { total_income: 300000, loan_type: 'Interest-only' },
    15: { total_income: 410468, loan_type: 'Interest-only' },
    20: { total_income: 443306, loan_type: 'Interest-only' },
    25: { total_income: 498478, loan_type: 'Interest-only' },
    30: { total_income: 553088, loan_type: 'Interest-only' }
  }

  basePropertyValue = 1500000
  minPropertyValue = 800000
  maxPropertyValue = 10000000

  connect() {
    this.currentHomeValue = this.basePropertyValue
    this.currentTerm = 10
    this.updateDisplay()
    this.updateSliderTrack()
  }

  // Calculate monthly annuity amount (matches React app exactly)
  // Formula: (total_income / annuityDuration / 12) * multiplier
  calculateMonthlyIncome(homeValue, term) {
    const loanData = this.loanLookup[term]
    if (!loanData) return 0

    const multiplier = homeValue / this.basePropertyValue
    const monthlyAmount = (loanData.total_income / term / 12) * multiplier

    return Math.round(monthlyAmount * 100) / 100
  }

  // Format currency (matches React app: $2,500)
  formatCurrency(amount, fractionless = false) {
    const options = {
      style: 'currency',
      currency: 'USD'
    }

    if (fractionless) {
      options.minimumFractionDigits = 0
      options.maximumFractionDigits = 0
    }

    return new Intl.NumberFormat('en-US', options).format(amount)
  }

  // Format big currency (matches React app: $1.5 M)
  formatBigCurrency(amount) {
    const million = amount / 1000000
    const formatted = Number.isInteger(million) ? million.toFixed(0) : million.toFixed(1)
    return `$${formatted} M`
  }

  // Update all display elements
  updateDisplay() {
    const monthlyIncome = this.calculateMonthlyIncome(this.currentHomeValue, this.currentTerm)

    // Update home value display (big currency format: $1.5 M)
    if (this.hasHomeValueTarget) {
      this.homeValueTarget.textContent = this.formatBigCurrency(this.currentHomeValue)
    }

    // Update monthly income with animation
    if (this.hasMonthlyIncomeTarget) {
      this.animateValue(this.monthlyIncomeTarget, monthlyIncome)
    }

    // Update term display
    if (this.hasTermDisplayTarget) {
      this.termDisplayTarget.textContent = `Every month over ${this.currentTerm} years*`
    }

    // Update slider steps
    this.updateSliderSteps()
  }

  // Animate the value change (slot counter effect)
  animateValue(element, newValue) {
    const formatted = this.formatCurrency(newValue, true)
    element.classList.add('gs-slot-counter')

    // Quick animation
    element.style.transform = 'translateY(-10px)'
    element.style.opacity = '0'

    setTimeout(() => {
      element.textContent = formatted
      element.style.transform = 'translateY(0)'
      element.style.opacity = '1'
    }, 100)
  }

  // Update slider step indicators
  updateSliderSteps() {
    const steps = this.element.querySelectorAll('.gs-slider-step')
    steps.forEach(step => {
      const year = parseInt(step.dataset.year)
      if (year <= this.currentTerm) {
        step.classList.add('active')
      } else {
        step.classList.remove('active')
      }
    })
  }

  // Update slider track to show progress
  updateSliderTrack() {
    if (this.hasTermSliderTarget) {
      const min = parseInt(this.termSliderTarget.min)
      const max = parseInt(this.termSliderTarget.max)
      const value = parseInt(this.termSliderTarget.value)
      const progress = ((value - min) / (max - min)) * 100
      this.termSliderTarget.style.setProperty('--slider-progress', `${progress}%`)
    }
  }

  // Handle term slider change
  updateTerm(event) {
    this.currentTerm = parseInt(event.target.value)
    this.updateDisplay()
    this.updateSliderTrack()
  }

  // Open modal for changing home value
  openModal() {
    if (this.hasModalTarget) {
      this.modalTarget.classList.add('active')
      if (this.hasModalInputTarget) {
        // Format input value with commas
        const formatted = this.currentHomeValue.toLocaleString('en-US')
        this.modalInputTarget.value = formatted
        this.modalInputTarget.focus()
        this.modalInputTarget.select()
      }
    }
  }

  // Close modal
  closeModal() {
    if (this.hasModalTarget) {
      this.modalTarget.classList.remove('active')
    }
  }

  // Format modal input as user types
  formatModalInput(event) {
    let value = event.target.value.replace(/[^0-9]/g, '')
    if (value) {
      value = parseInt(value).toLocaleString('en-US')
    }
    event.target.value = value
  }

  // Save home value from modal
  saveHomeValue() {
    if (this.hasModalInputTarget) {
      const rawValue = this.modalInputTarget.value.replace(/[^0-9]/g, '')
      const newValue = parseInt(rawValue)

      if (newValue >= this.minPropertyValue && newValue <= this.maxPropertyValue) {
        this.currentHomeValue = newValue
        this.updateDisplay()
        this.closeModal()
      } else {
        // Show error - value out of range
        this.modalInputTarget.style.borderColor = '#b91c1c'
        setTimeout(() => {
          this.modalInputTarget.style.borderColor = ''
        }, 2000)
      }
    }
  }

  // Handle click outside modal to close
  handleModalClick(event) {
    if (event.target === this.modalTarget) {
      this.closeModal()
    }
  }

  // Handle keyboard events in modal
  handleModalKeydown(event) {
    if (event.key === 'Enter') {
      this.saveHomeValue()
    } else if (event.key === 'Escape') {
      this.closeModal()
    }
  }

  // Open help modal
  openHelpModal() {
    if (this.hasHelpModalTarget) {
      this.helpModalTarget.classList.add('active')
    }
  }

  // Close help modal
  closeHelpModal() {
    if (this.hasHelpModalTarget) {
      this.helpModalTarget.classList.remove('active')
    }
  }

  // Handle click outside help modal to close
  handleHelpModalClick(event) {
    if (event.target === this.helpModalTarget) {
      this.closeHelpModal()
    }
  }

  // =====================================================
  // EMAIL MODAL (Create Account Flow)
  // Matches React webapp /application/create-account
  // =====================================================

  // Open email modal
  openEmailModal() {
    if (this.hasEmailModalTarget) {
      this.emailModalTarget.classList.add('active')
      if (this.hasEmailInputTarget) {
        this.emailInputTarget.value = ''
        this.emailInputTarget.focus()
      }
      if (this.hasTermsCheckboxTarget) {
        this.termsCheckboxTarget.checked = false
      }
      this.updateContinueButton()
    }
  }

  // Close email modal
  closeEmailModal() {
    if (this.hasEmailModalTarget) {
      this.emailModalTarget.classList.remove('active')
    }
  }

  // Handle click outside email modal to close
  handleEmailModalClick(event) {
    if (event.target === this.emailModalTarget) {
      this.closeEmailModal()
    }
  }

  // Update continue button state based on form validity
  updateContinueButton() {
    if (this.hasContinueButtonTarget && this.hasEmailInputTarget && this.hasTermsCheckboxTarget) {
      const emailValid = this.emailInputTarget.validity.valid && this.emailInputTarget.value.trim() !== ''
      const termsAccepted = this.termsCheckboxTarget.checked
      this.continueButtonTarget.disabled = !(emailValid && termsAccepted)

      // Update terms label border color
      if (this.hasTermsLabelTarget) {
        if (termsAccepted) {
          this.termsLabelTarget.classList.add('checked')
        } else {
          this.termsLabelTarget.classList.remove('checked')
        }
      }
    }
  }

  // Handle email input change to update button state
  handleEmailInput() {
    this.updateContinueButton()
  }

  // Submit email form - redirect to registration/login with email pre-filled
  submitEmail(event) {
    event.preventDefault()

    if (this.hasEmailInputTarget && this.hasTermsCheckboxTarget) {
      const email = this.emailInputTarget.value.trim()
      const termsAccepted = this.termsCheckboxTarget.checked

      if (email && termsAccepted) {
        // Store email and home value in sessionStorage for the registration/application flow
        sessionStorage.setItem('gs_email', email)
        sessionStorage.setItem('gs_home_value', this.currentHomeValue)
        sessionStorage.setItem('gs_term', this.currentTerm)

        // Redirect to registration with email pre-filled
        // The registration flow will send OTP verification code
        const encodedEmail = encodeURIComponent(email)
        window.location.href = `/users/sign_up?email=${encodedEmail}`
      }
    }
  }

  // =====================================================
  // MOBILE MENU
  // =====================================================

  // Toggle mobile menu
  toggleMobileMenu() {
    if (this.hasMobileMenuTarget && this.hasMobileOverlayTarget) {
      const isOpen = this.mobileMenuTarget.classList.contains('active')
      if (isOpen) {
        this.closeMobileMenu()
      } else {
        this.openMobileMenu()
      }
    }
  }

  // Open mobile menu
  openMobileMenu() {
    if (this.hasMobileMenuTarget && this.hasMobileOverlayTarget) {
      this.mobileMenuTarget.classList.add('active')
      this.mobileOverlayTarget.classList.add('active')
      document.body.style.overflow = 'hidden'
    }
  }

  // Close mobile menu
  closeMobileMenu() {
    if (this.hasMobileMenuTarget && this.hasMobileOverlayTarget) {
      this.mobileMenuTarget.classList.remove('active')
      this.mobileOverlayTarget.classList.remove('active')
      document.body.style.overflow = ''
    }
  }
}
