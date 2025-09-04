document.addEventListener('DOMContentLoaded', function() {
  // Tab switching functionality
  const tabButtons = document.querySelectorAll('.tab-button');
  const tabContents = document.querySelectorAll('.tab-content');
  
  tabButtons.forEach(button => {
    button.addEventListener('click', () => {
      const targetTab = button.getAttribute('data-tab');
      
      // Remove active class from all buttons and contents
      tabButtons.forEach(btn => btn.classList.remove('active'));
      tabContents.forEach(content => content.classList.remove('active'));
      
      // Add active class to clicked button and corresponding content
      button.classList.add('active');
      const targetContent = document.getElementById(`${targetTab}-tab`);
      if (targetContent) {
        targetContent.classList.add('active');
      }
      
      // Load content based on tab
      if (targetTab === 'templates') {
        loadEmailTemplates();
      } else if (targetTab === 'library') {
        loadTemplateLibrary();
      }
    });
  });
  
  // Load email templates via AJAX
  window.loadEmailTemplates = function() {
    const templatesContainer = document.getElementById('templates-tab');
    const templatesContent = templatesContainer.querySelector('.templates-content');
    const loadingDiv = templatesContent.querySelector('.templates-loading');
    
    if (templatesContainer.dataset.loaded === 'true') return;
    
    fetch('/admin/email_workflows/email_templates_content', {
      headers: {
        'Accept': 'text/html',
        'X-Requested-With': 'XMLHttpRequest'
      }
    })
    .then(response => response.text())
    .then(html => {
      // Replace loading content with actual templates (html is already the partial content)
      templatesContent.innerHTML = html;
      templatesContainer.dataset.loaded = 'true';
    })
    .catch(error => {
      if (loadingDiv) {
        loadingDiv.innerHTML = `
          <div class="error-state">
            <i class="fas fa-exclamation-triangle"></i>
            <p>Failed to load email templates</p>
            <button onclick="loadEmailTemplates()" class="btn-secondary">Retry</button>
          </div>
        `;
      }
      console.error('Error loading email templates:', error);
    });
  };
  
  // Load template library via AJAX
  window.loadTemplateLibrary = function() {
    const libraryContainer = document.getElementById('library-tab');
    const loadingDiv = libraryContainer.querySelector('.library-loading');
    
    if (libraryContainer.dataset.loaded === 'true') return;
    
    fetch('/admin/email_workflows/templates', {
      headers: {
        'Accept': 'text/html',
        'X-Requested-With': 'XMLHttpRequest'
      }
    })
    .then(response => response.text())
    .then(html => {
      // Extract the main content from the response
      const parser = new DOMParser();
      const doc = parser.parseFromString(html, 'text/html');
      const mainContent = doc.querySelector('.admin-content') || doc.body;
      
      // Replace loading content with actual library
      loadingDiv.innerHTML = mainContent.innerHTML;
      libraryContainer.dataset.loaded = 'true';
    })
    .catch(error => {
      if (loadingDiv) {
        loadingDiv.innerHTML = `
          <div class="error-state">
            <i class="fas fa-exclamation-triangle"></i>
            <p>Failed to load template library</p>
            <button onclick="loadTemplateLibrary()" class="btn-secondary">Retry</button>
          </div>
        `;
      }
      console.error('Error loading template library:', error);
    });
  };
});