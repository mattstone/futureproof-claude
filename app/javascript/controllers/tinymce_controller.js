import { Controller } from "@hotwired/stimulus"
import "tinymce"

// Connects to data-controller="tinymce"
export default class extends Controller {
  static targets = ["editor"]
  static values = { 
    mode: String,
    placeholder: String
  }

  connect() {
    this.initializeTinyMCE()
  }

  disconnect() {
    if (this.editorInstance) {
      this.editorInstance.remove()
    }
  }

  initializeTinyMCE() {
    const targetElement = this.editorTarget
    
    // Email-optimized TinyMCE configuration
    tinymce.init({
      target: targetElement,
      height: 400,
      menubar: false,
      plugins: [
        'advlist', 'autolink', 'lists', 'link', 'image', 'charmap',
        'anchor', 'searchreplace', 'visualblocks', 'code', 'fullscreen',
        'insertdatetime', 'media', 'table', 'preview', 'help', 'wordcount'
      ],
      toolbar: 'undo redo | blocks | ' +
        'bold italic forecolor backcolor | alignleft aligncenter ' +
        'alignright alignjustify | bullist numlist outdent indent | ' +
        'removeformat | help | code',
      content_style: 'body { font-family: Arial, sans-serif; font-size: 14px; line-height: 1.6; }',
      
      // Email-specific settings
      valid_elements: 'a[href|title],strong/b,em/i,br,p,div[style],h1[style],h2[style],h3[style],h4[style],h5[style],h6[style],ul,ol,li,img[src|alt|style|width|height],table[style|border|cellpadding|cellspacing],tbody,tr,td[style|colspan|rowspan],th[style|colspan|rowspan],span[style]',
      forced_root_block: 'p',
      force_p_newlines: true,
      remove_trailing_brs: true,
      
      // Custom styles for email compatibility
      formats: {
        alignleft: { selector: 'p,h1,h2,h3,h4,h5,h6,td,th,div,ul,ol,li,table', styles: { textAlign: 'left' } },
        aligncenter: { selector: 'p,h1,h2,h3,h4,h5,h6,td,th,div,ul,ol,li,table', styles: { textAlign: 'center' } },
        alignright: { selector: 'p,h1,h2,h3,h4,h5,h6,td,th,div,ul,ol,li,table', styles: { textAlign: 'right' } },
        alignjustify: { selector: 'p,h1,h2,h3,h4,h5,h6,td,th,div,ul,ol,li,table', styles: { textAlign: 'justify' } }
      },
      
      // Block elements for email
      block_formats: 'Paragraph=p; Heading 2=h2; Heading 3=h3; Heading 4=h4',
      
      // Placeholder text
      placeholder: this.placeholderValue || 'Enter your email content here...',
      
      // Event handlers
      setup: (editor) => {
        this.editorInstance = editor
        
        // Update the original textarea when content changes
        editor.on('change input undo redo', () => {
          editor.save()
          // Trigger change event for any listeners
          targetElement.dispatchEvent(new Event('change', { bubbles: true }))
        })

        // Handle field placeholder insertion
        this.addPlaceholderSupport(editor)
      }
    })
  }

  addPlaceholderSupport(editor) {
    // Add custom menu item for field placeholders
    editor.ui.registry.addMenuButton('fieldplaceholders', {
      text: 'Fields',
      fetch: (callback) => {
        const items = [
          {
            type: 'menuitem',
            text: 'User Fields',
            onAction: () => this.showPlaceholderMenu(editor, 'user')
          },
          {
            type: 'menuitem', 
            text: 'Application Fields',
            onAction: () => this.showPlaceholderMenu(editor, 'application')
          },
          {
            type: 'menuitem',
            text: 'Security Fields', 
            onAction: () => this.showPlaceholderMenu(editor, 'security')
          },
          {
            type: 'menuitem',
            text: 'Verification Fields',
            onAction: () => this.showPlaceholderMenu(editor, 'verification')
          }
        ]
        callback(items)
      }
    })

    // Add to toolbar
    const currentToolbar = editor.options.toolbar
    editor.options.toolbar = currentToolbar + ' | fieldplaceholders'
  }

  showPlaceholderMenu(editor, category) {
    const placeholders = {
      user: ['{{user.first_name}}', '{{user.last_name}}', '{{user.full_name}}', '{{user.email}}'],
      application: ['{{application.reference_number}}', '{{application.address}}', '{{application.formatted_home_value}}', '{{application.formatted_loan_value}}'],
      security: ['{{security.ip_address}}', '{{security.location}}', '{{security.sign_in_time}}', '{{security.browser_info}}'],
      verification: ['{{verification.verification_code}}', '{{verification.formatted_expires_at}}']
    }

    const items = placeholders[category]?.map(placeholder => ({
      type: 'menuitem',
      text: placeholder,
      onAction: () => {
        editor.insertContent(`<span style="background-color: #e3f2fd; padding: 2px 4px; border-radius: 3px; font-family: monospace;">${placeholder}</span>&nbsp;`)
      }
    })) || []

    if (items.length > 0) {
      editor.windowManager.open({
        title: `${category.charAt(0).toUpperCase() + category.slice(1)} Field Placeholders`,
        body: {
          type: 'panel',
          items: items.map(item => ({
            type: 'button',
            text: item.text,
            onAction: item.onAction
          }))
        },
        buttons: [
          {
            type: 'cancel',
            text: 'Close'
          }
        ]
      })
    }
  }

  // Method to get the current content
  getContent() {
    return this.editorInstance ? this.editorInstance.getContent() : this.editorTarget.value
  }

  // Method to set content
  setContent(content) {
    if (this.editorInstance) {
      this.editorInstance.setContent(content)
    } else {
      this.editorTarget.value = content
    }
  }
}