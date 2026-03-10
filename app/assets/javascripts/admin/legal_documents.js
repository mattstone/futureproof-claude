// Admin Legal Documents - Interactive Features
// Vanilla JavaScript, no external dependencies (except optional Highlight.js CDN)

// =============================================================================
// Feature 1: Tab Switching
// =============================================================================
document.addEventListener('DOMContentLoaded', function() {
  const tabButtons = document.querySelectorAll('[data-tab-button]');
  const tabPanes = document.querySelectorAll('[data-tab-pane]');

  tabButtons.forEach(button => {
    button.addEventListener('click', function() {
      const tabName = this.getAttribute('data-tab-button');

      tabPanes.forEach(pane => pane.style.display = 'none');
      tabButtons.forEach(btn => btn.classList.remove('active'));

      document.querySelector(`[data-tab-pane="${tabName}"]`).style.display = 'block';
      this.classList.add('active');
    });
  });

  if (tabButtons.length > 0) {
    tabButtons[0].click();
  }
});

// =============================================================================
// Feature 2: Auto-Save (to localStorage)
// =============================================================================
(function() {
  const SAVE_KEY = 'legal_doc_draft_';
  const INTERVAL = 30000;

  function getDocKey() {
    return SAVE_KEY + (window.location.pathname || 'new');
  }

  function saveToStorage() {
    const form = document.querySelector('form[data-auto-save]');
    if (!form) return;

    var data = {
      timestamp: new Date().toISOString(),
      fields: {}
    };

    form.querySelectorAll('input, textarea, select').forEach(function(field) {
      if (field.name) {
        data.fields[field.name] = field.value;
      }
    });

    localStorage.setItem(getDocKey(), JSON.stringify(data));
    updateSaveIndicator();
  }

  function restoreFromStorage() {
    var saved = localStorage.getItem(getDocKey());
    if (!saved) return;

    var data = JSON.parse(saved);
    var form = document.querySelector('form[data-auto-save]');

    Object.keys(data.fields).forEach(function(fieldName) {
      var field = form.querySelector('[name="' + fieldName + '"]');
      if (field) {
        field.value = data.fields[fieldName];
      }
    });
  }

  function updateSaveIndicator() {
    var indicator = document.querySelector('[data-save-indicator]');
    if (!indicator) return;

    var now = new Date();
    indicator.textContent = 'Last saved at ' + now.toLocaleTimeString();
    indicator.style.display = 'block';
  }

  function clearSave() {
    localStorage.removeItem(getDocKey());
  }

  document.addEventListener('DOMContentLoaded', function() {
    if (localStorage.getItem(getDocKey())) {
      var recoveryMsg = document.querySelector('[data-recovery-message]');
      if (recoveryMsg) {
        recoveryMsg.style.display = 'block';
        document.querySelector('[data-restore-draft]').addEventListener('click', restoreFromStorage);
        document.querySelector('[data-discard-draft]').addEventListener('click', clearSave);
      }
    }

    setInterval(saveToStorage, INTERVAL);

    var form = document.querySelector('form[data-auto-save]');
    if (form) {
      form.addEventListener('submit', clearSave);
    }
  });
})();

// =============================================================================
// Feature 3: Code Highlighting (Highlight.js CDN)
// =============================================================================
(function() {
  if (typeof hljs === 'undefined') {
    var script = document.createElement('script');
    script.src = 'https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.8.0/highlight.min.js';
    script.onload = function() { highlightCode(); };
    document.head.appendChild(script);

    var link = document.createElement('link');
    link.rel = 'stylesheet';
    link.href = 'https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.8.0/styles/atom-one-light.min.css';
    document.head.appendChild(link);
  } else {
    highlightCode();
  }

  function highlightCode() {
    document.querySelectorAll('pre code').forEach(function(block) {
      hljs.highlightElement(block);
    });
  }
})();

// =============================================================================
// Feature 4: Inline Diff Viewer
// =============================================================================
(function() {
  function escapeHtml(text) {
    var div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
  }

  function createDiffHTML(oldText, newText) {
    return '<div style="display: grid; grid-template-columns: 1fr 1fr; gap: 20px;">' +
      '<div><h4>Previous</h4>' +
      '<pre style="background: #fef3c7; padding: 10px; border-radius: 4px; overflow-x: auto;">' +
      escapeHtml(oldText) + '</pre></div>' +
      '<div><h4>Current</h4>' +
      '<pre style="background: #dcfce7; padding: 10px; border-radius: 4px; overflow-x: auto;">' +
      escapeHtml(newText) + '</pre></div></div>';
  }

  window.showDiff = function(previousContent, newContent) {
    var container = document.querySelector('[data-diff-viewer]');
    if (container) {
      container.innerHTML = createDiffHTML(previousContent, newContent);
    }
  };
})();

// =============================================================================
// Feature 5: Form Validation
// =============================================================================
(function() {
  document.addEventListener('DOMContentLoaded', function() {
    var form = document.querySelector('form[data-validate]');
    if (!form) return;

    form.addEventListener('submit', function(e) {
      var isValid = true;

      form.querySelectorAll('[required]').forEach(function(field) {
        if (!field.value.trim()) {
          field.classList.add('error');
          isValid = false;
        } else {
          field.classList.remove('error');
        }
      });

      if (!isValid) {
        e.preventDefault();
        alert('Please fill in all required fields');
      }
    });

    form.querySelectorAll('[required]').forEach(function(field) {
      field.addEventListener('focus', function() {
        this.classList.remove('error');
      });
    });
  });
})();

// =============================================================================
// Feature 6: Bulk Actions
// =============================================================================
(function() {
  document.addEventListener('DOMContentLoaded', function() {
    var selectAllCheckbox = document.querySelector('[data-select-all]');
    var rowCheckboxes = document.querySelectorAll('[data-row-select]');

    if (selectAllCheckbox) {
      selectAllCheckbox.addEventListener('change', function() {
        var checked = this.checked;
        rowCheckboxes.forEach(function(checkbox) {
          checkbox.checked = checked;
        });
        updateBulkActionButtons();
      });
    }

    rowCheckboxes.forEach(function(checkbox) {
      checkbox.addEventListener('change', updateBulkActionButtons);
    });

    function updateBulkActionButtons() {
      var selectedCount = document.querySelectorAll('[data-row-select]:checked').length;
      var bulkActions = document.querySelector('[data-bulk-actions]');

      if (bulkActions) {
        bulkActions.style.display = selectedCount > 0 ? 'block' : 'none';
      }
    }
  });
})();
