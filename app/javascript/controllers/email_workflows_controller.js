import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="email-workflows"
export default class extends Controller {
  static targets = ["tab", "tabContent"]
  
  connect() {
    console.log("Email workflows controller connected")
    this.bindTriggerTypeChange()
  }
  
  bindTriggerTypeChange() {
    const triggerSelect = document.querySelector('[data-trigger-select="true"]')
    if (triggerSelect) {
      triggerSelect.addEventListener('change', (event) => {
        this.updateTriggerConditions(event.target.value)
      })
    }
  }
  
  updateTriggerConditions(triggerType) {
    const conditionsContent = document.getElementById('trigger-conditions-content')
    if (!conditionsContent) return
    
    // Get the workflow ID from the form or data attribute
    const workflowData = document.querySelector('.workflow-form-data')
    const workflowId = workflowData ? workflowData.dataset.workflowId : 'new'
    
    // Show loading state
    conditionsContent.innerHTML = `
      <div class="trigger-conditions-loading">
        <i class="fas fa-spinner fa-spin"></i> Loading conditions...
      </div>
    `
    
    // Fetch updated trigger conditions
    const url = `/admin/email_workflows/${workflowId}/trigger_conditions?trigger_type=${encodeURIComponent(triggerType)}`
    
    fetch(url, {
      headers: {
        'Accept': 'text/html',
        'X-Requested-With': 'XMLHttpRequest'
      }
    })
    .then(response => response.text())
    .then(html => {
      conditionsContent.innerHTML = html
    })
    .catch(error => {
      console.error('Error loading trigger conditions:', error)
      conditionsContent.innerHTML = `
        <div class="trigger-conditions-error">
          <i class="fas fa-exclamation-triangle"></i>
          <p>Failed to load trigger conditions. Please try again.</p>
        </div>
      `
    })
  }
  
  switchTab(event) {
    const targetTab = event.currentTarget.dataset.tab
    
    // Remove active class from all buttons and contents
    this.tabTargets.forEach(btn => btn.classList.remove('active'))
    this.tabContentTargets.forEach(content => content.classList.remove('active'))
    
    // Add active class to clicked button and corresponding content
    event.currentTarget.classList.add('active')
    const targetContent = document.getElementById(`${targetTab}-tab`)
    if (targetContent) {
      targetContent.classList.add('active')
    }
    
    // Load content based on tab
    if (targetTab === 'templates') {
      this.loadEmailTemplates()
    } else if (targetTab === 'library') {
      this.loadTemplateLibrary()
    }
  }
  
  loadEmailTemplates() {
    const templatesContainer = document.getElementById('templates-tab')
    const templatesContent = templatesContainer.querySelector('.templates-content')
    const loadingDiv = templatesContent?.querySelector('.templates-loading')
    
    if (templatesContainer.dataset.loaded === 'true') return
    
    fetch('/admin/email_workflows/email_templates_content', {
      headers: {
        'Accept': 'text/html',
        'X-Requested-With': 'XMLHttpRequest'
      }
    })
    .then(response => response.text())
    .then(html => {
      if (templatesContent) {
        templatesContent.innerHTML = html
        templatesContainer.dataset.loaded = 'true'
      }
    })
    .catch(error => {
      if (loadingDiv) {
        loadingDiv.innerHTML = `
          <div class="error-state">
            <i class="fas fa-exclamation-triangle"></i>
            <p>Failed to load email templates</p>
            <button onclick="this.closest('[data-controller]').controller.loadEmailTemplates()" class="btn-secondary">Retry</button>
          </div>
        `
      }
      console.error('Error loading email templates:', error)
    })
  }
  
  loadTemplateLibrary() {
    const libraryContainer = document.getElementById('library-tab')
    const loadingDiv = libraryContainer.querySelector('.library-loading')
    
    if (libraryContainer.dataset.loaded === 'true') return
    
    fetch('/admin/email_workflows/templates', {
      headers: {
        'Accept': 'text/html',
        'X-Requested-With': 'XMLHttpRequest'
      }
    })
    .then(response => response.text())
    .then(html => {
      const parser = new DOMParser()
      const doc = parser.parseFromString(html, 'text/html')
      const mainContent = doc.querySelector('.admin-content') || doc.body
      
      if (loadingDiv) {
        loadingDiv.innerHTML = mainContent.innerHTML
        libraryContainer.dataset.loaded = 'true'
      }
    })
    .catch(error => {
      if (loadingDiv) {
        loadingDiv.innerHTML = `
          <div class="error-state">
            <i class="fas fa-exclamation-triangle"></i>
            <p>Failed to load template library</p>
            <button onclick="this.closest('[data-controller]').controller.loadTemplateLibrary()" class="btn-secondary">Retry</button>
          </div>
        `
      }
      console.error('Error loading template library:', error)
    })
  }
}