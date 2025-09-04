import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="workflow-templates"
export default class extends Controller {
  
  showTemplatePreview(event) {
    const button = event.currentTarget
    const templateName = button.dataset.template
    const modal = document.getElementById('template-preview-modal')
    const title = document.getElementById('preview-title')
    const content = document.getElementById('preview-content')
    const createBtn = document.getElementById('create-from-preview')
    
    if (!modal || !title || !content || !createBtn) {
      console.error('Modal elements not found')
      return
    }
    
    title.textContent = `Preview: ${templateName}`
    content.innerHTML = '<div class="loading">Loading template preview...</div>'
    
    // Set create button action
    createBtn.onclick = () => {
      const newUrl = new URL(window.location.origin + '/admin/email_workflows/new')
      newUrl.searchParams.set('template', templateName)
      window.location.href = newUrl.toString()
    }
    
    modal.classList.remove('hidden')
    
    // Load template details (in a real app, this would be an AJAX request)
    setTimeout(() => {
      content.innerHTML = this.generateTemplatePreview(templateName)
    }, 500)
  }
  
  closeTemplatePreview() {
    const modal = document.getElementById('template-preview-modal')
    if (modal) {
      modal.classList.add('hidden')
    }
  }
  
  generateTemplatePreview(templateName) {
    return `
      <div class="preview-summary">
        <div class="preview-item">
          <strong>Template:</strong> ${templateName}
        </div>
        <div class="preview-item">
          <strong>Status:</strong> Ready to create
        </div>
      </div>
      <div class="preview-description">
        <p>This template will create a complete workflow with pre-configured steps for ${templateName}.</p>
      </div>
    `
  }
  
  createAllTemplates(event) {
    const templateCount = parseInt(document.querySelector('[data-template-count]')?.dataset.templateCount || '7')
    const onboardingCount = parseInt(document.querySelector('[data-onboarding-count]')?.dataset.onboardingCount || '1')
    const operationalCount = parseInt(document.querySelector('[data-operational-count]')?.dataset.operationalCount || '5')  
    const endContractCount = parseInt(document.querySelector('[data-end-contract-count]')?.dataset.endContractCount || '2')
    
    const confirmMessage = `This will create ${templateCount} workflow templates:\n\n` +
      `• ${onboardingCount} Onboarding workflows\n` +
      `• ${operationalCount} Operational workflows\n` +
      `• ${endContractCount} Contract completion workflows\n\n` +
      `Are you sure you want to proceed?`
      
    if (confirm(confirmMessage)) {
      // Show loading state
      const button = event.currentTarget
      if (button) {
        const originalText = button.innerHTML
        button.disabled = true
        button.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Creating...'
      }
      
      // Create a form and submit it
      const form = document.createElement('form')
      form.method = 'POST'
      form.action = '/admin/email_workflows/bulk_create'
      
      // Get CSRF token
      const csrfToken = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content')
      
      form.innerHTML = `
        <input type="hidden" name="authenticity_token" value="${csrfToken}">
        <input type="hidden" name="create_all_templates" value="true">
      `
      document.body.appendChild(form)
      form.submit()
    }
  }
  
  createCategoryTemplates(event) {
    const category = event.currentTarget.dataset.category
    const counts = {
      onboarding: parseInt(document.querySelector('[data-onboarding-count]')?.dataset.onboardingCount || '1'),
      operational: parseInt(document.querySelector('[data-operational-count]')?.dataset.operationalCount || '5'),
      end_of_contract: parseInt(document.querySelector('[data-end-contract-count]')?.dataset.endContractCount || '2')
    }
    
    const categoryName = category.replace('_', ' ')
    const confirmMessage = `This will create ${counts[category]} ${categoryName} workflow templates. Are you sure?`
    
    if (confirm(confirmMessage)) {
      // Show loading state
      const button = event.currentTarget
      if (button) {
        const originalText = button.innerHTML
        button.disabled = true
        button.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Creating...'
      }
      
      const form = document.createElement('form')
      form.method = 'POST'
      form.action = '/admin/email_workflows/bulk_create'
      
      // Get CSRF token
      const csrfToken = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content')
      
      form.innerHTML = `
        <input type="hidden" name="authenticity_token" value="${csrfToken}">
        <input type="hidden" name="create_category_templates" value="${category}">
      `
      document.body.appendChild(form)
      form.submit()
    }
  }
}