import { Controller } from "@hotwired/stimulus"

/**
 * Akane AI Chat Widget
 * Floating chat bubble with expandable panel, voice input, and Claude-powered responses.
 */
export default class extends Controller {
  static targets = [
    "bubble", "panel", "messages", "input", "sendButton",
    "micButton", "typingIndicator", "escalationBar",
    "quickActions", "charCount", "welcome", "voiceBar"
  ]

  static values = {
    region: { type: String, default: "us" },
    page: { type: String, default: "get_started" },
    open: { type: Boolean, default: false }
  }

  connect() {
    this.messageCount = 0
    this.isWaiting = false
    this.recognition = null
    this.isRecording = false
    this.hasGreeted = sessionStorage.getItem("akane_greeted") === "true"
    this.storedMessages = []

    // Restore conversation from sessionStorage
    this._restoreConversation()

    // Setup voice if available
    this._initVoice()

    // CSRF token
    const meta = document.querySelector('meta[name="csrf-token"]')
    this.csrfToken = meta ? meta.getAttribute("content") : ""

    // Auto-show greeting after delay (only on first visit)
    if (!this.hasGreeted) {
      this._greetingTimeout = setTimeout(() => this._pulseAttention(), 5000)
    }
  }

  disconnect() {
    if (this._greetingTimeout) clearTimeout(this._greetingTimeout)
    if (this.recognition) {
      try { this.recognition.abort() } catch (_) { /* noop */ }
    }
  }

  // ── Toggle Panel ──────────────────────────────
  toggle() {
    this.openValue = !this.openValue
    this.element.classList.toggle("akane-chat--open", this.openValue)
    this.bubbleTarget.setAttribute("aria-expanded", this.openValue)

    if (this.openValue) {
      // First open — show greeting
      if (!this.hasGreeted && this.messageCount === 0) {
        this._showGreeting()
        this.hasGreeted = true
        sessionStorage.setItem("akane_greeted", "true")
      }
      // Focus input after animation
      setTimeout(() => this.inputTarget.focus(), 350)
      this._scrollToBottom()
    }
  }

  // ── Clear Conversation ───────────────────────────
  clearConversation() {
    // Clear sessionStorage
    sessionStorage.removeItem("akane_messages")
    sessionStorage.removeItem("akane_greeted")
    this.storedMessages = []
    this.messageCount = 0
    this.hasGreeted = false

    // Clear rendered messages
    const messages = this.messagesTarget.querySelectorAll(".akane-chat-msg")
    messages.forEach(msg => msg.remove())

    // Show welcome and quick actions again
    if (this.hasWelcomeTarget) {
      this.welcomeTarget.style.display = ""
    }
    if (this.hasQuickActionsTarget) {
      this.quickActionsTarget.classList.remove("akane-chat-hidden")
    }

    // Hide escalation bar
    if (this.hasEscalationBarTarget) {
      this.escalationBarTarget.hidden = true
    }
  }

  // ── Send Message ──────────────────────────────
  async sendMessage() {
    const text = this.inputTarget.value.trim()
    if (!text || this.isWaiting) return
    if (text.length > 5000) return

    // Hide quick actions
    if (this.hasQuickActionsTarget) {
      this.quickActionsTarget.classList.add("akane-chat-hidden")
    }

    // Add user message
    this._addMessage("user", text)
    this.inputTarget.value = ""
    this._autoResize()
    this._updateCharCount()

    // Show typing
    this.isWaiting = true
    this._showTyping()
    this.sendButtonTarget.disabled = true

    try {
      const url = this.regionValue === "us"
        ? "/support/send_message"
        : `/${this.regionValue}/support/send_message`

      const response = await fetch(url, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this.csrfToken,
          "Accept": "application/json"
        },
        body: JSON.stringify({
          message: text,
          page_context: this.pageValue
        })
      })

      const data = await response.json()

      this._hideTyping()

