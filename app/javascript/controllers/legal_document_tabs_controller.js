import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel", "diffRow"]

  switch(event) {
    const tabName = event.params.tab
    const btn = event.currentTarget

    // Update buttons
    this.element.querySelectorAll(".ld-tab-btn").forEach(b => b.classList.remove("active"))
    btn.classList.add("active")

    // Update panels
    this.panelTargets.forEach(panel => {
      panel.classList.toggle("active", panel.dataset.tab === tabName)
    })
  }

  toggleDiff(event) {
    const btn = event.currentTarget
    const row = btn.closest("tr").nextElementSibling
    if (row && row.classList.contains("ld-diff-row")) {
      const isHidden = row.hidden
      row.hidden = !isHidden
      btn.textContent = isHidden ? "Hide Diff" : "View Diff"
    }
  }
}
