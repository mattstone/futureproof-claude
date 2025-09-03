import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="email-template-editor"
export default class extends Controller {
  static targets = [ 
    "templateType", "fieldHelper", "fieldHelperContent", "toggleFieldHelper",
    "htmlContent", "markupContent", "richContent", "subject", "subjectPreview", "contentPreview",
    "htmlSection", "markupSection", "richSection", "htmlTab", "markupTab", "richTab", "refreshBtn", "toggleSampleBtn"
  ]
  
  static values = { 
    useSampleData: Boolean, 
    currentEditorMode: String,
    ajaxUrl: String
  }

  connect() {
    console.log("Email template editor controller connected")
    this.useSampleDataValue = true  // Default to showing sample data
    this.currentEditorModeValue = 'rich'  // Default to rich text editor
    this.ajaxUrlValue = '/admin/email_templates/preview_ajax'
    
    // Set initial button text and style for sample data (enabled by default)
    if (this.hasToggleSampleBtnTarget) {
      this.toggleSampleBtnTarget.textContent = 'Hide Sample Data'
      this.toggleSampleBtnTarget.classList.add('admin-btn-success')
    }
    
    // Initialize the preview
    this.updatePreview()
    if (this.templateTypeTarget.value) {
      this.updateFieldHelper()
    }
  }

  // Sample data for preview
  get sampleData() {
    return {
      'verification': {
        user: { first_name: 'John', last_name: 'Smith', full_name: 'John Smith', email: 'john.smith@example.com' },
        verification: { verification_code: '123456', formatted_expires_at: '11:30 PM' }
      },
      'application_submitted': {
        user: { first_name: 'Sarah', last_name: 'Johnson', full_name: 'Sarah Johnson', email: 'sarah.johnson@example.com' },
        application: { 
          id: '12345', reference_number: '000123', address: '123 Main Street, Sydney NSW 2000',
          formatted_home_value: '$1,500,000', formatted_loan_value: '$900,000', loan_term: '25'
        },
        mortgage: { name: 'Premium Equity Mortgage', lvr: '60', interest_rate: '7.45' }
      },
      'security_notification': {
        user: { first_name: 'Michael', full_name: 'Michael Brown', email: 'michael.brown@example.com' },
        security: { 
          browser_info: 'Chrome on macOS', ip_address: '192.168.1.100', 
          location: 'Sydney, Australia', sign_in_time: 'December 5, 2024 at 2:30 PM' 
        }
      }
    }
  }

  // Available fields for each template type
  get availableFields() {
    return {
      'verification': {
        'user': ['first_name', 'last_name', 'full_name', 'email', 'mobile_number', 'country_of_residence'],
        'verification': ['verification_code', 'expires_at', 'formatted_expires_at']
      },
      'application_submitted': {
        'user': ['first_name', 'last_name', 'full_name', 'email', 'mobile_number'],
        'application': ['id', 'reference_number', 'address', 'home_value', 'formatted_home_value', 'existing_mortgage_amount', 'formatted_existing_mortgage_amount', 'loan_value', 'formatted_loan_value', 'borrower_age', 'loan_term', 'growth_rate', 'formatted_growth_rate', 'future_property_value', 'formatted_future_property_value', 'home_equity_preserved', 'formatted_home_equity_preserved', 'status', 'status_display', 'created_at', 'updated_at', 'submitted_at', 'formatted_created_at', 'formatted_updated_at', 'formatted_submitted_at'],
        'mortgage': ['name', 'lvr', 'interest_rate', 'mortgage_type_display']
      },
      'security_notification': {
        'user': ['first_name', 'last_name', 'full_name', 'email'],
        'security': ['browser_info', 'ip_address', 'location', 'sign_in_time']
      }
    }
  }

  // Switch between Rich Text, HTML and Markup editors
  switchToRich(event) {
    event.preventDefault()
    this.switchEditorMode('rich')
  }

  switchToHtml(event) {
    event.preventDefault()
    this.switchEditorMode('html')
  }

