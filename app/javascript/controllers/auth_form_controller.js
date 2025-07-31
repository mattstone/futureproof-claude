import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "title", "subtitle", 
    "registrationForm", "loginForm", 
    "emailInput", "loginEmailInput", "emailStatus",
    "toggleToLogin", "toggleToRegister",
    "linkSeparator", "createAccountLink"
  ]

  connect() {
    this.showRegistration()
    this.checkForEmailTakenError()
  }

  async checkEmail() {
    const email = this.emailInputTarget.value.trim()
    
    if (!email || !this.isValidEmail(email)) {
      this.clearEmailStatus()
      return
    }

    try {
      const response = await fetch(`/api/check_email?email=${encodeURIComponent(email)}`)
      const data = await response.json()
      
      if (data.exists) {
        this.showEmailExistsMessage()
      } else {
        this.showEmailAvailableMessage()
      }
    } catch (error) {
      console.error('Error checking email:', error)
      this.clearEmailStatus()
    }
  }

  showLogin() {
    // Update title and subtitle
    this.titleTarget.textContent = "Welcome Back"
    this.subtitleTarget.textContent = "Sign in to your Equity Preservation Mortgage® account"
    
    // Hide registration form, show login form
    this.registrationFormTarget.style.display = "none"
    this.loginFormTarget.style.display = "block"
    
    // Update toggle links
    this.toggleToLoginTarget.style.display = "none"
    this.toggleToRegisterTarget.style.display = "block"
    
    // Show create account link next to forgot password
    if (this.hasLinkSeparatorTarget) {
      this.linkSeparatorTarget.style.display = "inline"
    }
    if (this.hasCreateAccountLinkTarget) {
      this.createAccountLinkTarget.style.display = "inline"
    }
    
    // Clear email status
    this.clearEmailStatus()
    
    // Copy email from registration to login if present
    if (this.emailInputTarget.value) {
      this.loginEmailInputTarget.value = this.emailInputTarget.value
    }
  }

  showRegistration() {
    // Update title and subtitle
    this.titleTarget.textContent = "Create Account"
    this.subtitleTarget.textContent = "Start your journey with Equity Preservation Mortgage®"
    
    // Show registration form, hide login form
    this.registrationFormTarget.style.display = "block"
    this.loginFormTarget.style.display = "none"
    
    // Update toggle links
    this.toggleToLoginTarget.style.display = "block"
    this.toggleToRegisterTarget.style.display = "none"
    
    // Hide create account link (only show when in login mode)
    if (this.hasLinkSeparatorTarget) {
      this.linkSeparatorTarget.style.display = "none"
    }
    if (this.hasCreateAccountLinkTarget) {
      this.createAccountLinkTarget.style.display = "none"
    }
    
    // Copy email from login to registration if present
    if (this.hasLoginEmailInputTarget && this.loginEmailInputTarget.value) {
      this.emailInputTarget.value = this.loginEmailInputTarget.value
    }
  }

  showEmailExistsMessage() {
    this.emailStatusTarget.innerHTML = `
      <div class="email-status-message email-exists">
        <span class="status-icon">ℹ️</span>
        <span class="status-text">This email is already registered. 
          <button type="button" class="status-link" data-action="click->auth-form#showLogin">Sign in instead?</button>
        </span>
      </div>
    `
    this.toggleToLoginTarget.style.display = "block"
  }

  showEmailAvailableMessage() {
    this.emailStatusTarget.innerHTML = `
      <div class="email-status-message email-available">
        <span class="status-icon">✅</span>
        <span class="status-text">Email available for registration</span>
      </div>
    `
  }

  clearEmailStatus() {
    if (this.hasEmailStatusTarget) {
      this.emailStatusTarget.innerHTML = ""
    }
  }

  isValidEmail(email) {
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
    return emailRegex.test(email)
  }

  checkForEmailTakenError() {
    // Check if there's an error message indicating email is already taken
    const errorElement = document.querySelector('.alert-danger')
    if (errorElement) {
      const errorText = errorElement.textContent || errorElement.innerText
      if (errorText.includes('Email has already been taken') || 
          errorText.includes('email has already been taken') ||
          errorText.includes('has already been taken')) {
        // Extract email from form if available
        const emailValue = this.emailInputTarget.value
        if (emailValue) {
          // Hide the error message since we're handling it
          errorElement.style.display = 'none'
          
          // Switch to login form
          this.showLogin()
          
          // Show a helpful message
          this.showEmailTakenSwitchMessage(emailValue)
        }
      }
    }
  }

  showEmailTakenSwitchMessage(email) {
    this.emailStatusTarget.innerHTML = `
      <div class="email-status-message email-exists">
        <span class="status-icon">ℹ️</span>
        <span class="status-text">This email is already registered. Please sign in with your existing account.</span>
      </div>
    `
  }
}