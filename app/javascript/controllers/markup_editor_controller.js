import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="markup-editor"
export default class extends Controller {
  static targets = ["editor", "preview", "previewButton"]
  static values = { 
    previewUrl: String,
    legalType: String // 'privacy', 'terms', 'contract'
  }

  connect() {
    this.setupEventListeners()
    this.initializePreview()
  }

  setupEventListeners() {
    if (this.hasEditorTarget) {
      this.editorTarget.addEventListener('input', this.updatePreview.bind(this))
      this.editorTarget.addEventListener('keydown', this.handleKeydown.bind(this))
    }

    if (this.hasPreviewButtonTarget) {
      this.previewButtonTarget.addEventListener('click', this.showFullPreview.bind(this))
    }
  }

  handleKeydown(event) {
    if (event.key === 'Tab') {
      event.preventDefault()
      const start = this.editorTarget.selectionStart
      const end = this.editorTarget.selectionEnd
      this.editorTarget.value = this.editorTarget.value.substring(0, start) + '  ' + this.editorTarget.value.substring(end)
      this.editorTarget.selectionStart = this.editorTarget.selectionEnd = start + 2
      this.updatePreview()
    }
  }

  initializePreview() {
    // Delayed initial update to ensure DOM is ready
    setTimeout(() => {
      this.updatePreview()
    }, 200)
  }

  updatePreview() {
    if (!this.hasEditorTarget || !this.hasPreviewTarget) return

    const htmlContent = this.markupToHtml(this.editorTarget.value)
    this.previewTarget.innerHTML = htmlContent
  }

  markupToHtml(text) {
    if (!text.trim()) {
      return '<p class="preview-note">Content preview will appear here as you type...</p>'
    }

    const lines = text.split('\n')
    let html = ''
    let inList = false
    let currentSection = ''

    lines.forEach(line => {
      const trimmedLine = line.trim()

      if (trimmedLine.startsWith('## ')) {
        if (currentSection) html += '</section>'
        const heading = trimmedLine.replace(/^## /, '')
        html += `<section class="legal-section"><h2>${heading}</h2>`
        currentSection = 'section'
        inList = false
      } else if (trimmedLine.startsWith('### ')) {
        const subheading = trimmedLine.replace(/^### /, '')
        html += `<h3>${subheading}</h3>`
        inList = false
      } else if (trimmedLine.startsWith('- ')) {
        if (!inList) { html += '<ul>'; inList = true }
        const item = trimmedLine.replace(/^- /, '')
        html += `<li>${item.replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>')}</li>`
      } else if (trimmedLine.startsWith('**Contact Info:**')) {
        if (inList) { html += '</ul>'; inList = false }
        html += '<div class="contact-info"><p><strong>Contact Information:</strong><br>'
      } else if (trimmedLine && !trimmedLine.startsWith('Lender:') && !trimmedLine.startsWith('Email:') && !trimmedLine.startsWith('Address:')) {
        if (inList) { html += '</ul>'; inList = false }
        if (trimmedLine) {
          const processedLine = trimmedLine.replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>')
          html += `<p>${processedLine}</p>`
        }
      } else if (trimmedLine.startsWith('Lender:') || trimmedLine.startsWith('Email:') || trimmedLine.startsWith('Address:')) {
        html += `${trimmedLine}<br>`
      }
    })

    if (inList) html += '</ul>'
    if (currentSection) html += '</section>'
    if (!html.includes('<section')) html = `<section class="legal-section">${html}</section>`

    return html
  }

  async showFullPreview(event) {
    event.preventDefault()

    if (!this.hasPreviewUrlValue) {
      console.error('Preview URL not provided')
      return
    }

    const form = this.element.closest('form')
    if (!form) {
      console.error('Form not found')
      return
    }

    const formData = new FormData()
    
    // Get CSRF token
    const csrfToken = document.querySelector('meta[name="csrf-token"]') || 
                     document.querySelector('input[name="authenticity_token"]')
    
    if (csrfToken) {
      formData.append('authenticity_token', 
        csrfToken.getAttribute ? csrfToken.getAttribute('content') : csrfToken.value)
    }

    // Get form data
    const titleInput = form.querySelector('input[name*="[title]"]')
    const contentInput = form.querySelector('textarea[name*="[content]"]')

    if (titleInput && titleInput.value) {
      const fieldName = titleInput.name.match(/\[(\w+)\]\[title\]/)?.[1] || 'document'
      formData.append(`${fieldName}[title]`, titleInput.value)
    }

    if (contentInput && contentInput.value) {
      const fieldName = contentInput.name.match(/\[(\w+)\]\[content\]/)?.[1] || 'document'
      formData.append(`${fieldName}[content]`, contentInput.value)
    }

    try {
      const response = await fetch(this.previewUrlValue, {
        method: 'POST',
        body: formData
      })

      if (response.ok) {
        const html = await response.text()
        const previewWindow = window.open('', '_blank', 'width=1200,height=800,scrollbars=yes')
        previewWindow.document.open()
        previewWindow.document.write(html)
        previewWindow.document.close()
      } else {
        throw new Error(`HTTP error! status: ${response.status}`)
      }
    } catch (error) {
      console.error('Preview error:', error)
      alert('Failed to open preview. Please try again.')
    }
  }
}