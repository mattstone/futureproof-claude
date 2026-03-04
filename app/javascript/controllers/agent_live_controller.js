import { Controller } from "@hotwired/stimulus"

// Agent Live Dashboard Controller
// Simulates real-time updates to give impression of agents working live
export default class extends Controller {
  static targets = ["agentStatus", "taskCount", "activityStream", "lastUpdate"]

  connect() {
    this.updateInterval = setInterval(() => this.simulateActivity(), 8000) // Every 8 seconds
    this.simulateActivity() // Initial run
  }

  disconnect() {
    if (this.updateInterval) clearInterval(this.updateInterval)
  }

  simulateActivity() {
    this.updateAgentStatuses()
    this.addActivityEntry()
    this.updateTimestamp()
  }

  updateAgentStatuses() {
    const statusElements = this.agentStatusTargets
    if (statusElements.length === 0) return

    // Randomly change 1-2 agent statuses
    const count = Math.floor(Math.random() * 2) + 1
    for (let i = 0; i < count; i++) {
      const el = statusElements[Math.floor(Math.random() * statusElements.length)]
      const statuses = ["idle", "processing", "processing", "processing"] // Bias toward processing
      const newStatus = statuses[Math.floor(Math.random() * statuses.length)]
      const badge = el.querySelector(".agent-status-badge")
      if (badge) {
        badge.textContent = newStatus.charAt(0).toUpperCase() + newStatus.slice(1)
        badge.className = "agent-status-badge status-" + newStatus
      }
    }
  }

  addActivityEntry() {
    const stream = this.activityStreamTarget
    if (!stream) return

    const activities = [
      { agent: "Ava (AI)", action: "completed application review", icon: "✅", detail: "#" + (1000 + Math.floor(Math.random() * 999)) },
      { agent: "Marcus (AI)", action: "generated income projection", icon: "📊", detail: "for $" + (500 + Math.floor(Math.random() * 1500)) + "K property" },
      { agent: "Claire (AI)", action: "verified compliance docs", icon: "⚖️", detail: ["AU", "NZ", "UK", "US"][Math.floor(Math.random() * 4)] + " region" },
      { agent: "Sam (AI)", action: "resolved support ticket", icon: "🔧", detail: "#" + (8000 + Math.floor(Math.random() * 999)) },
      { agent: "Diana (AI)", action: "processed status update", icon: "⚙️", detail: "application advanced to review" },
      { agent: "James T.", action: "approved high-value application", icon: "👤", detail: "#" + (1000 + Math.floor(Math.random() * 999)) },
      { agent: "Sarah L.", action: "completed document verification", icon: "👤", detail: "3 documents verified" },
      { agent: "Michael R.", action: "finished compliance audit", icon: "👤", detail: "Q1 " + ["AU", "NZ", "UK", "US"][Math.floor(Math.random() * 4)] }
    ]

    const activity = activities[Math.floor(Math.random() * activities.length)]
    const now = new Date()
    const time = now.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit", second: "2-digit" })

    const entry = document.createElement("div")
    entry.className = "activity-entry activity-new"
    entry.innerHTML = `<span class="activity-time">${time}</span> <span class="activity-icon">${activity.icon}</span> <strong>${activity.agent}</strong> ${activity.action} <span class="activity-detail">${activity.detail}</span>`

    stream.prepend(entry)

    // Remove animation class after transition
    setTimeout(() => entry.classList.remove("activity-new"), 500)

    // Keep only last 20 entries
    const entries = stream.querySelectorAll(".activity-entry")
    if (entries.length > 20) {
      entries[entries.length - 1].remove()
    }

    // Increment task counters
    this.taskCountTargets.forEach(el => {
      const current = parseInt(el.textContent) || 0
      if (Math.random() > 0.5) {
        el.textContent = current + 1
      }
    })
  }

  updateTimestamp() {
    const el = this.lastUpdateTarget
    if (el) {
      el.textContent = "Last updated: " + new Date().toLocaleTimeString()
    }
  }
}
