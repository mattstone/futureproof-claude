import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["primaryImage", "thumbnail"]

  selectImage(event) {
    const imageUrl = event.currentTarget.dataset.imageUrl

    // Update the primary image
    this.primaryImageTarget.src = imageUrl

    // Update active thumbnail
    this.thumbnailTargets.forEach(thumb => thumb.classList.remove("active"))
    event.currentTarget.classList.add("active")
  }
}