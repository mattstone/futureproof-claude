import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="messaging"
export default class extends Controller {
  static targets = ["subjectInput", "contentInput", "agentSelect", "preview", "previewSubject", "previewContent", 
                   "agentPreview", "previewAgentHeader", "previewAgentName", "previewAgentRole", 
                   "previewAgentAvatar", "previewAgentFallback"]
  
  static values = { 
    resourceType: String,
    resourceData: Object,
    aiAgentData: Array 
  }

  connect() {
    this.setupEventListeners()
    this.initializeForm()
  }

  setupEventListeners() {
    if (this.hasSubjectInputTarget) {
      this.subjectInputTarget.addEventListener('input', this.updatePreview.bind(this))
    }

    if (this.hasContentInputTarget) {
      this.contentInputTarget.addEventListener('input', this.updatePreview.bind(this))
    }

    if (this.hasAgentSelectTarget && this.agentSelectTarget.value) {
      this.updateAgentPreview({ target: this.agentSelectTarget })
    }
  }

  initializeForm() {
    this.updatePreview()
  }

  // Handle agent selection change
  agentChanged(event) {
    this.updateAgentPreview(event)
  }

  // Field insertion helpers
  insertField(event) {
    const fieldValue = event.target.dataset.fieldValue
    if (!this.hasContentInputTarget || !fieldValue) return

    const contentInput = this.contentInputTarget
    const start = contentInput.selectionStart
    const end = contentInput.selectionEnd
    const text = contentInput.value

    contentInput.value = text.substring(0, start) + fieldValue + text.substring(end)
    contentInput.focus()
    contentInput.setSelectionRange(start + fieldValue.length, start + fieldValue.length)

    this.updatePreview()
  }

  // Markup application helpers
  applyBold(event) {
    this.applyMarkup('**', '**')
  }

  applyItalic(event) {
    this.applyMarkup('*', '*')
  }

  applyBulletPoint(event) {
    this.applyMarkup('- ', '')
  }

  applyNumberedList(event) {
    this.applyMarkup('1. ', '')
  }

  insertLineBreak(event) {
    if (!this.hasContentInputTarget) return

    const contentInput = this.contentInputTarget
    const start = contentInput.selectionStart
    const end = contentInput.selectionEnd
    const text = contentInput.value

    contentInput.value = text.substring(0, start) + '\n' + text.substring(end)
    contentInput.focus()
    contentInput.setSelectionRange(start + 1, start + 1)

    this.updatePreview()
  }

  applyMarkup(openTag, closeTag) {
    if (!this.hasContentInputTarget) return

    const contentInput = this.contentInputTarget
    const start = contentInput.selectionStart
    const end = contentInput.selectionEnd
    const selectedText = contentInput.value.substring(start, end)
    const text = contentInput.value

    if (selectedText) {
      const replacement = openTag + selectedText + closeTag
      contentInput.value = text.substring(0, start) + replacement + text.substring(end)
      contentInput.focus()
      contentInput.setSelectionRange(start + openTag.length, start + openTag.length + selectedText.length)
    } else {
      const insertion = openTag + closeTag
      contentInput.value = text.substring(0, start) + insertion + text.substring(end)
      contentInput.focus()
      contentInput.setSelectionRange(start + openTag.length, start + openTag.length)
    }

    this.updatePreview()
  }

  // Template variable processing
  processTemplateVariables(text, resourceData = this.resourceDataValue) {
    let processed = text

    // User variables
    if (resourceData.user) {
      processed = processed.replace(/\{\{user\.first_name\}\}/gi, resourceData.user.firstName || '[First Name]')
      processed = processed.replace(/\{\{user\.last_name\}\}/gi, resourceData.user.lastName || '[Last Name]')
      processed = processed.replace(/\{\{user\.email\}\}/gi, resourceData.user.email || '[Email]')
    }

    if (this.resourceTypeValue === 'application') {
      // Application-specific variables
      processed = processed.replace(/\{\{application\.id\}\}/gi, resourceData.id || '[ID]')
      processed = processed.replace(/\{\{application\.address\}\}/gi, resourceData.address || '[Address]')
      processed = processed.replace(/\{\{application\.status_display\}\}/gi, resourceData.statusDisplay || '[Status]')
      processed = processed.replace(/\{\{application\.formatted_home_value\}\}/gi, resourceData.formattedHomeValue || '[Home Value]')
    } else if (this.resourceTypeValue === 'contract') {
      // Contract-specific variables
      processed = processed.replace(/\{\{contract\.id\}\}/gi, resourceData.id || '[ID]')
      processed = processed.replace(/\{\{contract\.status_display\}\}/gi, resourceData.statusDisplay || '[Status]')
      processed = processed.replace(/\{\{contract\.start_date\}\}/gi, resourceData.startDate || '[Start Date]')
      processed = processed.replace(/\{\{contract\.end_date\}\}/gi, resourceData.endDate || '[End Date]')

      // Application variables (through contract)
      if (resourceData.application) {
        processed = processed.replace(/\{\{application\.address\}\}/gi, resourceData.application.address || '[Address]')
        processed = processed.replace(/\{\{application\.formatted_home_value\}\}/gi, resourceData.application.formattedHomeValue || '[Home Value]')
      }
    }

    return processed
  }

