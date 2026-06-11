import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "idsField"]
  static values = { url: String }

  connect() {
    this.draggedItem = null
    this.items.forEach(item => this.bindItem(item))
  }

  get items() {
    return Array.from(this.element.querySelectorAll("[data-faq-id]"))
  }

  bindItem(item) {
    item.addEventListener("dragstart", (e) => {
      this.draggedItem = item
      item.classList.add("sortable-dragging")
      e.dataTransfer.effectAllowed = "move"
      e.dataTransfer.setData("text/plain", item.dataset.faqId)
    })

    item.addEventListener("dragover", (e) => {
      e.preventDefault()
      e.dataTransfer.dropEffect = "move"
    })

    item.addEventListener("dragenter", (e) => {
      e.preventDefault()
      if (item !== this.draggedItem) {
        item.classList.add("sortable-drop-target")
      }
    })

    item.addEventListener("dragleave", (e) => {
      if (!item.contains(e.relatedTarget)) {
        item.classList.remove("sortable-drop-target")
      }
    })

    item.addEventListener("drop", (e) => {
      e.preventDefault()
      e.stopPropagation()
      item.classList.remove("sortable-drop-target")

      if (!this.draggedItem || item === this.draggedItem) return

      const list = item.parentNode
      const allItems = this.items
      const draggedIdx = allItems.indexOf(this.draggedItem)
      const targetIdx = allItems.indexOf(item)

      if (draggedIdx < targetIdx) {
        list.insertBefore(this.draggedItem, item.nextSibling)
      } else {
        list.insertBefore(this.draggedItem, item)
      }

      this.saveOrder()
    })

    item.addEventListener("dragend", () => {
      this.items.forEach(i => {
        i.classList.remove("sortable-dragging")
        i.classList.remove("sortable-drop-target")
      })
      this.draggedItem = null
    })
  }

  saveOrder() {
    const ids = this.items.map(i => i.dataset.faqId)
    const token = document.querySelector('meta[name="csrf-token"]')?.content

    fetch(this.urlValue, {
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
        "X-CSRF-Token": token,
        "Accept": "text/html"
      },
      body: "faq_ids=" + encodeURIComponent(ids.join(","))
    })
  }
}
