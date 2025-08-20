import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="tabs"
export default class extends Controller {
  static targets = ["tab", "link"]
  static values = { defaultTab: String }

  connect() {
    // Set the default active tab if specified
    if (this.hasDefaultTabValue) {
      this.showTab({ target: { dataset: { tabName: this.defaultTabValue } } })
    }
  }

  showTab(event) {
    event.preventDefault()
    
    const tabName = event.target.dataset.tabName
    if (!tabName) return

    // Hide all tab contents
    this.tabTargets.forEach(tab => {
      tab.classList.remove('active')
    })
    
    // Remove active class from all tab links
    this.linkTargets.forEach(link => {
      link.classList.remove('active')
    })
    
    // Show selected tab content
    const selectedTab = document.getElementById(tabName + '-tab')
    if (selectedTab) {
      selectedTab.classList.add('active')
    }
    
    // Add active class to clicked tab link
    event.target.classList.add('active')
  }
}