  // Markup to HTML conversion
  markupToHtml(text) {
    let html = text

    // Bold text
    html = html.replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>')

    // Italic text
    html = html.replace(/\*(.*?)\*/g, '<em>$1</em>')

    // Bullet points
    html = html.replace(/^- (.+)$/gm, '<li>$1</li>')
    html = html.replace(/(<li>.*<\/li>)/s, '<ul>$1</ul>')

    // Numbered lists
    html = html.replace(/^\d+\. (.+)$/gm, '<li>$1</li>')

    // Line breaks
    html = html.replace(/\n/g, '<br>')

    return html
  }

  // Update preview when content changes
  updatePreview() {
    if (!this.hasSubjectInputTarget || !this.hasContentInputTarget) return

    const subject = this.subjectInputTarget.value
    const content = this.contentInputTarget.value

    // Process template variables
    const processedSubject = this.processTemplateVariables(subject)
    const processedContent = this.processTemplateVariables(content)

    // Convert markup to HTML
    const contentHtml = this.markupToHtml(processedContent)

    // Update preview
    if (this.hasPreviewSubjectTarget) {
      this.previewSubjectTarget.textContent = processedSubject || 'Enter a subject above'
    }

    if (this.hasPreviewContentTarget) {
      if (contentHtml.trim()) {
        this.previewContentTarget.innerHTML = contentHtml
      } else {
        this.previewContentTarget.innerHTML = '<p>Type your message content above to see the preview...</p>'
      }
    }
  }

  // Update agent preview
  updateAgentPreview(event) {
    const agentId = parseInt(event.target.value)
    const agent = this.aiAgentDataValue.find(a => a.id === agentId)

    if (this.hasAgentPreviewTarget) {
      if (!agent) {
        this.agentPreviewTarget.classList.remove('visible')
        this.agentPreviewTarget.style.display = 'none'
        this.updateEmailAgentPreview(null)
        return
      }

      this.agentPreviewTarget.classList.add('visible')
      this.agentPreviewTarget.style.display = 'block'

      // Update agent info in selection area
      const agentName = this.agentPreviewTarget.querySelector('.agent-name')
      const agentRole = this.agentPreviewTarget.querySelector('.agent-role')
      const agentSpecialties = this.agentPreviewTarget.querySelector('.agent-specialties')
      const agentAvatar = this.agentPreviewTarget.querySelector('.agent-avatar')

      if (agentName) agentName.textContent = agent.displayName || agent.name
      if (agentRole) agentRole.textContent = agent.roleDescription
      if (agentSpecialties) agentSpecialties.textContent = `Specialties: ${agent.specialties || 'General assistance'}`

      // Update avatar
      if (agentAvatar && agent.avatarPath) {
        if (agentAvatar.tagName === 'IMG') {
          agentAvatar.src = agent.avatarPath
          agentAvatar.alt = `${agent.name} Avatar`
        }
      }
    }

    // Update email preview
    this.updateEmailAgentPreview(agent)
  }

  // Update agent in email preview
  updateEmailAgentPreview(agent) {
    if (!this.hasPreviewAgentHeaderTarget) return

    if (!agent) {
      this.previewAgentHeaderTarget.style.display = 'none'
      return
    }

    this.previewAgentHeaderTarget.style.display = 'block'

    if (this.hasPreviewAgentNameTarget) {
      this.previewAgentNameTarget.textContent = agent.displayName || agent.name
    }
    if (this.hasPreviewAgentRoleTarget) {
      this.previewAgentRoleTarget.textContent = agent.roleDescription
    }

    // Handle avatar
    if (agent.avatarPath && this.hasPreviewAgentAvatarTarget && this.hasPreviewAgentFallbackTarget) {
      this.previewAgentAvatarTarget.src = agent.avatarPath
      this.previewAgentAvatarTarget.classList.add('visible')
      this.previewAgentAvatarTarget.style.display = 'block'
      this.previewAgentFallbackTarget.style.display = 'none'
    } else if (this.hasPreviewAgentFallbackTarget) {
      if (this.hasPreviewAgentAvatarTarget) {
        this.previewAgentAvatarTarget.classList.remove('visible')
        this.previewAgentAvatarTarget.style.display = 'none'
      }
      this.previewAgentFallbackTarget.style.display = 'flex'
      this.previewAgentFallbackTarget.textContent = agent.name ? agent.name.charAt(0).toUpperCase() : '🤖'
    }
  }

  // Handle Turbo events for re-initialization
  handleTurboStreamConnected() {
    setTimeout(() => this.initializeForm(), 50)
  }

  handleTurboMorph() {
    setTimeout(() => this.initializeForm(), 50)
  }

  handleTurboRender() {
    setTimeout(() => this.initializeForm(), 50)
  }
}