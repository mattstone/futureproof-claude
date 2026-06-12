import { Controller } from "@hotwired/stimulus"

// Sidebar show/hide for narrow viewports. Connects to data-controller="console--nav"
export default class extends Controller {
  static targets = ["sidebar"]

  toggle() {
    this.sidebarTarget.classList.toggle("is-open")
  }
}
