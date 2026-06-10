import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "preview", "confirm", "submit"]

  updatePreview() {
    const name = this.inputTarget.value.trim()
    if (name) {
      this.previewTarget.textContent = name
      this.previewTarget.classList.add("agreement-signature-preview--active")
    } else {
      this.previewTarget.textContent = ""
      this.previewTarget.classList.remove("agreement-signature-preview--active")
    }
  }

  toggleSubmit() {
    const confirmed = this.confirmTarget.checked
    const hasSignature = this.inputTarget.value.trim().length > 0
    this.submitTarget.disabled = !(confirmed && hasSignature)
  }
}
