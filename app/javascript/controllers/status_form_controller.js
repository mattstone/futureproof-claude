import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["statusSelect", "rejectedReasonField", "rejectedReasonTextarea"]
  
  connect() {
    console.log("Status form controller connected")
    this.toggleRejectedReason()
  }
  
  statusChanged() {
    this.toggleRejectedReason()
  }
  
  toggleRejectedReason() {
    if (this.statusSelectTarget.value === 'rejected') {
      this.rejectedReasonFieldTarget.classList.remove('rejected-reason-field-hidden')
      this.rejectedReasonTextareaTarget.required = true
    } else {
      this.rejectedReasonFieldTarget.classList.add('rejected-reason-field-hidden')
      this.rejectedReasonTextareaTarget.required = false
      this.rejectedReasonTextareaTarget.value = '' // Clear the field when hidden
    }
  }
}