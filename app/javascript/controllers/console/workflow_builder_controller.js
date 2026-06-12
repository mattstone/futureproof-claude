import { Controller } from "@hotwired/stimulus"

// Step management for the email workflow form: add a step from the <template>,
// remove (soft-delete via _destroy), renumber positions, and show the right
// configuration section for each step's type.
// Replaces the legacy admin's four glue JS files.
export default class extends Controller {
  static targets = ["steps", "template", "empty"]

  connect() {
    this.counter = this.stepElements().length
    this.refresh()
    this.stepElements().forEach((step) => this.applyTypeVisibility(step))
  }

  addStep(event) {
    const type = event.currentTarget.dataset.stepType
    const index = `new_${this.counter++}`
    const html = this.templateTarget.innerHTML.replaceAll("NEW_RECORD", index)

    this.stepsTarget.insertAdjacentHTML("beforeend", html)
    const step = this.stepsTarget.lastElementChild

    const typeSelect = step.querySelector("[data-workflow-step-type]")
    if (typeSelect && type) {
      typeSelect.value = type
      this.applyTypeVisibility(step)
    }

    this.refresh()
  }

  removeStep(event) {
    const step = event.currentTarget.closest("[data-workflow-step]")
    const destroyField = step.querySelector("input[name*='_destroy']")

    if (destroyField && step.querySelector("input[name*='[id]']")) {
      destroyField.value = "1"
      step.hidden = true
    } else {
      step.remove()
    }

    this.refresh()
  }

  typeChanged(event) {
    this.applyTypeVisibility(event.currentTarget.closest("[data-workflow-step]"))
  }

  applyTypeVisibility(step) {
    const type = step.querySelector("[data-workflow-step-type]")?.value
    step.querySelectorAll("[data-config-for]").forEach((section) => {
      section.hidden = section.dataset.configFor !== type
    })
  }

  refresh() {
    const visible = this.stepElements()
    visible.forEach((step, index) => {
      const position = step.querySelector("input[name*='[position]']")
      if (position) position.value = index
      const number = step.querySelector("[data-step-number]")
      if (number) number.textContent = index + 1
    })
    if (this.hasEmptyTarget) this.emptyTarget.hidden = visible.length > 0
  }

  stepElements() {
    return Array.from(this.stepsTarget.querySelectorAll("[data-workflow-step]")).filter((el) => !el.hidden)
  }
}
