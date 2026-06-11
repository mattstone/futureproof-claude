import consumer from "channels/consumer"

document.addEventListener('turbo:load', () => {
  const messageContainer = document.getElementById('message-list')
  if (!messageContainer) return

  const applicationId = messageContainer.dataset.applicationId
  if (!applicationId) return

  const subscription = consumer.subscriptions.create(
    { channel: 'BorrowerMessageChannel', application_id: applicationId },
    {
      connected() {
        console.log('✓ Connected to BorrowerMessageChannel')
      },

      disconnected() {
        console.log('✗ Disconnected from BorrowerMessageChannel')
      },

      received(data) {
        // Add new message to the list
        const messageEl = createMessageElement(data)
        messageContainer.appendChild(messageEl)
        
        // Scroll to bottom
        messageContainer.scrollTop = messageContainer.scrollHeight
        
        // Flash badge on new message (if from other party)
        if (!data.is_current_user) {
          flashNewMessageBadge()
        }
      },

      send_message(message) {
        this.perform('send_message', { message: message })
      }
    }
  )

  // Handle message form submission
  const messageForm = document.getElementById('message-form')
  if (messageForm) {
    messageForm.addEventListener('submit', (e) => {
      e.preventDefault()
      const textarea = messageForm.querySelector('textarea[name="message"]')
      const message = textarea.value.trim()
      
      if (message.length > 0) {
        subscription.send_message(message)
        textarea.value = ''
        textarea.focus()
        updateCharCount(textarea)
      }
    })

    // Character counter
    const textarea = messageForm.querySelector('textarea[name="message"]')
    if (textarea) {
      textarea.addEventListener('input', () => updateCharCount(textarea))
    }
  }

  // Mark messages as read when viewing
  markMessagesAsRead()
})

function createMessageElement(data) {
  const wrapper = document.createElement('div')
  wrapper.className = `message-item message-from-${data.sender_type}`
  wrapper.innerHTML = `
    <div class="message-avatar">
      <img src="${data.user_avatar}" alt="${data.user_name}" class="avatar-img">
    </div>
    <div class="message-content">
      <div class="message-header">
        <span class="message-author">${escapeHtml(data.user_name)}</span>
        <span class="message-time">${data.created_at}</span>
      </div>
      <div class="message-text">${escapeHtml(data.message)}</div>
    </div>
  `
  return wrapper
}

function updateCharCount(textarea) {
  const count = textarea.value.length
  const limit = 5000
  const counter = textarea.parentElement.querySelector('.char-count')
  if (counter) {
    counter.textContent = `${count}/${limit}`
    counter.classList.toggle('warning', count > limit * 0.9)
  }
}

function markMessagesAsRead() {
  // Find all unread messages from lender and mark as read
  document.querySelectorAll('[data-message-id][data-unread="true"]').forEach(el => {
    const messageId = el.dataset.messageId
    fetch(`/borrower/messages/${messageId}`, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
      },
      body: JSON.stringify({ mark_as_read: true })
    })
    el.dataset.unread = 'false'
  })
}

function flashNewMessageBadge() {
  // Optional: add visual notification for new message
  const badge = document.querySelector('[data-unread-count]')
  if (badge) {
    badge.classList.add('pulse')
    setTimeout(() => badge.classList.remove('pulse'), 1000)
  }
}

function escapeHtml(text) {
  const div = document.createElement('div')
  div.textContent = text
  return div.innerHTML
}
