import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["sidebar", "overlay"]

  toggle() {
    const sidebar = this.sidebarTarget
    const overlay = this.overlayTarget

    sidebar.classList.toggle("sidebar-open")
    overlay.classList.toggle("active")
  }

  close() {
    this.sidebarTarget.classList.remove("sidebar-open")
    this.overlayTarget.classList.remove("active")
  }
}
