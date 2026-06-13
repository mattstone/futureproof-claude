import { Controller } from "@hotwired/stimulus"

// Console sidebar: mobile drawer toggle + active-link tracking.
//
// The sidebar is data-turbo-permanent, so a nav click that swaps only the
// #console_main frame never re-renders the sidebar — the server-side
// is-active class would go stale. updateActive() re-derives the active link
// from window.location on every frame load / full visit, mirroring the
// request.path matching the partial uses, and opens the active group.
export default class extends Controller {
  static targets = ["sidebar", "link"]

  connect() {
    this.updateActive()
  }

  toggle() {
    this.sidebarTarget.classList.toggle("is-open")
  }

  updateActive() {
    const path = window.location.pathname

    this.linkTargets.forEach((link) => {
      const href = link.getAttribute("href")
      if (!href) return
      const active = path === href || (href !== "/console" && path.startsWith(href + "/"))
      link.classList.toggle("is-active", active)
      if (active) {
        const group = link.closest("details.console-nav-group")
        if (group) group.open = true
      }
    })

    // The <head> is outside the frame, so the tab title would go stale on a
    // frame-only navigation — track it from the page header instead.
    const title = document.querySelector(".console-page-title")
    if (title && title.textContent.trim()) {
      document.title = `${title.textContent.trim()} — FutureProof Console`
    }

    // Close the mobile drawer after a navigation.
    if (this.hasSidebarTarget) this.sidebarTarget.classList.remove("is-open")
  }
}
