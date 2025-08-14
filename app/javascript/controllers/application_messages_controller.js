import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="application-messages"
export default class extends Controller {
  static targets = ["detailsSection", "messagesSection", "replyForm", "messageCount"]
  
  static values = {
    applicationId: Number,
    highlightMessageId: Number
  }

  connect() {
    console.log("Application messages controller connected")
    
    // Auto-scroll to highlighted message if present
    if (this.hasHighlightMessageIdValue) {
      this.scrollToHighlightedMessage()
    }
  }

  scrollToHighlightedMessage() {
    setTimeout(() => {
      const highlightedMessage = document.getElementById(`message-${this.highlightMessageIdValue}`)
      if (highlightedMessage) {
        highlightedMessage.scrollIntoView({
          behavior: 'smooth',
          block: 'center'
        })
      }
    }, 300)
  }

  toggleDetails(event) {
    event.preventDefault()
    const applicationId = event.currentTarget.dataset.applicationId
    const detailsSection = document.getElementById(`details-${applicationId}`)
    const messagesSection = document.getElementById(`messages-${applicationId}`)
    
    if (detailsSection.style.display === 'none') {
      detailsSection.style.display = 'block'
      messagesSection.style.display = 'none'
    } else {
      detailsSection.style.display = 'none'
    }
  }

  toggleMessages(event) {
    event.preventDefault()
    const applicationId = event.currentTarget.dataset.applicationId
    const detailsSection = document.getElementById(`details-${applicationId}`)
    const messagesSection = document.getElementById(`messages-${applicationId}`)
    
    if (messagesSection.style.display === 'none') {
      messagesSection.style.display = 'block'
      detailsSection.style.display = 'none'
      
      // Mark messages as read when viewing
      this.markAllAsRead(applicationId)
    } else {
      messagesSection.style.display = 'none'
    }
  }

  showReplyForm(event) {
    event.preventDefault()
    const messageId = event.currentTarget.dataset.messageId
    const replyForm = document.getElementById(`reply-form-${messageId}`)
    if (replyForm) {
      replyForm.style.display = 'block'
    }
  }

  hideReplyForm(event) {
    event.preventDefault()
    const messageId = event.currentTarget.dataset.messageId
    const replyForm = document.getElementById(`reply-form-${messageId}`)
    if (replyForm) {
      replyForm.style.display = 'none'
    }
  }

  markAsRead(event) {
    event.preventDefault()
    const messageId = event.currentTarget.dataset.messageId
    
    // Make AJAX request to mark message as read
    this.makeMarkAsReadRequest('application_messages', messageId)
    
    // Hide the mark as read button
    event.currentTarget.style.display = 'none'
    
    // Update status display
    const messageElement = event.currentTarget.closest('.message-thread')
    const statusElement = messageElement.querySelector('.message-status')
    if (statusElement) {
      statusElement.textContent = 'Read'
      statusElement.className = 'message-status status-read'
    }
  }

  markAllAsRead(applicationId) {
    // Make AJAX request to mark all messages as read for this application
    this.makeMarkAllAsReadRequest('applications', applicationId)
    
    // Update UI to reflect all messages are read
    const messageThreads = document.querySelectorAll(`#messages-${applicationId} .message-thread`)
    messageThreads.forEach(thread => {
      const statusElement = thread.querySelector('.message-status')
      const markAsReadBtn = thread.querySelector('.btn[data-action*="markAsRead"]')
      
      if (statusElement && statusElement.textContent !== 'Read') {
        statusElement.textContent = 'Read'
        statusElement.className = 'message-status status-read'
      }
      
      if (markAsReadBtn) {
        markAsReadBtn.style.display = 'none'
      }
    })
    
    // Update message count
    this.updateMessageCount(applicationId, 0)
  }

  makeMarkAsReadRequest(resourceType, messageId) {
    const csrfToken = document.querySelector('meta[name="csrf-token"]').getAttribute('content')
    
    fetch(`/${resourceType}/${messageId}/mark_as_read`, {
      method: 'PATCH',
      headers: {
        'X-CSRF-Token': csrfToken,
        'Content-Type': 'application/json',
        'Accept': 'application/json'
      }
    })
    .then(response => response.json())
    .then(data => {
      if (data.success) {
        console.log('Message marked as read successfully')
        // Update navigation unread counter
        this.updateNavigationCounter(data.unread_count)
      } else {
        console.error('Failed to mark message as read:', data.error)
      }
    })
    .catch(error => {
      console.error('Error marking message as read:', error)
    })
  }

  makeMarkAllAsReadRequest(resourceType, resourceId) {
    const csrfToken = document.querySelector('meta[name="csrf-token"]').getAttribute('content')
    
    fetch(`/${resourceType}/${resourceId}/mark_all_messages_as_read`, {
      method: 'PATCH',
      headers: {
        'X-CSRF-Token': csrfToken,
        'Content-Type': 'application/json',
        'Accept': 'application/json'
      }
    })
    .then(response => response.json())
    .then(data => {
      if (data.success) {
        console.log('All messages marked as read successfully')
        // Update navigation unread counter
        this.updateNavigationCounter(data.unread_count)
      } else {
        console.error('Failed to mark all messages as read:', data.error)
      }
    })
    .catch(error => {
      console.error('Error marking all messages as read:', error)
    })
  }

  updateMessageCount(applicationId, count) {
    const messageCountElements = document.querySelectorAll(`[data-application-id="${applicationId}"] .message-count`)
    messageCountElements.forEach(element => {
      if (count === 0) {
        element.style.display = 'none'
      } else {
        element.textContent = count
        element.style.display = 'inline'
      }
    })
  }

  updateNavigationCounter(unreadCount) {
    // Update the navigation unread badge for applications
    const navBadges = document.querySelectorAll('a[href*="section=applications"] .unread-badge')
    navBadges.forEach(badge => {
      if (unreadCount === 0) {
        badge.style.display = 'none'
      } else {
        badge.textContent = unreadCount > 99 ? "99+" : unreadCount
        badge.style.display = 'inline'
      }
    })
  }
}