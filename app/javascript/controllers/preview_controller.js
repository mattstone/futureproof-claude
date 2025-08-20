import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="preview"
export default class extends Controller {
  static targets = ["button"]
  static values = { 
    previewUrl: String,
    formSelector: String
  }

  connect() {
    this.setupEventListeners()
  }

  setupEventListeners() {
    if (this.hasButtonTarget) {
      this.buttonTarget.addEventListener('click', this.openPreview.bind(this))
    }
  }

  async openPreview(event) {
    event.preventDefault()

    const form = this.formSelectorValue ? 
      document.querySelector(this.formSelectorValue) : 
      this.element.closest('form')

    if (!form) {
      console.error('Form not found')
      return
    }

    try {
      const formData = new FormData()
      
      // Get CSRF token
      const csrfToken = document.querySelector('meta[name="csrf-token"]')
      if (csrfToken) {
        formData.append('authenticity_token', csrfToken.getAttribute('content'))
      }

      // Get all form inputs
      const inputs = form.querySelectorAll('input, textarea, select')
      inputs.forEach(input => {
        if (input.name && input.value && input.type !== 'submit' && input.type !== 'button') {
          formData.append(input.name, input.value)
        }
      })

      const previewWindow = window.open('', '_blank', 'width=1200,height=800,scrollbars=yes')
      previewWindow.document.write('<html><body><h3>Loading preview...</h3></body></html>')

      const response = await fetch(this.previewUrlValue, {
        method: 'POST',
        body: formData
      })

      if (response.ok) {
        const html = await response.text()
        previewWindow.document.open()
        previewWindow.document.write(html)
        previewWindow.document.close()
      } else {
        throw new Error(`HTTP error! status: ${response.status}`)
      }
    } catch (error) {
      console.error('Preview error:', error)
      if (previewWindow) {
        previewWindow.document.write('<html><body><h3>Error loading preview</h3><p>' + error + '</p></body></html>')
      }
    }
  }
}