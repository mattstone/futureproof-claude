import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="clause-preview"
export default class extends Controller {
  static targets = ["content", "preview"]

  connect() {
    // Initial preview update with delay for smooth loading
    this.previewTarget.innerHTML = '<p class="preview-note">Loading preview...</p>'
    setTimeout(() => {
      this.previewTarget.innerHTML = this.markupToHtml(this.contentTarget.value)
    }, 200)

    // Set up event listeners
    this.contentTarget.addEventListener('input', this.updatePreviewInstant.bind(this))
    this.contentTarget.addEventListener('keydown', this.handleKeydown.bind(this))
  }

  // Instant update function for user input - NO FLICKER VERSION
  updatePreviewInstant() {
    const htmlContent = this.markupToHtml(this.contentTarget.value)
    this.previewTarget.innerHTML = htmlContent
  }

  handleKeydown(e) {
    if (e.key === 'Tab') {
      e.preventDefault()
      const start = this.contentTarget.selectionStart
      const end = this.contentTarget.selectionEnd
      this.contentTarget.value = this.contentTarget.value.substring(0, start) + '  ' + this.contentTarget.value.substring(end)
      this.contentTarget.selectionStart = this.contentTarget.selectionEnd = start + 2
      this.updatePreviewInstant()
    }
  }

  markupToHtml(text) {
    if (!text.trim()) {
      return '<p class="preview-note">Clause preview will appear here as you type...</p>'
    }
    
    // Substitute placeholders with sample data for preview
    const sampleSubstitutions = {
      'lender_name': this.data.get('lenderName') || 'Sample Lender',
      'primary_user_full_name': 'John Smith',
      'primary_user_address': '123 Main Street, Melbourne VIC 3000',
      'contract_start_date': new Date().toLocaleDateString('en-US', { year: 'numeric', month: 'long', day: 'numeric' })
    }
    
    // Apply substitutions
    let substitutedText = text
    Object.keys(sampleSubstitutions).forEach(key => {
      const regex = new RegExp(`{{${key}}}`, 'g')
      substitutedText = substitutedText.replace(regex, sampleSubstitutions[key])
    })
    
    // Split into sections first
    const sections = substitutedText.split(/^## /).filter(s => s.trim())
    let htmlParts = []
    
    sections.forEach(sectionText => {
      const sectionLines = sectionText.split('\n')
      const title = sectionLines[0]?.trim()
      const contentLines = sectionLines.slice(1) || []
      
      htmlParts.push('<section class="legal-section">')
      
      // Add section title
      if (title && title.length > 0) {
        htmlParts.push(`  <h2>${this.sanitizeText(title)}</h2>`)
      }
      
      // Process content lines
      let inList = false
      let inContact = false
      let inDetails = false
      
      contentLines.forEach(line => {
        line = line.trim()
        if (!line) return
        
        // Handle subsections
        if (line.match(/^### (.+)$/)) {
          // Close any open structures
          if (inList) {
            htmlParts.push('  </ul>')
            inList = false
          }
          if (inDetails) {
            htmlParts.push('  </div>')
            inDetails = false
          }
          
          const subtitle = line.replace(/^### /, '').trim()
          htmlParts.push(`  <h3>${this.sanitizeText(subtitle)}</h3>`)
          
        // Handle bullet points
        } else if (line.match(/^- (.+)$/)) {
          if (!inList) {
            htmlParts.push('  <ul>')
            inList = true
          }
          const item = line.replace(/^- /, '').trim()
          htmlParts.push(`    <li>${this.sanitizeText(item).replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>')}</li>`)
          
        // Handle loan details pattern
        } else if (line.match(/^\*\*(.+):\*\* (.+)$/)) {
          if (!inDetails) {
            htmlParts.push('  <div class="loan-details">')
            inDetails = true
          }
          const field = line.match(/^\*\*(.+):\*\*/)[1].trim()
          const value = line.replace(/^\*\*(.+):\*\* /, '').trim()
          htmlParts.push('    <div class="detail-row">')
          htmlParts.push(`      <strong>${this.sanitizeText(field)}:</strong>`)
          htmlParts.push(`      <span>${this.sanitizeText(value)}</span>`)
          htmlParts.push('    </div>')
          
        // Handle contact info pattern  
        } else if (line.match(/^(Lender|Email|Phone|Address): (.+)$/)) {
          if (!inContact) {
            if (inDetails) {
              htmlParts.push('  </div>')
              inDetails = false
            }
            htmlParts.push('  <div class="contact-info">')
            inContact = true
          }
          const parts = line.split(': ')
          const field = parts[0]
          const value = parts.slice(1).join(': ').trim()
          if (field === 'Lender') {
            htmlParts.push(`    <p><strong>${this.sanitizeText(value)}</strong></p>`)
          } else {
            htmlParts.push(`    <p>${this.sanitizeText(field)}: ${this.sanitizeText(value)}</p>`)
          }
          
        // Handle regular paragraphs
        } else {
          // Close any open structures
          if (inList) {
            htmlParts.push('  </ul>')
            inList = false
          }
          if (inDetails) {
            htmlParts.push('  </div>')
            inDetails = false
          }
          if (inContact) {
            htmlParts.push('  </div>')
            inContact = false
          }
          
          // Process **bold** text
          const processedLine = line.replace(/\*\*(.+?)\*\*/g, (match, p1) => `<strong>${this.sanitizeText(p1)}</strong>`)
          htmlParts.push(`  <p>${processedLine}</p>`)
        }
      })
      
      // Close any open structures
      if (inList) {
        htmlParts.push('  </ul>')
      }
      if (inDetails) {
        htmlParts.push('  </div>')
      }
      if (inContact) {
        htmlParts.push('  </div>')
      }
      
      htmlParts.push('</section>')
    })
    
    return htmlParts.join('\n')
  }
  
  sanitizeText(text) {
    if (!text) return ''
    // Allow only safe characters, preserve special symbols
    return text.toString().replace(/[<>"]/g, '').trim()
  }
}