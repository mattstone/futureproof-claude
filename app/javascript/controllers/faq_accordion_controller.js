import { Controller } from "@hotwired/stimulus"

/**
 * FAQ Accordion — smooth CSS grid animation, single-open.
 * Uses grid-template-rows 0fr → 1fr for natural height animation.
 */
export default class extends Controller {
  static targets = ["item"]

  toggle(event) {
    const clicked = event.currentTarget.closest("[data-faq-accordion-target='item']")
    if (!clicked) return

    const isOpen = clicked.classList.contains("is-open")

    // Close all items
    this.itemTargets.forEach(item => item.classList.remove("is-open"))

    // Open clicked item (unless it was already open — toggle off)
    if (!isOpen) {
      clicked.classList.add("is-open")
    }
  }
}
