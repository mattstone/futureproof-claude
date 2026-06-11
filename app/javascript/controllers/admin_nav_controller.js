import { Controller } from "@hotwired/stimulus"

/**
 * Admin Nav — updates active state and document title on Turbo Frame navigation.
 * The sidebar is marked data-turbo-permanent so it persists across all navigations.
 */
export default class extends Controller {
  static targets = ["link"]

  connect() {
    // On initial page load, scroll active item into view
    this.updateActive()
    const active = this.element.querySelector(".admin-nav-link.active")
    if (active) {
      active.scrollIntoView({ block: "nearest", behavior: "instant" })
    }
  }

  // Called on turbo:frame-load and turbo:load
  updateActive() {
    const path = window.location.pathname

    // Update active link
    this.linkTargets.forEach(link => {
      const href = link.getAttribute("href")
      const isActive = path === href || (href !== "/admin" && path.startsWith(href + "/"))
      link.classList.toggle("active", isActive)

      // Open parent <details> if this link is active
      if (isActive) {
        const details = link.closest("details.admin-nav-group")
        if (details) details.open = true
      }
    })

    // Update document title from the h1 inside the frame
    const h1 = document.querySelector(".admin-header h1")
    if (h1 && h1.textContent.trim()) {
      document.title = `Admin - ${h1.textContent.trim()}`
    }
  }
}
