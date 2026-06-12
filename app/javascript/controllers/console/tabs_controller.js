import { Controller } from "@hotwired/stimulus"

// Tab switching for Console::TabsComponent. Connects to data-controller="console--tabs"
export default class extends Controller {
  static targets = ["tab", "panel"]

  select(event) {
    const index = this.tabTargets.indexOf(event.currentTarget)

    this.tabTargets.forEach((tab, i) => {
      tab.classList.toggle("is-active", i === index)
      tab.setAttribute("aria-selected", i === index)
    })

    this.panelTargets.forEach((panel, i) => {
      panel.classList.toggle("is-active", i === index)
      panel.hidden = i !== index
    })
  }
}
