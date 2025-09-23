import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["overlay", "content"]

  connect() {
    // Initialize modal as hidden
    this.close()
    
    // Set up button state management
    this.setupButtonStates()
    
    // Listen for checkbox changes
    const checkbox = this.getTermsCheckbox()
    if (checkbox) {
      checkbox.addEventListener('change', () => this.updateButtonState())
      // Initial state
      this.updateButtonState()
    }
  }

  open(event) {
    event.preventDefault()
    this.loadTerms()
    this.overlayTarget.style.display = "flex"
    document.body.style.overflow = "hidden"
  }

  close() {
    if (this.hasOverlayTarget) {
      this.overlayTarget.style.display = "none"
    }
    document.body.style.overflow = "auto"
  }

  accept() {
    // Check the terms acceptance checkbox
    const checkbox = this.getTermsCheckbox()
    if (checkbox) {
      checkbox.checked = true
      // Trigger change event for any validation
      checkbox.dispatchEvent(new Event('change', { bubbles: true }))
      this.updateButtonState()
    }
    this.close()
  }

  stopPropagation(event) {
    event.stopPropagation()
  }

  getTermsCheckbox() {
    return document.querySelector('input[name="user[terms_accepted]"][type="checkbox"]')
  }

  getSubmitButton() {
    return document.querySelector('input[type="submit"][value="Create Account"], button[type="submit"]')
  }

  setupButtonStates() {
    const submitButton = this.getSubmitButton()
    if (submitButton) {
      submitButton.style.transition = "opacity 0.3s ease, background-color 0.3s ease"
    }
  }

  updateButtonState() {
    const checkbox = this.getTermsCheckbox()
    const submitButton = this.getSubmitButton()

    if (checkbox && submitButton) {
      if (checkbox.checked) {
        // Enable the button and remove disabled styling
        submitButton.disabled = false
        submitButton.classList.remove('site-btn-disabled')
        submitButton.style.opacity = ""  // Clear inline opacity to let CSS take over
        submitButton.style.cursor = ""   // Clear inline cursor to let CSS take over
      } else {
        // Disable the button and add disabled styling
        submitButton.disabled = true
        submitButton.classList.add('site-btn-disabled')
        submitButton.style.opacity = ""  // Clear inline opacity to let CSS take over
        submitButton.style.cursor = ""   // Clear inline cursor to let CSS take over
      }
    }
  }

  async loadTerms() {
    try {
      this.contentTarget.innerHTML = '<div class="loading-spinner">Loading terms...</div>'
      
      const response = await fetch('/terms-and-conditions', {
        headers: {
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Cache-Control': 'no-cache'
        }
      })
      
      if (!response.ok) {
        throw new Error(`Failed to load terms: ${response.status}`)
      }
      
      const html = await response.text()
      
      // Extract just the legal content from the response
      const parser = new DOMParser()
      const doc = parser.parseFromString(html, 'text/html')
      
      // Try multiple selectors for content
      let content = doc.querySelector('.legal-content')
      
      if (!content) {
        content = doc.querySelector('.legal-container') ||
                 doc.querySelector('.container') ||
                 doc.querySelector('main') ||
                 doc.querySelector('[class*="legal"]') ||
                 doc.querySelector('body')
      }
      
      if (content) {
        // If we got the legal-content div, use its innerHTML
        // Otherwise, try to extract just the meaningful content
        if (content.classList.contains('legal-content')) {
          this.contentTarget.innerHTML = content.innerHTML
        } else {
          // Try to find the title and content within the container
          const title = content.querySelector('h1')
          const contentDiv = content.querySelector('.legal-content') || content
          
          let finalContent = ''
          if (title) {
            finalContent += `<h1>${title.textContent}</h1>`
          }
          
          if (contentDiv && contentDiv !== title) {
            finalContent += contentDiv.innerHTML
          } else {
            // Fallback: just show some basic terms text
            finalContent += `
              <h2>Terms and Conditions</h2>
              <p>By creating an account and using our services, you agree to our terms and conditions.</p>
              <p>For the complete terms, please <a href="/terms-and-conditions" target="_blank">visit our full Terms and Conditions page</a>.</p>
            `
          }
          
          this.contentTarget.innerHTML = finalContent
        }
      } else {
        throw new Error("No content found")
      }
    } catch (error) {
      this.contentTarget.innerHTML = `
        <div class="error-message">
          <h3>Terms and Conditions</h3>
          <p>By creating an account, you agree to our terms and conditions.</p>
          <p>Sorry, we couldn't load the full terms at this time.</p>
          <p>Please <a href="/terms-and-conditions" target="_blank">click here to view them in a new tab</a>.</p>
        </div>
      `
    }
  }
}