  switchToMarkup(event) {
    event.preventDefault()
    this.switchEditorMode('markup')
  }

  switchEditorMode(mode) {
    // Hide all sections first
    this.richSectionTarget.style.display = 'none'
    this.htmlSectionTarget.style.display = 'none'
    this.markupSectionTarget.style.display = 'none'
    
    // Remove active class from all tabs
    this.richTabTarget.classList.remove('active')
    this.htmlTabTarget.classList.remove('active')
    this.markupTabTarget.classList.remove('active')
    
    // Show the selected section and activate its tab
    if (mode === 'rich') {
      this.richSectionTarget.style.display = 'block'
      this.richTabTarget.classList.add('active')
      this.currentEditorModeValue = 'rich'
    } else if (mode === 'html') {
      this.htmlSectionTarget.style.display = 'block'
      this.htmlTabTarget.classList.add('active')
      this.currentEditorModeValue = 'html'
    } else if (mode === 'markup') {
      this.markupSectionTarget.style.display = 'block'
      this.markupTabTarget.classList.add('active')
      this.currentEditorModeValue = 'markup'
    }
    
    this.updatePreview()
  }

  // Convert markup to HTML (similar to terms system)
  markupToHtml(text) {
    if (!text) return ''
    
    let html = text
    
    // Convert line breaks to paragraph breaks
    html = html.replace(/\n\n+/g, '</p><p>')
    html = '<p>' + html + '</p>'
    
    // Convert headers
    html = html.replace(/<p>## (.+?)<\/p>/g, '<h2 style="color: #0891b2; font-size: 20px; margin: 24px 0 16px 0;">$1</h2>')
    html = html.replace(/<p>### (.+?)<\/p>/g, '<h3 style="color: #374151; font-size: 16px; margin: 20px 0 12px 0;">$1</h3>')
    
    // Convert bold and italic
    html = html.replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>')
    html = html.replace(/\*(.+?)\*/g, '<em>$1</em>')
    
    // Convert bullet points
    html = html.replace(/<p>- (.+?)<\/p>/g, '<li>$1</li>')
    html = html.replace(/(<li>.*<\/li>)/gs, '<ul style="margin: 16px 0; padding-left: 24px;">$1</ul>')
    
    // Clean up empty paragraphs
    html = html.replace(/<p><\/p>/g, '')
    html = html.replace(/<p>\s*<\/p>/g, '')
    
    return html
  }

  // Update preview
  updatePreview() {
    const templateType = this.templateTypeTarget.value
    let content = ''
    let subject = this.hasSubjectTarget ? this.subjectTarget.value : ''
    
    if (this.currentEditorModeValue === 'rich') {
      // Get content from TinyMCE if available
      const tinymceElement = this.richSectionTarget.querySelector('[data-tinymce-target="editor"]')
      if (window.tinymce && tinymce.get(tinymceElement.id)) {
        content = tinymce.get(tinymceElement.id).getContent()
      } else {
        content = this.richContentTarget.value
      }
    } else if (this.currentEditorModeValue === 'html') {
      content = this.htmlContentTarget.value
    } else {
      content = this.markupToHtml(this.markupContentTarget.value)
    }
    
    // If we have content and template type, make AJAX call for server-side rendering
    if (content.trim() && templateType) {
      const formData = new FormData()
      formData.append('template_type', templateType)
      formData.append('content', content)
      formData.append('subject', subject)
      formData.append('use_sample_data', this.useSampleDataValue)
      
      fetch(this.ajaxUrlValue, {
        method: 'POST',
        headers: {
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').getAttribute('content')
        },
        body: formData
      })
      .then(response => response.json())
      .then(data => {
        if (data.error) {
          console.error('Preview error:', data.error)
          this.setFallbackPreview(subject, content)
        } else {
          this.subjectPreviewTarget.textContent = data.subject || 'No subject entered'
          this.contentPreviewTarget.innerHTML = data.content || '<p class="text-muted">No content entered</p>'
        }
      })
      .catch(error => {
        console.error('Preview error:', error)
        this.setFallbackPreview(subject, content)
      })
    } else {
      this.setFallbackPreview(subject, content)
    }
  }

  setFallbackPreview(subject, content) {
    this.subjectPreviewTarget.textContent = subject || 'No subject entered'
    this.contentPreviewTarget.innerHTML = content || '<p class="text-muted">No content entered</p>'
  }

  updateFieldHelper() {
    const selectedType = this.templateTypeTarget.value
    const fields = this.availableFields[selectedType]
    
    if (!fields) {
      this.fieldHelperContentTarget.innerHTML = '<p class="text-muted">Select a template type to see available fields</p>'
      return
    }
    
    let html = '<div class="field-groups">'
    
    Object.keys(fields).forEach(groupName => {
      html += '<div class="field-group" style="margin-bottom: 16px;">'
      html += '<h5 style="margin: 0 0 8px 0; color: #0891b2; text-transform: capitalize;">' + groupName + ' Fields:</h5>'
      html += '<div class="field-tags" style="display: flex; flex-wrap: wrap; gap: 6px;">'
      
      fields[groupName].forEach(field => {
        const placeholder = '{{' + groupName + '.' + field + '}}'
        html += '<span class="field-tag" data-action="click->email-template-editor#insertField" data-placeholder="' + placeholder + '" style="'
        html += 'cursor: pointer; background: #e0f2fe; border: 1px solid #0891b2; border-radius: 4px; '
        html += 'padding: 4px 8px; font-size: 12px; font-family: monospace; color: #0891b2;" '
        html += 'title="Click to insert">' + placeholder + '</span>'
      })
      
      html += '</div></div>'
    })
    
    html += '</div>'
    html += '<p style="margin-top: 16px; font-size: 12px; color: #6b7280;"><strong>Tip:</strong> Click on any field to insert it at your cursor position in the content editor.</p>'
    
    this.fieldHelperContentTarget.innerHTML = html
  }

  // Insert field at cursor position
  insertField(event) {
    const placeholder = event.target.dataset.placeholder
    const activeTextarea = this.currentEditorModeValue === 'html' ? this.htmlContentTarget : this.markupContentTarget
    const start = activeTextarea.selectionStart
    const end = activeTextarea.selectionEnd
    const text = activeTextarea.value
    
    activeTextarea.value = text.substring(0, start) + placeholder + text.substring(end)
    activeTextarea.focus()
    activeTextarea.setSelectionRange(start + placeholder.length, start + placeholder.length)
    this.updatePreview()
  }

  // Event handlers
  templateTypeChanged() {
    if (this.fieldHelperContentTarget.style.display !== 'none') {
      this.updateFieldHelper()
    }
    this.updatePreview()
  }

  contentChanged() {
    this.updatePreview()
  }

  subjectChanged() {
    this.updatePreview()
  }

  toggleFieldHelper(event) {
    event.preventDefault()
    const content = this.fieldHelperContentTarget
    if (content.style.display === 'none') {
      content.style.display = 'block'
      this.toggleFieldHelperTarget.textContent = 'Hide Fields'
      this.updateFieldHelper()
    } else {
      content.style.display = 'none'
      this.toggleFieldHelperTarget.textContent = 'Show Fields'
    }
  }

  refreshPreview(event) {
    event.preventDefault()
    this.updatePreview()
  }

  toggleSampleData(event) {
    event.preventDefault()
    this.useSampleDataValue = !this.useSampleDataValue
    this.toggleSampleBtnTarget.textContent = this.useSampleDataValue ? 'Hide Sample Data' : 'Show Sample Data'
    this.toggleSampleBtnTarget.classList.toggle('admin-btn-success', this.useSampleDataValue)
    this.updatePreview()
  }

  // Before form submission, sync markup content to HTML content if in markup mode
  formSubmit(event) {
    if (this.currentEditorModeValue === 'markup' && this.markupContentTarget.value) {
      this.htmlContentTarget.value = this.markupToHtml(this.markupContentTarget.value)
    }
  }
}