      if (data.success) {
        this._addMessage("agent", data.assistant_message.content)

        // Check escalation
        if (data.escalate) {
          this._showEscalation()
        }
      } else {
        this._addMessage("agent", "I'm sorry, I had trouble processing that. Could you try again?")
      }
    } catch (error) {
      this._hideTyping()
      this._addMessage("agent",
        "I'm having trouble connecting right now. Please try again, or contact us at support@futureproof.com.au")
    }

    this.isWaiting = false
    this.sendButtonTarget.disabled = false
    this.inputTarget.focus()
  }

  // ── Quick Question ────────────────────────────
  sendQuickQuestion(event) {
    const question = event.currentTarget.dataset.question
    if (!question) return
    this.inputTarget.value = question
    this.sendMessage()
  }

  // ── Keyboard Handling ─────────────────────────
  handleKeydown(event) {
    if (event.key === "Enter" && !event.shiftKey) {
      event.preventDefault()
      this.sendMessage()
    }
  }

  // ── Auto Resize Textarea ──────────────────────
  autoResize() {
    this._autoResize()
    this._updateCharCount()
  }

  _autoResize() {
    const el = this.inputTarget
    el.style.height = "auto"
    el.style.height = Math.min(el.scrollHeight, 100) + "px"
  }

  _updateCharCount() {
    if (this.hasCharCountTarget) {
      const len = this.inputTarget.value.length
      this.charCountTarget.textContent = `${len}/5000`
    }
  }

  // ── Voice Input ───────────────────────────────
  _initVoice() {
    const SR = window.SpeechRecognition || window.webkitSpeechRecognition
    if (!SR) {
      // Hide mic button if not supported
      if (this.hasMicButtonTarget) this.micButtonTarget.hidden = true
      return
    }

    if (this.hasMicButtonTarget) this.micButtonTarget.hidden = false

    this.recognition = new SR()
    this.recognition.continuous = false
    this.recognition.interimResults = true
    this.recognition.lang = this._voiceLocale()

    this.recognition.onresult = (event) => {
      let transcript = ""
      for (let i = event.resultIndex; i < event.results.length; i++) {
        transcript += event.results[i][0].transcript
      }
      this.inputTarget.value = transcript
      this._autoResize()
      this._updateCharCount()
    }

    this.recognition.onend = () => {
      this._stopRecordingUI()
      // Auto-send if we got text
      const text = this.inputTarget.value.trim()
      if (text && text.length > 3) {
        this.sendMessage()
      }
    }

    this.recognition.onerror = (event) => {
      this._stopRecordingUI()
      if (event.error !== "aborted" && event.error !== "no-speech") {
        console.warn("Speech recognition error:", event.error)
      }
    }
  }

  toggleVoice() {
    if (!this.recognition) return

    if (this.isRecording) {
      this.recognition.stop()
      this._stopRecordingUI()
    } else {
      this.inputTarget.value = ""
      this._updateCharCount()
      try {
        this.recognition.start()
        this._startRecordingUI()
      } catch (e) {
        console.warn("Could not start speech recognition:", e)
      }
    }
  }

  _startRecordingUI() {
    this.isRecording = true
    this.micButtonTarget.classList.add("akane-chat-recording")
    // Show voice bar
    if (this.hasVoiceBarTarget) this.voiceBarTarget.hidden = false
  }

  _stopRecordingUI() {
    this.isRecording = false
    if (this.hasMicButtonTarget) {
      this.micButtonTarget.classList.remove("akane-chat-recording")
    }
    if (this.hasVoiceBarTarget) this.voiceBarTarget.hidden = true
  }

  _voiceLocale() {
    const map = { au: "en-AU", nz: "en-NZ", uk: "en-GB", us: "en-US" }
    return map[this.regionValue] || "en-US"
  }

  // ── Escalation ────────────────────────────────
  _showEscalation() {
    if (this.hasEscalationBarTarget) {
      this.escalationBarTarget.hidden = false
    }
  }

  escalateToHuman() {
    this._addMessage("system",
      "We'll connect you with a human agent. Please email support@futureproof.com.au or call 1300 388 873. Our team responds within 1 business day.")
    if (this.hasEscalationBarTarget) {
      this.escalationBarTarget.hidden = true
    }
  }

  // ── Message Rendering ─────────────────────────
  _addMessage(role, content) {
    this.messageCount++

    // Store in sessionStorage
    this.storedMessages.push({ role, content, time: Date.now() })
    try {
      sessionStorage.setItem("akane_messages", JSON.stringify(this.storedMessages.slice(-30)))
    } catch (_) { /* storage full */ }

    this._renderMessage(role, content)
  }

  _renderMessage(role, content) {
    const msg = document.createElement("div")
    const timeStr = new Date().toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })

    if (role === "system") {
      msg.className = "akane-chat-msg akane-chat-msg--system"
      msg.innerHTML = `<div class="akane-chat-msg-bubble">${this._escapeHtml(content)}</div>`
    } else if (role === "user") {
      msg.className = "akane-chat-msg akane-chat-msg--user"
      msg.innerHTML = `
        <div>
          <div class="akane-chat-msg-bubble">${this._escapeHtml(content)}</div>
          <div class="akane-chat-msg-time">${timeStr}</div>
        </div>`
    } else {
      msg.className = "akane-chat-msg akane-chat-msg--agent"
      msg.innerHTML = `
        <span class="akane-orb akane-orb--msg">
          <span class="akane-orb-core"></span>
          <span class="akane-orb-ring akane-orb-ring--1"></span>
        </span>
        <div>
          <div class="akane-chat-msg-bubble">${this._formatResponse(content)}</div>
          <div class="akane-chat-msg-time">${timeStr}</div>
        </div>`
    }

    this.messagesTarget.appendChild(msg)
    this._scrollToBottom()
  }

  _formatResponse(text) {
    // Escape HTML first
    let html = this._escapeHtml(text)
    // Bold: **text**
    html = html.replace(/\*\*(.+?)\*\*/g, "<strong>$1</strong>")
    // Bullet lists: lines starting with - or •
    html = html.replace(/^[\-•]\s+(.+)$/gm, "<li>$1</li>")
    html = html.replace(/(<li>.*<\/li>\n?)+/g, (match) => `<ul>${match}</ul>`)
    // Numbered lists: lines starting with 1. 2. etc
    html = html.replace(/^\d+\.\s+(.+)$/gm, "<li>$1</li>")
    // Paragraphs: double newlines
    html = html.replace(/\n\n/g, "</p><p>")
    // Single newlines to <br>
    html = html.replace(/\n/g, "<br>")
    // Wrap in paragraph
    html = `<p>${html}</p>`
    // Clean up empty paragraphs
    html = html.replace(/<p><\/p>/g, "")

    return html
  }

  _escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }

  // ── Typing Indicator ──────────────────────────
  _showTyping() {
    if (this.hasTypingIndicatorTarget) {
      this.typingIndicatorTarget.hidden = false
      this._scrollToBottom()
    }
  }

  _hideTyping() {
    if (this.hasTypingIndicatorTarget) {
      this.typingIndicatorTarget.hidden = true
    }
  }

  // ── Scroll ────────────────────────────────────
  _scrollToBottom() {
    requestAnimationFrame(() => {
      this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight
    })
  }

  // ── Greeting ──────────────────────────────────
  _showGreeting() {
    const greetings = {
      get_started: "Welcome. I'm the FutureProof assistant — your guide to the FutureProof platform. I specialise in the Equity Preservation Mortgage: how it works, eligibility, the application process, and how it compares to other products. Ask me anything.",
      apply: "I'm the FutureProof assistant. I'll walk you through the EPM application — what you need, each step of the process, and what to expect. Where would you like to start?"
    }

    const greeting = greetings[this.pageValue] || greetings.get_started
    this._renderMessage("agent", greeting)

    // Store greeting
    this.storedMessages.push({ role: "agent", content: greeting, time: Date.now() })
    try {
      sessionStorage.setItem("akane_messages", JSON.stringify(this.storedMessages))
    } catch (_) { /* noop */ }
  }

  // ── Attention Pulse ───────────────────────────
  _pulseAttention() {
    if (this.openValue) return
    // Add an extra strong pulse to draw attention
    this.bubbleTarget.style.animation = "none"
    void this.bubbleTarget.offsetHeight // force reflow
    this.bubbleTarget.style.animation = ""
  }

  // ── Session Restore ───────────────────────────
  _restoreConversation() {
    try {
      const stored = sessionStorage.getItem("akane_messages")
      if (stored) {
        this.storedMessages = JSON.parse(stored)
        this.storedMessages.forEach(msg => {
          this._renderMessage(msg.role, msg.content)
        })
        this.messageCount = this.storedMessages.length

        // Hide quick actions if there are messages
        if (this.messageCount > 0 && this.hasQuickActionsTarget) {
          this.quickActionsTarget.classList.add("akane-chat-hidden")
        }
      }
    } catch (_) { /* noop */ }
  }
}
