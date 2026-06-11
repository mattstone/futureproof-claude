import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["draftField"]

  setDraft(event) {
    if (this.hasDraftFieldTarget) {
      this.draftFieldTarget.value = "true"
    }
  }

  setPublish(event) {
    if (this.hasDraftFieldTarget) {
      this.draftFieldTarget.value = "false"
    }
  }
}
